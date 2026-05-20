# Enterprise Patterns

> **TL;DR.** Padrões para aplicações corporativas catalogados por **Martin Fowler** em *Patterns of Enterprise Application Architecture* (2002). Repository, Unit of Work, Active Record, Data Mapper, Identity Map, Lazy Load, Service Layer, DTO. Continua sendo o vocabulário central de qualquer ORM e arquitetura backend séria.

## O quê

Em 2002, **Martin Fowler** publicou *Patterns of Enterprise Application Architecture* (PoEAA), catálogo de padrões observados em aplicações corporativas (entendidas como aquelas com lógica de negócio complexa + persistência + transações).

PoEAA cobre **mais de 40 padrões** divididos em:

- **Domain Logic Patterns**: como organizar regra de negócio.
- **Data Source Architectural Patterns**: como falar com banco.
- **Object-Relational Behavioral Patterns**: comportamento ORM.
- **Object-Relational Structural Patterns**: estrutura ORM.
- **Web Presentation Patterns**: MVC, MVP, MVVM, Page Controller.
- **Distribution Patterns**: DTO, Remote Facade.
- **Offline Concurrency Patterns**: Optimistic/Pessimistic Locking.
- **Session State Patterns**: onde guardar estado de sessão.
- **Base Patterns**: Money, Special Case, Plugin, Layer Supertype.

Este documento foca nos **mais úteis no dia a dia**.

## Por quê

Apps corporativas têm dores específicas que PoEAA endereça:

- **Persistência:** como mapear objetos para banco sem amarrar domínio ao schema.
- **Transações:** como rastrear mudanças e aplicar atomicamente.
- **Identidade:** como garantir que `customer.id = 42` é sempre o mesmo objeto.
- **Concorrência:** como detectar e resolver edição simultânea.
- **Apresentação:** como separar domínio de UI sem duplicação.

PoEAA é a fonte de vocabulário que ORMs (Hibernate, Entity Framework, ActiveRecord, TypeORM, Prisma) materializam.

## Como aplicar

### Domain Logic Patterns

#### Transaction Script

**Intenção:** procedure simples que faz uma operação de negócio. Sem orientação a objetos.

```ts
async function transferMoney(fromId: string, toId: string, amount: number) {
  await db.transaction(async (trx) => {
    await trx.accounts.where('id', fromId).decrement('balance', amount);
    await trx.accounts.where('id', toId).increment('balance', amount);
    await trx.transactions.insert({ from: fromId, to: toId, amount });
  });
}
```

**Quando usar:**
- Lógica simples, sem reuso entre operações.
- App pequeno, time pequeno.
- CRUD direto sem regras complexas.

#### Domain Model

**Intenção:** rede de objetos com **dados + comportamento**. O modelo de domínio expressa as regras.

```ts
class Account {
  constructor(
    readonly id: string,
    private balance: Money,
  ) {}

  withdraw(amount: Money): void {
    if (this.balance.isLessThan(amount)) throw new InsufficientFundsError();
    this.balance = this.balance.minus(amount);
  }

  deposit(amount: Money): void {
    this.balance = this.balance.plus(amount);
  }
}

class TransferService {
  async transfer(from: Account, to: Account, amount: Money) {
    from.withdraw(amount);
    to.deposit(amount);
    // persistir via repository
  }
}
```

**Quando usar:**
- Domínio com regras significativas.
- Times maiores, com lógica complexa.
- Combina naturalmente com [DDD](../architecture/domain-driven-design.md).

#### Service Layer

**Intenção:** API explícita do que o sistema **faz**: orquestra entidades e repositórios.

```ts
class OrderService {
  constructor(
    private orders: OrderRepository,
    private inventory: InventoryService,
    private payments: PaymentService,
  ) {}

  async placeOrder(input: PlaceOrderInput): Promise<Order> {
    const order = Order.create(input);

    await this.inventory.reserve(order);
    await this.payments.charge(order);
    await this.orders.save(order);

    return order;
  }
}
```

Cada método do `OrderService` é um *use case*. É a porta de entrada para a lógica.

### Data Source Patterns

#### Repository

