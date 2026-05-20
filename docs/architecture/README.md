# Arquitetura

Estilos arquiteturais e técnicas de modelagem em alto nível: como organizar camadas, contextos e serviços; como visualizar e registrar decisões.

## Documentos

- **[Modular Monorepo](./modular-monorepo.md).** Um repositório, várias libs isoladas. Nx, Turborepo, escopo por domínio.
- **[Layered Architecture](./layered-architecture.md).** Camadas horizontais (Presentation, Application, Domain, Infrastructure) com regra de dependência.
- **[Hexagonal (Ports & Adapters)](./hexagonal-ports-adapters.md).** Domínio no centro, ports como interfaces, adapters implementam.
- **[Clean Architecture](./clean-architecture.md).** Camadas concêntricas com dependências apontando sempre para dentro.
- **[Domain-Driven Design](./domain-driven-design.md).** Linguagem ubíqua, bounded contexts, aggregates, value objects.
- **[Microsserviços](./microservices.md).** Quando vale o "premium de complexidade". Quando não.
- **[Event-Driven Architecture](./event-driven.md).** Eventos, pub/sub, sagas, event sourcing, CQRS.
- **[Monolith first](./monolith-first.md).** Comece monolítico e modular. Decomponha quando justificado.
- **[Modelo C4](./c4-model.md).** Quatro níveis de zoom para diagramar arquitetura (Context, Container, Component, Code).
- **[ADRs — Architecture Decision Records](./architecture-decision-records.md).** Registros curtos de decisões arquiteturais e seu porquê.

## Voltar

[Índice geral](../README.md)
