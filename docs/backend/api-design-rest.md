# API Design: REST

> **TL;DR.** Modele recursos com URLs estáveis. Use HTTP de verdade (métodos, status, headers). Padronize formato de erro (RFC 7807), pagine com cursor, versione no path quando necessário. APIs duram anos, desenhe para evolução.

## O quê

**REST** (*Representational State Transfer*) foi proposto por **Roy Fielding** em sua tese de doutorado de 2000. É um **estilo arquitetural** para sistemas distribuídos com restrições específicas (statelessness, uniform interface, cache, layered system).

Na prática, a maioria das "APIs REST" implementa apenas parte do que Fielding propôs, geralmente sem HATEOAS, frequentemente sem cacheability formal. O que sobrou e virou padrão de mercado pode ser chamado mais corretamente de "APIs HTTP+JSON com convenção de recursos".

Este documento foca em **convenções práticas** para essas APIs HTTP, não puristas, mas eficazes.

## Por quê

APIs públicas (ou semi-públicas) são **contratos duradouros**. Clientes mobile, parceiros externos, integrações de B2B, todos podem demorar meses para migrar. Design ruim cobra juros por anos:

- URLs inconsistentes confundem clientes e geram bugs.
- Status codes mal usados quebram middlewares (load balancers, CDNs, navegadores).
- Falta de padrão de erro força cada cliente a escrever lógica de tratamento custom.
- Versionamento ad-hoc impede evolução sem quebrar todo mundo.

Boas APIs são previsíveis, o cliente lê uma documentação curta e adivinha o resto.

## Como aplicar

### Modele recursos, não ações

A unidade central de uma API REST é o **recurso**: uma entidade do domínio acessível por URL.

```
✅ Recursos
GET    /orders                 → lista pedidos
POST   /orders                 → cria pedido
GET    /orders/123             → detalhes do pedido 123
PATCH  /orders/123             → atualização parcial
DELETE /orders/123             → exclusão

❌ Ações em URLs (RPC-style)
POST /createOrder
POST /getOrderById
POST /deleteOrderById
```

**Substantivos para recursos, plural** (`orders`, `users`). Verbos vivem nos métodos HTTP.

#### Quando ação não cabe em recurso

Algumas operações são naturalmente verbos ("cancel", "publish", "approve"). Modele como **sub-recurso de ação**:

```
POST /orders/123/cancellation
POST /orders/123/approval
POST /posts/45/publication
```

Ou aceite o pragmatismo e use um sub-path com verbo:

```
POST /orders/123/cancel
POST /orders/123/approve
```

A consistência interna importa mais que a ortodoxia.

### Use HTTP corretamente

#### Métodos

| Método | Uso | Idempotente? | Seguro? |
|---|---|---|---|
| `GET` | Recuperar recurso | Sim | Sim (sem efeito colateral) |
| `POST` | Criar recurso (ou ação genérica) | **Não** | Não |
| `PUT` | Substituir recurso inteiro | Sim | Não |
| `PATCH` | Atualizar parcialmente | Depende | Não |
| `DELETE` | Excluir recurso | Sim | Não |
| `HEAD` | Como GET, sem body | Sim | Sim |
| `OPTIONS` | Metadados (CORS, capacidades) | Sim | Sim |

- **"Seguro"** = não causa efeito colateral observável (read-only).
- **"Idempotente"** = mesma requisição N vezes tem o mesmo efeito que 1.

Idempotência é crítica para retries, clientes devem poder repetir `PUT`/`DELETE` sem medo. Ver [idempotência](./idempotency.md).

#### Status codes

Use o que existe; não invente. Os essenciais:

