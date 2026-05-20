# Event-Driven Architecture

> **TL;DR.** Componentes comunicam-se publicando e consumindo **eventos**: fatos que aconteceram no sistema. Reduz acoplamento, habilita extensibilidade e processamento assíncrono, ao custo de complexidade em consistência e debugging.

## O quê

**Event-Driven Architecture (EDA)** é um estilo arquitetural onde componentes reagem a **eventos**: registros imutáveis de algo que aconteceu, em vez de chamar uns aos outros diretamente.

Quatro estilos comuns ([Fowler, 2017](https://martinfowler.com/articles/201701-event-driven.html)):

| Estilo | O quê |
|---|---|
| **Event Notification** | Componentes publicam eventos para sinalizar mudanças. Listeners reagem como acharem melhor. |
| **Event-Carried State Transfer** | O evento carrega todo o estado relevante; consumidores podem agir sem consultar o publisher. |
| **Event Sourcing** | O estado é derivado do log completo de eventos, fonte de verdade muda do "tabela" para "log". |
| **CQRS** | Modelos separados para escrita (command) e leitura (query). Frequentemente combinado com event sourcing. |

São estilos independentes que podem ser combinados.

## Por quê

EDA endereça três problemas típicos de arquiteturas síncronas:

1. **Acoplamento.** Em `A → B → C → D`, A precisa conhecer (ou pelo menos depender de) toda a cadeia. Em EDA, A só publica "aconteceu X"; quem se interessa reage.
2. **Extensibilidade.** Adicionar um consumidor novo (novo serviço, novo relatório) não exige alterar quem publica.
3. **Resiliência e throughput.** Operações lentas (envio de email, geração de PDF) saem do caminho crítico do request.

Custos correspondentes:

- **Consistência eventual.** O sistema não fica "instantaneamente" consistente.
- **Debugging mais difícil.** Stack trace local não revela o fluxo distribuído, precisa de tracing.
- **Garantias da fila.** "At-least-once", "at-most-once", "exactly-once", escolha consciente exigida.

## Como aplicar

### Modelagem de eventos

Eventos representam **fatos no passado**: algo que aconteceu, no tense passado:

```ts
// ✅ Evento
type OrderPlaced = {
  eventType: 'OrderPlaced';
  occurredAt: string;       // ISO-8601
  orderId: string;
  customerId: string;
  items: Array<{ productId: string; quantity: number; price: number }>;
  total: { amount: number; currency: string };
};

// ❌ Não é evento, é comando
type PlaceOrder = {
  eventType: 'PlaceOrder';
  /* ... */
};
```

**Comandos** ("Faça X") são diferentes de **eventos** ("X aconteceu"). Comandos vão para um destinatário específico; eventos são fatos que qualquer um pode consumir.

### Princípios para schemas de evento

- **Imutáveis.** Um evento publicado nunca é alterado.
- **Versionados.** Inclua `version` para suportar evolução: `OrderPlaced v1` → `v2`.
- **Auto-contidos.** Quem consome não deveria precisar fazer uma chamada para entender o evento (princípio do *event-carried state transfer*).
- **Nomeados no passado.** `OrderPlaced`, `PaymentSucceeded`, `EmailDelivered`.

### Tipos de evento por audiência

- **Internal events**: circulam dentro de um bounded context. Detalhados, rico em domínio.
- **Integration events**: atravessam fronteiras de contexto (entre microsserviços). Mais estáveis, com schema versionado rigorosamente.

Não publique seus internal events para outros contextos diretamente, eles vazam detalhes do domínio interno.

### Broker / message infrastructure

Algumas opções:

| Sistema | Modelo | Quando |
|---|---|---|
| **Apache Kafka** | Log particionado, replay nativo | Throughput alto, event sourcing, analytics |
| **RabbitMQ** | Queue tradicional, exchanges flexíveis | Workflows, padrão de filas |
| **AWS SQS / SNS** | Managed, simples | AWS-native, casos simples |
| **NATS / NATS JetStream** | Light-weight, performance alta | Sistemas com muitos serviços |
| **Google Pub/Sub** | Managed, escala automaticamente | GCP-native |
| **Redis Streams** | Light-weight | Casos médios, simplicidade |

A escolha depende de garantias (ordering, retention, replay) e do ecossistema.

### Garantias de entrega

- **At-most-once.** Mensagem pode ser perdida; nunca duplicada. Raro na prática.
- **At-least-once.** Mensagem nunca é perdida; pode ser duplicada. **Mais comum.** Exige consumidores idempotentes.
- **Exactly-once.** Mensagem é entregue exatamente uma vez. Difícil e caro, frequentemente uma ilusão.

A maioria dos sistemas garantem **at-least-once**, então o **consumidor deve ser idempotente**:

```ts
async function handleOrderPlaced(event: OrderPlaced) {
  // Use o eventId / orderId como chave de idempotência
  const already = await db.processedEvents.findOne({ eventId: event.eventId });
  if (already) return;   // já processado

  await db.orders.insert({ /* ... */ });
  await db.processedEvents.insert({ eventId: event.eventId, at: new Date() });
}
```

Ver [idempotência](../backend/idempotency.md).

### Outbox pattern: publish reliably

Problema: como garantir que um evento é publicado **se e somente se** a transação local foi confirmada?

```
❌ Race condition
  await db.save(order);
  await broker.publish(event);   // pode falhar, banco já tem; consumidor não recebe
```

Solução: **outbox**: grava o evento na mesma transação que persiste a mudança; um processo separado lê o outbox e publica.

```sql
BEGIN;
  INSERT INTO orders (...) VALUES (...);
  INSERT INTO outbox (event_type, payload) VALUES ('OrderPlaced', ...);
COMMIT;
```

Um *relay* lê `outbox`, publica no broker, marca como sent. Garantia: ou ambos foram persistidos, ou nenhum.

### Event Sourcing: quando faz sentido

Em vez de armazenar **o estado atual**, armazene o **log de eventos** que levou a ele. O estado é derivado por *replay*.

Benefícios:

- **Histórico completo.** Cada mudança é auditável.
- **Time travel.** Reconstruir estado em qualquer ponto do tempo.
- **Projeções múltiplas.** Mesma fonte gera várias views (relatórios, dashboards).

Custos:

- **Complexidade.** Eventos antigos podem ter schemas antigos, versionar é trabalho.
- **Não-trivial de consultar.** Queries em log de eventos não são SQL, precisa de projeções materializadas.
- **Snapshotting.** Replay de milhões de eventos é lento; precisa de snapshots periódicos.

Use event sourcing quando o **histórico é parte do domínio** (auditoria financeira, log de mudanças em entidades regulamentadas) ou quando você precisa de múltiplas projeções da mesma fonte.

### CQRS

Separa modelos:

- **Command model**: recebe escritas, aplica regras de negócio, persiste eventos/mudanças.
- **Query model**: projeção otimizada para leituras (geralmente desnormalizada).

```
Client → Command → Command Handler → Event → Event Handler → Query Store
                                              ↑                   ↓
                                              └─── Aggregate     Client ← Query
```

Frequentemente combinado com event sourcing, mas não obrigatório.

### Padrão Saga: transações distribuídas

Sem transação ACID entre serviços, use **saga**: sequência de operações locais, cada uma com sua **compensação** (rollback semântico).

```
1. Reservar estoque  → compensação: liberar estoque
2. Cobrar pagamento  → compensação: estornar
3. Confirmar pedido  → (sem compensação)
```

Se a etapa 3 falhar, executar as compensações de 2 e 1 na ordem inversa.

Duas formas:

- **Choreography**: cada serviço escuta eventos e age sem coordenador central. Mais desacoplado, mais difícil de visualizar.
- **Orchestration**: um *saga orchestrator* coordena explicitamente. Mais legível, ponto único de orquestração.

## Quando *não* usar

- **Operações que exigem feedback síncrono ao usuário.** "O pagamento passou?" geralmente precisa de resposta na hora.
- **Sistemas com domínio simples.** EDA agrega complexidade, só vale a pena se traz benefício correspondente.
- **Equipe sem maturidade em sistemas distribuídos.** EDA exige conforto com consistência eventual, idempotência, debugging distribuído.
- **Quando consistência forte é requisito.** Sistemas financeiros podem usar EDA para integração, mas o core transacional costuma ser síncrono e ACID.

## Conceitos relacionados

- [Microsserviços](./microservices.md), comunicação assíncrona típica.
- [Domain-Driven Design](./domain-driven-design.md), domain events vêm do DDD tático.
- [Idempotência](../backend/idempotency.md), pré-requisito para consumidores at-least-once.

## Referências

- **Livro.** Martin Kleppmann, *Designing Data-Intensive Applications* (O'Reilly, 2017). Parte III ("Derived Data") é referência sobre eventos, streams, event sourcing.
- **Livro.** Chris Richardson, *Microservices Patterns* (Manning, 2018). Padrões de sagas, event sourcing, CQRS.
- **Livro.** Ben Stopford, *Designing Event-Driven Systems* (O'Reilly, 2018). [PDF gratuito](https://www.confluent.io/designing-event-driven-systems/). Centrado em Kafka.
- **Livro.** Adam Bellemare, *Building Event-Driven Microservices* (O'Reilly, 2020).
- **Artigo.** Martin Fowler, ["What do you mean by 'Event-Driven'?"](https://martinfowler.com/articles/201701-event-driven.html) (2017). Os 4 estilos.
- **Artigo.** Martin Fowler, ["Event Sourcing"](https://martinfowler.com/eaaDev/EventSourcing.html).
- **Artigo.** Greg Young, ["CQRS Documents"](https://cqrs.files.wordpress.com/2010/11/cqrs_documents.pdf) (2010). Texto seminal de CQRS.
- **Site.** [microservices.io: Pattern: Saga](https://microservices.io/patterns/data/saga.html), [Event Sourcing](https://microservices.io/patterns/data/event-sourcing.html), [Outbox](https://microservices.io/patterns/data/transactional-outbox.html).
