# Event Sourcing e CQRS

> **TL;DR.** Event Sourcing armazena o sistema como uma **sequência imutável de eventos**, derivando o estado atual a partir do log. CQRS separa modelos de escrita (commands) e leitura (queries). Os dois são padrões independentes que se complementam. Use com convicção, não com modismo.

## O quê

### Event Sourcing

Em vez de armazenar **o estado atual** dos objetos, armazene **a sequência de eventos** que levou a ele. O estado é derivado replayando os eventos.

```
Estado tradicional:
+----+----------+--------+
| id | balance  | status |
+----+----------+--------+
| 1  | 150.00   | active |
+----+----------+--------+

Event sourcing:
+----+-------------------+--------+
| id | event             | amount |
+----+-------------------+--------+
| 1  | AccountCreated    |        |
| 2  | MoneyDeposited    | 100    |
| 3  | MoneyDeposited    | 50     |
| 4  | (saldo derivado: 150)      |
+----+-------------------+--------+
```

Foi popularizado por **Greg Young** e **Martin Fowler** nos anos 2000 ([Fowler, 2005](https://martinfowler.com/eaaDev/EventSourcing.html)).

### CQRS: Command Query Responsibility Segregation

Modelos **separados** para:

- **Commands** (escritas), aplicam regras de negócio, mudam estado.
- **Queries** (leituras), projeções otimizadas para os casos de uso de leitura.

```
       ┌──────────┐
       │  Write   │
Client ─→  Command ──→ Aggregate → Event Store
       └──────────┘                     │
                                        ▼
                                  ┌──────────┐
                                  │ Projection│ → Query Store (read-optimized)
                                  └──────────┘                ↑
                                                              │
                                              Client → Query ─┘
```

CQRS foi cunhado por **Greg Young** em 2010, derivando do conceito CQS de **Bertrand Meyer** (1988).

### Os dois juntos: quando faz sentido

Event Sourcing **não exige** CQRS; CQRS **não exige** Event Sourcing. Mas se combinam naturalmente: events são a fonte; projeções são as queries.

## Por quê

### Event Sourcing: benefícios

- **Auditoria nativa.** Cada mudança é um evento imutável com timestamp. Compliance, debugging, análise post-mortem.
- **Time travel.** Reconstruir estado em qualquer ponto do tempo.
- **Múltiplas projeções.** Mesma fonte gera dashboards, relatórios, modelos de ML, todos sincronizados com a verdade.
- **Integração natural com eventos de domínio.** Mesmo modelo de evento serve para consumo externo (pub/sub).
- **Reprocessamento.** Bug numa projeção? Apague-a, replaye os eventos, projete de novo.

### CQRS: benefícios

- **Otimização independente.** Leitura desnormalizada, denormaliza para dashboards, pode ter índices diferentes.
- **Escalabilidade independente.** Réplicas de leitura escalam separadas da escrita.
- **Modelos focados.** Escrita modela regras; leitura modela apresentação. Cada um sem compromissos.

### Custos

- **Complexidade alta.** Mais código, mais infra, mais conceitos.
- **Consistência eventual.** Projeções têm latência em relação aos eventos.
- **Versionamento de eventos.** Eventos antigos têm schema antigo. Evoluir requer disciplina.
- **Replay caro.** Milhões de eventos = replay lento sem snapshots.
- **Debugging não-trivial.** Estado atual depende de N eventos passados.

> "Event sourcing is a tradeoff. Like all tradeoffs, you must understand the costs as well as the benefits before adopting it."
> (Martin Kleppmann)

## Como aplicar

### Modelagem: eventos como fatos no passado

Eventos representam **algo que aconteceu**, no pretérito. **Imutáveis** após escritos.

```ts
type AccountEvent =
  | { type: 'AccountCreated'; accountId: string; ownerId: string; at: string }
  | { type: 'MoneyDeposited';  accountId: string; amount: number; at: string }
  | { type: 'MoneyWithdrawn';  accountId: string; amount: number; at: string }
  | { type: 'AccountClosed';   accountId: string; reason: string; at: string };
```

Regras:

- **Imutáveis.** Um evento publicado nunca é alterado. Erros corrigem-se com **eventos compensatórios**, não edição.
- **Pretérito.** `OrderPlaced`, não `PlaceOrder` (comando).
- **Auto-contidos.** Carregam os dados necessários para entender o que aconteceu.
- **Versionados.** Inclua `version` para evoluir schema.

### Aggregate: derivando estado dos eventos

O aggregate é a entidade DDD que **decide quais eventos emitir** e **reconstrói seu estado** a partir deles.

```ts
class Account {
  private constructor(
    public readonly id: string,
    public balance: number,
    public closed: boolean,
  ) {}

  static empty(id: string): Account {
    return new Account(id, 0, false);
  }

  static fromEvents(id: string, events: AccountEvent[]): Account {
    return events.reduce((acc, ev) => acc.apply(ev), Account.empty(id));
  }

  // Aplica evento (reconstrução)
  private apply(event: AccountEvent): Account {
    switch (event.type) {
      case 'AccountCreated':  return new Account(event.accountId, 0, false);
      case 'MoneyDeposited':  return new Account(this.id, this.balance + event.amount, this.closed);
      case 'MoneyWithdrawn':  return new Account(this.id, this.balance - event.amount, this.closed);
      case 'AccountClosed':   return new Account(this.id, this.balance, true);
    }
  }

  // Command, decide eventos a emitir
  deposit(amount: number): AccountEvent[] {
    if (this.closed) throw new AccountClosedError();
    if (amount <= 0) throw new InvalidAmountError();
    return [{ type: 'MoneyDeposited', accountId: this.id, amount, at: new Date().toISOString() }];
  }

  withdraw(amount: number): AccountEvent[] {
    if (this.closed) throw new AccountClosedError();
    if (amount <= 0) throw new InvalidAmountError();
    if (this.balance < amount) throw new InsufficientFundsError();
    return [{ type: 'MoneyWithdrawn', accountId: this.id, amount, at: new Date().toISOString() }];
  }
}
```

Fluxo de comando:

```ts
async function handleDeposit(accountId: string, amount: number) {
  const events  = await eventStore.load(accountId);
  const account = Account.fromEvents(accountId, events);

  const newEvents = account.deposit(amount);

  await eventStore.append(accountId, newEvents, /* expectedVersion */ events.length);
}
```

### Event Store

O armazenamento dos eventos. Operações:

- **`append(streamId, events, expectedVersion)`**: adiciona eventos. `expectedVersion` evita escrita concorrente (optimistic concurrency).
- **`load(streamId)`**: lê todos os eventos de um stream.
- **`subscribe(handler)`**: projeções escutam eventos novos.

Opções:

- **[EventStoreDB](https://www.eventstore.com)**: banco dedicado, criado pelo Greg Young.
- **PostgreSQL com tabela de eventos**: funciona bem para casos médios.
- **Apache Kafka**: log distribuído. Excelente para escala alta.
- **AWS DynamoDB Streams**: managed.

#### Esquema simples em Postgres

```sql
CREATE TABLE events (
  id              BIGSERIAL PRIMARY KEY,
  stream_id       UUID NOT NULL,
  version         INT  NOT NULL,
  event_type      TEXT NOT NULL,
  payload         JSONB NOT NULL,
  metadata        JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (stream_id, version)
);

CREATE INDEX events_stream_idx   ON events (stream_id, version);
CREATE INDEX events_created_idx  ON events (created_at);
```

### Snapshots

Replay de 10k eventos a cada comando é caro. Crie **snapshots** periódicos:

```sql
CREATE TABLE snapshots (
  stream_id  UUID PRIMARY KEY,
  version    INT  NOT NULL,
  state      JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

Ao carregar o aggregate:

1. Load snapshot mais recente.
2. Load eventos `WHERE version > snapshot.version`.
3. Reconstruir aplicando só os eventos posteriores.

Crie snapshots a cada N eventos (ex.: 100) ou em rotina background.

### Projeções (read models)

Read models são derivações otimizadas para consultas:

```ts
// Projeção: saldo atual por conta
async function onMoneyDeposited(event: MoneyDepositedEvent) {
  await readDb.query(`
    INSERT INTO account_balances (account_id, balance)
    VALUES ($1, $2)
    ON CONFLICT (account_id)
    DO UPDATE SET balance = account_balances.balance + EXCLUDED.balance
  `, [event.accountId, event.amount]);
}

// Projeção: histórico para extrato
async function onAnyAccountEvent(event: AccountEvent) {
  await readDb.transactions.insert({
    accountId: event.accountId,
    type:      event.type,
    amount:    'amount' in event ? event.amount : null,
    at:        event.at,
  });
}
```

- Projeções podem ser **eventualmente consistentes**: minutos atrás da escrita.
- **Idempotentes**: processar o mesmo evento duas vezes não deve duplicar.
- **Reprocessáveis**: `DROP TABLE` + replay = projeção zerada e reconstruída.

### Versionamento de eventos

Eventos vivem para sempre. Evolução cuidadosa:

#### Adicionar campos opcionais: seguro

```json
// v1
{ "type": "OrderPlaced", "orderId": "..." }
// v2, campo extra é OK
{ "type": "OrderPlaced", "orderId": "...", "customerLanguage": "pt-BR" }
```

#### Remover/renomear/mudar tipo: exige *upcasting*

Crie funções que transformam eventos antigos para o formato atual ao ler:

```ts
function upcast(event: any): AccountEvent {
  if (event.type === 'AccountCreated' && !event.version) {
    return { ...event, version: 1, currency: 'BRL' };
  }
  return event;
}
```

Em sistemas grandes, considere ferramentas dedicadas: [Marten](https://martendb.io/events/versioning.html) (.NET), [Axon](https://axoniq.io) (Java), [Decider pattern](https://thinkbeforecoding.com/post/2021/12/17/functional-event-sourcing-decider).

### CQRS: quando vale separar

CQRS **não exige** event sourcing. Você pode aplicar:

- **Write side** com modelo rico (DDD aggregates), persistindo num banco relacional.
- **Read side** com projeção materializada (view, denormalized table, Elasticsearch).

Atualização da projeção pode ser:

- **Síncrona**: escreve write store e read store na mesma transação. Mais simples, menos performático.
- **Assíncrona**: via [outbox](../architecture/event-driven.md) + worker. Mais escalável, eventual consistency.

### Padrões úteis

#### Saga / process manager

Workflow longo coordenado por eventos. Recebe eventos, emite comandos.

```
OrderPlaced → reserva inventário
InventoryReserved → cobra pagamento
PaymentSucceeded → envia para entrega
PaymentFailed → libera inventário
```

#### Compensation events

Em vez de "editar" um evento errado, emita um evento compensatório:

```
MoneyDeposited (100) → erro!
MoneyWithdrawn (100, reason: 'correction')
```

A história fica intacta; o estado fica correto.

## Quando *não* usar

- **CRUDs simples.** Event sourcing adiciona complexidade enorme para ganho mínimo.
- **Domínio onde histórico não importa.** Se ninguém vai querer "estado de ontem", você está mantendo histórico para nada.
- **Sem necessidade de auditoria fina.** Audit log tradicional resolve.
- **Equipe sem maturidade em sistemas eventualmente consistentes.** Event sourcing exige conforto com latência entre escrita e leitura.

### Use quando

- Domínio é fortemente baseado em eventos / transações (financeiro, billing, contabilidade).
- Auditoria detalhada é requisito.
- Múltiplas projeções da mesma realidade são necessárias.
- *Time travel* é valioso (debugging em produção, análise retroativa).

## Conceitos relacionados

- [Event-Driven Architecture](../architecture/event-driven.md), eventos em geral.
- [Domain-Driven Design](../architecture/domain-driven-design.md), aggregates emitindo events.
- [Transações e isolamento](./transactions-isolation.md), concorrência via optimistic locking.
- [Migrations](./migrations.md), versionamento de schemas (analogia direta).

## Referências

- **Artigo.** Martin Fowler, ["Event Sourcing"](https://martinfowler.com/eaaDev/EventSourcing.html) (2005). Texto seminal.
- **Artigo.** Greg Young, ["CQRS Documents"](https://cqrs.files.wordpress.com/2010/11/cqrs_documents.pdf) (2010). PDF gratuito, fundador de CQRS moderno.
- **Livro.** Greg Young, *Versioning in an Event Sourced System* (Leanpub, 2017). Free na Leanpub.
- **Livro.** Martin Kleppmann, *Designing Data-Intensive Applications* (O'Reilly, 2017). Capítulo 11 (*Stream Processing*) trata de event sourcing.
- **Livro.** Vaughn Vernon, *Implementing Domain-Driven Design* (Addison-Wesley, 2013). Capítulo 8 trata de domain events.
- **Livro.** Alexey Zimarev, *Hands-On Domain-Driven Design with .NET Core* (Packt, 2019). Exemplo prático de ES+CQRS.
- **Documentação.** [EventStoreDB docs](https://developers.eventstore.com).
- **Site.** [microservices.io: Event Sourcing](https://microservices.io/patterns/data/event-sourcing.html) e [CQRS](https://microservices.io/patterns/data/cqrs.html).
- **Artigo.** Jonathan Oliver, ["Why I Love CQRS"](https://jonathan-oliver.blogspot.com/2010/12/why-i-love-cqrs.html). Defesa pragmática.
