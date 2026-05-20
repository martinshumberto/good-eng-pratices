# Idempotência

> **TL;DR.** Uma operação é idempotente quando executá-la N vezes produz o mesmo efeito que executá-la 1 vez. Em sistemas distribuídos, idempotência não é luxo, é o que faz retries serem seguros. *Exactly-once* é mito; *at-least-once* + idempotente é a realidade.

## O quê

**Idempotência** é uma propriedade matemática: `f(f(x)) == f(x)`. Aplicada a operações de software, significa: executar a mesma operação várias vezes tem o mesmo efeito que executá-la uma vez.

| Operação | Idempotente? |
|---|---|
| `setStatus(order, 'PAID')` | Sim, resultado final é o mesmo |
| `incrementCounter()` | **Não**: N chamadas = N incrementos |
| `DELETE /users/42` | Sim, depois da primeira, o resultado é o mesmo |
| `POST /orders` (criar) | Por padrão **não**: N chamadas = N pedidos. **Pode ser tornada idempotente** com idempotency key. |
| `addItemToCart(item)` | Depende, se for `incrementQuantity`, não; se for `setQuantity`, sim. |

## Por quê

Em sistemas distribuídos, **falhas de rede são certas**. Um cliente que envia request sem receber resposta tem que decidir: retry ou desistir?

- Se retry e o servidor processou a primeira request, **executa duas vezes**.
- Se desiste e o servidor não processou, **operação perdida**.

A única saída sã é tornar operações **idempotentes**: retry sem medo, o servidor descarta duplicatas.

