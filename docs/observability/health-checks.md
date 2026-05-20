# Health Checks

> **TL;DR.** Distinga **liveness** (estou vivo? (reinicie se não), **readiness** (posso receber tráfego?) retire do balanço se não) e **startup** (já inicializei?, espere antes de checar). Não cheque dependências externas no liveness; cheque com cuidado no readiness.

## O quê

**Health check** é um endpoint (ou mecanismo equivalente) que sinaliza ao orquestrador, load balancer ou monitor: **o serviço está saudável?**

Em Kubernetes, existem **três tipos distintos** ([documentação oficial](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)), e a confusão entre eles é uma das fontes mais comuns de problemas em produção:

| Probe | Pergunta | Falha → |
|---|---|---|
| **Liveness** | Estou vivo? | Reinicia o pod |
| **Readiness** | Posso receber tráfego? | Retira do load balancer (sem matar) |
| **Startup** | Já terminei de inicializar? | Aguarda; outras probes só iniciam quando esta passa |

Outros orquestradores (ECS, Cloud Run, App Engine, Nomad) têm equivalentes, os princípios são os mesmos.

## Por quê

Sem health checks bem desenhados:

- **Pods quebrados recebem tráfego** → usuários veem erro.
- **Pods saudáveis são reiniciados** → instabilidade autoinduzida.
- **Pods em startup recebem tráfego** → primeiras requests falham.
- **Falha de dependência externa derruba o serviço** → "fail cascading".

Com health checks corretos:

- **Self-healing** automático funciona.
- **Rolling updates** sem downtime, pod novo só recebe tráfego quando pronto.
- **Resilience**: degradação graciosa quando dependências falham.

## Como aplicar

### Os três tipos: quando cada um falha

#### Liveness: "estou vivo?"

A pergunta certa: *o processo está fundamentalmente quebrado e só reiniciar resolve?*

**Sintomas que justificam liveness fail:**

- Deadlock no código.
- Memória corrompida.
- Estado interno irrecuperável.

**O que NÃO checar em liveness:**

- ❌ Conexão com banco.
- ❌ Conexão com cache.
- ❌ Conexão com fila.

Por quê? Se o banco está fora, **reiniciar o pod não conserta**. Pior: 100 pods reiniciando ao mesmo tempo agravam o problema.

```ts
// ✅ Liveness, checa só "eu funciono internamente?"
app.get('/healthz/live', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});
```

Liveness deve ser **trivialmente verdadeiro** na maioria absoluta dos casos.

#### Readiness: "posso receber tráfego?"

A pergunta: *vou conseguir atender bem o próximo request?*

**Sintomas que justificam readiness fail:**

- Cache local ainda não pré-aquecido.
- Conexão com banco caiu (e o serviço depende dela).
- Migrations ainda rodando.
- Conexão com config service não estabelecida.

```ts
// ✅ Readiness, checa dependências críticas
app.get('/healthz/ready', async (_req, res) => {
  const checks = await Promise.allSettled([
    db.query('SELECT 1'),
    redis.ping(),
  ]);

  const allOk = checks.every(c => c.status === 'fulfilled');
  res.status(allOk ? 200 : 503).json({
    status: allOk ? 'ok' : 'degraded',
    checks: checks.map((c, i) => ({
      name: ['db', 'redis'][i],
      status: c.status,
    })),
  });
});
```

O orquestrador retira esse pod do balanço, mas **não o mata**: quando o banco voltar, o pod entra de novo.

#### Startup: "já terminei de iniciar?"

Útil para serviços de **inicialização longa** (carrega 5GB em cache, faz migrations, conecta a 10 dependências). Sem startup probe, o liveness começa imediatamente e mata o pod antes de inicializar.

```ts
let isInitialized = false;

async function initialize() {
  await db.connect();
  await loadConfig();
  await warmupCache();
  isInitialized = true;
}

initialize().catch(/* ... */);

app.get('/healthz/startup', (_req, res) => {
  res.status(isInitialized ? 200 : 503).json({ initialized: isInitialized });
});
```

Configure no K8s para esperar até startup passar antes de liveness/readiness começarem:

```yaml
startupProbe:
  httpGet: { path: /healthz/startup, port: 8080 }
  failureThreshold: 30
  periodSeconds: 10
  # 30 × 10s = 5 minutos para inicializar
livenessProbe:
  httpGet: { path: /healthz/live, port: 8080 }
  periodSeconds: 10
readinessProbe:
  httpGet: { path: /healthz/ready, port: 8080 }
  periodSeconds: 5
```

### Deep vs Shallow checks

#### Shallow (raso)

Apenas confirma que o processo responde:

```ts
app.get('/healthz', (_req, res) => res.json({ status: 'ok' }));
```

Bom para liveness. Detecta apenas que o servidor HTTP está respondendo.

#### Deep (profundo)

Verifica dependências:

```ts
async function checkDb()    { await db.query('SELECT 1'); }
async function checkRedis() { await redis.ping(); }
async function checkQueue() { await broker.healthCheck(); }
```

Bom para readiness. Detecta que o serviço **pode** servir requests.

### Padrão de implementação: registro de checks

Em vez de hardcodar cada dependência, registre componentes:

