# Os Três Pilares da Observabilidade

> **TL;DR.** **Logs** contam o que aconteceu. **Métricas** contam quanto e com que frequência. **Traces** contam por onde uma request passou. Os três são **complementares**: não substituem-se. Sem os três, há perguntas em produção que não dá pra responder.

## O quê

O termo **observabilidade** vem da teoria de controle (Kalman, 1960): um sistema é "observável" se você consegue inferir seu estado interno a partir das saídas externas.

Aplicado a software, popularizou-se com o livro de **Cindy Sridharan** (*Distributed Systems Observability*, O'Reilly, 2018), que propôs os **três pilares**:

| Pilar | Pergunta que responde |
|---|---|
| **Logs** | *O que aconteceu?*, eventos discretos com contexto |
| **Métricas** | *Quanto? Com que frequência? Quão rápido?*, valores numéricos agregáveis no tempo |
| **Traces** | *Por onde passou? O que demorou?*, fluxo de uma request por múltiplos serviços |

Há controvérsia sobre os "três pilares" serem suficientes (alguns autores incluem profiling, eventos, etc.), mas o modelo continua sendo a forma mais usada de pensar observabilidade.

## Por quê

Cada pilar pega informação que os outros não pegam:

- **Logs** sem agregação respondem "o que aconteceu **agora, neste request**". Bons para diagnóstico pontual.
- **Métricas** agregam. Respondem "qual a tendência?", "qual o P99?", não dizem nada sobre um request específico.
- **Traces** mostram dependências em runtime. Respondem "qual chamada está demorando?" e "quem chama quem?".

Confiar só em um deixa lacunas:

- Só logs → caro de buscar, sem visão agregada, sem fluxo.
- Só métricas → não sabe **por que** algo está mal.
- Só traces → ótimos para diagnóstico, mas não para alerta agregado.

> "The output of any service or system should be such that an observer can determine its internal state."
> (Cindy Sridharan)

## Como aplicar

### Pilar 1: Logs

**O que são:** registros discretos de eventos com timestamp e contexto.

**Tipos:**

- **Application logs**: emitidos pelo seu código (request started, user logged in).
- **Access logs**: emitidos pelo servidor web/proxy (one line per request).
- **Audit logs**: registros de ações sensíveis para compliance.
- **System logs**: kernel, init, daemons.

**Estrutura recomendada:**

Use **structured logging** (JSON), não texto livre. Permite filtrar, agregar, alertar.

```json
{
  "timestamp": "2024-08-15T10:23:45.123Z",
  "level":     "info",
  "service":   "orders",
  "version":   "1.2.3",
  "msg":       "order created",
  "orderId":   "ord_42",
  "customerId":"cus_7",
  "amount":    150.0,
  "currency":  "BRL",
  "traceId":   "abc123",  // ← correlação com traces
  "spanId":    "def456",
  "duration_ms": 23
}
```

Ver [Structured Logging](./structured-logging.md) para detalhes.

**Centralização:** logs locais não servem em produção. Mandem todos para um destino central (ELK/OpenSearch, Loki, Splunk, Datadog Logs, Cloud Logging, etc).

### Pilar 2: Métricas

**O que são:** valores numéricos agregáveis no tempo. Baixo custo de armazenamento, alta densidade.

**Tipos de métrica (modelo Prometheus / OTel):**

- **Counter**: contador monotônico (só sobe). Ex.: `http_requests_total`.
- **Gauge**: valor instantâneo. Ex.: `cpu_usage_percent`, `queue_size`.
- **Histogram**: distribuição de valores em buckets. Ex.: `http_request_duration_seconds`.
- **Summary**: similar a histogram, com quantis pré-calculados.

**O que medir, RED, USE, Golden Signals**

#### RED: para serviços (Tom Wilkie)

- **Rate**: requests por segundo.
- **Errors**: taxa de erro.
- **Duration**: tempo de resposta.

#### USE: para recursos (Brendan Gregg)

- **Utilization**: % do tempo ocupado.
- **Saturation**: quanto trabalho está enfileirado.
- **Errors**: taxa de erro.

#### Four Golden Signals (Google SRE)

- Latency
- Traffic
- Errors
- Saturation

Não são listas exclusivas, escolha a que faz sentido. **Comece sempre com RED para todo serviço HTTP**.

**Exemplo prático:**

```ts
import { Counter, Histogram, register } from 'prom-client';

const requestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total de requests HTTP',
  labelNames: ['method', 'path', 'status'],
});

const requestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duração de requests HTTP',
  labelNames: ['method', 'path', 'status'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
});

// Middleware
app.use((req, res, next) => {
  const end = requestDuration.startTimer({ method: req.method, path: req.route?.path });
  res.on('finish', () => {
    const labels = { method: req.method, path: req.route?.path, status: res.statusCode };
    requestsTotal.inc(labels);
    end(labels);
  });
  next();
});

// Endpoint de scrape
app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', register.contentType);
  res.send(await register.metrics());
});
```

**Cuidado com cardinalidade**

Métricas com muitos labels diferentes (ex.: `userId`) explodem o armazenamento. Mantenha **labels com valores bounded** (status, path, region, env), não IDs.

### Pilar 3: Traces

**O que são:** registros do **caminho** de uma request por múltiplos componentes, com timestamps por etapa.

**Conceitos:**

- **Trace**: uma operação end-to-end, identificada por `traceId`.
- **Span**: uma unidade de trabalho dentro do trace (ex.: "chamou DB", "fez HTTP request"). Cada span tem `spanId`, `parentSpanId`, `start`, `end`, atributos.

```
Trace: abc123 (request to /orders)
│
├── Span: HTTP GET /orders        (500ms)
│   │
│   ├── Span: authMiddleware       (5ms)
│   │
│   ├── Span: db.query SELECT ...  (300ms)  ← gargalo
│   │
│   └── Span: render JSON          (10ms)
```

**Propagação de contexto:**

Para um trace cruzar serviços, o `traceId` precisa ser propagado em headers HTTP (padrão [W3C Trace Context](https://www.w3.org/TR/trace-context/)):

```http
traceparent: 00-abc123def456789-0123456789abcdef-01
```

Bibliotecas (OTel, Datadog, Honeycomb) injetam e extraem automaticamente quando configuradas em middlewares.

**O que registrar como span:**

- HTTP requests (entrada e saída).
- Queries de banco.
- Operações em fila (publish/consume).
- Chamadas a APIs externas.
- Computações pesadas (com cuidado para não inflar).

**Ferramentas:**

- **[Jaeger](https://www.jaegertracing.io)**: open source, padrão de fato.
- **[Tempo](https://grafana.com/oss/tempo/)**: Grafana, integra com Loki/Prometheus.
- **[Zipkin](https://zipkin.io)**: clássico, ainda usado.
- **Datadog APM**, **Honeycomb**, **Lightstep**, **New Relic**: managed.

### Como os pilares conversam: correlação

A força vem de **conectar os três**:

```
Métrica:     http_requests_total{status="500"} subiu  →  alerta
↓
Trace:       traceId=abc123 com erro em /orders     →  identifica o span de erro
↓
Logs:        traceId=abc123 → todos os logs daquela request → contexto
```

Para isso funcionar, **incluir `traceId` em logs** é crucial. SDKs de OTel fazem automaticamente em vários frameworks.

### Sampling

Em alta escala, **gravar 100%** de traces e logs custa caro. Estratégias:

- **Head-based sampling**: decide na origem (ex.: 1% das requests, todos os erros).
- **Tail-based sampling**: coletor decide ao final, baseado em propriedades do trace (sempre erros, sempre lentos).

OTel Collector suporta tail-based sampling configurável.

### O que **não** está nos três pilares

Há perspectivas modernas (Charity Majors, Honeycomb) argumentando que "pilares" são um framework limitado, e que o **evento estruturado** com alta cardinalidade é mais útil. Ver [Charity Majors ("Observability) A 3-year retrospective"](https://thenewstack.io/observability-a-3-year-retrospective/) (2020). Não invalida os pilares, refina a discussão.

## Quando *não* usar

- **Aplicações simples sem produção real.** Logs locais bastam para protótipos.
- **CLI tools e scripts.** Print/stderr é suficiente.
- **Quando você não vai olhar.** Investir em observabilidade sem cultura de operação é desperdício.

## Conceitos relacionados

- [Structured logging](./structured-logging.md)
- [SLO: SLI, SLA](./slo-sli-sla.md), métricas que viram compromisso.
- [Alerting](./alerting.md), derivado das métricas.
- [Health checks](./health-checks.md), endpoint específico para orquestrador.
- [OpenTelemetry](./opentelemetry.md), padrão unificador.

## Referências

- **Livro.** Cindy Sridharan, *Distributed Systems Observability* (O'Reilly, 2018). [PDF gratuito](https://www.oreilly.com/library/view/distributed-systems-observability/9781492033431/). Texto fundador moderno.
- **Livro.** *Site Reliability Engineering* (Google), capítulo 6: ["Monitoring Distributed Systems"](https://sre.google/sre-book/monitoring-distributed-systems/). Golden Signals.
- **Livro.** Charity Majors, Liz Fong-Jones, George Miranda, *Observability Engineering* (O'Reilly, 2022). Visão moderna (Honeycomb).
- **Artigo.** Tom Wilkie, ["The RED Method"](https://www.weave.works/blog/the-red-method-key-metrics-for-microservices-architecture/). Mais relevante para serviços.
- **Artigo.** Brendan Gregg, ["USE Method"](https://www.brendangregg.com/usemethod.html). Mais relevante para recursos.
- **Site.** [opentelemetry.io](https://opentelemetry.io). Padrão unificado para os três pilares.
- **Site.** [Honeycomb Glossary](https://www.honeycomb.io/glossary/observability). Boas definições.
- **Spec.** [W3C Trace Context](https://www.w3.org/TR/trace-context/). Padrão de propagação.
