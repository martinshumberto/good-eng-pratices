# Hexagonal: Ports & Adapters

> **TL;DR.** O domínio fica no centro, isolado. Tudo que é externo (HTTP, banco, fila, UI) entra via **portas** (interfaces definidas pelo domínio) implementadas por **adapters**. Permite trocar tecnologia sem mexer no núcleo.

## O quê

**Hexagonal Architecture** (também conhecida como **Ports & Adapters**) foi descrita por **Alistair Cockburn** em 2005 ([artigo original](https://alistair.cockburn.us/hexagonal-architecture/)).

A ideia:

- O **domínio** (lógica de negócio) fica no centro, isolado.
- **Ports** (portas) são *interfaces* definidas pelo domínio para falar com o mundo externo, tanto para receber chamadas (*driving ports*) quanto para fazê-las (*driven ports*).
- **Adapters** (adaptadores) são as implementações concretas dessas interfaces, um adapter HTTP recebe requests e chama o domínio; um adapter Postgres implementa a interface de persistência que o domínio definiu.

```
                ┌───────────────────────────────┐
                │                               │
   HTTP ──→ Driving Adapter ──→ Driving Port ──→│                               │
                                               │            Domain             │←── Driven Port ──── Driven Adapter ──→ Postgres
   CLI  ──→ Driving Adapter ──→ Driving Port ──→│           (núcleo)           │←── Driven Port ──── Driven Adapter ──→ Stripe
                                               │                               │←── Driven Port ──── Driven Adapter ──→ Email SMTP
                                               │                               │
                                               └───────────────────────────────┘
```

O hexágono virou ícone visual, não tem significado especial; é apenas um polígono regular onde cada lado pode ser uma porta diferente.

## Por quê

A versão clássica de [Layered Architecture](./layered-architecture.md) tem um problema sutil: a camada Domain *na prática* acaba dependendo de detalhes da Infrastructure (ORM, formato de DTOs, exceptions do framework). A "inversão" existe na ideia mas não na realidade.

Hexagonal força a separação via tipos:

- **Domínio independente.** Sem `import` de ORM, HTTP framework, ou client externo.
- **Detalhes substituíveis.** Trocar Postgres por DynamoDB é alterar um adapter, sem tocar no domínio.
- **Testabilidade.** O domínio é testado sem rodar banco, sem subir servidor, só puros adapters em memória.
- **Múltiplos canais.** Mesma lógica acessível por HTTP, CLI, fila, gRPC, basta um adapter de cada.

> "The hexagonal architecture allows an application to equally be driven by users, programs, automated tests or batch scripts, and to be developed and tested in isolation from its eventual run-time devices and databases."
> (Alistair Cockburn)

## Como aplicar

### Estrutura

```
src/
├─ domain/                     ← núcleo
│  ├─ entities/
│  │  └─ order.ts
│  ├─ value-objects/
│  │  └─ money.ts
│  ├─ ports/                   ← interfaces definidas pelo domínio
│  │  ├─ driving/
│  │  │  └─ create-order.ts    ← interface usada por adapters de entrada
│  │  └─ driven/
│  │     ├─ order-repository.ts
│  │     ├─ payment-gateway.ts
│  │     └─ event-publisher.ts
│  └─ use-cases/
│     └─ create-order.ts       ← implementa CreateOrder (driving port)
└─ adapters/
   ├─ driving/                 ← entram no sistema
   │  ├─ http/
   │  │  └─ order-controller.ts
   │  └─ cli/
   │     └─ create-order-command.ts
   └─ driven/                  ← chamados pelo sistema
      ├─ postgres-order-repository.ts
      ├─ stripe-payment-gateway.ts
      └─ rabbitmq-event-publisher.ts
```

### Driving ports (entrada)

São as **APIs do domínio** vistas de fora. Definem o que o sistema sabe fazer:

```ts
// domain/ports/driving/create-order.ts
export interface CreateOrder {
  exec(input: CreateOrderInput): Promise<Order>;
}
```

Implementação (use case):

```ts
// domain/use-cases/create-order.ts
export class CreateOrderUseCase implements CreateOrder {
  constructor(
    private orderRepo: OrderRepository,    // driven port
    private payments:  PaymentGateway,     // driven port
    private events:    EventPublisher,     // driven port
  ) {}

  async exec(input: CreateOrderInput): Promise<Order> {
    const order = Order.create(input);

    const result = await this.payments.charge({
      orderId: order.id,
      amount:  order.total(),
    });
    if (!result.ok) throw new PaymentFailedError(result.reason);

    await this.orderRepo.save(order);
    await this.events.publish('OrderCreated', { orderId: order.id });

    return order;
  }
}
```

### Driven ports (saída)

São interfaces que o **domínio define** para o que ele precisa pedir ao mundo:

```ts
// domain/ports/driven/order-repository.ts
export interface OrderRepository {
  save(order: Order): Promise<void>;
  findById(id: OrderId): Promise<Order | null>;
}

// domain/ports/driven/payment-gateway.ts
export interface PaymentGateway {
  charge(req: ChargeRequest): Promise<ChargeResult>;
}
```

Crucial: a interface vive **dentro do domínio**. O domínio decide o que precisa; o adapter se ajusta.

### Driving adapters (entrada)

Traduzem entrada do mundo (HTTP, CLI, fila) em chamadas a *driving ports*:

```ts
// adapters/driving/http/order-controller.ts
export function makeOrderRouter(createOrder: CreateOrder) {
  const router = Router();

  router.post('/orders', async (req, res) => {
    const input = CreateOrderInputSchema.parse(req.body);
    const order = await createOrder.exec(input);
    res.status(201).json(toResponseDto(order));
  });

  return router;
}
```

O controller **só conhece a interface** `CreateOrder`. Pode ser substituído por outro adapter (gRPC, CLI) sem o use case saber.

### Driven adapters (saída)

Implementam *driven ports* contra tecnologia concreta:

```ts
// adapters/driven/postgres-order-repository.ts
export class PostgresOrderRepository implements OrderRepository {
  constructor(private db: Pool) {}

  async save(order: Order): Promise<void> {
    await this.db.query(
      'INSERT INTO orders (id, status, items) VALUES ($1, $2, $3)',
      [order.id.value, order.status, JSON.stringify(order.items)],
    );
  }

  async findById(id: OrderId): Promise<Order | null> {
    const { rows } = await this.db.query('SELECT * FROM orders WHERE id = $1', [id.value]);
    return rows[0] ? Order.fromRow(rows[0]) : null;
  }
}
```

### Composition root: conecta tudo

A montagem dos adapters acontece em **um único lugar** (geralmente `main.ts` ou `bootstrap.ts`):

```ts
// src/bootstrap.ts
async function main() {
  // Adapters driven (saída)
  const db = await createDb();
  const orderRepo = new PostgresOrderRepository(db);
  const payments  = new StripePaymentGateway(process.env.STRIPE_KEY!);
  const events    = new RabbitMQEventPublisher(process.env.AMQP_URL!);

  // Use cases (domínio)
  const createOrder = new CreateOrderUseCase(orderRepo, payments, events);

  // Adapters driving (entrada)
  const app = express();
  app.use('/api', makeOrderRouter(createOrder));
  app.listen(3000);
}
```

Trocar Stripe por outro gateway = alterar uma linha aqui. O domínio não muda.

### Testes: adapters em memória

A grande conveniência: testar use cases com adapters in-memory:

```ts
class InMemoryOrderRepository implements OrderRepository {
  private orders = new Map<string, Order>();
  async save(o: Order)      { this.orders.set(o.id.value, o); }
  async findById(id: OrderId) { return this.orders.get(id.value) ?? null; }
}

it('creates an order when payment succeeds', async () => {
  const repo     = new InMemoryOrderRepository();
  const payments = { charge: async () => ({ ok: true }) } satisfies PaymentGateway;
  const events   = { publish: async () => {} }            satisfies EventPublisher;

  const useCase = new CreateOrderUseCase(repo, payments, events);
  const order   = await useCase.exec({ items: [/* ... */] });

  expect(order.status).toBe('placed');
  expect(await repo.findById(order.id)).toEqual(order);
});
```

Sem banco, sem mocks de biblioteca, sem container subindo.

## Quando *não* usar

- **Aplicações simples / CRUD diretos.** Cerimônia de portas e adapters não se paga em casos onde "controller → repository" basta.
- **Quando o domínio é fino.** Se 90% do sistema é orquestração e 10% é regra, Layered simples funciona melhor.
- **Quando o time não compra a disciplina.** Se "só dessa vez vou importar o ORM no domínio" é aceitável, a arquitetura desaba em meses.

## Conceitos relacionados

- [Layered Architecture](./layered-architecture.md), versão mais simples do mesmo objetivo.
- [Clean Architecture](./clean-architecture.md), formulação alternativa equivalente, com camadas concêntricas e regra de dependência explícita.
- [DDD](./domain-driven-design.md), combina bem com Hexagonal: bounded contexts viram hexágonos.
- [SOLID (DIP](../foundations/solid.md)) a regra que sustenta as ports.

## Referências

- **Artigo.** Alistair Cockburn, ["Hexagonal Architecture"](https://alistair.cockburn.us/hexagonal-architecture/) (2005). Texto original.
- **Livro.** Tom Hombergs, *Get Your Hands Dirty on Clean Architecture* (Packt, 2019). Aplicação prática de Hexagonal em Java.
- **Livro.** Vaughn Vernon, *Implementing Domain-Driven Design* (Addison-Wesley, 2013). Capítulo 4 trata de Architecture, incluindo Hexagonal.
- **Artigo.** Herberto Graça, ["DDD: Hexagonal, Onion, Clean, CQRS, How I put it all together"](https://herbertograca.com/2017/11/16/explicit-architecture-01-ddd-hexagonal-onion-clean-cqrs-how-i-put-it-all-together/). Síntese das arquiteturas correlatas.
- **Site.** [Refactoring Guru: Hexagonal Architecture](https://refactoring.guru) (apresentação visual).
