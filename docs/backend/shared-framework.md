# Framework de Backend Compartilhado

> **TL;DR.** Em arquiteturas com muitos microsserviços, extrair as decisões transversais (router, logger, health, swagger, cliente HTTP, response padrão) para um framework interno único elimina divergência e acelera novos serviços.

## O quê

Um **framework de backend compartilhado** é uma library interna que consolida tudo que todo serviço HTTP do ecossistema precisa fazer da mesma forma:

- Inicializar um servidor com middlewares padronizados.
- Expor health check.
- Servir documentação automática (OpenAPI/Swagger).
- Padronizar logging estruturado.
- Tratar erros de maneira uniforme ([ver](./error-handling.md)).
- Validar entradas via schema ([ver](./input-validation.md)).
- Fazer chamadas HTTP entre serviços com convenções comuns.
- Retornar respostas no mesmo envelope.

## Por quê

Sem framework comum, cada microsserviço **reinventa** essas decisões. O que parece flexibilidade vira problema quando:

- Logs têm formatos diferentes, observabilidade quebra.
- Health checks respondem diferente, orquestrador não consegue tratar uniformemente.
- Documentação está num serviço, ausente em outro.
- Cada equipe descobre os mesmos bugs sozinha.

Um framework central:

- Define **uma forma certa** de fazer.
- Concentra o esforço de correção (fix uma vez, propaga para todos via [versionamento](./api-versioning.md)).
- Permite onboarding rápido, quem conhece um serviço conhece todos.

## Como aplicar

### Componentes essenciais

#### Health Check

Toda app expõe `/health`. O endpoint valida dependências críticas:

```ts
interface Component {
  connCheck(): Promise<boolean>;
}

class HealthCheck {
  constructor(private components: Record<string, Component>) {}

  async run() {
    const results = await Promise.all(
      Object.entries(this.components).map(async ([name, c]) => ({
        name, ok: await c.connCheck(),
      })),
    );
    const allOk = results.every(r => r.ok);
    return { ok: allOk, components: results };
  }
}
```

Inicialização:

```ts
const db = await createDb();
const cache = await createCache();

const health = new HealthCheck({ postgres: db, redis: cache });

app.get('/health', async (_req, res) => {
  const result = await health.run();
  res.status(result.ok ? 200 : 503).json(result);
});
```

Convenção: 200 quando todas as dependências estão OK; 503 caso contrário. Orquestradores (Kubernetes, Cloud Run) leem isso para reiniciar instâncias.

#### Router padronizado

Encapsule a criação do servidor com middlewares já acoplados:

```ts
import express from 'express';

export function createRouter(opts: {
  healthCheck: HealthCheck;
  serviceName: string;
}) {
  const app = express();

  app.use(express.json());
  app.use(loggerMiddleware(opts.serviceName));
  app.use(requestIdMiddleware());

  app.get('/health',  healthHandler(opts.healthCheck));
  app.get('/swagger', swaggerHandler());

  app.use(errorMiddleware);

  return app;
}
```

Cada serviço inicializa assim:

```ts
const app = createRouter({ healthCheck, serviceName: 'auth' });

const v1 = app.route('/v1');
v1.use(authMiddleware);
v1.get('/users', listUsersHandler);

app.listen(8080);
```

#### Documentação automática (Swagger / OpenAPI)

Gere a spec automaticamente a partir do código, anotações JSDoc, decorators, ou inferência via schema (Zod → OpenAPI):

```ts
// Via tsoa, fastify-swagger, zod-to-openapi etc.
/**
 * @route   GET /accounts
 * @summary List accounts
 * @returns {Account[]} 200 - Lista de contas
 * @throws  {HTTPError}  400 - Bad request
 */
function listAccounts(req: Request, res: Response) { /* ... */ }
```

Exponha em `/swagger` ou `/docs`. Gerar a spec deve fazer parte do build, não ser passo manual.

#### Logger estruturado

Logs como JSON estruturado, com campos padronizados:

```ts
import pino from 'pino';

export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  formatters: {
    level: (label) => ({ level: label }),
  },
  base: {
    service: process.env.SERVICE_NAME,
    version: process.env.SERVICE_VERSION,
  },
});

// Uso
logger.info({ userId, action: 'login' }, 'user logged in');
```

