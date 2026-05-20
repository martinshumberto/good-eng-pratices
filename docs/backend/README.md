# Backend

Práticas para APIs e serviços: design de endpoints, tratamento de erros, validação, idempotência, cache, autenticação, jobs assíncronos.

## Documentos

- **[Framework de Backend Compartilhado](./shared-framework.md).** Library interna com router, logger, swagger, response padrão, fetch client.
- **[API design — REST](./api-design-rest.md).** Recursos, métodos HTTP, status codes, paginação por cursor, RFC 7807.
- **[API design — gRPC](./api-design-grpc.md).** Proto, streaming, evolução de schema, error model.
- **[Versionamento de API](./api-versioning.md).** SemVer, breaking changes, pré-releases, Changesets.
- **[Tratamento de erros](./error-handling.md).** Envelope padrão, códigos estáveis, mensagens traduzíveis, cadeia de erros.
- **[Validação de entrada](./input-validation.md).** Parse, don't validate. Schemas declarativos, branded types.
- **[Idempotência](./idempotency.md).** Idempotency-Key, outbox, dedup em consumers. Exactly-once é mito.
- **[Estratégias de cache](./caching-strategies.md).** Cache-aside, write-through/behind, TTL, stampede, cache HTTP.
- **[Rate limiting](./rate-limiting.md).** Token bucket, sliding window, distribuído via Redis, headers padronizados.
- **[Autenticação e autorização](./authentication-authorization.md).** Authn vs Authz, OAuth2, JWT, RBAC/ABAC, MFA.
- **[Background jobs](./background-jobs.md).** Filas, retries com backoff, DLQ, workers, idempotência.

## Voltar

[Índice geral](../README.md)
