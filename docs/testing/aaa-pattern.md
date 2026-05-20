# Padrão AAA: Arrange, Act, Assert

> **TL;DR.** Estruture cada teste em três blocos claros: prepare os dados (*Arrange*), execute a ação (*Act*), verifique o resultado (*Assert*). Testes legíveis seguem essa cadência.

## O quê

O padrão AAA (*Arrange, Act, Assert*) propõe que cada teste seja dividido em três seções visualmente distintas:

- **Arrange.** Prepara o cenário: cria objetos, configura dependências, define entradas.
- **Act.** Executa a única ação que o teste está verificando.
- **Assert.** Verifica que o resultado da ação atende à expectativa.

A formulação foi popularizada por **Bill Wake** em 2001 e é hoje a convenção mais difundida de organização de testes unitários.

## Por quê

Testes são lidos muito mais vezes do que escritos. Quando um teste falha, alguém precisa entender em segundos *o que* o teste verifica para diagnosticar a regressão. AAA cria um esqueleto previsível: o olho do leitor procura "qual é o setup, qual é a ação, qual é a expectativa", e encontra cada coisa em um lugar reservado.

Benefícios:

- **Diagnóstico rápido.** Falhou em quê? Olha o *Assert*. Por quê? Olha o *Arrange* + *Act*.
- **Disciplina.** Forçar uma única ação por teste impede testes que verificam "tudo de uma vez" e falham por motivos ambíguos.
- **Documentação executável.** O teste vira um exemplo de uso da API.

## Como aplicar

### Estrutura básica

```ts
import { describe, it, expect } from 'vitest';

describe('Cart', () => {
  it('returns the total price with tax', () => {
    // Arrange
    const cart = buildCart({ items: 2, unitPrice: 10 });

    // Act
    const total = cart.totalWithTax(0.1);

    // Assert
    expect(total).toBe(22);
  });
});
```

Não é obrigatório escrever os comentários `// Arrange` etc., o espaçamento entre blocos costuma ser suficiente. O importante é a **separação visual**.

### Uma ação por teste

A regra mais valiosa do AAA. Quando o *Act* tem várias linhas, o teste passa a falhar por qualquer uma delas, e a mensagem de erro perde precisão.

```ts
// ❌ Três ações, três motivos possíveis de falhar
it('checkout flow', () => {
  const cart = new Cart();
  cart.addItem({ price: 10 });
  cart.applyCoupon('WELCOME10');
  cart.checkout();
  expect(cart.total).toBe(9);
});

// ✅ Cada teste verifica uma transição
it('applies coupon discount on total', () => {
  const cart = new Cart();
  cart.addItem({ price: 10 });

  cart.applyCoupon('WELCOME10');

  expect(cart.total).toBe(9);
});
```

### Asserções afirmativas e simples

Bons PRs cobrem a lógica de negócio com afirmações claras:

- cria um novo usuário
- deleta um usuário
- lança erro quando o usuário não existe
- aplica desconto quando o cliente é fiel

O revisor deve ser capaz de entender o que o código faz **lendo apenas os nomes dos testes**. Se os testes não funcionam como documentação, há espaço para melhorias.

### Entradas e saídas descritivas

O fluxo computacional básico é IPO (*Input → Process → Output*). Quando entradas e saídas dos testes são descritivas, a intenção do método fica clara.

```ts
// ❌
it('test 1', () => {
  expect(calc(1, 2)).toBe(3);
});

// ✅
it('sums two positive integers', () => {
  const result = calc(1, 2);
  expect(result).toBe(3);
});
```

### Use *builders* para o Arrange

Repetir setup completo em todo teste cansa a leitura. Concentre a montagem em *factory* ou *builder* funções, deixando no teste só o que é relevante para aquele caso.

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

it('cancels a placed order', () => {
  const order = buildOrder({ status: 'placed' });

  const result = cancel(order);

  expect(result.status).toBe('canceled');
});
```

### Variantes equivalentes

- **Given / When / Then**: vocabulário do BDD (*Behavior-Driven Development*), popular com Cucumber/Gherkin. Estrutura idêntica ao AAA, ênfase em comportamento.
- **Four-Phase Test**: de *xUnit Test Patterns* (Meszaros, 2007): *Setup → Exercise → Verify → Teardown*. Inclui um quarto bloco explícito para cleanup quando o framework não cuida.

## Quando *não* usar

- **Testes de propriedade (property-based).** Frameworks como [fast-check](https://fast-check.dev/) geram casos automaticamente. A estrutura "AAA" desaparece, o que sobra é a propriedade invariante.
- **Testes "snapshot".** O *Assert* é o snapshot armazenado em arquivo, não uma expectativa explícita. Use com parcimônia para evitar testes que ninguém entende.
- **Quando o setup é trivial.** Testes de uma linha (`expect(slugify('Hello World')).toBe('hello-world')`) não ganham nada com a divisão.

## Conceitos relacionados

- [Pirâmide de testes](./test-pyramid.md), onde testes unitários se encaixam.
- [TDD / BDD](./tdd-bdd.md)
- [Test doubles](./test-doubles.md), quando o *Arrange* envolve mocks/stubs.

## Referências

- **Artigo.** Bill Wake, ["3A: Arrange, Act, Assert"](https://xp123.com/articles/3a-arrange-act-assert/) (XP123, 2001). Texto original do padrão.
- **Livro.** Gerard Meszaros, *xUnit Test Patterns* (Addison-Wesley, 2007). Apresentação do *Four-Phase Test*.
- **Livro.** Steve Freeman & Nat Pryce, *Growing Object-Oriented Software, Guided by Tests* (Addison-Wesley, 2009). TDD aplicado.
- **Livro.** Vladimir Khorikov, *Unit Testing Principles, Practices, and Patterns* (Manning, 2020). Discussão moderna sobre testes legíveis e mantíveis.
