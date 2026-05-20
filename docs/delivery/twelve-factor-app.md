# The Twelve-Factor App

> **TL;DR.** Manifesto de 2011 (Heroku) com 12 princípios para construir aplicações cloud-native: separar config do código, treat backing services as attached resources, logs como streams, stateless processes, port binding, etc. Continua sendo a base do que se chama "cloud-native" hoje.

## O quê

**The Twelve-Factor App** ([12factor.net](https://12factor.net)) é um manifesto escrito por **Adam Wiggins** (cofundador da Heroku) em 2011. Resume **doze princípios** para construir aplicações:

- **Portáteis** entre ambientes (dev, staging, prod).
- **Escaláveis** horizontalmente sem mudanças no código.
- **Robustas** a falhas e deploys frequentes.
- **Aderentes a plataformas modernas** (PaaS, containers, orquestradores).

Mais de uma década depois, continua sendo a referência mais citada para o que se chama "cloud-native". Kubernetes, Heroku, Cloud Run, ECS, todos esperam que sua app siga (grosso modo) os 12 fatores.

## Por quê

Apps que **não** seguem 12-Factor enfrentam problemas previsíveis:

- **Config no código** → dev e prod divergem; secrets vazam.
- **Estado local em processo** → scaling horizontal impossível.
- **Logs em arquivo** → invisíveis em produção; perdidos no scale.
- **Dependências implícitas** → "funciona na minha máquina".
- **Deploy artesanal** → demorado, sujeito a erros.

Apps que **seguem** são triviais de operar:

- Sobem em qualquer plataforma.
- Escalam por replicação.
- Reiniciam sem perda de estado.
- Atualizam sem downtime.

## Como aplicar

### I. Codebase: One codebase tracked in revision control, many deploys

**Um app, um repo.** Múltiplos deploys (dev, staging, prod) vêm do mesmo código.

- ✅ Um repo por app. Múltiplas branches/tags = múltiplos deploys.
- ❌ Múltiplos repos para "versão de prod" e "versão de dev".

> Se houver várias codebases, é um sistema distribuído, não uma app.

### II. Dependencies: Explicitly declare and isolate dependencies

**Dependências declaradas, nunca implícitas.** Não confie em libs do sistema operacional.

- ✅ `package.json` + lock file. `requirements.txt`. `go.mod`. `Cargo.lock`.
- ✅ Isolamento via Docker, venv, nvm.
- ❌ "Funciona se você tiver Node 18 instalado globalmente".
- ❌ Esperar libs do sistema (ImageMagick, ffmpeg) sem documentar.

### III. Config: Store config in the environment

**Config (que muda entre ambientes) vive no environment.** Código vai pra Git; config não.

```ts
// ❌ Config no código
const DB_URL = 'postgres://localhost:5432/myapp';

// ✅ Config no environment
const DB_URL = process.env.DATABASE_URL;
if (!DB_URL) throw new Error('DATABASE_URL not set');
```

Isso inclui:

- URLs de banco/cache/fila.
- Credenciais (mas use [secret manager](../security/secrets-management.md), não env crua).
- Feature flags estáticas.
- Hostnames, ports.

Cuidado: **constants do app** (não muda entre ambientes) vão no código mesmo. Limites de timeout, configuração de retry, código.

### IV. Backing Services: Treat backing services as attached resources

**Banco, cache, fila, S3, SMTP, todos são "recursos" reconectáveis por URL.**

```ts
// ✅ Trocar de provider = mudar env, sem mudar código
const db = createDb(process.env.DATABASE_URL);
// DATABASE_URL=postgres://...local      → dev
// DATABASE_URL=postgres://...amazonaws  → prod
```

Aplicações 12-factor não distinguem entre serviço **local** e **terceiro**: tudo é URL.

### V. Build, Release, Run: Strictly separate build and run stages

Três estágios estritamente separados:

- **Build**: código + dependências → artifact imutável (binário, container image).
- **Release**: build + config → release identificável (`v1.2.3+config-abc`).
- **Run**: executar o release.

Princípio: **release é imutável**. Para mudar config, gera-se nova release; nunca se edita uma em execução.

```bash
# Build: gera imagem
docker build -t myapp:abc123 .

# Release: combina com config
helm install myapp ./chart \
  --set image.tag=abc123 \
  --set env.DATABASE_URL=...

# Run
kubectl apply ...
```

### VI. Processes: Execute the app as one or more stateless processes

**App é um processo stateless.** Estado vive em backing services (banco, cache, S3).

- ❌ Cache em memória do processo que precisa persistir.
- ❌ Arquivos em `/tmp` para uso entre requests.
- ❌ Sticky sessions confiando em estado local.
- ✅ Sessão em Redis ou JWT.
- ✅ Cache em Redis (não local) quando precisa ser compartilhado.
- ✅ Uploads em S3.

Resultado: matar e recriar o processo é seguro. Scaling horizontal é trivial.

### VII. Port Binding: Export services via port binding

**App se autobinda em uma porta.** Não depende de servidor externo para servir HTTP.

```ts
// ✅ App expõe HTTP por si só
const port = Number(process.env.PORT ?? 8080);
app.listen(port);

// ❌ Espera ser servida por Apache/IIS
// (app é um módulo PHP/ASP que outra coisa serve)
```

Plataformas (Heroku, Cloud Run, K8s) passam `PORT` por env; app escuta.

### VIII. Concurrency: Scale out via the process model

**Escale via replicação de processos.** Cada processo faz uma coisa.

```
web    ──→ workers HTTP                  (replicar para handle traffic)
worker ──→ consumidores de filas         (replicar para handle backlog)
clock  ──→ scheduler                     (singleton)
```

Cada tipo de processo escala independentemente. Não use threads/workers complexos dentro do mesmo processo para "scaling", replique processos.

### IX. Disposability: Maximize robustness with fast startup and graceful shutdown

Processos devem:

- **Iniciar rápido**: segundos, não minutos.
- **Encerrar graciosamente** ao receber `SIGTERM`:
  1. Marcar [readiness](../observability/health-checks.md) como falha.
  2. Aguardar requests em andamento.
  3. Fechar conexões com banco/cache.
  4. Sair.
- **Resilientes a crash súbito**: recursos retomados sem corrupção.

```ts
let shuttingDown = false;

process.on('SIGTERM', async () => {
  shuttingDown = true;
  server.close();
  await db.end();
  process.exit(0);
});

app.get('/healthz/ready', (_req, res) => {
  res.status(shuttingDown ? 503 : 200).json({ status: shuttingDown ? 'shutting down' : 'ok' });
});
```

### X. Dev/Prod Parity: Keep development, staging, and production as similar as possible

Três tipos de gap:

| Gap | Tradicional | 12-Factor |
|---|---|---|
| **Time** | Devs commitam diário; deploy mensal | Deploy contínuo |
| **Personnel** | Devs escrevem; ops deploya | Devs também deployam |
| **Tools** | SQLite em dev, Postgres em prod | Postgres em ambos |

Use os **mesmos backing services** em todos os ambientes (Docker, Testcontainers ajudam). Reduzem surpresas em prod.

### XI. Logs: Treat logs as event streams

**App não gerencia logs.** Ela escreve em **stdout**. Plataforma coleta, agrega, roteia.

```ts
// ✅ Just print
logger.info({ orderId }, 'order created');

// ❌ Escrever em arquivo, rotacionar, fazer upload
fs.appendFile('/var/log/myapp.log', ...);
```

Em produção, a plataforma (Fluent Bit, CloudWatch agent, Stackdriver) captura stdout e envia para destino central. Ver [structured logging](../observability/structured-logging.md).

### XII. Admin Processes: Run admin/management tasks as one-off processes

**Tarefas administrativas (migrations, seeds, scripts ad-hoc) rodam no mesmo ambiente da app.**

```bash
# ✅ Mesma imagem, comando diferente
docker run myapp:abc123 npm run db:migrate
docker run myapp:abc123 node scripts/cleanup-old-data.js

# ❌ Script bash em laptop do dev com acesso ao banco de prod
```

Em Kubernetes: `kubectl exec`, `Job` resource, ou um sidecar.

## Como avaliar

Use os 12 fatores como **checklist** ao revisar uma app:

- [ ] Um repo, múltiplos deploys?
- [ ] Dependências declaradas e isoladas?
- [ ] Config via env (não no código)?
- [ ] Backing services reconectáveis?
- [ ] Build/Release/Run separados?
- [ ] Processo stateless?
- [ ] Auto-bind em port?
- [ ] Scale por replicação?
- [ ] Startup rápido + graceful shutdown?
- [ ] Dev/Prod parity?
- [ ] Logs em stdout?
- [ ] Admin tasks como one-off processes?

Cumprir todos = app pronta para qualquer plataforma cloud-native.

## Críticas modernas

12-Factor foi escrito em 2011, no contexto de PaaS (Heroku). Há contextos onde precisa ser **atualizado**:

- **Stateful workloads** (banco, broker), naturalmente violam alguns fatores. Use orquestradores que entendam (K8s StatefulSets).
- **Multi-region / disaster recovery**: 12-Factor é silencioso. Pat Helland ([*Beyond Distributed Transactions*](https://queue.acm.org/detail.cfm?id=3025012)) e outros refinam.
- **Edge / serverless**: alguns princípios (port binding) não aplicam diretamente.
- **Build-only languages** (Go, Rust), fator II (isolate dependencies) é trivial.

Como **base**, continua valendo. Como **religião**, não.

> "12-factor is a great starting point, not a finishing line."
> (comentário comum em discussões modernas)

## Conceitos relacionados

- [Twelve-Factor original](https://12factor.net), leitura primária.
- [CI/CD](./ci-cd.md), fatores I, V, X.
- [Health checks](../observability/health-checks.md), fator IX.
- [Structured logging](../observability/structured-logging.md), fator XI.
- [Secrets management](../security/secrets-management.md), fator III com nuance.
- [Modular monorepo](../architecture/modular-monorepo.md), codebase aplicado a multi-apps.

## Referências

- **Site.** [12factor.net](https://12factor.net). O manifesto. Curto, ler na íntegra.
- **Livro.** Kevin Hoffman, *Beyond the Twelve-Factor App* (O'Reilly, 2016). Expande para 15 fatores, com microsserviços em mente.
- **Livro.** Cornelia Davis, *Cloud Native Patterns* (Manning, 2019). Como 12-Factor se traduz em cloud-native.
- **Livro.** Sam Newman, *Building Microservices*, 2ª ed. (O'Reilly, 2021).
- **Artigo.** Adam Wiggins, ["The Twelve-Factor App at 5"](https://blog.heroku.com/twelve_factor_app_principles_for_cloud_apps) (2016). Reflexão do autor.
- **Documentação.** [Kubernetes: Application architecture](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/). K8s espera 12-factor.
