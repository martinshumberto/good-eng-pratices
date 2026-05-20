# Structured Logging

> **TL;DR.** Logs em **JSON** com campos consistentes (service, version, level, traceId, requestId), não texto livre. Permite filtrar, agregar e correlacionar. Sem PII. Sem `console.log`. Em produção, todos os logs vão para um destino central.

## O quê

**Structured logging** é a prática de emitir logs como **objetos** com campos nomeados, em vez de strings concatenadas. Cada log entry é parseable por máquina (geralmente JSON), preservando tipos (números são números, datas são datas).

```text
❌ Texto livre, difícil de parsear, sem tipos
[2024-08-15 10:23] INFO User user_42 placed order ord_99 for $150.50

✅ Estruturado, filtra por qualquer campo
{"ts":"2024-08-15T10:23:45.123Z","level":"info","service":"orders","msg":"order placed","userId":"user_42","orderId":"ord_99","amount":150.50,"currency":"BRL","traceId":"abc123"}
```

A diferença é fundamental para qualquer análise não-trivial. Ferramentas modernas de log (Loki, ELK, Splunk, Datadog Logs) **dependem** de estrutura para indexar e filtrar.

## Por quê

Logs estruturados resolvem três problemas:

1. **Buscabilidade.** "Quero todos os erros do serviço X nos últimos 30min, agrupados por endpoint", trivial com JSON, infame com regex em texto.
2. **Correlação.** Incluir `traceId`/`requestId` em cada log permite seguir um request por múltiplos serviços (ver [traces](./three-pillars.md)).
3. **Custo.** Indexação por campos estruturados é **muito** mais barata e rápida que full-text search em strings grandes.

Custo? Marginal. Bibliotecas modernas (Pino, Winston, Bunyan, Zap, Zerolog) emitem JSON com performance equivalente (ou superior) a printf.

## Como aplicar

### Bibliotecas em TypeScript/Node

