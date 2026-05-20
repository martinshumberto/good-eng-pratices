# Dados

Modelagem relacional, identificadores, auditoria, versionamento de schema e transações. Inclui padrões avançados como event sourcing e CQRS.

## Documentos

- **[Modelagem relacional](./relational-modeling.md).** Tipos certos, NOT NULL por padrão, UNIQUE, FK dentro do schema. Sem float para dinheiro.
- **[Identificadores: UUID vs serial](./identifiers-uuid-vs-serial.md).** UUID público + id_int interno. Quando usar v7/ULID.
- **[Auditoria e soft delete](./auditing-soft-delete.md).** created_at, updated_at, deleted_at e o que fazer com eles.
- **[Migrations](./migrations.md).** Versionamento de schema, idempotência, reversibilidade, expand-and-contract.
- **[Transações e isolamento](./transactions-isolation.md).** ACID, anomalias (dirty/non-repeatable/phantom/lost update/write skew), MVCC.
- **[Event Sourcing e CQRS](./event-sourcing-cqrs.md).** Estado como sequência de eventos, projeções, snapshots, upcasting.

## Voltar

[Índice geral](../README.md)
