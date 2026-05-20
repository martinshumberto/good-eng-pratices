# API Design: gRPC

> **TL;DR.** Contratos `.proto` versionados, binário sobre HTTP/2, suporte nativo a streaming bidirecional. Ideal para comunicação interna entre serviços; menos confortável que REST para clientes externos no navegador.

## O quê

**gRPC** é um framework de RPC criado pelo Google e open-sourced em 2015. Combina:

- **Protocol Buffers (Protobuf)** como linguagem de definição de contrato e formato de serialização binária.
- **HTTP/2** como transporte (multiplexação, header compression).
- **Suporte a 4 padrões de chamada:** unary, server streaming, client streaming, bidirectional streaming.
- **Code generation** de cliente e servidor em múltiplas linguagens a partir do `.proto`.

Não é HTTP+JSON disfarçado. É um modelo RPC com **tipagem forte de contrato**, transporte binário e ferramentas pesadas de codegen.

## Por quê

gRPC resolve dores reais de comunicação **entre serviços internos**:

- **Performance.** Binário compacto, HTTP/2 multiplexado, menor overhead que JSON+HTTP/1.1.
- **Contratos formais.** Schema versionado em `.proto`. Quebras de contrato aparecem em compile-time.
- **Type safety cross-language.** Cliente Java fala com servidor Go com tipagem garantida.
- **Streaming nativo.** Sem WebSocket / SSE / long-polling, streams são primitivos.

Custos correspondentes:

