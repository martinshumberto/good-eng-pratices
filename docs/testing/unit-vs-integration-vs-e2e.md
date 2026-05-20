# Unit vs Integration vs E2E

> **TL;DR.** **Unit** testa uma unidade isolada (rápido, muitos). **Integration** testa unidades juntas, incluindo I/O real (médio, alguns). **E2E** testa o sistema completo via interface externa (lento, poucos). Cada um pega um tipo de bug diferente, não substitua um pelo outro.

## O quê

Os termos não têm definição universal; cada autor usa um pouco diferente. Para fins deste documento:

| Nível | Escopo | Dependências reais | Velocidade típica |
|---|---|---|---|
| **Unit** | Uma função / classe | Tudo mockado | < 10ms |
| **Integration** | Múltiplos componentes | Banco, fila, FS reais | 100ms – 1s |
| **E2E** | Sistema completo via UI ou API pública | Tudo (frontend + backend + DB + serviços) | 1s – 30s |

A distinção mais importante: **o que você está disposto a tocar de verdade?**

- Unit: nada externo.
- Integration: algumas dependências (banco real, fila real); outras stubbed (APIs externas).
- E2E: tudo, em ambiente próximo de produção.

## Por quê

Cada nível pega um tipo de bug que os outros não pegam:

- **Unit pega bugs de lógica.** Cálculos errados, branches mal tratados, edge cases.
- **Integration pega bugs de borda.** Query SQL inválida, serialização, contratos entre módulos.
- **E2E pega bugs de fluxo.** "O botão de login não está visível", "checkout quebra com cupom".

Confiar em **só um nível** deixa categorias de bug passarem. Eis a [pirâmide](./test-pyramid.md): balanceie quantidade × confiança × custo.

## Como aplicar

### Unit tests

**Objetivo:** verificar lógica isolada. Rápido feedback no dev.

**Estrutura:**

```ts
// Teste de função pura, ideal para unit
import { calculateDiscount } from './discount';

describe('calculateDiscount', () => {
  it('returns 0 below threshold', () => {
    expect(calculateDiscount(50)).toBe(0);
  });

  it('returns 10% above 100', () => {
    expect(calculateDiscount(150)).toBe(15);
  });
});
```

**Dependências mockadas:**

```ts
// Teste de use case, colaboradores mockados
import { CreateOrderUseCase } from './create-order';

const repo = { save: vi.fn() };
const events = { publish: vi.fn() };

it('saves the order and publishes event', async () => {
  const useCase = new CreateOrderUseCase(repo, events);
  await useCase.exec({ items: [/* ... */] });

  expect(repo.save).toHaveBeenCalled();
  expect(events.publish).toHaveBeenCalledWith('OrderPlaced', expect.anything());
});
```

**Quando usar:**

- Toda lógica de domínio nova.
- Funções puras com múltiplos casos.
- Validação, cálculos, transformações.
- Branches importantes (sucesso, falha, edge cases).

**Quando *não* usar:**

- Glue code trivial (controllers que só chamam use case).
- Wrappers de bibliotecas (a lib já é testada).
- Configuração estática.

### Integration tests

**Objetivo:** verificar que componentes funcionam **juntos** com dependências reais.

**Estrutura típica:**

```ts
import { Pool } from 'pg';
import { PostgresOrderRepository } from './postgres-order-repository';

let db: Pool;
let repo: PostgresOrderRepository;

beforeAll(async () => {
  db = new Pool({ connectionString: process.env.TEST_DATABASE_URL });
  await runMigrations(db);
});

beforeEach(async () => {
  await db.query('TRUNCATE TABLE orders CASCADE');
});

afterAll(() => db.end());

describe('PostgresOrderRepository (integration)', () => {
  beforeEach(() => { repo = new PostgresOrderRepository(db); });

  it('persists and retrieves an order', async () => {
    const order = buildOrder({ id: 'ord_1' });
    await repo.save(order);

    const fetched = await repo.findById('ord_1');
    expect(fetched).toMatchObject({ id: 'ord_1', status: 'placed' });
  });

  it('returns null when order does not exist', async () => {
    expect(await repo.findById('nope')).toBeNull();
  });
});
```

**Banco para testes:**

