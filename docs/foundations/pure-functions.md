# Funções puras

> **TL;DR.** Funções que dependem apenas dos seus argumentos e não causam efeitos colaterais são a forma mais simples de código testável, paralelizável e raciocinável. Prefira-as para lógica de negócio.

## O quê

Uma função é **pura** quando satisfaz duas condições:

1. **Determinística**: para os mesmos argumentos, sempre retorna o mesmo resultado.
2. **Sem efeitos colaterais observáveis**: não modifica estado fora do seu escopo, não faz I/O, não muta os argumentos.

```ts
// ✅ Pura
function totalWithTax(amount: number, rate: number): number {
  return amount * (1 + rate);
}

// ❌ Impura, depende de Date.now (não-determinística)
function isExpired(dueAt: Date): boolean {
  return dueAt.getTime() < Date.now();
}

// ❌ Impura, muta um argumento
function addItem(cart: Cart, item: Item): void {
  cart.items.push(item);
}
```

O conceito vem da matemática e é central em linguagens funcionais (Haskell, Elm, OCaml), mas se aplica a qualquer linguagem.

## Por quê

Funções puras oferecem três ganhos diretos para a lógica de negócio:

1. **Clareza**: separam a regra ("o que") da plumbagem ("quem chama, quando, com qual estado").
2. **Testabilidade**: sem dependências externas, o teste é apenas *input → assertion*. Sem mocks, sem fixtures.
3. **Manutenção**: chamar uma função pura não muda o resto do mundo. Bugs ficam localizados.

Há ganhos secundários: cache (memoization), paralelização segura, otimização agressiva do compilador.

> "If a function does not produce a side effect, it is referentially transparent."
> (*Structure and Interpretation of Computer Programs* (SICP))

## Como aplicar

### Empurre a impureza para a borda

A maioria dos sistemas precisa de I/O, datas, IDs gerados aleatoriamente, atividades inerentemente impuras. A estratégia é manter o **núcleo** puro e isolar a impureza na **borda** (também chamada de *functional core, imperative shell*).

```ts
// ❌ Mistura regra (pura) com I/O (impuro) e relógio (impuro)
async function chargeCustomer(customerId: string, amount: number) {
  const customer = await db.findCustomer(customerId);
  const tax = customer.region === 'BR' ? 0.1 : 0;
  const total = amount * (1 + tax);
  await stripe.charge(customer.cardId, total);
  await db.logCharge({ customerId, total, at: new Date() });
}

// ✅ Núcleo puro
function calculateTotalForRegion(amount: number, region: Region): number {
  const rate = region === 'BR' ? 0.1 : 0;
  return amount * (1 + rate);
}

// ✅ Casca impura, pequena, fácil de testar de ponta a ponta
async function chargeCustomer(customerId: string, amount: number) {
  const customer = await db.findCustomer(customerId);
  const total    = calculateTotalForRegion(amount, customer.region);
  await stripe.charge(customer.cardId, total);
  await db.logCharge({ customerId, total, at: new Date() });
}
```

A regra de negócio agora pode ser testada com `expect(calculateTotalForRegion(100, 'BR')).toBe(110)`: sem mockar Stripe nem banco.

### Trate dados como imutáveis

Operações que "mudam" um objeto devem retornar um novo:

```ts
// ❌ Muta o argumento, quem mais aponta para ele se ferra
function addItem(cart: Cart, item: Item): void {
  cart.items.push(item);
}

// ✅ Retorna um novo Cart
function addItem(cart: Cart, item: Item): Cart {
  return { ...cart, items: [...cart.items, item] };
}
```

Em TypeScript, marque tipos como `readonly` para deixar a intenção explícita.

### Receba dependências como parâmetros

Quando a função precisa de algo que normalmente seria global (relógio, gerador de IDs), receba via argumento:

```ts
// ❌ Acopla a Date.now, não-testável sem mock global
function isExpired(dueAt: Date): boolean {
  return dueAt.getTime() < Date.now();
}

// ✅ Recebe o relógio, testável com qualquer valor
function isExpiredAt(dueAt: Date, now: Date): boolean {
  return dueAt.getTime() < now.getTime();
}
```

## Quando *não* usar

- **Quando o efeito colateral É o ponto.** `console.log`, gravar no banco, enviar um email, operações *com* efeito colateral são necessárias. Funções puras dominam o núcleo, não 100% do código.
- **Em hot paths com performance crítica.** Cópias imutáveis criam alocação. Para *high-throughput*, mutação local controlada (sem vazar para fora da função) pode ser aceitável.
- **Quando o cliente está acostumado com a API mutável.** Mudar uma API estabelecida só por pureza pode quebrar mais do que resolve.

## Conceitos relacionados

- [MISU: Make Illegal States Unrepresentable](./make-illegal-states-unrepresentable.md)
- [Padrão AAA em testes](../testing/aaa-pattern.md)
- [SOLID](./solid.md), especialmente DIP, que injeta dependências de impureza.

## Referências

- **Livro.** Eric Normand, *Grokking Simplicity* (Manning, 2021). Apresentação acessível de *functional core, imperative shell*.
- **Livro.** Harold Abelson & Gerald Sussman, *Structure and Interpretation of Computer Programs* (MIT Press, 1985). Capítulo 3 introduz transparência referencial.
- **Artigo.** Gary Bernhardt, ["Boundaries"](https://www.destroyallsoftware.com/talks/boundaries) (palestra). Apresenta o padrão *functional core, imperative shell*.
- **Artigo.** Mark Seemann, ["Pure functions suffer from no… side effects"](https://blog.ploeh.dk/2018/11/19/functional-architecture-the-pits-of-success/).