> "Exactly-once delivery is impossible. But exactly-once processing is possible if you have idempotent receivers."
> (Tyler Treat, [You Cannot Have Exactly-Once Delivery](https://bravenewgeek.com/you-cannot-have-exactly-once-delivery/) (2015))

A trinca canônica:

- **At-most-once delivery** + **non-idempotent receiver** → operações perdidas.
- **At-least-once delivery** + **non-idempotent receiver** → operações duplicadas.
- **At-least-once delivery** + **idempotent receiver** → ✅ funciona.

Idempotência é pré-requisito para:

- **Retries seguros** (cliente, fila, gateway).
- **At-least-once messaging** (Kafka, SQS, RabbitMQ).
- **Eventos de domínio** (consumidor pode receber duplicata).
- **APIs públicas confiáveis** (cliente faz retry quando timeout).

## Como aplicar

### Idempotency Key em APIs HTTP

O padrão de mercado é o cliente enviar um **identificador único** para a operação. O servidor armazena o resultado da primeira execução; chamadas subsequentes com o mesmo key retornam o resultado armazenado.

#### Cliente

```http
POST /orders HTTP/1.1
Idempotency-Key: 7f8c3e4a-1234-5678-9abc-def012345678
Content-Type: application/json

{ "items": [...] }
```

A chave é gerada **no cliente** (UUID v4/v7). O cliente reusa a mesma chave em retries da mesma operação lógica, não em operações diferentes.

#### Servidor

```ts
async function createOrder(req: Request, res: Response) {
  const key = req.header('Idempotency-Key');
  if (!key) return res.status(400).json({ error: 'idempotency_key_required' });

  // Procura o registro
  const existing = await db.idempotencyRecords.findOne({ key });

  if (existing) {
    // Retorna o resultado armazenado
    return res.status(existing.statusCode).json(existing.responseBody);
  }

  // Lock para evitar duas execuções concorrentes da mesma chave
  await db.idempotencyRecords.insert({
    key,
    status: 'in_progress',
    lockedAt: new Date(),
  });

  try {
    const order = await ordersService.create(req.body);

    await db.idempotencyRecords.update({ key }, {
      status: 'completed',
      statusCode: 201,
      responseBody: order,
    });

    return res.status(201).json(order);
  } catch (err) {
    // Apaga o registro para permitir retry
    await db.idempotencyRecords.delete({ key });
    throw err;
  }
}
```

#### Considerações

- **TTL na tabela**: não guarde idempotency keys para sempre. 24h–7 dias é razoável; ajuste pelo seu padrão de retry.
- **Validação do payload.** Algumas implementações também armazenam um hash do body, se a mesma chave vier com payload diferente, retorna `422 Unprocessable Entity`. Stripe faz assim.
- **Concorrência.** Use lock no banco (constraint UNIQUE em `key`) para evitar dupla execução em retry rápido.

### Idempotência natural via tipo de operação

Algumas operações são **naturalmente idempotentes**: não precisa de chave:

```http
PUT /users/42 { "name": "Alice" }   ✅ Idempotente
DELETE /users/42                     ✅ Idempotente
GET /users/42                        ✅ Idempotente (e seguro)
```

PUT substitui; rodar 5 vezes = 1 vez. DELETE remove; depois da primeira, é no-op.

`POST` (criar recurso) **não é** idempotente por natureza, precisa de Idempotency-Key.

### Idempotência em consumers de fila

Filas frequentemente garantem **at-least-once**: duplicatas acontecem. Consumidores devem deduplicar:

```ts
async function handleOrderPlaced(event: OrderPlaced) {
  // Use o eventId como chave de idempotência
  const seen = await db.processedEvents.findOne({ eventId: event.eventId });
  if (seen) return;  // já processado

  await db.transaction(async (trx) => {
    await processOrder(event, trx);
    await trx.processedEvents.insert({ eventId: event.eventId, at: new Date() });
  });
}
```

**Importante:** a marcação como "processado" e o efeito principal devem ser **na mesma transação**: senão você pode processar e cair antes de marcar, voltando à estaca zero.

### Outbox para garantir publicação idempotente

Quando o serviço precisa **publicar** um evento após uma operação local, há um problema:

```ts
// ❌ Race: pode persistir e cair antes de publicar
await db.save(order);
await broker.publish('OrderPlaced', event);
```

Solução: **outbox pattern**: grava o evento na mesma transação; um processo separado publica.

```sql
BEGIN;
  INSERT INTO orders (...) VALUES (...);
  INSERT INTO outbox (event_type, payload, status) VALUES ('OrderPlaced', ..., 'pending');
COMMIT;
```

Um *relay* lê `outbox WHERE status = 'pending'`, publica, marca como `sent`. Se cair entre publicar e marcar, vai publicar de novo, daí a importância do **consumer ser idempotente**.

### Compensações (sagas) também precisam ser idempotentes

Em sagas, cada passo tem uma compensação. Tanto a operação quanto a compensação podem ser retried. Ambas devem ser idempotentes.

```
Reservar estoque  → liberar estoque
Cobrar pagamento  → estornar pagamento
```

"Liberar estoque" rodando 2 vezes não pode liberar duas vezes. "Estornar" rodando 2 vezes não pode estornar duas vezes.

### Padrões de implementação

#### Stateless idempotency via natural key

Se o domínio tem uma chave natural (`order.id`, `transaction.id`), o `INSERT ... ON CONFLICT` resolve naturalmente:

```sql
INSERT INTO orders (id, customer_id, total)
VALUES ($1, $2, $3)
ON CONFLICT (id) DO NOTHING
RETURNING *;
```

Se o cliente envia o `id` (UUID gerado lá), o servidor é idempotente sem extra logic.

#### Conditional updates (compare-and-set)

Para evitar overwrite acidental:

```sql
UPDATE orders
SET status = 'paid', updated_at = NOW()
WHERE id = $1 AND status = 'placed';
```

Se a primeira request mudou de `placed` para `paid`, a segunda não tem efeito, não acha o registro com `status = 'placed'`.

#### Use upsert quando faz sentido

```sql
INSERT INTO settings (user_id, key, value)
VALUES ($1, $2, $3)
ON CONFLICT (user_id, key) DO UPDATE SET value = EXCLUDED.value;
```

Setar a mesma key duas vezes não muda nada de relevante.

### Cuidados

- **Side effects externos (cobranças, e-mails).** Cobrança duplicada não é "no-op", é fraude operacional. Idempotency-Key é **obrigatório** em payment APIs.
- **Logs com timestamps.** Logar a mesma operação várias vezes pode confundir auditoria. Identifique o evento por ID e dedupe na análise.
- **Métricas e contadores.** "Incrementou 5 vezes" gera 5 incrementos. Garanta deduplicação na pipeline (eventos com eventId).

## Quando *não* usar

- **Comandos genuinamente ações** (não-recursos): "tocar a campainha agora", naturalmente não idempotente, e está tudo bem.
- **Operações cuja semântica exige cada execução** (auditoria de tentativas, contadores de acesso). Mas frequentemente o que parece exigir contagem real é resolvido com IDs por tentativa.
- **Quando a infraestrutura garante exactly-once de verdade.** Sistemas como Kafka EOS para consumers + transactional outbox conseguem; ainda assim, defender em profundidade com idempotência no consumer é sensato.

## Conceitos relacionados

- [Event-Driven Architecture](../architecture/event-driven.md), outbox pattern, at-least-once.
- [API design (REST](./api-design-rest.md)) métodos idempotentes vs não.
- [Background jobs](./background-jobs.md), retries e deduplicação.
- [Tratamento de erros](./error-handling.md).

## Referências

- **Artigo.** Stripe, ["Designing robust and predictable APIs with idempotency"](https://stripe.com/blog/idempotency) (2017). Texto canônico sobre Idempotency-Key. Referência de implementação na indústria.
- **Artigo.** Tyler Treat, ["You Cannot Have Exactly-Once Delivery"](https://bravenewgeek.com/you-cannot-have-exactly-once-delivery/) (2015). Argumento clássico sobre o limite teórico.
- **Artigo.** Pat Helland, ["Idempotence Is Not a Medical Condition"](https://queue.acm.org/detail.cfm?id=2187821) (ACM Queue, 2012). Texto fundamental, pelo arquiteto da Amazon/Microsoft.
- **Artigo.** Aphyr (Kyle Kingsbury), ["Strong consistency models"](https://aphyr.com/posts/313-strong-consistency-models) (2014). Contexto sobre garantias em sistemas distribuídos.
- **Documentação.** [Stripe API: Idempotent Requests](https://stripe.com/docs/api/idempotent_requests). Spec da implementação.
- **Site.** [microservices.io: Pattern: Idempotent Consumer](https://microservices.io/patterns/communication-style/idempotent-consumer.html).
- **RFC (draft).** [The Idempotency-Key HTTP Header](https://datatracker.ietf.org/doc/draft-ietf-httpapi-idempotency-key-header/) (IETF, em discussão). Padronização do header.
