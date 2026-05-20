# OpenTelemetry

> **TL;DR.** OpenTelemetry (OTel) é o **padrão aberto** para instrumentar aplicações com traces, métricas e logs, uma API + SDK + coletor por linguagem, exportando para qualquer backend. Substitui SDKs proprietários (Jaeger, Zipkin, libs específicas) por uma camada única.

## O quê

**OpenTelemetry** é um projeto open source da [CNCF](https://www.cncf.io) (Cloud Native Computing Foundation), nascido em 2019 da fusão de **OpenTracing** + **OpenCensus**. É hoje o **segundo maior projeto** da CNCF em atividade (atrás de Kubernetes), suportado por todas as principais clouds e vendors de observabilidade.

OTel oferece:

- **APIs por linguagem**: instrumente uma vez, mude o backend depois.
- **SDK**: implementação padrão das APIs.
- **Instrumentation libraries**: instrumentação automática de frameworks comuns (HTTP, DB, queues).
- **Collector**: proxy/agente que recebe, transforma e exporta telemetria.
- **OTLP** (OpenTelemetry Protocol), formato de fio padrão.

```
   Application
   ├─ OTel API           (instrumentação manual)
   ├─ OTel SDK           (configuração: exporters, processadores)
   └─ Auto-instrumentação (HTTP, DB, queue, etc.)
        ↓ OTLP (gRPC/HTTP)
   ┌─────────────────────┐
   │  OTel Collector     │   ← processamento opcional
   └─────────┬───────────┘
             ↓
   ┌──────────────────────────────────────┐
   │ Backend (Jaeger, Tempo, Prometheus,  │
   │  Datadog, Honeycomb, Cloud, etc.)    │
   └──────────────────────────────────────┘
```

## Por quê

Antes do OTel, instrumentação era uma **dor crônica**:

- Cada backend (Jaeger, Zipkin, Datadog, New Relic) tinha SDK próprio.
- Trocar de vendor = reinstrumentar tudo.
- Cada linguagem implementava do zero.
- Logs, traces, métricas usavam libs diferentes, sem correlação.

OTel resolve:

- **Vendor neutrality.** Mesma API; exporter define o destino.
- **Cobertura por linguagem.** SDKs maduros em Go, Java, Python, JavaScript/TypeScript, .NET, Ruby, PHP, Rust, etc.
- **Unificação.** Traces, métricas e logs no mesmo SDK.
- **Adoção massiva.** Praticamente todo backend moderno aceita OTLP.

> "OpenTelemetry is the industry-standard for cloud-native observability."
> (CNCF)

## Como aplicar

### Conceitos

#### Resource

Metadados que descrevem **quem está emitindo**: service.name, service.version, deployment.environment, host.name. Inclusos automaticamente em todos os sinais.

#### Signal

Tipo de telemetria. OTel cobre três:

- **Traces** (e spans), fluxo de uma operação.
- **Metrics**: números agregados.
- **Logs**: eventos discretos.

#### Span

Unidade de trabalho no trace. Tem nome, atributos, eventos, links, tempo de início/fim, status.

```
Trace
└── Span "HTTP GET /orders"           (500ms)
    ├── Span "auth.verify"            (5ms)
    ├── Span "db.query SELECT"        (300ms)
    └── Span "render JSON"            (10ms)
```

#### Context propagation

Como o `traceId` cruza serviços. Padrão: [W3C Trace Context](https://www.w3.org/TR/trace-context/), header `traceparent`.

### Setup em Node.js / TypeScript

```bash
npm install @opentelemetry/api @opentelemetry/sdk-node \
            @opentelemetry/auto-instrumentations-node \
            @opentelemetry/exporter-trace-otlp-http \
            @opentelemetry/exporter-metrics-otlp-http
```

```ts
// telemetry.ts, carregue ANTES do resto da aplicação
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter }   from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter }  from '@opentelemetry/exporter-metrics-otlp-http';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]:    process.env.SERVICE_NAME ?? 'unknown',
    [SemanticResourceAttributes.SERVICE_VERSION]: process.env.SERVICE_VERSION ?? '0.0.0',
  }),
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT,
  }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT,
    }),
    exportIntervalMillis: 10_000,
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
```

```ts
// app.ts, carregue a telemetria primeiro!
import './telemetry';
import express from 'express';

const app = express();
// HTTP, DB, redis, etc. já estão instrumentados automaticamente.
```

### Auto-instrumentação

`@opentelemetry/auto-instrumentations-node` cobre os frameworks mais comuns:

- HTTP / HTTPS / undici / fetch
- Express / Fastify / Koa / Hapi
- PostgreSQL / MySQL / Redis / MongoDB
- gRPC
- AWS SDK / GCP / Azure
- Kafka / RabbitMQ / Bull

Você ganha traces e métricas de operações HTTP, queries SQL, etc. **sem escrever uma linha**.

### Instrumentação manual

Para operações próprias, crie spans manualmente:

```ts
import { trace, SpanStatusCode } from '@opentelemetry/api';

const tracer = trace.getTracer('orders-service');

async function processOrder(orderId: string) {
  return await tracer.startActiveSpan('process_order', async (span) => {
    span.setAttributes({ 'order.id': orderId });

    try {
      await validateOrder(orderId);
      span.addEvent('order validated');

      const result = await chargeCard(orderId);
      span.setAttribute('payment.amount', result.amount);

      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } catch (err) {
      span.recordException(err as Error);
      span.setStatus({ code: SpanStatusCode.ERROR, message: (err as Error).message });
      throw err;
    } finally {
      span.end();
    }
  });
}
```

### Métricas customizadas

```ts
import { metrics } from '@opentelemetry/api';

const meter = metrics.getMeter('orders-service');

const orderCounter = meter.createCounter('orders_created_total', {
  description: 'Total orders created',
});

const orderValue = meter.createHistogram('order_value_brl', {
  description: 'Order value distribution',
  unit: 'BRL',
});

// Em uso:
orderCounter.add(1, { customer_segment: 'pro' });
orderValue.record(150.0, { customer_segment: 'pro' });
```

### Logs com correlação

Quando OTel SDK está ativo, libs de logging modernas (Pino) integram-se automaticamente:

```ts
import pino from 'pino';

const logger = pino({
  mixin() {
    const ctx = trace.getActiveSpan()?.spanContext();
    return ctx ? { traceId: ctx.traceId, spanId: ctx.spanId } : {};
  },
});

logger.info({ orderId }, 'order created');
// → { traceId: "abc123...", spanId: "def456...", orderId: "ord_42", msg: "order created", ... }
```

Resultado: cada log do request carrega o `traceId` → busca no log central retorna o trace completo.

### O Collector

O **OpenTelemetry Collector** é um agente/proxy que:

- Recebe telemetria das aplicações (OTLP gRPC ou HTTP).
- **Processa** (sampling, filtro, atributo customizado, dedup, batching).
- **Exporta** para um ou mais backends.

```
App ─→ Collector ─→ Jaeger (traces)
              ├──→ Prometheus (metrics)
              └──→ Loki (logs)
```

Pode rodar como **agent** (sidecar/daemonset, processando o que vem do nó local) ou **gateway** (instância central que recebe de vários agents).

Configuração via YAML:

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }
      http: { endpoint: 0.0.0.0:4318 }

processors:
  batch:
    timeout: 5s
  tail_sampling:
    decision_wait: 10s
    policies:
      - { name: errors,  type: status_code,    status_code: { status_codes: [ERROR] } }
      - { name: slow,    type: latency,        latency:     { threshold_ms: 1000 } }
      - { name: sample,  type: probabilistic,  probabilistic: { sampling_percentage: 5 } }

exporters:
  otlp/jaeger:
    endpoint: jaeger:4317
    tls: { insecure: true }
  prometheus:
    endpoint: 0.0.0.0:8889

service:
  pipelines:
    traces:
      receivers:  [otlp]
      processors: [tail_sampling, batch]
      exporters:  [otlp/jaeger]
    metrics:
      receivers:  [otlp]
      processors: [batch]
      exporters:  [prometheus]
```

### Sampling: controle de volume

Em produção com alto tráfego, **gravar 100% custa caro**. Estratégias:

- **Head sampling**: decide na origem (no SDK).
- **Tail sampling**: decide no collector, depois de ver o trace todo (sempre erros, sempre lentos, X% do resto).

Tail sampling no Collector é a estratégia mais flexível.

### Semantic conventions

OTel padroniza **nomes de atributos** para que dashboards sejam reutilizáveis. Exemplos:

- `http.method`, `http.status_code`, `http.route`.
- `db.system`, `db.statement`, `db.operation`.
- `messaging.system`, `messaging.destination`.

Use **sempre que possível**: facilita ferramentas e dashboards prontos.

[OpenTelemetry Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/).

### Backends que aceitam OTLP

Praticamente todos modernos:

- **Open source:** Jaeger (traces), Prometheus (metrics, via gateway), Tempo (Grafana), Loki (logs).
- **Managed:** Datadog, New Relic, Honeycomb, Lightstep, Grafana Cloud, AWS X-Ray, GCP Cloud Trace.

Trocar de backend = mudar URL do exporter. Aplicação não muda.

### Boas práticas

- **Use auto-instrumentação como base.** Cobre 80%; escreva spans manuais para o restante.
- **Resource bem definido.** Service.name, version, environment em todo emissão.
- **Atributos com cardinalidade controlada**: `userId` como atributo de span é OK; em métrica explode.
- **Errors como exceptions recorded**: não strings.
- **Use o Collector.** Mesmo localmente em dev, vale para inspecionar pipeline.
- **Propagação automática.** SDK cuida; só **não quebre** ao serializar/deserializar requests manualmente.

### Cuidados

- **Overhead.** Auto-instrumentação tem custo (1–5% típico). Mensurável; aceitável na maioria dos casos.
- **Memória do SDK.** Spans em buffer; tenha limite de batching configurado.
- **Latência de inicialização.** Carregamento do SDK adiciona dezenas de ms; ative só em entradas que precisam.

## Quando *não* usar

- **Scripts simples / CLIs.** Overhead não se paga.
- **Aplicações sem destino para telemetria.** Não monte SDK sem ter para onde enviar.
- **Quando você precisa de algo extremamente específico do vendor.** Algumas features de plataformas managed não estão em OTel, combine.

## Conceitos relacionados

- [Os três pilares](./three-pillars.md): OTel cobre os três.
- [Structured logging](./structured-logging.md), logs OTel ainda emergentes; libs nativas + correlação manual de `traceId` é comum.
- [Health checks](./health-checks.md).
- [Monitoramento de microsserviços](./microservices-monitoring.md).

## Referências

- **Site oficial.** [opentelemetry.io](https://opentelemetry.io). Documentação central.
- **Spec.** [OTel Specification](https://opentelemetry.io/docs/specs/otel/). Padrão completo.
- **Spec.** [Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/). Padronização de atributos.
- **Documentação.** [OTel Collector](https://opentelemetry.io/docs/collector/).
- **Documentação.** [OTel JavaScript](https://opentelemetry.io/docs/languages/js/). SDK para Node/Browser.
- **Livro.** Daniel Gomez Blanco, *Practical OpenTelemetry* (Apress, 2023). Tratado prático recente.
- **Livro.** Charity Majors, Liz Fong-Jones, George Miranda, *Observability Engineering* (O'Reilly, 2022). Capítulo dedicado a OTel.
- **Artigo.** [The OpenTelemetry Bootcamp](https://learn.lightstep.com/courses/learn-opentelemetry). Curso introdutório.
- **Spec.** [W3C Trace Context](https://www.w3.org/TR/trace-context/). Padrão de propagação adotado por OTel.
