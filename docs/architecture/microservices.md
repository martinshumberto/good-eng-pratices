# Microsserviços

> **TL;DR.** Microsserviços é um estilo arquitetural que decompõe um sistema em serviços pequenos, autônomos, com seu próprio modelo de dados, comunicando-se via rede. Resolvem problemas reais, e trazem complexidade real. Não use sem motivo claro.

## O quê

**Microsserviços** é um estilo arquitetural onde uma aplicação é construída como um conjunto de serviços pequenos, cada um:

- Rodando em **processo próprio**.
- **Independente em deploy**: pode subir versão nova sem coordenar com outros.
- **Comunicando-se via rede**: HTTP, gRPC, mensageria.
- **Com seu próprio modelo de dados** (idealmente seu próprio banco).
- **Construído em torno de uma capacidade de negócio**: não de uma camada técnica.

O termo foi cunhado coletivamente em um workshop em 2011, e cristalizado no [artigo seminal de Martin Fowler e James Lewis em 2014](https://martinfowler.com/articles/microservices.html).

> "The microservice architectural style is an approach to developing a single application as a suite of small services, each running in its own process and communicating with lightweight mechanisms."
> (Martin Fowler & James Lewis (2014))

## Por quê

Microsserviços viraram tendência por motivos reais:

- **Escalabilidade independente.** Serviço com gargalo escala sozinho.
- **Deploy independente.** Equipes não esperam release window comum.
- **Polyglot.** Cada serviço pode usar a linguagem/banco mais adequado.
- **Resiliência.** Falha em um serviço não derruba o sistema todo (se isolada bem).
- **Alinhamento com equipes.** Conway's Law, a arquitetura espelha a estrutura organizacional. Microsserviços permitem times autônomos.

E pelos motivos errados:

- **Hype.** "Todo mundo está fazendo".
- **Falta de disciplina em monolito.** Decompor não conserta acoplamento, apenas o transporta para a rede.
- **Resume-driven development.** Tecnologias da moda.

A regra prática mais citada vem de Martin Fowler:

> "Don't start a new project with microservices, even if you're sure your application will be big enough to make it worthwhile."
> (Martin Fowler, [Microservice Premium](https://martinfowler.com/bliki/MicroservicePremium.html))

Microsserviços têm um **prêmio de complexidade** que só vale a pena pagar quando o sistema já demonstrou que precisa. Ver [Monolith First](./monolith-first.md).

## Como aplicar

### Tamanho: quão pequeno é "micro"?

Não há resposta fixa. Heurísticas:

- **"Small enough to be owned by a small team"** (Newman), uma equipe pequena (2 pizzas) tem domínio total de um serviço.
- **"Built around a business capability"** (Fowler), um serviço = uma capacidade de negócio (Auth, Catálogo, Pagamento), não uma camada (Database Service).
- **Bounded context (DDD)**: cada bounded context é candidato natural a um microsserviço.

**Não** é sobre LOC. Um serviço de pagamento pode ter 10k linhas, ainda é um microsserviço se sua fronteira é clara.

### Princípios essenciais

#### Database per service

Cada microsserviço tem seu próprio armazenamento. Outros serviços não acessam **direto**: só via API.

```
❌ Anti-pattern: shared database
   Order Service ──┐
                   ├──→ Database (clients, orders, products)
   Catalog Service ┘

✅ Database per service
   Order Service ───→ Order DB
   Catalog Service ─→ Catalog DB
```

Por quê? Banco compartilhado reintroduz acoplamento. Migrar uma tabela exige coordenação entre equipes.

#### Comunicação síncrona vs. assíncrona

| Tipo | Quando usar | Tecnologias |
|---|---|---|
| **Síncrona (req/res)** | Resposta imediata necessária, baixa cardinalidade | HTTP/REST, gRPC |
| **Assíncrona (event/message)** | Resposta pode esperar, alto throughput, baixo acoplamento | Kafka, RabbitMQ, SQS, NATS |

Prefira **assíncrona** quando possível, reduz acoplamento temporal entre serviços.

#### Smart endpoints, dumb pipes

> "We favour an alternative approach: smart endpoints and dumb pipes."
> (Fowler & Lewis)

Lógica vive nos serviços; a infraestrutura de comunicação é boba, apenas roteia mensagens. **Não** use um ESB (Enterprise Service Bus) com lógica embutida.

#### Design for failure

Em sistemas distribuídos, **rede falha**. Latência, partições, timeouts são normais.

Padrões essenciais:

- **Timeouts** em todas as chamadas externas.
- **Retries com jitter** em falhas transitórias.
- **Circuit breakers**: para de bater em serviço que está down.
- **Bulkheads**: isole pools de recursos para um problema não cascatear.
- **Idempotência**: mensagens podem chegar duplicadas.

Ver Michael Nygard, *Release It!* (referência absoluta).

### Patterns comuns

#### API Gateway

Ponto único de entrada para clientes externos. Roteia para serviços internos, agrega respostas, faz authn/authz.

#### Service Discovery

Como serviços encontram-se uns aos outros num ambiente dinâmico (containers efêmeros). Soluções: Consul, etcd, DNS dinâmico, Kubernetes Services.

#### Saga

Transações distribuídas via sequência de operações locais, cada uma com sua compensação (rollback semântico). Substitui transações ACID em um mundo sem 2PC.

#### CQRS: Command Query Responsibility Segregation

Separe modelos de leitura e escrita. Leituras agregadas vivem em uma projeção otimizada; escritas usam o modelo "rico".

#### Event Sourcing

O estado é derivado do log de eventos. Histórico completo, replay possível. Complexo, use só quando o domínio justifica.

### Trade-offs: o "premium" de complexidade

| Aspecto | Monolito | Microsserviços |
|---|---|---|
| **Deploy** | Um deploy | N deploys, coordenados |
| **Testes** | Um processo, fácil | Múltiplos processos, contracts entre serviços, e2e custosa |
| **Debugging** | Stack trace local | Distributed tracing essencial |
| **Transações** | ACID natural | Saga / consistência eventual |
| **Latência** | Chamadas in-process | Chamadas via rede |
| **Operação** | Um runtime | N runtimes, orquestração |
| **Observabilidade** | Logs locais | Logs + métricas + traces agregados |

Esses custos são reais e somam-se. Pequenos sistemas pagam o premium sem capturar os benefícios.

### Quando microsserviços fazem sentido

Sinais positivos:

- Time grande (>20–30 engs) com múltiplas equipes que se atropelam num monolito.
- Cargas muito diferentes em componentes diferentes (parte do sistema precisa escalar 100x; outra parte, não).
- Tecnologias muito diferentes em partes do sistema (ML em Python, backend em Go, mobile sync em outro).
- Requisitos de deploy independente forte (compliance, SLAs distintos).
- Bounded contexts bem definidos e estáveis.

### Migração: extração gradual

Quando um monolito justifica decomposição, faça **incrementalmente**. Padrões úteis:

- **Strangler Fig**: novo código vai para microsserviços; o monolito vai sendo "estrangulado" ao longo do tempo.
- **Branch by Abstraction**: introduz uma abstração entre o caller e o código, depois cria implementação alternativa.

Ver Sam Newman, *Monolith to Microservices*.

## Quando *não* usar

Os sinais mais fortes de que microsserviços não são a resposta:

- **Equipe pequena** (< 10–15 engenheiros). Cobertura operacional sai cara.
- **Sistema novo, domínio incerto.** Você ainda está descobrindo fronteiras. Aplicações monolíticas refatoradas amadurecem mais rápido.
- **Sem cultura DevOps madura.** Sem CI/CD, observabilidade e automação, microsserviços viram um pesadelo operacional.
- **Domínio simples / CRUD.** Não há complexidade que justifique decompor.

> "Microservices are an option, but they're a particular option that requires a particular set of conditions to be successful."
> (Sam Newman)

## Conceitos relacionados

- [Monolith First](./monolith-first.md), comece simples, decomponha quando justificado.
- [DDD](./domain-driven-design.md), bounded contexts são candidatos naturais a microsserviços.
- [Event-Driven Architecture](./event-driven.md), comunicação assíncrona típica.
- [Monitoramento de microsserviços](../observability/microservices-monitoring.md), observabilidade é não-negociável.

## Referências

- **Livro.** Sam Newman, *Building Microservices*, 2ª ed. (O'Reilly, 2021). Referência canônica.
- **Livro.** Sam Newman, *Monolith to Microservices* (O'Reilly, 2019). Estratégias de migração.
- **Livro.** Chris Richardson, *Microservices Patterns* (Manning, 2018). Catálogo de padrões com exemplos.
- **Livro.** Susan Fowler, *Production-Ready Microservices* (O'Reilly, 2016). Foco em operação.
- **Artigo.** Martin Fowler & James Lewis, ["Microservices"](https://martinfowler.com/articles/microservices.html) (2014). Texto seminal.
- **Artigo.** Martin Fowler, ["Microservice Premium"](https://martinfowler.com/bliki/MicroservicePremium.html). Por que não começar com microsserviços.
- **Site.** [microservices.io](https://microservices.io), catálogo de padrões mantido por Chris Richardson.
