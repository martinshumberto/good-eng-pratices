# Test Doubles

> **TL;DR.** *Test double* é um termo guarda-chuva para **objetos que substituem dependências reais em testes**. Há cinco categorias canônicas (dummy, stub, spy, mock, fake) com semânticas distintas. Conheça-as, e use a mais simples que resolve o problema.

## O quê

O termo foi cunhado por **Gerard Meszaros** em *xUnit Test Patterns* (Addison-Wesley, 2007) como analogia ao "dublê" no cinema: substitui o real em situações onde o real seria caro, lento ou inadequado.

Meszaros distingue cinco tipos:

| Tipo | O que faz |
|---|---|
| **Dummy** | Objeto passado mas nunca usado pelo teste. Só preenche assinatura. |
| **Stub** | Retorna valores pré-definidos quando chamado. Não verifica chamadas. |
| **Spy** | Stub que **registra** as chamadas para inspeção posterior. |
| **Mock** | Objeto que **verifica** expectations específicas (geralmente declaradas antes). |
| **Fake** | Implementação simplificada, mas funcional, de uma dependência real. |

**Martin Fowler** consolidou essa terminologia em ["Mocks Aren't Stubs"](https://martinfowler.com/articles/mocksArentStubs.html) (2007), distinguindo dois estilos de teste:

- **Classicist (Detroit)**: usa o real sempre que possível, doubles só quando necessário.
- **Mockist (London)**: usa mocks para todo colaborador, isolando a unidade sob teste.

## Por quê

Test doubles resolvem problemas concretos:

- **Determinismo.** API externa imprevisível? Stub para retornar valor fixo.
- **Velocidade.** Banco real lento? Fake ou stub.
- **Isolamento.** Testar A sem testar B junto.
- **Cenários difíceis.** Reproduzir erro 500 da API parceira em teste local.
- **Antes que exista.** Dependência ainda não implementada.

Mas doubles têm custo:

- **Acoplamento à implementação.** Mocks dizem "essa função vai chamar essa outra"; refactor inocente quebra.
- **Falsa confiança.** Stub que retorna o que você espera não significa que o real retorna assim.
- **Manutenção.** Cada double é mais código para manter.

A regra prática: **use o real sempre que viável**; double quando necessário.

## Como aplicar

### Os cinco tipos

#### Dummy

Objeto inerte. Existe só para preencher uma assinatura. Nunca é chamado pelo teste.

```ts
// Função aceita um logger, mas o teste não verifica logging
const dummyLogger: Logger = { info: () => {}, error: () => {}, warn: () => {} };

it('processes order', async () => {
  const processor = new OrderProcessor(dummyLogger);
  // ...
});
```

#### Stub

Retorna respostas pré-programadas. Não interage além disso.

```ts
const stubRepo: OrderRepository = {
  findById: async (id: string) => buildOrder({ id, status: 'placed' }),
  save:     async () => {},
};

it('cancels a placed order', async () => {
  const useCase = new CancelOrderUseCase(stubRepo);
  const result  = await useCase.exec('ord_1');
  expect(result.status).toBe('canceled');
});
```

#### Spy

Stub que **observa** as chamadas. Útil para verificar que algo foi chamado.

```ts
const events = {
  publish: vi.fn(),
};

it('publishes an event when order is placed', async () => {
  const useCase = new CreateOrderUseCase(stubRepo, events);
  await useCase.exec(validInput);

  expect(events.publish).toHaveBeenCalledWith('OrderPlaced', expect.objectContaining({
    orderId: expect.any(String),
  }));
});
```

`vi.fn()` (Vitest) ou `jest.fn()` (Jest) criam spies por default.

#### Mock

Objeto com **expectations declaradas antes**. A própria existência do mock impõe verificações.

```ts
// Estilo "expectation-first" (raro em JS/TS, comum em outras linguagens)
const mockRepo = createMock<OrderRepository>();
mockRepo.expect('save').once().withArgs(matching({ status: 'placed' }));

await useCase.exec(input);
mockRepo.verify();  // falha se não foi chamado como esperado
```

Em JS/TS, a distinção entre spy e mock é tênue, `vi.fn()` faz os dois trabalhos. Em Java/Mockito ou C#/Moq, mocks têm sintaxe própria.

#### Fake

Implementação **funcional**, mas simplificada. Diferente de stub: tem lógica de verdade.

```ts
class InMemoryOrderRepository implements OrderRepository {
  private orders = new Map<string, Order>();

  async save(order: Order):      Promise<void>          { this.orders.set(order.id, order); }
  async findById(id: string):    Promise<Order | null>  { return this.orders.get(id) ?? null; }
  async findByCustomer(cId: string): Promise<Order[]>   { return [...this.orders.values()].filter(o => o.customerId === cId); }
}

it('finds orders by customer', async () => {
  const repo = new InMemoryOrderRepository();
  await repo.save(buildOrder({ id: '1', customerId: 'c1' }));
  await repo.save(buildOrder({ id: '2', customerId: 'c2' }));

  const orders = await repo.findByCustomer('c1');
  expect(orders).toHaveLength(1);
});
```

Fakes são **mais robustos** que stubs/mocks. Servem como dependência durante o desenvolvimento da app inteira ([In-Memory implementation pattern](https://martinfowler.com/bliki/InMemoryTestDatabase.html)).

### Stub vs Mock: a diferença que importa

A distinção central, segundo Fowler:

- **Stub:** *state verification*. Você verifica o **estado final** (`expect(saved.status).toBe('placed')`).
- **Mock:** *behavior verification*. Você verifica que **certas chamadas foram feitas** (`expect(repo.save).toHaveBeenCalled()`).

State verification é **mais robusto** a mudanças de implementação. Behavior verification **acopla** o teste ao "como", refactor que mantém o comportamento pode quebrar o teste.

```ts
// ❌ Behavior verification, acoplado à implementação
it('publishes event after saving', async () => {
  await useCase.exec(input);
  expect(repo.save).toHaveBeenCalledBefore(events.publish);
});

// ✅ State verification, verifica resultado observável
it('marks order as placed', async () => {
  await useCase.exec(input);
  expect((await repo.findById(orderId)).status).toBe('placed');
});
```

Use behavior verification quando a **interação em si** é o ponto (ex.: "deve enviar email") e o resultado não é observável de outro modo.

### Quando usar cada tipo

| Cenário | Use |
|---|---|
| Função recebe argumento que nem é usado no teste | Dummy |
| Função consulta dependência; quero controlar o retorno | Stub |
| Função chama dependência; quero verificar que chamou | Spy |
| Função orquestra colaboradores; quero verificar interações | Mock (= spy + asserções) |
| Função consulta e escreve em dependência; quero comportamento próximo do real | Fake |
| Função interage com banco; quero verificar SQL | **Real** (integration test) |

### Classicist vs Mockist (Detroit vs London)

#### Classicist

> "Use the real implementation. Only use a double if the real thing is expensive or unavailable."

Característica:

- **Funções puras** são testadas direto.
- **Banco** vira fake/integration test.
- **Doubles** são exceção.

#### Mockist

> "Mock every collaborator. Test units in pure isolation."

Característica:

- **Cada teste mocka tudo** ao redor da unidade.
- **Outside-in TDD**: começa pelo top, mocka colaboradores, depois implementa.

A maior parte dos times modernos é **predominantemente classicist com pontos mockist**: usa o real quando possível, mocka quando faz sentido.

### Anti-padrões

#### Mock everywhere

Quando todo teste tem 5 mocks, refatorar vira pesadelo, cada mudança quebra 20 testes.

```ts
// ❌ Mocks duplicam a implementação
it('does the thing', async () => {
  mockA.method1.mockResolvedValue(/* exact mirror of impl */);
  mockB.method2.mockResolvedValue(/* exact mirror of impl */);
  mockC.method3.mockResolvedValue(/* exact mirror of impl */);
  // ...
});
```

#### Mockar coisas que você não controla

Mock de `fetch`, `Date.now`, libs externas, frágil. Esses mocks não pegam mudanças nas bibliotecas, e quebram em upgrades.

```ts
// ❌ Mocka método interno de uma library
vi.mock('axios', () => ({ default: { get: vi.fn() } }));

// ✅ Wrapper na sua camada; testa contra o wrapper
class HttpClient {
  async get<T>(url: string): Promise<T> { /* uses axios */ }
}
const stubClient: HttpClient = { get: async () => ({ /* ... */ }) };
```

#### Stubs que retornam o que você precisa

Stub que retorna **exatamente** o que faz o teste passar não verifica nada além de "o teste compila".

```ts
// ❌
stub.calculate.mockReturnValue(42);
// ...
expect(thing.value).toBe(42);   // veio do mock direto
```

### Hand-rolled vs Framework-driven

#### Hand-rolled (preferível em geral)

Objetos manuais. Explícitos. Refatoração-amigáveis.

```ts
class InMemoryEmailService implements EmailService {
  sentEmails: Email[] = [];
  async send(email: Email): Promise<void> { this.sentEmails.push(email); }
}

it('sends welcome email on signup', async () => {
  const emails = new InMemoryEmailService();
  await signupUseCase.exec(user, { emails });

  expect(emails.sentEmails).toHaveLength(1);
  expect(emails.sentEmails[0].subject).toBe('Welcome!');
});
```

#### Framework-driven (Vitest mock, Sinon)

Mais flexível para casos simples; mais magia.

```ts
const send = vi.fn();
await signupUseCase.exec(user, { send });
expect(send).toHaveBeenCalledWith(expect.objectContaining({ subject: 'Welcome!' }));
```

Ambos são válidos. Hand-rolled é mais auto-documentado; framework-driven é mais conciso.

## Quando *não* usar

- **Testes integration com banco real.** Não mock o ORM, teste contra Postgres em Testcontainers.
- **Funções puras.** Sem dependências externas, sem necessidade de doubles.
- **Quando o "double" tem mais código que o real.** Sinal de que o real já é simples, use-o.

## Conceitos relacionados

- [Pirâmide de testes](./test-pyramid.md), doubles vivem no nível unit.
- [Unit vs Integration vs E2E](./unit-vs-integration-vs-e2e.md), quando substituir reais.
- [TDD / BDD](./tdd-bdd.md), escolha classicist/mockist afeta TDD.
- [Hexagonal](../architecture/hexagonal-ports-adapters.md), interfaces dos ports facilitam fakes.

## Referências

- **Livro.** Gerard Meszaros, *xUnit Test Patterns* (Addison-Wesley, 2007). Texto canônico que cunhou os termos. [xunitpatterns.com](http://xunitpatterns.com).
- **Livro.** Steve Freeman & Nat Pryce, *Growing Object-Oriented Software, Guided by Tests* (Addison-Wesley, 2009). Defesa de mockist style.
- **Livro.** Vladimir Khorikov, *Unit Testing Principles, Practices, and Patterns* (Manning, 2020). Crítica balanceada.
- **Artigo.** Martin Fowler, ["Mocks Aren't Stubs"](https://martinfowler.com/articles/mocksArentStubs.html) (2007). Texto que consolidou a terminologia.
- **Artigo.** Martin Fowler, ["TestDouble"](https://martinfowler.com/bliki/TestDouble.html).
- **Artigo.** Martin Fowler, ["InMemoryTestDatabase"](https://martinfowler.com/bliki/InMemoryTestDatabase.html). Sobre fakes de banco.
- **Documentação.** [Vitest: Mock Functions](https://vitest.dev/api/mock.html).
- **Documentação.** [Sinon.JS](https://sinonjs.org/). Library mais antiga, ainda relevante.