| Faixa | Significa |
|---|---|
| **2xx** | Sucesso |
| `200 OK` | Sucesso geral |
| `201 Created` | Recurso criado, inclua `Location: /orders/123` no header |
| `202 Accepted` | Aceito mas ainda processando (async) |
| `204 No Content` | Sucesso, sem body de resposta |
| **3xx** | Redirecionamento |
| `301 Moved Permanently` | Recurso mudou de URL |
| `304 Not Modified` | Cache hit (após `If-None-Match` / `If-Modified-Since`) |
| **4xx** | Erro do cliente |
| `400 Bad Request` | Requisição malformada |
| `401 Unauthorized` | Falta autenticação (semanticamente: "Unauthenticated") |
| `403 Forbidden` | Autenticado, mas sem permissão |
| `404 Not Found` | Recurso não existe |
| `409 Conflict` | Estado inconsistente (ex.: editing stale resource) |
| `422 Unprocessable Entity` | Validação falhou |
| `429 Too Many Requests` | Rate limit atingido |
| **5xx** | Erro do servidor |
| `500 Internal Server Error` | Erro genérico |
| `502 Bad Gateway` | Erro em serviço a jusante |
| `503 Service Unavailable` | Indisponível temporariamente |
| `504 Gateway Timeout` | Timeout em serviço a jusante |

**Evite** códigos não-padrão (`200` com `{ "success": false }`), quebra middlewares.

#### Headers úteis

- `Content-Type: application/json; charset=utf-8`: sempre declarar.
- `Accept: application/json`: cliente declara o que aceita.
- `Authorization: Bearer <token>`: autenticação.
- `Location: /orders/123`: após `201 Created`.
- `ETag: "abc123"` + `If-None-Match: "abc123"`: cache condicional.
- `Idempotency-Key: <uuid>`: ver [idempotência](./idempotency.md).
- `X-Request-Id: <uuid>`: correlação em traces e logs.

### Estrutura de URLs

#### Hierarquia

```
GET    /customers/42/orders                ✅ pedidos do cliente 42
GET    /customers/42/orders/123             ✅ pedido específico do cliente
POST   /customers/42/orders                 ✅ criar pedido para cliente 42
```

Aninhamento mostra **propriedade** ou contexto. Evite mais de 2 níveis, depois disso, expor recurso top-level é mais legível:

```
❌ /customers/42/orders/123/items/5/comments
✅ /comments/5  (com filtro: /comments?item_id=5)
```

#### Convenções

- **kebab-case** em paths: `/payment-methods`, `/cost-centers`.
- **Plural** para coleções: `/orders`, não `/order`.
- **Sem extensão**: `/orders/123`, não `/orders/123.json` (use header `Accept`).

### Filtragem, ordenação, paginação

#### Query params para refinamento

```
GET /orders?status=placed&customer_id=42&sort=-created_at
```

Convenções comuns:

- `?sort=-created_at`: prefixo `-` para descendente.
- `?fields=id,total,status`: sparse fieldsets.
- `?include=customer,items`: embed de recursos relacionados.

#### Paginação: prefira cursor

```
❌ Offset-based (frágil em datasets que mudam)
GET /orders?offset=100&limit=20

✅ Cursor-based (estável)
GET /orders?after=cur_abc123&limit=20
```

**Resposta com cursor:**

```json
{
  "data": [/* ... */],
  "pagination": {
    "next":     "cur_def456",
    "previous": "cur_xyz789",
    "limit":    20
  }
}
```

Cursor é opaco do ponto de vista do cliente, o servidor sabe codificar/decodificar.

Quando offset é aceitável: datasets pequenos e estáveis, ou em telas que mostram "página 5 de 12".

### Formato de erro: RFC 7807

A [RFC 7807: Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc7807) define um formato padrão para respostas de erro:

```json
HTTP/1.1 400 Bad Request
Content-Type: application/problem+json

{
  "type":     "https://example.com/probs/validation-failed",
  "title":    "Validation failed",
  "status":   400,
  "detail":   "The 'email' field must be a valid email address.",
  "instance": "/orders/123",
  "errors": [
    { "field": "email", "code": "invalid_format" }
  ]
}
```

Campos:

- **`type`**: URI estável que identifica o tipo de erro.
- **`title`**: descrição humana, curta.
- **`status`**: HTTP status (redundância proposital, facilita parse).
- **`detail`**: explicação específica desta ocorrência.
- **`instance`**: URI do recurso afetado.
- **Campos custom**: `errors[]`, `request_id`, etc.

