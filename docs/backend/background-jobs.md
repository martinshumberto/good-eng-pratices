# Background Jobs

> **TL;DR.** Tudo que não precisa de resposta imediata deve sair do request. Use filas com workers, projete jobs idempotentes, configure retries com backoff e DLQ, e monitore tempo em fila + taxa de erro como métricas de primeira classe.

## O quê

**Background jobs** (também *async jobs*, *workers*, *tasks*) são unidades de trabalho **executadas fora do request HTTP**. Em vez de processar dentro do controller e devolver a resposta, o controller **enfileira** o trabalho; um *worker* o processa depois.

Casos típicos:

- **Envio de email / notificação.**
- **Geração de PDF / relatório.**
- **Sincronização com sistema externo.**
- **Processamento de imagem / vídeo.**
- **Webhook delivery.**
- **Recálculos batch (agregações, scoring).**
- **Importação / exportação de dados grandes.**
- **Cron, tarefas agendadas.**

## Por quê

Empurrar trabalho para o background dá:

- **Latência baixa no request.** Cliente recebe resposta em ms, mesmo que o trabalho real demore segundos/minutos.
- **Throughput.** O servidor HTTP não fica bloqueado em I/O lento.
- **Resiliência.** Falha em integração externa (terceiro fora do ar) não derruba a operação do usuário, fica na fila e retry depois.
- **Picos absorvidos.** Fila acumula em picos; workers processam no ritmo deles.

Custos:

- **Complexidade operacional.** Mais um runtime para deployar, monitorar, alertar.
- **Consistência eventual.** O cliente recebe "OK" mas o efeito ainda não aconteceu, UX precisa lidar.
- **Debugging mais difícil.** Logs do request + logs do worker precisam estar correlacionados.

## Como aplicar

### Componentes essenciais

```
┌────────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐
│  Producer  │ ───→ │   Queue  │ ───→ │  Worker  │ ───→ │ External │
│  (web app) │      │          │      │  pool    │      │  system  │
└────────────┘      └──────────┘      └──────────┘      └──────────┘
                          ↓                  ↓
                      ┌─────┐           ┌────────┐
                      │ DLQ │           │ Result │
                      └─────┘           │ store  │
                                        └────────┘
```

- **Producer**: quem enfileira o job (geralmente o serviço HTTP).
- **Queue / broker**: armazenamento durável dos jobs.
- **Worker**: processo separado que consome a fila.
- **Result store**: onde o status/resultado é guardado (opcional).
- **DLQ (Dead Letter Queue)**: fila de jobs que falharam definitivamente.

### Escolha do broker