```ts
interface HealthCheck {
  name: string;
  critical: boolean;
  check(): Promise<boolean>;
}

class HealthService {
  constructor(private checks: HealthCheck[]) {}

  async runAll() {
    return Promise.all(
      this.checks.map(async (c) => {
        try {
          const ok = await Promise.race([
            c.check(),
            new Promise<boolean>((_, rej) => setTimeout(() => rej(new Error('timeout')), 2000)),
          ]);
          return { name: c.name, status: ok ? 'pass' : 'fail', critical: c.critical };
        } catch (err) {
          return { name: c.name, status: 'fail', critical: c.critical, error: String(err) };
        }
      }),
    );
  }
}

// Setup
const health = new HealthService([
  { name: 'postgres', critical: true,  check: async () => { await db.query('SELECT 1'); return true; }},
  { name: 'redis',    critical: false, check: async () => { await redis.ping(); return true; }},
]);

// Readiness, só falha se algo CRÍTICO está mal
app.get('/healthz/ready', async (_req, res) => {
  const results = await health.runAll();
  const failed  = results.filter(r => r.critical && r.status !== 'pass');
  res.status(failed.length === 0 ? 200 : 503).json({ checks: results });
});
```

Note: **dependências não-críticas** (cache que tem fallback, métricas) **não devem** derrubar o readiness.

### Boas práticas

#### Não expor health publicamente

Health endpoints revelam estrutura interna e podem ser usados em DoS. Restrinja:

- Em K8s: probes vêm do nó local, não precisam ser públicas.
- Em CDN/proxy: bloquear `/healthz*` na borda.
- Não autentique (deve ser rápido), mas restrinja IP.

#### Timeout no check

Cada check deve ter timeout próprio. Sem isso, um banco lento trava a probe inteira.

```ts
const result = await Promise.race([
  realCheck(),
  new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), 1000)),
]);
```

#### Endpoint barato

Health é chamado **frequentemente** (a cada 5–10s, por múltiplos sistemas). Não exponha endpoint que faz query pesada, vira gargalo de si próprio.

#### Padrão IETF

[RFC 8615 + draft IETF Health Check API](https://datatracker.ietf.org/doc/html/draft-inadarei-api-health-check) sugere formato JSON:

```http
GET /health HTTP/1.1

HTTP/1.1 200 OK
Content-Type: application/health+json

{
  "status": "pass",
  "version": "1.2.3",
  "releaseId": "abc123",
  "checks": {
    "postgres:responseTime": [{
      "componentType": "datastore",
      "status": "pass",
      "observedValue": 23,
      "observedUnit": "ms"
    }],
    "redis:responseTime": [{
      "componentType": "cache",
      "status": "pass",
      "observedValue": 2,
      "observedUnit": "ms"
    }]
  }
}
```

`status`: `pass` / `warn` / `fail`. Não obrigatório seguir 100%, mas o padrão é referência útil.

#### gRPC health protocol

gRPC tem seu próprio padrão de health check ([proto](https://github.com/grpc/grpc/blob/master/doc/health-checking.md)):

```protobuf
service Health {
  rpc Check(HealthCheckRequest) returns (HealthCheckResponse);
  rpc Watch(HealthCheckRequest) returns (stream HealthCheckResponse);
}
```

Implementações em todas as linguagens. Use sempre que o serviço expõe gRPC.

### Padrões avançados

#### Graceful shutdown

Quando o pod recebe `SIGTERM`, ele deve:

1. Marcar `/healthz/ready` como falha → orquestrador o tira do balanço.
2. Aguardar conexões em andamento terminarem.
3. Fechar conexões com banco/cache.
4. Encerrar.

```ts
let shuttingDown = false;

process.on('SIGTERM', async () => {
  shuttingDown = true;
  server.close();
  await Promise.all([db.end(), redis.quit()]);
  process.exit(0);
});

app.get('/healthz/ready', (_req, res) => {
  if (shuttingDown) return res.status(503).json({ status: 'shutting down' });
  res.json({ status: 'ok' });
});
```

#### Circuit breaker no health

Se uma dependência cai mas tem fallback, o readiness não deveria falhar pelo próximo request, falhe apenas quando o fallback também falhar. Use circuit breakers no código real, e o health refletir o estado do breaker.

## Quando *não* usar

- **Aplicações sem orquestrador / load balancer.** Health checks sem consumidor são logging glorificado.
- **Em scripts de uma só execução.** Health endpoint num cron job não faz sentido.
- **Quando seu orquestrador já infere saúde de outras formas** (logs structurados + métricas + ausência de tráfego). Mas mesmo assim, o endpoint é barato.

## Conceitos relacionados

- [Os três pilares](./three-pillars.md), health é uma forma de métrica de disponibilidade.
- [Alerting](./alerting.md), alertas em readiness failing são típicos.
- [Twelve-Factor App](../delivery/twelve-factor-app.md): IX. Disposability.
- [Framework de Backend Compartilhado](../backend/shared-framework.md), onde frequentemente é centralizado.

## Referências

- **Documentação.** [Kubernetes: Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/). Referência oficial.
- **Draft IETF.** [draft-inadarei-api-health-check](https://datatracker.ietf.org/doc/html/draft-inadarei-api-health-check). Padrão JSON proposto.
- **Spec.** [gRPC Health Checking Protocol](https://github.com/grpc/grpc/blob/master/doc/health-checking.md).
- **Livro.** Michael Nygard, *Release It!*, 2ª ed. (Pragmatic Bookshelf, 2018). Padrão "Steady State", "Test Harness".
- **Artigo.** Tim Bray, ["The Health Check"](https://www.tbray.org/ongoing/When/202x/2023/10/30/Health-Check). Reflexão moderna.
- **Artigo.** Liz Rice, ["Kubernetes Probes: Detailed Guide"](https://www.airplane.dev/blog/kubernetes-probes). Boa intro prática.
- **Site.** [microservices.io: Health Check API](https://microservices.io/patterns/observability/health-check-api.html).