Para implementação alinhada com framework próprio, ver [tratamento de erros](./error-handling.md).

### Versionamento

Estratégias em ordem de preferência:

#### 1) Sem versionamento: evolua sem quebrar

A melhor versão é a que não existe. Adicione campos opcionais, nunca remova nem mude semântica. Funciona para boa parte da evolução natural.

#### 2) Versão no path

```
GET /v1/orders
GET /v2/orders
```

Simples, explícito, fácil de cachear e rotear. **Mais comum no mercado.**

#### 3) Versão no header

```
GET /orders
Accept: application/vnd.example.v2+json
```

Mais "puro" segundo Fielding, mas mais difícil de testar e cachear.

Evite versionar por query param (`?v=2`), viola cache semantics.

### HATEOAS: Hipermídia

Fielding considera HATEOAS uma restrição **obrigatória** para algo ser REST de verdade, respostas incluem links para as próximas ações possíveis:

```json
{
  "id": "123",
  "status": "placed",
  "_links": {
    "self":   { "href": "/orders/123" },
    "cancel": { "href": "/orders/123/cancellation", "method": "POST" },
    "items":  { "href": "/orders/123/items" }
  }
}
```

Na prática, **a maioria das APIs ignora**. O custo de implementação raramente se justifica pelo benefício real. Use quando a navegabilidade for genuinamente útil (sistemas de hipermídia, APIs longevas com clientes que vão durar década).

### Documentação: OpenAPI / Swagger

Sempre publique um spec [OpenAPI](https://www.openapis.org). Gerado a partir do código (via decorators, anotações ou inferência de schemas Zod) ou escrito à mão. Hospeda Swagger UI ou Redoc.

Spec viva é tão importante quanto a API. APIs sem doc são APIs internas, não importa quão pública seja a URL.

## Quando *não* usar

- **Streams de eventos / pub-sub.** REST request/response não cabe. Use WebSockets, SSE, ou um broker.
- **APIs internas alto-throughput.** [gRPC](./api-design-grpc.md) tende a ser melhor, proto, binário, streaming nativo.
- **Operações em lote complexas.** REST é ruim para "atualize 100 recursos atomicamente". GraphQL ou endpoints custom resolvem melhor.

## Conceitos relacionados

- [API design, gRPC](./api-design-grpc.md)
- [Versionamento de API](./api-versioning.md)
- [Tratamento de erros](./error-handling.md)
- [Idempotência](./idempotency.md)
- [Validação de entrada](./input-validation.md)

## Referências

- **Tese.** Roy Fielding, [*Architectural Styles and the Design of Network-based Software Architectures*](https://www.ics.uci.edu/~fielding/pubs/dissertation/top.htm) (UC Irvine, 2000). Texto fundador.
- **RFC.** [RFC 9110: HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110). Atualiza RFC 7231 e companhia. Referência atual para semântica HTTP.
- **RFC.** [RFC 7807: Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc7807). Formato padrão de erro.
- **Spec.** [OpenAPI Specification](https://www.openapis.org). Padrão de descrição de APIs.
- **Livro.** Mark Massé, *REST API Design Rulebook* (O'Reilly, 2011). Catálogo de regras.
- **Livro.** Arnaud Lauret, *The Design of Web APIs* (Manning, 2019). Design-thinking aplicado a APIs.
- **Documentação.** [Microsoft REST API Guidelines](https://github.com/Microsoft/api-guidelines). Guia detalhado, com decisões justificadas.
- **Documentação.** [Google AIP: API Improvement Proposals](https://google.aip.dev). Convenções Google, muito detalhadas.
- **Site.** [JSON:API](https://jsonapi.org). Spec opinionada para API JSON.
- **Site.** [Zalando RESTful API Guidelines](https://opensource.zalando.com/restful-api-guidelines/). Guia maduro de empresa real.
