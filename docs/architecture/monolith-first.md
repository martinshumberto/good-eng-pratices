# Monolith First

> **TL;DR.** Comece com um **monolito modular**. Decomponha em microsserviços só quando o monolito demonstrar dor real, e você tiver entendimento suficiente do domínio para traçar fronteiras corretas.

## O quê

**Monolith First** é uma recomendação articulada por **Martin Fowler** em 2015 ([artigo original](https://martinfowler.com/bliki/MonolithFirst.html)). A tese:

> "Almost all the successful microservice stories have started with a monolith that got too big and was broken up. Almost all the cases I've heard of a system that was built as a microservice system from scratch, it has ended up in serious trouble."

A intuição central: **traçar fronteiras corretas exige conhecer o domínio**. No início de um projeto, o entendimento é raso. Decompor cedo congela fronteiras erradas em barreiras de rede caras de mover depois.

O monolito não precisa ser uma "bola de barro". Pode ser um **monolito modular**: bem estruturado internamente, com módulos com fronteiras claras, mas rodando em um único processo.

## Por quê

Microsserviços têm um [prêmio de complexidade](./microservices.md#por-quê) significativo. Você paga esse prêmio desde o dia 1, mas só captura os benefícios quando o sistema cresce o bastante para precisar deles.

O argumento de Fowler tem três pilares:

### 1) Você ainda não sabe os bounded contexts

> "It's much easier to find the boundaries of an existing application than it is to find them in a fresh design."
> (Sam Newman, *Building Microservices*)

Domínios novos têm fronteiras incertas. Você acha que "Catálogo" e "Inventário" são duas coisas, descobre depois que 70% das operações cruzam os dois. Mover uma fronteira **dentro** de um monolito é refactoring; **entre** microsserviços é projeto.

### 2) Microsserviços têm custo inicial alto

CI/CD multiplicado, observabilidade distribuída, contratos versionados, deploy orquestrado, debugging via trace. Esses custos são reais antes da primeira venda. Em um sistema novo, eles competem com a velocidade de descobrir produto.

### 3) Refatorar dentro do monolito é barato

Um refactor que move classes entre módulos no monolito é uma PR. O mesmo refactor entre microsserviços é uma migração com data sync, contratos de API, rollback plan.

## Como aplicar

### Comece com um monolito modular

**Modular** ≠ "spaghetti em um processo". O monolito modular tem:

- **Fronteiras internas claras.** Módulos por capacidade de negócio, não por camada técnica.
- **Comunicação interna explícita.** Módulos chamam-se por interfaces, não navegando estruturas internas.
- **Banco com schemas separados** por módulo (ainda que no mesmo servidor).
- **Tabelas não-compartilhadas.** Módulo A não faz SELECT em tabelas do módulo B, pede via interface.

```
monolith/
├─ src/
│  ├─ modules/
│  │  ├─ catalog/         ← módulo
│  │  │  ├─ api/          ← interface pública do módulo
│  │  │  ├─ domain/
│  │  │  └─ infra/
│  │  ├─ inventory/
│  │  ├─ orders/
│  │  └─ payments/
│  └─ shared/
│     ├─ events/
│     └─ types/
└─ db/
   └─ migrations/
       ├─ catalog/        ← schema catalog
       ├─ inventory/      ← schema inventory
       └─ orders/         ← schema orders
```

A vantagem: quando (e se) um módulo precisar virar microsserviço, a extração é mecânica, não-arqueologia.

### Combine com DDD tático

Trate cada módulo do monolito como um **bounded context** (ver [DDD](./domain-driven-design.md)). Use ubiquitous language, entities, aggregates. O esforço de modelagem se paga **agora** (código mais legível) e **depois** (extração mais limpa).

### Use eventos internos

Mesmo dentro do monolito, comunique-se entre módulos via **eventos**:

```ts
// catalog module publica
eventBus.publish(new ProductCreated({ productId, sku, name }));

// inventory module reage
eventBus.subscribe(ProductCreated, async (event) => {
  await inventoryService.createSlot(event.productId);
});
```

Internamente isso é uma chamada de função; externamente (quando extrair), vira um event broker. Mudança mínima no consumidor.

### Critérios para começar a decompor

Decomponha quando aparecer **pelo menos um** desses sinais:

- **Equipe se atropela.** Múltiplas equipes mexem no mesmo módulo e deploy vira coordenação.
- **Componente precisa escalar diferente.** Parte do sistema é hot path; o resto, frio.
- **Tecnologia diferente faz sentido.** Componente que vai ganhar de migração para outra stack.
- **Ciclos de release divergem.** Componente que muda toda semana vs. outro que muda a cada 6 meses.
- **Falha em um módulo derruba outros.** Isolamento físico vira requisito de SLA.

**Não decomponha** porque:

- "É a melhor prática"
- Quer escrever no CV
- Outro time tá fazendo

### Estratégias de extração: Strangler Fig

Quando justificado, **extraia incrementalmente**. Padrão clássico: **[Strangler Fig](https://martinfowler.com/bliki/StranglerFigApplication.html)** (Fowler, 2004):

1. **Identifique o módulo** a extrair (idealmente um bounded context bem definido).
2. **Coloque uma fachada** que roteia chamadas para o monolito.
3. **Crie o serviço novo** com a funcionalidade duplicada.
4. **Troque o roteamento** da fachada para o serviço novo, gradualmente.
5. **Remova o código do monolito** quando o serviço novo cobre tudo.

Iterações típicas: 1–3 meses por extração. Resista à tentação de extrair tudo de uma vez.

### Quando ir direto para microsserviços

Há contextos onde **monolith first** não se aplica:

- **Time grande e maduro** já com domínio bem entendido (ex.: empresa migrando uma área para nova stack).
- **Requisitos não-funcionais extremos** desde o dia 1 (latência, isolamento de tenants, compliance).
- **Plataforma já estabelecida** que oferece "microsserviços baratos" (ex.: ecosistema interno + tooling completo + experiência prévia da empresa).

Mas mesmo nesses casos, **uma equipe nova explorando um domínio novo** se beneficia de começar simples.

## Quando *não* usar

- **Já existe um monolito grande e dolorido.** Decompor é melhor que reescrever. Use Strangler Fig.
- **Domínio super-bem entendido** com fronteiras inegáveis. Se você sabe que vai precisar de microsserviços e sabe onde, pode começar lá.
- **Sistemas embarcados / single-purpose.** Não há "decomposição", o produto é o monolito.

## Conceitos relacionados

- [Microsserviços](./microservices.md), para onde monolitos modulares costumam evoluir.
- [DDD](./domain-driven-design.md), modelagem que sustenta a separação interna.
- [Modular Monorepo](./modular-monorepo.md), outra forma de modularidade.
- [Hexagonal](./hexagonal-ports-adapters.md), viabiliza fronteiras claras dentro do monolito.

## Referências

- **Artigo.** Martin Fowler, ["MonolithFirst"](https://martinfowler.com/bliki/MonolithFirst.html) (2015). Texto canônico.
- **Artigo.** Martin Fowler, ["StranglerFigApplication"](https://martinfowler.com/bliki/StranglerFigApplication.html) (2004). Padrão de extração incremental.
- **Artigo.** Stefan Tilkov, ["Don't start with a monolith"](https://martinfowler.com/articles/dont-start-monolith.html) (2015). Contraponto no próprio site do Fowler.
- **Livro.** Sam Newman, *Monolith to Microservices* (O'Reilly, 2019). Estratégias de extração detalhadas.
- **Livro.** Kamil Grzybek, *Modular Monolith Architecture* (auto-publicado, free). Exemplo prático em .NET.
- **Livro.** Vlad Khononov, *Learning Domain-Driven Design* (O'Reilly, 2021). Capítulo "Architectural Decisions" trata explicitamente do trade-off monolito/microsserviços.
- **Artigo.** Shopify Engineering, ["Deconstructing the Monolith"](https://shopify.engineering/deconstructing-monolith-designing-software-maximizes-developer-productivity) (2019). Case real de monolito modular gigante.