**Intenção:** mediador entre domínio e camada de mapeamento, atuando como uma **coleção em memória** de objetos do domínio.

```ts
interface OrderRepository {
  findById(id: OrderId): Promise<Order | null>;
  findByCustomer(customerId: CustomerId): Promise<Order[]>;
  save(order: Order): Promise<void>;
  delete(order: Order): Promise<void>;
}
```

**Vantagens:**
- Domínio não conhece SQL.
- Trocar Postgres por Mongo = troca a implementação.
- Testes usam `InMemoryOrderRepository`.

**Combina com:**
- [Hexagonal](../architecture/hexagonal-ports-adapters.md), repository é driven port.
- [DDD](../architecture/domain-driven-design.md), repository por aggregate root.

#### Active Record

**Intenção:** objeto carrega **dados + comportamento + persistência**.

```ts
// Rails-style
class Order extends Model {
  static tableName = 'orders';

  async save() {
    // INSERT/UPDATE direto
    await db.query(/* ... */);
  }

  static async findById(id: string) {
    return db.query('SELECT * FROM orders WHERE id = $1', [id])
      .then(rows => new Order(rows[0]));
  }
}

const order = await Order.findById('123');
order.status = 'shipped';
await order.save();
```

**Quando usar:**
- Mapeamento direto domínio ↔ tabela.
- CRUD-heavy.
- Apps pequenos/médios, Ruby on Rails, Laravel, Django ORM.

**Cuidados:** Active Record **acopla** domínio à persistência. Difícil testar lógica sem banco; difícil ter modelo de domínio que não bata 1:1 com tabela.

#### Data Mapper

**Intenção:** separar **completamente** o modelo de domínio do schema. Mapeamento vive em camada própria.

```ts
// Domain, sem amarração com persistência
class Order {
  constructor(readonly id: OrderId, readonly items: OrderItem[]) {}
  // ... regras puras
}

// Data Mapper
class OrderMapper {
  toEntity(row: OrderRow): Order { /* ... */ }
  toRow(order: Order): OrderRow { /* ... */ }
}

class PostgresOrderRepository implements OrderRepository {
  async findById(id: OrderId): Promise<Order | null> {
    const row = await this.db.query('SELECT * FROM orders WHERE id = $1', [id.value]);
    return row ? this.mapper.toEntity(row) : null;
  }
}
```

**Quando usar:**
- Domínio complexo que não bate com schema.
- Refactoring de banco sem refactoring de domínio.
- [Clean Architecture](../architecture/clean-architecture.md) / [DDD](../architecture/domain-driven-design.md).

ORMs como **Prisma** (parcialmente), **Hibernate** (em modo entity), **Doctrine** (PHP), **MikroORM** seguem este padrão.

### Object-Relational Patterns

#### Unit of Work

**Intenção:** rastreia mudanças feitas durante uma operação de negócio e aplica todas numa transação atômica.

```ts
class UnitOfWork {
  private newOrders: Order[] = [];
  private dirtyOrders: Order[] = [];
  private removedOrders: Order[] = [];

  registerNew(order: Order)     { this.newOrders.push(order); }
  registerDirty(order: Order)   { this.dirtyOrders.push(order); }
  registerRemoved(order: Order) { this.removedOrders.push(order); }

  async commit() {
    await db.transaction(async (trx) => {
      for (const o of this.newOrders)    await trx.insert(o);
      for (const o of this.dirtyOrders)  await trx.update(o);
      for (const o of this.removedOrders) await trx.delete(o);
    });
  }
}
```

**Quando usar:**
- Operações que tocam múltiplas entidades em uma transação.
- Quando "lembrar de salvar tudo" no fim seria error-prone.

Hibernate Session, EF DbContext, NHibernate ISession, todos implementam Unit of Work.

#### Identity Map

**Intenção:** garante que cada objeto seja carregado **uma vez por session**: múltiplas requests retornam a **mesma instância**.