- **Tooling pesado.** Build precisa gerar código; depende de protobuf compiler (`protoc`) e plugins.
- **Debug menos confortável.** Não dá pra inspecionar com curl/Postman trivialmente (existem ferramentas, [grpcurl](https://github.com/fullstorydev/grpcurl), [Postman gRPC](https://blog.postman.com/postman-now-supports-grpc/), [Bloom RPC](https://github.com/bloomrpc/bloomrpc)).
- **Browsers.** Suporte nativo limitado; precisa de [gRPC-Web](https://grpc.io/blog/state-of-grpc-web/) ou um proxy.

Conclusão prática: **gRPC para comunicação interna, REST para APIs públicas / browser-facing**.

## Como aplicar

### Definição do contrato: `.proto`

```protobuf
// orders.proto
syntax = "proto3";

package commerce.orders.v1;

import "google/protobuf/timestamp.proto";

service Orders {
  rpc CreateOrder (CreateOrderRequest)  returns (Order);
  rpc GetOrder    (GetOrderRequest)     returns (Order);
  rpc ListOrders  (ListOrdersRequest)   returns (stream Order);  // server streaming
}

message Order {
  string                       id          = 1;
  string                       customer_id = 2;
  repeated OrderItem           items       = 3;
  OrderStatus                  status      = 4;
  Money                        total       = 5;
  google.protobuf.Timestamp    created_at  = 6;
}

message OrderItem {
  string product_id = 1;
  int32  quantity   = 2;
  Money  unit_price = 3;
}

message Money {
  string amount   = 1;   // decimal como string
  string currency = 2;   // ISO 4217
}

enum OrderStatus {
  ORDER_STATUS_UNSPECIFIED = 0;
  ORDER_STATUS_PLACED      = 1;
  ORDER_STATUS_PAID        = 2;
  ORDER_STATUS_SHIPPED     = 3;
  ORDER_STATUS_DELIVERED   = 4;
  ORDER_STATUS_CANCELED    = 5;
}

message CreateOrderRequest {
  string                  customer_id = 1;
  repeated CreateOrderItem items      = 2;
}

message CreateOrderItem {
  string product_id = 1;
  int32  quantity   = 2;
}

message GetOrderRequest {
  string id = 1;
}

message ListOrdersRequest {
  string customer_id = 1;
  int32  page_size   = 2;
  string page_token  = 3;
}
```

**Convenções:**

- **Package versionado:** `commerce.orders.v1`: facilita evolução.
- **Tags numéricas estáveis:** o número (`= 1`, `= 2`) define a wire-compatibility. **Nunca renumere** depois de publicar.
- **Enums com `UNSPECIFIED = 0`:** o zero deve ser "valor desconhecido", protobuf3 não distingue `unset` de zero em campos escalares.
- **`Money` como string decimal:** evita ponto flutuante (ver [modelagem](../data/relational-modeling.md)).
- **Timestamps:** use `google.protobuf.Timestamp`, não inteiros mágicos.

### Padrões de chamada

#### Unary: request/response simples

```protobuf
rpc GetOrder(GetOrderRequest) returns (Order);
```

Equivalente a uma chamada REST tradicional.

#### Server streaming

```protobuf
rpc ListOrders(ListOrdersRequest) returns (stream Order);
```

Cliente envia uma request; servidor envia múltiplos responses ao longo do tempo. Útil para dump de dados, broadcasts.

#### Client streaming

```protobuf
rpc UploadOrderEvents(stream OrderEvent) returns (UploadAck);
```

Cliente envia múltiplos messages; servidor responde uma vez ao final. Útil para upload em chunks.

#### Bidirectional streaming

```protobuf
rpc Chat(stream Message) returns (stream Message);
```

Ambos os lados streamam. Útil para tempo real (collaboration, jogos).

### Code generation

```bash
# Buf é o tooling moderno recomendado
buf generate
```

Gera client + server stubs em TypeScript, Go, Java, etc.

```ts
// TypeScript via @bufbuild/protobuf + connect-es
import { createClient } from '@connectrpc/connect';
import { Orders } from './gen/orders/v1/orders_connect';

const client = createClient(Orders, transport);

const order = await client.getOrder({ id: '123' });
```

### Evolução do schema

Regras para **compatibilidade retroativa**:

#### ✅ Mudanças seguras

- **Adicionar campos novos** (com tags novas).
- **Adicionar valores novos em enum.**
- **Adicionar RPC novo no service.**
- **Adicionar service novo.**

Clientes antigos ignoram o desconhecido; servidores antigos aceitam payloads parciais.

#### ❌ Mudanças quebradoras

- **Renumerar campo**: quebra wire compatibility.
- **Mudar tipo do campo** (`int32` → `int64` é OK em alguns casos; `string` → `int32` não).
- **Remover campo necessário.**
- **Renomear campo** com mesmo tag, em wire é tolerável, mas confunde quem lê.

Quando precisa quebrar, **versione o package**: `commerce.orders.v1` → `v2`. Os dois coexistem; clientes migram no seu tempo.

### Erros: gRPC Status

gRPC tem um modelo de erro próprio, com status codes específicos:

| Código | Significado |
|---|---|
| `OK` | Sucesso |
| `INVALID_ARGUMENT` | Argumento inválido (similar a HTTP 400) |
| `NOT_FOUND` | Recurso não existe (HTTP 404) |
| `ALREADY_EXISTS` | Recurso já existe (HTTP 409) |
| `PERMISSION_DENIED` | Sem permissão (HTTP 403) |
| `UNAUTHENTICATED` | Falta autenticação (HTTP 401) |
| `RESOURCE_EXHAUSTED` | Quota / rate limit (HTTP 429) |
| `FAILED_PRECONDITION` | Estado inválido para a operação |
| `ABORTED` | Conflito de concorrência |
| `UNAVAILABLE` | Serviço indisponível (HTTP 503) |
| `DEADLINE_EXCEEDED` | Timeout |
| `INTERNAL` | Erro interno |
| `UNKNOWN` | Erro desconhecido |

Para detalhes ricos, use `google.rpc.Status`:

```protobuf
import "google/rpc/status.proto";
import "google/rpc/error_details.proto";

// status com detalhes
status: ALREADY_EXISTS
message: "order already exists"
details:
  - type: BadRequest
    field_violations:
      - field: "items[0].product_id"
        description: "product not in catalog"
```

### Tooling recomendado

- **[Buf](https://buf.build/)**: gerenciador de proto modern. Lint, breaking change detection, registry. **Substitua `protoc` manual por Buf.**
- **[Connect](https://connectrpc.com/)**: implementação moderna alternativa a gRPC tradicional. Mesmo `.proto`, mas funciona naturalmente em browsers (sem precisar de proxy gRPC-Web).
- **[grpcurl](https://github.com/fullstorydev/grpcurl)**: `curl` para gRPC.
- **[Bloom RPC](https://github.com/bloomrpc/bloomrpc)** / **[grpcui](https://github.com/fullstorydev/grpcui)**: UI para inspeção.

### Boas práticas

- **Sempre defina timeouts (deadlines).** gRPC propaga deadline pela cadeia, use.
- **Use metadata para correlação:** trace ID, request ID em headers.
- **Defina retry policies no client:** quais códigos devem retry (`UNAVAILABLE`, `DEADLINE_EXCEEDED`); quais não (`INVALID_ARGUMENT`).
- **Health checks:** implemente o [Health Checking Protocol padrão](https://github.com/grpc/grpc/blob/master/doc/health-checking.md).
- **Reflection:** habilite [Server Reflection](https://github.com/grpc/grpc/blob/master/doc/server-reflection.md) em ambientes não-prod para tooling.
- **Validation:** use [protovalidate](https://github.com/bufbuild/protovalidate) para validar mensagens declarativamente.

## Quando *não* usar

- **APIs públicas para browser.** Use REST + JSON. gRPC-Web ajuda, mas tem fricções.
- **Integrações externas.** Parceiros esperam OpenAPI + JSON. gRPC é "interno"; impor para outsider raramente vale.
- **Operações simples sem demanda de performance.** REST é mais barato para construir/manter quando não há gargalo.
- **Equipe sem maturidade em proto tooling.** Sem disciplina (Buf, lint, breaking change detection), o ecossistema vira caos.

## Conceitos relacionados

- [API design (REST](./api-design-rest.md)) alternativa para casos externos.
- [Versionamento de API](./api-versioning.md), versionar `.proto`.
- [Microsserviços](../architecture/microservices.md), comunicação inter-service típica.
- [Tratamento de erros](./error-handling.md).

## Referências

- **Documentação oficial.** [grpc.io](https://grpc.io).
- **Spec.** [Protocol Buffers Language Guide (proto3)](https://protobuf.dev/programming-guides/proto3/).
- **Documentação.** [Buf](https://buf.build/docs/), tooling moderno para gerenciar proto.
- **Documentação.** [Connect](https://connectrpc.com/docs/), implementação browser-friendly.
- **Documentação.** [Google AIP: Versioning](https://google.aip.dev/180) e relacionados. Convenções Google para evolução de protos.
- **Livro.** Kasun Indrasiri & Danesh Kuruppu, *gRPC: Up and Running* (O'Reilly, 2020).
- **Artigo.** Buf, ["The state of Protobuf"](https://buf.build/blog). Atualizações frequentes sobre o ecossistema.
- **Artigo.** [gRPC vs REST](https://www.cncf.io/blog/2018/08/30/grpc-vs-rest/), comparação direta, ainda relevante.
