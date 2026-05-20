# Boas Práticas de Arquitetura e Engenharia

Repositório de **referência** sobre fundamentos e convenções de engenharia de software. O foco é em conceitos aplicáveis a qualquer projeto (independente de linguagem, stack ou domínio) com bibliografia verificável ao final de cada documento.

> **Não é um curso.** É um material de consulta. Para o leitor que quer profundidade, cada documento aponta para os livros e artigos canônicos sobre o tema.

---

## Como navegar

O conteúdo está organizado por **área**. Você pode ler em ordem ou pular direto para o tópico que precisa.

```
docs/
├─ meta/            ← convenções do próprio repositório
├─ foundations/     ← princípios universais (SOLID, DRY, KISS…)
├─ architecture/    ← estilos arquiteturais (Hexagonal, Clean, DDD, microsserviços)
├─ design-patterns/ ← padrões de projeto (GoF e enterprise)
├─ backend/         ← APIs, validação, erros, idempotência, caching
├─ data/            ← modelagem, identificadores, migrations, transações
├─ frontend/        ← componentes, estado, performance, acessibilidade
├─ testing/         ← pirâmide, TDD/BDD, doubles, contratos
├─ observability/   ← logs, métricas, traces, SLOs
├─ security/        ← OWASP, secrets, authn/authz, threat modeling
├─ delivery/        ← 12-factor, CI/CD, feature flags, release
├─ collaboration/   ← Git, commits, PRs, code review
└─ references/      ← livros, autores e sites canônicos
```

---

## Convenções deste repositório

- **Idioma:** português. Termos técnicos consagrados podem ficar em inglês.
- **Exemplos de código:** TypeScript como padrão. Outras linguagens só quando necessário para o conceito.
- **Toda afirmação forte tem fonte.** Bibliografia obrigatória ao final de cada documento.
- **Documentos curtos e focados.** Um conceito por arquivo. TL;DR no topo, referências no fim.

Detalhes em [`meta/how-to-contribute.md`](./meta/how-to-contribute.md) e no [template de documento](./meta/document-template.md).

---

## Índice de documentos

> Itens com link ativo já estão prontos. Itens marcados `(pendente)` ainda serão escritos.

### Meta

- [Como contribuir](./meta/how-to-contribute.md)
- [Template de documento](./meta/document-template.md)
- [Glossário](./meta/glossary.md)
- [Ferramentas de trabalho](./meta/tooling.md)

### Fundamentos

- [SOLID](./foundations/solid.md)
- [DRY: KISS, YAGNI](./foundations/dry-kiss-yagni.md)
- [Coesão e acoplamento](./foundations/cohesion-coupling.md)
- [Funções puras](./foundations/pure-functions.md)
- [Make Illegal States Unrepresentable (MISU)](./foundations/make-illegal-states-unrepresentable.md)
- [Code smells](./foundations/code-smells.md)
- [Naming](./foundations/naming.md)

### Arquitetura

- [Modular Monorepo](./architecture/modular-monorepo.md)
- [Layered Architecture](./architecture/layered-architecture.md)
- [Hexagonal (Ports & Adapters)](./architecture/hexagonal-ports-adapters.md)
- [Clean Architecture](./architecture/clean-architecture.md)
- [Domain-Driven Design](./architecture/domain-driven-design.md)
- [Microsserviços](./architecture/microservices.md)
- [Event-Driven Architecture](./architecture/event-driven.md)
- [Monolith first](./architecture/monolith-first.md)
- [Modelo C4](./architecture/c4-model.md)
- [ADRs: Architecture Decision Records](./architecture/architecture-decision-records.md)

### Padrões de projeto

- [Padrões criacionais](./design-patterns/creational.md)
- [Padrões estruturais](./design-patterns/structural.md)
- [Padrões comportamentais](./design-patterns/behavioral.md)
- [Enterprise patterns (Fowler)](./design-patterns/enterprise-patterns.md)

### Backend

- [Framework de Backend Compartilhado](./backend/shared-framework.md)
- [API design: REST](./backend/api-design-rest.md)
- [API design, gRPC](./backend/api-design-grpc.md)
- [Versionamento de API](./backend/api-versioning.md)
- [Tratamento de erros](./backend/error-handling.md)
- [Validação de entrada](./backend/input-validation.md)
- [Idempotência](./backend/idempotency.md)
- [Estratégias de cache](./backend/caching-strategies.md)
- [Rate limiting](./backend/rate-limiting.md)
- [Autenticação e autorização](./backend/authentication-authorization.md)
- [Background jobs](./backend/background-jobs.md)

### Dados

- [Modelagem relacional](./data/relational-modeling.md)
- [Identificadores: UUID vs serial](./data/identifiers-uuid-vs-serial.md)
- [Auditoria e soft delete](./data/auditing-soft-delete.md)
- [Migrations](./data/migrations.md)
- [Transações e isolamento](./data/transactions-isolation.md)
- [Event Sourcing e CQRS](./data/event-sourcing-cqrs.md)

### Frontend

- [Design de componentes](./frontend/component-design.md)
- [Gerenciamento de estado](./frontend/state-management.md)
- [Data fetching](./frontend/data-fetching.md)
- [Acessibilidade](./frontend/accessibility.md)
- [Performance e Core Web Vitals](./frontend/performance-web-vitals.md)

### Testes

- [Pirâmide de testes](./testing/test-pyramid.md)
- [TDD e BDD](./testing/tdd-bdd.md)
- [Unit vs Integration vs E2E](./testing/unit-vs-integration-vs-e2e.md)
- [Test doubles](./testing/test-doubles.md)
- [Contract testing](./testing/contract-testing.md)
- [Padrão AAA](./testing/aaa-pattern.md)

### Observabilidade

- [Os três pilares (logs, métricas, traces)](./observability/three-pillars.md)
- [Structured logging](./observability/structured-logging.md)
- [SLO: SLI, SLA](./observability/slo-sli-sla.md)
- [Alerting](./observability/alerting.md)
- [Health checks](./observability/health-checks.md)
- [OpenTelemetry](./observability/opentelemetry.md)
- [Monitoramento de microsserviços](./observability/microservices-monitoring.md)

### Segurança

- [OWASP Top 10](./security/owasp-top-10.md)
- [Secrets management](./security/secrets-management.md)
- [Princípios de Authn/Authz](./security/authn-vs-authz.md)
- [Threat modeling](./security/threat-modeling.md)

### Entrega

- [Twelve-Factor App](./delivery/twelve-factor-app.md)
- [CI/CD](./delivery/ci-cd.md)
- [Feature flags](./delivery/feature-flags.md)
- [Estratégias de release (blue-green, canary, rolling)](./delivery/release-strategies.md)
- [Infrastructure as Code](./delivery/infrastructure-as-code.md)

### Colaboração

- [Git Flow](./collaboration/git-flow.md)
- [Conventional Commits](./collaboration/conventional-commits.md)
- [Pull Requests](./collaboration/pull-requests.md)
- [Code review](./collaboration/code-review.md)
- [Documentação](./collaboration/documentation.md)

### Referências

- [Livros](./references/books.md)
- [Autores](./references/people.md)
- [Sites](./references/sites.md)