```ts
class IdentityMap<K, V> {
  private map = new Map<K, V>();

  get(key: K): V | undefined { return this.map.get(key); }
  set(key: K, value: V): void { this.map.set(key, value); }

  clear() { this.map.clear(); }
}

class OrderRepository {
  private map = new IdentityMap<string, Order>();

  async findById(id: string): Promise<Order> {
    let cached = this.map.get(id);
    if (cached) return cached;

    const row = await db.query(/* ... */);
    const order = this.mapper.toEntity(row);
    this.map.set(id, order);
    return order;
  }
}
```

**Por quê:**
- **Identidade.** `order1.id === order2.id` ⇒ `order1 === order2`.
- **Evita query duplicada** na mesma operação.
- **Mudanças localizadas.** Se A modificar `order.status`, B (que também carregou) vê.

**Cuidado:** Identity Map é **por session/request**, não global. Senão vira leak de memória.

#### Lazy Load

**Intenção:** não carregar objeto até o momento que for usado.

```ts
class Order {
  private _items?: OrderItem[];

  async items(): Promise<OrderItem[]> {
    if (!this._items) {
      this._items = await db.query('SELECT * FROM order_items WHERE order_id = $1', [this.id]);
    }
    return this._items;
  }
}
```

**Variantes:**
- **Lazy Initialization**: campo carregado quando acessado.
- **Virtual Proxy**: proxy substitui o real até precisar.
- **Value Holder**: wrapper que sabe carregar quando perguntado.
- **Ghost**: objeto parcialmente carregado.

**Cuidado clássico, N+1:**

```ts
// ❌
const orders = await orderRepo.findAll();
for (const order of orders) {
  console.log(await order.items());   // 1 query por order!
}

// ✅
const orders = await orderRepo.findAllWithItems();   // eager load via JOIN
```

A maioria dos ORMs oferece `.include()` ou similar para resolver N+1.

#### Optimistic Offline Lock

**Intenção:** detecta edição concorrente sem **bloquear**: falha ao tentar persistir versão antiga.

```sql
ALTER TABLE orders ADD COLUMN version INT NOT NULL DEFAULT 0;
```

```ts
async function updateOrder(order: Order) {
  const result = await db.query(`
    UPDATE orders
    SET status = $1, version = version + 1
    WHERE id = $2 AND version = $3
  `, [order.status, order.id, order.version]);

  if (result.rowCount === 0) {
    throw new ConcurrentModificationError();
  }
}
```

Se outra transação salvou primeiro (version mudou), o UPDATE retorna 0 rows. Cliente recebe erro e pode tentar de novo com dados frescos.

Ver [transactions and isolation](../data/transactions-isolation.md).

### Distribution Patterns

#### Data Transfer Object (DTO)

**Intenção:** objeto pequeno e sem comportamento, usado para **trafegar dados** entre processos/camadas.

```ts
// Domain, rico
class Order {
  constructor(readonly id: OrderId, readonly items: OrderItem[], readonly status: OrderStatus) {}
  totalWithTax(): Money { /* ... */ }
}

// DTO, plano, serializável
interface OrderDTO {
  id: string;
  status: 'placed' | 'paid' | 'shipped';
  items: Array<{
    sku: string;
    quantity: number;
    price: number;
  }>;
  total: number;
}

// Conversor
function toDTO(order: Order): OrderDTO {
  return {
    id: order.id.value,
    status: order.status,
    items: order.items.map(i => ({ sku: i.sku.value, quantity: i.quantity, price: i.price.amount })),
    total: order.totalWithTax().amount,
  };
}
```

**Quando usar:**
- Resposta de API HTTP/gRPC.
- Mensagens entre serviços.
- Estado serializável (cache, queue).

Não confunda DTO com **Entity**: DTO **não tem comportamento**.

#### Remote Facade

**Intenção:** interface coarse-grained sobre um modelo de domínio fine-grained, para reduzir chamadas remotas.

```ts
// Domain (fine-grained)
class Order { /* muitos métodos */ }

// Remote Facade, uma chamada coarse-grained
class OrderFacade {
  async placeOrderAndCharge(input: PlaceOrderInput): Promise<OrderResult> {
    const order = await this.orderService.place(input);
    await this.paymentService.charge(order);
    return { orderId: order.id, total: order.total() };
  }
}
```

