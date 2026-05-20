# Pirâmide de Testes

> **TL;DR.** Tenha **muitos testes unitários (rápidos)**, **alguns testes de integração**, **poucos testes end-to-end (lentos e frágeis)**. A pirâmide é um princípio sobre custo × confiança, não uma regra absoluta. Em alguns contextos, vale repensar o formato.

## O quê

A **Test Pyramid** foi formalizada por **Mike Cohn** em *Succeeding with Agile* (Addison-Wesley, 2009). Define uma proporção sugerida entre tipos de testes ordenados por escopo:

```
                    ▲
                   ╱ ╲           E2E / UI tests
                  ╱   ╲           (poucos, lentos, frágeis)
                 ╱─────╲
                ╱       ╲        Integration tests
               ╱         ╲        (alguns)
              ╱───────────╲
             ╱             ╲     Unit tests
            ╱               ╲     (muitos, rápidos, isolados)
           ╱─────────────────╲
```

A intuição: à medida que se sobe a pirâmide, os testes ficam **mais caros para escrever e manter**, **mais lentos para rodar** e **mais frágeis**. À medida que se desce, ganha-se velocidade e estabilidade, mas perde-se confiança no comportamento integrado.

## Por quê

Sem essa distribuição, equipes caem em dois antipadrões clássicos:

- **Sorvete invertido (*ice cream cone*)**, muitos E2E, poucos unitários. CI demora horas, testes flakam, fix de bug exige rodar suite inteira. Sinal de testes adicionados depois, quando o código já estava difícil de testar em unidade.
- **Cone de testes**: só testes unitários, sem integração. Cada unidade passa, mas o sistema integrado quebra. Comum em projetos com mocks excessivos onde unidades nunca conversam com a verdade.

A pirâmide balanceia:

- **Velocidade.** Suite unitária roda em segundos; bom feedback no dev.
- **Confiança.** Integração e E2E pegam problemas que unitário esconde (queries, serialização, contratos).
- **Custo.** Manutenção de E2E é cara, quanto menos, melhor (mas não zero).

## Como aplicar

### As 3 camadas

#### Unit tests: base ampla

- **Escopo:** uma unidade lógica (função, classe, módulo) isolada.
- **Dependências externas:** stubbed/mocked.
- **Velocidade:** milissegundos por teste.
- **Quantidade típica:** centenas a milhares.

```ts
// Unidade pura, sem rede, sem banco, sem framework
describe('calculateDiscount', () => {
  it('applies 10% off when total is above 100', () => {
    expect(calculateDiscount(150)).toBe(15);
  });

  it('applies no discount when total is below 100', () => {
    expect(calculateDiscount(50)).toBe(0);
  });
});
```

#### Integration tests: meio

- **Escopo:** múltiplos componentes interagindo. Frequentemente envolve banco, fila, API externa via container/stub.
- **Velocidade:** centenas de ms por teste.
- **Quantidade típica:** dezenas a centenas.

```ts
// Roda contra Postgres real (em container ou banco local)
describe('OrderRepository (integration)', () => {
  beforeEach(() => db.migrate.rollback().then(() => db.migrate.latest()));

  it('persists and retrieves an order', async () => {
    const repo = new PostgresOrderRepository(db);
    await repo.save(buildOrder({ id: 'ord_1' }));

    const fetched = await repo.findById('ord_1');
    expect(fetched).toMatchObject({ id: 'ord_1', status: 'placed' });
  });
});
```

#### E2E / UI tests: topo

- **Escopo:** sistema inteiro, simulando o usuário.
- **Dependências:** ambiente próximo do real (frontend + backend + banco + serviços).
- **Velocidade:** segundos a dezenas de segundos por teste.
- **Quantidade típica:** poucas dezenas, só para os **fluxos críticos**.

```ts
// Playwright / Cypress
test('user can place an order', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Login' }).click();
  await page.fill('#email', 'alice@example.com');
  await page.fill('#password', 'password');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await page.getByText('Product A').click();
  await page.getByRole('button', { name: 'Add to cart' }).click();
  await page.getByRole('button', { name: 'Checkout' }).click();

  await expect(page.getByText('Order confirmed')).toBeVisible();
});
```

### Proporção sugerida (referência)

| Camada | % aproximado da suite |
|---|---|
| Unit | 70% |
| Integration | 20% |
| E2E | 10% |

São referências, não regras. Sistemas com lógica de domínio rica tendem a ter ainda mais unitários; sistemas integradores de APIs externas precisam de mais integração.

### Outras formas: o "Testing Trophy" de Kent C. Dodds