| Sistema | Quando usar |
|---|---|
| **PostgreSQL** (via [pg-boss](https://github.com/timgit/pg-boss): Sidekiq Postgres) | Quando você já tem Postgres; volume baixo-médio; quer transações end-to-end |
| **Redis** (via [BullMQ](https://docs.bullmq.io): Sidekiq) | Médio volume, baixa latência; queue features ricos |
| **RabbitMQ** | Workflows complexos, routing avançado, AMQP |
| **AWS SQS / Google Pub-Sub** | Managed, ecossistema cloud, escala automática |
| **Apache Kafka** | Volume muito alto, replay, eventos como logs duráveis |
| **Temporal / Cadence** | Workflows duráveis com lógica de longa duração |

**Default sensato:** Redis com BullMQ (Node) ou Sidekiq (Ruby). Postgres é ótimo escolha "low overhead" se você já tem.

### Estrutura de um job

```ts
import { Queue, Worker, Job } from 'bullmq';
import { redis } from './redis';

interface SendEmailJob {
  to: string;
  subject: string;
  templateId: string;
  variables: Record<string, string>;
}

const emailQueue = new Queue<SendEmailJob>('email', { connection: redis });

// Producer
async function sendWelcomeEmail(user: User) {
  await emailQueue.add('send-welcome', {
    to: user.email,
    subject: 'Welcome!',
    templateId: 'welcome',
    variables: { name: user.name },
  }, {
    attempts: 5,
    backoff: { type: 'exponential', delay: 2_000 },
    removeOnComplete: { age: 86_400 },   // mantém histórico por 1 dia
    removeOnFail:     { age: 604_800 },  // mantém falhas por 7 dias
  });
}

// Worker
const emailWorker = new Worker<SendEmailJob>('email', async (job: Job<SendEmailJob>) => {
  await emailProvider.send(job.data);
}, {
  connection: redis,
  concurrency: 10,
});

emailWorker.on('failed', (job, err) => {
  logger.error({ jobId: job?.id, err }, 'email job failed');
});
```

### Princípios de design

#### 1) Jobs idempotentes

Workers podem rodar o mesmo job **várias vezes**: por timeout, crash, retry, ou consumer at-least-once. Cada execução deve ser segura:

```ts
async function processOrderJob(job: Job<{ orderId: string }>) {
  const { orderId } = job.data;

  // Check antes de agir
  const order = await db.orders.findById(orderId);
  if (order.status === 'processed') return;   // já processado

  await db.transaction(async (trx) => {
    await processOrder(orderId, trx);
    await trx.orders.update(orderId, { status: 'processed' });
  });
}
```

Ver [idempotência](./idempotency.md).

#### 2) Inputs pequenos

O payload do job deve ser **pequeno e suficiente**. Em vez de:

```ts
// ❌ Payload grande, fica desatualizado
await queue.add('process-order', { order: { /* objeto inteiro */ } });
```

Prefira:

```ts
// ✅ Job carrega o ID; worker busca a versão atual
await queue.add('process-order', { orderId: '123' });
```

Vantagens:

- Payload do job menor.
- Worker sempre opera com a versão mais recente.
- Se o objeto cresceu entre enfileirar e processar, sem problema.

#### 3) Retries com backoff exponencial

Falhas transitórias (rede instável, serviço externo lento) costumam resolver com tempo. Configure:

- **Número máximo de tentativas** (3–7 dependendo do contexto).
- **Backoff exponencial** com **jitter** (variação aleatória) para evitar thundering herd.

```
1st retry: 2s
2nd retry: 4s
3rd retry: 8s
4th retry: 16s
```

```ts
await queue.add('send-email', payload, {
  attempts: 5,
  backoff: {
    type: 'exponential',
    delay: 2_000,
  },
});
```

#### 4) Distinção entre transient e permanent failures

Nem todo erro merece retry:

- **Transient (retry):** timeout, 5xx, conexão recusada.
- **Permanent (não retry):** validação falhou, recurso não existe, 4xx geral.

```ts
async function processWebhookJob(job: Job<WebhookJob>) {
  try {
    const res = await fetch(job.data.url, { /* ... */ });
    if (res.status >= 500) throw new Error('transient_5xx');
    if (res.status >= 400) {
      // 4xx, não retry
      await job.discard();
      throw new UnrecoverableError(`webhook returned ${res.status}`);
    }
  } catch (err) {
    if (err instanceof UnrecoverableError) throw err;   // não retry
    throw err;                                          // retry
  }
}
```

BullMQ tem `job.discard()` para marcar como não-retryable.

#### 5) Dead Letter Queue (DLQ)

Jobs que falharam definitivamente vão para uma fila à parte para análise humana.

```ts
emailWorker.on('failed', async (job, err) => {
  if (job && job.attemptsMade >= (job.opts.attempts ?? 0)) {
    await deadLetterQueue.add(`dead-${job.name}`, {
      originalJob: job.data,
      error: err.message,
      failedAt: new Date(),
    });
  }
});
```

Monitore tamanho da DLQ, não-vazia continuamente é sinal de bug.

#### 6) Timeouts no job

Cada job deve ter timeout explícito. Senão, um job travado segura o worker.

```ts
const emailWorker = new Worker('email', async (job) => {
  // ...
}, { lockDuration: 60_000 });  // worker tem 60s para processar antes de soltar
```

#### 7) Concorrência controlada

Configure quantos jobs cada worker processa em paralelo. Demais pode estourar conexões com banco; de menos subutiliza recursos.

```ts
new Worker('email', handler, { concurrency: 10 });
```

Para jobs CPU-bound, igualar ao número de cores. Para I/O-bound, pode ser bem maior.

### Cron: jobs agendados

Para tarefas recorrentes, agende explicitamente:

```ts
// BullMQ, repeating job
await queue.add('daily-report', {}, {
  repeat: { pattern: '0 8 * * *' },  // todo dia às 8h
});
```

Para cron mais complexo, use ferramentas dedicadas: Temporal, Apache Airflow, Prefect, Dagster (para workflows de dados).

### Observabilidade

Métricas essenciais por queue:

- **Jobs enfileirados / processados / falhados / por segundo.**
- **Tamanho da fila (`waiting`).** Cresce indefinidamente = workers não dão conta.
- **Tempo médio em fila (latência).**
- **Tempo médio de processamento.**
- **Taxa de retries.**
- **Tamanho da DLQ.**

Use [structured logging](../observability/structured-logging.md) com `jobId`, `queueName`, `attemptNumber`, `duration`.

UIs prontas: [BullMQ Dashboard](https://docs.bullmq.io/guide/ui), [Bull Board](https://github.com/felixmosh/bull-board), [Sidekiq Web UI].

### Padrões úteis

#### Job batching

Em vez de N jobs pequenos, agrupe em 1 job maior. Reduz overhead de enfileiramento.

#### Priority queues

Quando jobs têm urgências diferentes (envio crítico vs relatório semanal), use prioridades.

```ts
await queue.add('send-critical', payload, { priority: 1 });
await queue.add('send-newsletter', payload, { priority: 10 });
```

#### Delayed jobs

Job só executa após N segundos:

```ts
await queue.add('reminder', payload, { delay: 24 * 3600 * 1000 });  // amanhã
```

#### Outbox pattern

Quando o job depende de uma operação local (criar o usuário **e** enfileirar email), use [outbox](../architecture/event-driven.md) para garantir transacionalidade.

### Workflow / coreografia de longa duração

Para fluxos com múltiplos passos, decisões e esperas longas (dias), filas simples são insuficientes. Use **workflow engines**:

- **[Temporal](https://temporal.io)**: workflows duráveis em Go: Java, TS, Python.
- **[Cadence](https://cadenceworkflow.io)**: antecessor do Temporal.
- **AWS Step Functions** / **Google Workflows**: managed.

```ts
// Temporal-style workflow (pseudo-código)
async function bookingWorkflow(orderId: string) {
  await reserveInventory(orderId);
  try {
    await chargePayment(orderId);
    await sendConfirmation(orderId);
  } catch (err) {
    await releaseInventory(orderId);   // compensação
    throw err;
  }
}
```

A engine cuida de durabilidade, retry, timer entre passos.

## Quando *não* usar

- **Operações que precisam de resposta imediata.** Login, checkout payment, usuário precisa do resultado.
- **Operações triviais (< 50ms).** O overhead de fila não compensa.
- **Quando há transação distribuída séria.** Considere saga + workflow engine.

## Conceitos relacionados

- [Idempotência](./idempotency.md), pré-requisito para retry.
- [Event-Driven Architecture](../architecture/event-driven.md), workers como event consumers.
- [Tratamento de erros](./error-handling.md).
- [Observabilidade de microsserviços](../observability/microservices-monitoring.md).

## Referências

- **Livro.** Mike Perham, *Sidekiq in Action* (Manning, 2016). Embora focado em Ruby, princípios universais.
- **Livro.** Sam Newman, *Building Microservices*, 2ª ed. (O'Reilly, 2021). Capítulo sobre comunicação assíncrona.
- **Documentação.** [BullMQ](https://docs.bullmq.io/). Filas em Redis para Node.
- **Documentação.** [Temporal](https://docs.temporal.io/). Workflow engine moderno.
- **Documentação.** [pg-boss](https://github.com/timgit/pg-boss). Filas em Postgres.
- **Artigo.** Heroku, ["Worker Dynos: Background Jobs and Queueing"](https://devcenter.heroku.com/articles/background-jobs-queueing). Tutorial conceitual.
- **Artigo.** AWS, ["Backoff and Jitter"](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/). Por que jitter importa.
- **Artigo.** Brandur Leach, ["Transactionally Staged Job Drains in Postgres"](https://brandur.org/job-drain). Padrão de outbox para jobs.
- **Site.** [microservices.io: Saga](https://microservices.io/patterns/data/saga.html). Quando jobs viram coreografia.