Cliente externo (HTTP API, RPC) usa Facade. Cliente interno usa o domínio diretamente.

### Padrões base

#### Money

**Intenção:** representar dinheiro **corretamente**: com moeda, sem ponto flutuante.

```ts
class Money {
  private constructor(
    readonly amount: bigint,    // cents
    readonly currency: 'BRL' | 'USD',
  ) {}

  static of(amount: number, currency: 'BRL' | 'USD'): Money {
    return new Money(BigInt(Math.round(amount * 100)), currency);
  }

  plus(other: Money): Money {
    if (other.currency !== this.currency) throw new CurrencyMismatchError();
    return new Money(this.amount + other.amount, this.currency);
  }

  times(factor: number): Money { /* ... */ }

  toFormatted(): string {
    return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: this.currency }).format(Number(this.amount) / 100);
  }
}
```

**Não use** `number` para dinheiro. Ver [modelagem relacional](../data/relational-modeling.md).

#### Special Case

**Intenção:** subclasse para "caso especial", em vez de `null`.

```ts
abstract class Customer {
  abstract name(): string;
  abstract canBuy(): boolean;
}

class RegularCustomer extends Customer {
  /* ... */
}

class NullCustomer extends Customer {
  name() { return 'Guest'; }
  canBuy() { return false; }
}

// Cliente trata uniformemente, sem if (customer === null)
function show(customer: Customer) {
  console.log(customer.name());
}
```

Em TS moderno, união discriminada (`Customer | null`) com narrowing pelo compilador costuma resolver.

### Comparação rápida

| Quero... | Use |
|---|---|
| Operação simples sem reuso | **Transaction Script** |
| Domínio rico com regras complexas | **Domain Model** |
| API de casos de uso | **Service Layer** |
| Mediar domínio ↔ banco | **Repository** |
| Domínio + persistência junto (CRUD-heavy) | **Active Record** |
| Domínio totalmente separado da persistência | **Data Mapper** |
| Aplicar mudanças atomicamente | **Unit of Work** |
| Garantir identidade única na session | **Identity Map** |
| Carregar sob demanda | **Lazy Load** |
| Detectar concorrência sem bloquear | **Optimistic Offline Lock** |
| Trafegar dados entre camadas/serviços | **DTO** |

## Quando *não* usar

- **Sistemas triviais.** Padrões PoEAA são para aplicações **corporativas**: com regras, persistência, transações. App de 200 linhas não precisa.
- **Quando ORM já oferece.** Hibernate/Prisma/EF implementam UoW, Identity Map, Lazy Load, não reinvente.
- **Active Record + DDD ao mesmo tempo.** Não combinam, Active Record amarra domínio à persistência; DDD quer separação.

## Conceitos relacionados

- [Layered Architecture](../architecture/layered-architecture.md), onde encaixam.
- [Hexagonal](../architecture/hexagonal-ports-adapters.md): Repository como driven port.
- [DDD](../architecture/domain-driven-design.md): Service Layer + Domain Model são pré-requisitos.
- [Modelagem relacional](../data/relational-modeling.md).
- [Transações e isolamento](../data/transactions-isolation.md), base para UoW e locks.

## Referências

- **Livro.** Martin Fowler, *Patterns of Enterprise Application Architecture* (Addison-Wesley, 2002). Texto canônico.
- **Site.** [Fowler: PoEAA Catalog](https://martinfowler.com/eaaCatalog/). Catálogo online com resumo de cada padrão.
- **Livro.** Vaughn Vernon, *Implementing Domain-Driven Design* (Addison-Wesley, 2013). Como PoEAA encaixa em DDD.
- **Livro.** Eric Evans, *Domain-Driven Design* (Addison-Wesley, 2003).
- **Documentação.** [Prisma](https://www.prisma.io/docs). Data Mapper moderno.
- **Documentação.** [Hibernate Reference](https://hibernate.org/orm/documentation/). Implementa boa parte do PoEAA.
- **Livro.** Robert C. Martin, *Clean Architecture* (Prentice Hall, 2017). Como Service Layer + Repository + Domain se compõem.