| Estratégia | Quando |
|---|---|
| **Banco local dedicado** | Dev rápido. Limpo entre testes via `TRUNCATE` ou transactions. |
| **[Testcontainers](https://testcontainers.com)** | CI. Sobe Postgres em Docker por suíte. Isolamento total. |
| **SQLite in-memory** | Tentador, mas perigoso, diverge do Postgres em comportamentos sutis. |

Em CI, **prefira Testcontainers** sobre SQLite, testar contra o banco real evita surpresas em prod.

**Quando usar integration:**

- Queries SQL (especialmente as complexas).
- Implementações de repositories.
- Workers que consomem fila real.
- Integrações entre módulos próprios.

### E2E tests

**Objetivo:** verificar que **fluxos completos** funcionam do ponto de vista do usuário.

Duas variantes principais:

#### E2E via UI (Playwright, Cypress)

```ts
import { test, expect } from '@playwright/test';

test('user places an order', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('link', { name: 'Login' }).click();
  await page.fill('#email', 'alice@example.com');
  await page.fill('#password', 'secret');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await page.getByText('Product A').click();
  await page.getByRole('button', { name: 'Add to cart' }).click();
  await page.getByRole('button', { name: 'Checkout' }).click();

  await expect(page.getByText('Order confirmed')).toBeVisible();
});
```

#### E2E via API (subcutâneo)

Mesma cobertura, sem browser. Mais rápido e estável:

```ts
test('user places an order via API', async () => {
  const auth = await api.post('/auth/login', { email: 'alice@example.com', password: 'secret' });
  const cart = await api.post('/cart/items', { productId: 'p1', quantity: 1 }, auth.token);
  const order = await api.post('/orders', { cartId: cart.id }, auth.token);

  expect(order.status).toBe('placed');
});
```

E2E via API é frequentemente subestimado. **A maioria dos bugs "E2E" não está na UI**: está na integração de serviços. Teste isso sem o overhead de um browser.

**Quando usar E2E:**

- Fluxos críticos de negócio (signup, checkout, payment).
- Smoke tests pós-deploy.
- Cobertura de regressão em features-bandeira.

**Quanto:** **poucos**: dezenas, não centenas. Cada E2E é caro de escrever, lento de rodar, e tem mais chance de flakar.

### Test data: como cuidar

#### Builders / factories

Não monte objetos completos em cada teste. Centralize:

```ts
function buildOrder(overrides: Partial<Order> = {}): Order {
  return {
    id: 'ord_1',
    customerId: 'cus_1',
    items: [{ sku: 'A', quantity: 1, price: 10 }],
    status: 'placed',
    ...overrides,
  };
}

// no teste
const order = buildOrder({ status: 'canceled' });
```

#### Faker para variabilidade

[`@faker-js/faker`](https://fakerjs.dev) gera dados realistas (nomes, emails, datas).

#### Seeding controlado

Em E2E, evite "criar 5 users no banco antes de cada teste", devagar. Use seed compartilhado, ou crie via API o necessário.

### Performance da suite

#### Paralelização

```bash
# Vitest / Jest
vitest run --pool=threads --maxWorkers=8

# Playwright
playwright test --workers=4
```

Cuidado com **estado compartilhado**: paralelizar testes que tocam o mesmo banco gera flakiness. Use isolamento por schema/database/dado.

#### Test scoping em CI

Rode apenas o necessário em cada estágio:

```
Push:
  ✓ Lint
  ✓ Types
  ✓ Unit
PR:
  + Integration
Merge to main:
  + E2E
Nightly:
  + Performance / load
```

### Ferramentas comuns (TypeScript)

| Nível | Ferramentas |
|---|---|
| Unit | [Vitest](https://vitest.dev), [Jest](https://jestjs.io), [node:test](https://nodejs.org/api/test.html) |
| Integration | Vitest/Jest + [Testcontainers](https://testcontainers.com), [supertest](https://github.com/ladjs/supertest) |
| E2E (UI) | [Playwright](https://playwright.dev), [Cypress](https://www.cypress.io) |
| E2E (API) | Vitest + axios/fetch ou supertest |
| Visual | [Storybook](https://storybook.js.org) + [Chromatic](https://www.chromatic.com), [Percy](https://percy.io) |
| Mutation | [Stryker](https://stryker-mutator.io) |

## Quando *não* usar

- **E2E para tudo.** Ice cream cone. Caro, lento, frágil.
- **Unit puro para integração com banco.** Mockar o ORM esconde os bugs reais de SQL.
- **Integration que tenta ser unit.** Testar lógica de cálculo via API completa é desperdício.

Cada nível faz o seu trabalho. Misturar custa caro e cobre mal.

## Conceitos relacionados

- [Pirâmide de testes](./test-pyramid.md), proporção entre eles.
- [Test doubles](./test-doubles.md), quando mockar e como.
- [Contract testing](./contract-testing.md), alternativa a E2E entre serviços.
- [Padrão AAA](./aaa-pattern.md).

## Referências

- **Livro.** Vladimir Khorikov, *Unit Testing Principles, Practices, and Patterns* (Manning, 2020). Distinções precisas entre unit/integration.
- **Livro.** Lisa Crispin & Janet Gregory, *More Agile Testing* (Addison-Wesley, 2014).
- **Artigo.** Martin Fowler, ["UnitTest"](https://martinfowler.com/bliki/UnitTest.html), ["IntegrationTest"](https://martinfowler.com/bliki/IntegrationTest.html).
- **Artigo.** Mike Hadlow, ["The London (Mockist) vs Chicago (Classicist) Schools of TDD"](http://codebetter.com/jeremymiller/2007/04/22/london-vs-chicago-tdd/), distinção que ressoa em unit vs integration.
- **Documentação.** [Playwright](https://playwright.dev/docs/intro). E2E moderna.
- **Documentação.** [Testcontainers](https://testcontainers.com/). Padrão moderno para integration tests.
- **Artigo.** Google Testing Blog, ["Test Sizes"](https://testing.googleblog.com/2010/12/test-sizes.html). Small/medium/large como categorização alternativa.