Convenções:

- Sempre logar `service`, `version`, `requestId`, `userId` (quando disponível).
- Mensagens em inglês, campos descritivos.
- Sem PII em logs (CPF, senhas, tokens).

Ver [Structured logging](../observability/structured-logging.md).

#### Response padronizado

Toda resposta segue o mesmo envelope:

```ts
interface SuccessResponse<T> {
  success: true;
  return:  T;
  errors:  null;
}

interface ErrorResponse {
  success: false;
  return:  null;
  errors:  { code: string; error: string | null; message: string }[];
}

export type ApiResponse<T> = SuccessResponse<T> | ErrorResponse;

// Helpers
export function ok<T>(res: Response, status: number, data: T) {
  res.status(status).json({ success: true, return: data, errors: null });
}

export function fail(res: Response, status: number, errors: ErrorPayload[]) {
  res.status(status).json({ success: false, return: null, errors });
}
```

#### Cliente HTTP (`fetch`): chamadas entre serviços

Abstraia chamadas inter-service para padronizar timeouts, retries, headers e parsing:

```ts
export class HttpClient {
  constructor(
    private readonly baseUrl: string,
    private readonly defaults: Partial<RequestInit> = {},
  ) {}

  async request<T>(method: string, path: string, opts: RequestOpts = {}): Promise<Result<T>> {
    const url = buildUrl(this.baseUrl, path, opts.pathParams, opts.query);
    const init: RequestInit = {
      method,
      headers: { 'Content-Type': 'application/json', ...this.defaults.headers, ...opts.headers },
      body: opts.payload ? JSON.stringify(opts.payload) : undefined,
      signal: AbortSignal.timeout(opts.timeoutMs ?? 5000),
    };
    const res = await fetch(url, init);
    return parseResponse<T>(res);
  }

  get<T>(path: string,  opts?: RequestOpts) { return this.request<T>('GET',    path, opts); }
  post<T>(path: string, opts?: RequestOpts) { return this.request<T>('POST',   path, opts); }
  put<T>(path: string,  opts?: RequestOpts) { return this.request<T>('PUT',    path, opts); }
  del<T>(path: string,  opts?: RequestOpts) { return this.request<T>('DELETE', path, opts); }
}
```

Uso:

```ts
const client = new HttpClient('https://users.internal', {
  headers: { 'X-Service-Name': 'orders' },
});

const result = await client.get<User>('/users/:id', {
  pathParams: { id: '1' },
  query: { include: 'profile' },
});

if (!result.ok) {
  logger.error({ err: result.error }, 'failed to fetch user');
  throw new DomainError('user_fetch_failed', result.error);
}

return result.data;
```

### Versionamento do framework

Crítico: este pacote é dependência de **todos** os serviços. Siga [versionamento de API](./api-versioning.md) com rigor, em particular, sinalize *breaking changes* explicitamente.

## Quando *não* usar

- **Em uma equipe pequena com um único serviço.** Construir framework próprio é overhead que não se paga. Use libraries de mercado (Express + middlewares, Fastify, NestJS, etc.).
- **Quando bibliotecas existentes já cobrem.** Antes de criar, confira o que existe, NestJS, Fastify, tRPC já oferecem boa parte das peças.
- **Como "framework grande" que tenta resolver tudo.** Mantenha pequeno e composto: cada peça (router, logger, http client) usável independentemente.

## Conceitos relacionados

- [Tratamento de erros](./error-handling.md)
- [Validação de entrada](./input-validation.md)
- [Versionamento de API](./api-versioning.md)
- [Structured logging](../observability/structured-logging.md)
- [Health checks e probes](../observability/health-checks.md)

## Referências

- **Livro.** Sam Newman, *Building Microservices*, 2ª ed. (O'Reilly, 2021). Capítulo sobre comunicação inter-serviço.
- **Livro.** Chris Richardson, *Microservices Patterns* (Manning, 2018). Padrões comuns extraídos para shared libraries.
- **Site.** [microservices.io: Externalized Configuration](https://microservices.io/patterns/externalized-configuration.html) e padrões correlatos.
- **Site.** [12factor.net](https://12factor.net), princípios que o framework compartilhado deve respeitar.