Em apps **frontend pesadas em UI**, **Kent C. Dodds** [propôs o *Testing Trophy*](https://kentcdodds.com/blog/the-testing-trophy-and-testing-classifications):

```
       ╔═══════════════╗
       ║   End-to-end  ║       (poucos)
   ┌───╨───────────────╨───┐
   │     Integration       │   (muitos!)
   └───┐               ┌───┘
       │   Unit        │       (alguns)
       ╘═══════════════╛
            Static               (lint, types)
```

Argumento: em apps modernas, **integration tests com testing-library** dão maior retorno por linha de teste. Unitários puros de funções pequenas são menos críticos quando essas funções são triviais ou o framework cobre. **Tipos estáticos** + **lint** já pegam uma classe inteira de bugs.

A pirâmide tradicional sobrevive para backend lógica-pesada; o troféu serve melhor para frontend.

### Princípios práticos

#### Teste comportamento, não implementação

Foco em "dado X, o sistema faz Y", não em "função A chama função B". Testes acoplados à implementação quebram em todo refactor sem proteger comportamento.

```ts
// ❌ Acoplado à implementação
it('calls validator and then calls repo.save', () => {
  /* verifica spies em ordem */
});

// ✅ Verifica comportamento observável
it('saves the order when input is valid', async () => {
  await useCase.exec(validInput);
  const saved = await repo.findById(orderId);
  expect(saved).toBeDefined();
});
```

#### Isolation por convenção

Cada teste deveria poder rodar **sozinho**, em **qualquer ordem**, e produzir o mesmo resultado. Compartilhamento de estado entre testes é fonte clássica de flakiness.

```ts
// ❌ Depende de ordem (test 2 só passa depois de test 1)
let userId: string;
it('creates a user',  async () => { userId = (await createUser()).id; });
it('updates the user', async () => { await updateUser(userId, /* ... */); });

// ✅ Isolado
it('updates an existing user', async () => {
  const { id } = await createUser();
  await updateUser(id, /* ... */);
});
```

#### Não meça cobertura por meta

> "Coverage is a useful tool for finding untested parts of a codebase. It's not particularly useful as a number to drive."
> (Martin Fowler, [TestCoverage](https://martinfowler.com/bliki/TestCoverage.html))

80% de cobertura com testes ruins é pior que 60% com testes bons. Use coverage para **descobrir áreas sem teste**, não como KPI.

#### CI separado por camada

Configure pipelines em estágios:

```
Push → Unit + Lint + Types (rápido, todo commit)
     → Integration (em PR / merge)
     → E2E (após deploy em staging)
```

Feedback rápido nos níveis baixos; níveis altos só quando faz sentido.

### Pega-pegas comuns

#### Flakiness

Testes que falham aleatoriamente erodem confiança. Causas:

- **Time/timing**: race conditions; aguarde explicitamente (`waitFor`), não use `sleep` arbitrário.
- **Estado compartilhado**: banco, filesystem, env vars. Use isolation por teste.
- **Externals**: APIs externas em E2E. Use mocks ou ambientes dedicados.

Quando um teste flaka, **investigue e corrija**. Skippar é dívida que aumenta.

#### Tests que demoram demais

Suite que demora 30 min ninguém roda. Otimize:

- Paralelize quando possível (Vitest, Jest, Playwright suportam).
- Use containers efêmeros ([testcontainers](https://testcontainers.com)) em vez de banco compartilhado.
- Refatore testes lentos em camadas mais baixas quando possível.

#### Testar o framework

Não teste que `useState` funciona. Não teste que o ORM persiste. Testes assim cobrem o framework, não o seu código. Foque no que **você** escreveu.

## Quando *não* usar

- **Scripts triviais.** Pirâmide formal não se paga.
- **Prova de conceito.** Vale o teste manual + lint.
- **Quando rigidamente seguida ignora contexto.** Um app com lógica de UI complexa pode legitimamente ter mais integration que unit.

## Conceitos relacionados

- [Unit vs Integration vs E2E](./unit-vs-integration-vs-e2e.md), definições detalhadas de cada nível.
- [Test doubles](./test-doubles.md), quando mockar.
- [Padrão AAA](./aaa-pattern.md), estrutura interna do teste.
- [TDD / BDD](./tdd-bdd.md), práticas de **quando** escrever os testes.

## Referências

- **Livro.** Mike Cohn, *Succeeding with Agile: Software Development Using Scrum* (Addison-Wesley, 2009). Capítulo 16 introduz a pirâmide.
- **Livro.** Lisa Crispin & Janet Gregory, *Agile Testing* (Addison-Wesley, 2008). Discussão sobre níveis e quadrantes.
- **Livro.** Vladimir Khorikov, *Unit Testing Principles, Practices, and Patterns* (Manning, 2020). Tratado moderno sobre testes mantíveis.
- **Artigo.** Martin Fowler, ["TestPyramid"](https://martinfowler.com/bliki/TestPyramid.html). Bliki canônico.
- **Artigo.** Martin Fowler, ["Test Coverage"](https://martinfowler.com/bliki/TestCoverage.html).
- **Artigo.** Kent C. Dodds, ["Testing Trophy and Testing Classifications"](https://kentcdodds.com/blog/the-testing-trophy-and-testing-classifications). Variante para frontend.
- **Artigo.** Google Testing Blog, ["Just Say No to More End-to-End Tests"](https://testing.googleblog.com/2015/04/just-say-no-to-more-end-to-end-tests.html) (2015). Argumento contra abuso de E2E.