| Library | Notas |
|---|---|
| **[Pino](https://getpino.io)** | Recomendada. Mais rápida do ecossistema: JSON nativo. |
| **[Winston](https://github.com/winstonjs/winston)** | Tradicional, muito configurável. |
| **Bunyan** | Veterano, pioneiro em JSON logs. |

```ts
import pino from 'pino';

export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  base: {
    service: process.env.SERVICE_NAME,
    version: process.env.SERVICE_VERSION,
    env:     process.env.NODE_ENV,
  },
  formatters: {
    level: (label) => ({ level: label }),  // "level": "info" em vez de "level": 30
  },
  timestamp: () => `,"ts":"${new Date().toISOString()}"`,
});

// Uso
logger.info({ orderId, amount }, 'order created');
logger.error({ err, orderId }, 'failed to charge card');
```

### Campos padronizados

Defina um **schema mínimo** que todo log do projeto inclui:

| Campo | Sempre? | Conteúdo |
|---|---|---|
| `ts` | sim | Timestamp ISO-8601 com timezone (preferencialmente UTC) |
| `level` | sim | `debug` / `info` / `warn` / `error` / `fatal` |
| `service` | sim | Nome do serviço |
| `version` | sim | Versão do serviço (git SHA ou semver) |
| `env` | sim | `dev` / `staging` / `prod` |
| `msg` | sim | Mensagem humana, curta |
| `traceId` | em request | ID do trace ([W3C](https://www.w3.org/TR/trace-context/)) |
| `spanId` | em request | ID do span |
| `requestId` | em request | UUID do request (correlação) |
| `userId` | quando aplicável | ID do usuário autenticado |
| `err` | em erro | Objeto com `name`, `message`, `stack` |

### Níveis: convenção e uso

| Nível | Quando usar |
|---|---|
| `trace` / `debug` | Detalhes para desenvolvimento. Desligado em produção. |
| `info` | Eventos normais e esperados. "Order created", "user logged in". |
| `warn` | Algo suspeito mas não-crítico. Deprecation usado, retry necessário. |
| `error` | Falha em operação que não deveria falhar. Investigação necessária. |
| `fatal` | Erro que mata o processo / requer reinicialização. |

Cuidado com **excesso de `info`**. Em alto volume, logs custam (storage, ingestão, processamento). Logue eventos com **significado**, não passos triviais.

### Mensagem vs contexto

```ts
// ❌ Tudo na mensagem, não-buscável por campo
logger.info(`User ${userId} placed order ${orderId} for $${amount}`);

// ✅ Mensagem curta + campos estruturados
logger.info({ userId, orderId, amount }, 'order placed');
```

A mensagem (`msg`) é a "etiqueta" do evento. Os campos são os **dados**.

### Erros estruturados

Bibliotecas modernas serializam `Error` automaticamente, capturando stack:

```ts
try {
  await chargeCard(order);
} catch (err) {
  logger.error({ err, orderId: order.id }, 'failed to charge card');
}

// Output:
// {
//   "level": "error",
//   "msg": "failed to charge card",
//   "orderId": "ord_42",
//   "err": {
//     "type": "PaymentDeclinedError",
//     "message": "Insufficient funds",
//     "stack": "PaymentDeclinedError: ..."
//   }
// }
```

Inclua sempre o **contexto** do erro junto (IDs envolvidos).

### Correlação com traces: `traceId`

Em middlewares de framework HTTP, configure o logger para **incluir traceId automaticamente** em cada log do request:

```ts
import { context, trace } from '@opentelemetry/api';

app.use((req, res, next) => {
  const span = trace.getSpan(context.active());
  const sc   = span?.spanContext();

  // Cria um "child logger" com contexto
  req.log = logger.child({
    traceId:   sc?.traceId,
    spanId:    sc?.spanId,
    requestId: req.headers['x-request-id'] ?? crypto.randomUUID(),
  });

  next();
});

// Em handlers
req.log.info({ orderId }, 'creating order');
```

Resultado: todos os logs daquele request carregam o mesmo `traceId` → busca no log central retorna o caminho completo.

### Sampling: alto volume

Em produção com milhões de requests/dia, logar tudo é caro. Estratégias:

- **Reduza level em produção.** `info` só em fluxos significativos; `debug` desligado.
- **Sample logs de sucesso.** 100% de erros, 1% de sucessos.
- **Mantenha 100% em paths sensíveis.** Pagamento, autenticação, mudança de senha.

```ts
function logRequest(req, res, durationMs) {
  const isError = res.statusCode >= 500;
  const isSlow  = durationMs > 1000;

  if (isError || isSlow || Math.random() < 0.01) {
    logger.info({
      method: req.method,
      path:   req.url,
      status: res.statusCode,
      duration_ms: durationMs,
    }, 'request');
  }
}
```

### O que **não** logar: PII / segurança

Logs frequentemente são acessíveis por mais pessoas que o banco. Não logue:

- **Senhas, tokens, API keys**: em hipótese alguma.
- **Cartões de crédito**: proibido pelo PCI-DSS.
- **CPF, RG, endereço completo**: LGPD/GDPR.
- **Conteúdo de mensagens privadas, anexos.**

Quando precisa identificar o usuário, use **pseudonyms** (`userId`, `customerId`), não nome+email no log.

Para campos que **às vezes** vazam dados sensíveis (request body cru, query parameters), use **redação automática**:

```ts
const logger = pino({
  redact: {
    paths: ['req.headers.authorization', 'req.body.password', 'req.body.card.number'],
    censor: '[REDACTED]',
  },
});
```

### Onde logar: destino central

Logs **locais** em produção não servem. Em qualquer ambiente sério:

- **Aplicações escrevem em stdout/stderr** (12-factor).
- **Plataforma coleta e envia** para destino central.
  - Kubernetes: Fluent Bit / Fluentd → Loki / ELK / Splunk.
  - Cloud Run / GAE: Cloud Logging nativo.
  - AWS Lambda: CloudWatch nativo.
- **Armazenamento de longa duração**: após N dias, mova para object storage barato (S3, GCS).

### Performance: não mate o app

Em hot paths, logar pesado é gargalo. Boas práticas:

- **Pino é rápido.** Considere especificamente esta lib em Node se latência importa.
- **Don't stringify before logging.** Bibliotecas modernas serializam apenas se o log será emitido.
- **Avoid heavy `child()` creation per request.** Use middleware uma vez por request.

### Convenção do projeto

Documente em algum lugar central (ADR, README de plataforma):

- Qual library oficial.
- Schema dos campos obrigatórios.
- Convenções de mensagens (idioma, modo imperativo / passado).
- Política de retenção.
- Quais campos são sensíveis e devem ser redacted.

## Quando *não* usar

- **CLI tools / scripts.** Texto livre simples é mais legível por humanos em terminal.
- **Tests**: `console.log` em testes é OK (e geralmente removido depois).
- **Sistemas extremamente embedded**: onde JSON parsing custa recursos.

## Conceitos relacionados

- [Os três pilares](./three-pillars.md), logs como um pilar.
- [OpenTelemetry](./opentelemetry.md), instrumentação unificada.
- [Tratamento de erros](../backend/error-handling.md), onde erros se conectam aos logs.
- [Twelve-Factor App](../delivery/twelve-factor-app.md): XI. Logs como streams de eventos.
- [OWASP (Logging](../security/owasp-top-10.md)) práticas seguras.

## Referências

- **Livro.** Cindy Sridharan, *Distributed Systems Observability* (O'Reilly, 2018). Capítulo sobre logs.
- **Livro.** Charity Majors, Liz Fong-Jones, George Miranda, *Observability Engineering* (O'Reilly, 2022).
- **Documentação.** [Pino: Best Practices](https://getpino.io/#/docs/help). Excelente guia prático.
- **Documentação.** [Twelve-Factor App: Logs](https://12factor.net/logs). Princípio "treat logs as event streams".
- **Site.** [OpenTelemetry Logs](https://opentelemetry.io/docs/concepts/signals/logs/). Spec moderna.
- **Artigo.** Brandur Leach, ["Logging at Stripe"](https://stripe.com/blog/canonical-log-lines) (2019). Padrão de "canonical log line", um log por request resume tudo.
- **Artigo.** Google Cloud, ["Structured logging"](https://cloud.google.com/logging/docs/structured-logging). Boa intro.
- **Site.** [OWASP: Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html). Aspectos de segurança.
