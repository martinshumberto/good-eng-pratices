# TDD e BDD

> **TL;DR.** **TDD** = escrever o teste antes do código (red → green → refactor). **BDD** = escrever especificações em linguagem natural focadas em comportamento. TDD é prática de programação; BDD é prática de comunicação. Os dois se complementam mas resolvem coisas diferentes.

## O quê

### TDD: Test-Driven Development

**Test-Driven Development** foi codificado por **Kent Beck** em *Test Driven Development: By Example* (Addison-Wesley, 2002), embora a prática venha de antes (XP, anos 90).

O ciclo é curto e disciplinado:

```
   Red    →    Green    →    Refactor
 (test)     (passa)        (limpa)
```

1. **Red.** Escreva um teste que falha (a feature ainda não existe).
2. **Green.** Implemente o mínimo necessário para o teste passar.
3. **Refactor.** Melhore o código sem quebrar o teste.

Repita em ciclos de **minutos**.

### BDD: Behavior-Driven Development

**Behavior-Driven Development** foi nomeado por **Dan North** em 2003 ([artigo original](https://dannorth.net/introducing-bdd/)). Surgiu da observação de que TDD funcionava bem tecnicamente, mas equipes ainda escreviam testes que erravam **o que** deveria ser testado.

BDD foca em:

- **Linguagem do domínio.** Especificações falam o vocabulário do produto, não do código.
- **Comportamento observável.** Testes descrevem **o que** o sistema faz para os usuários, não como.
- **Conversa entre dev e produto.** O teste é um artefato compartilhado, escrito **antes** da implementação.

Sintaxe canônica (*Gherkin*):

```gherkin
Feature: Place order

  Scenario: Customer places an order with items in cart
    Given a customer with items in the cart
    When they confirm the order
    Then the order is marked as placed
    And the inventory is decremented
```

## Por quê

### TDD

- **Cobertura natural.** Toda linha de código nasce com teste.
- **Design pressionado.** Código difícil de testar revela problemas de design (acoplamento, dependências escondidas).
- **Confiança para refatorar.** Testes existentes permitem mudanças sem medo.
- **Documentação executável.** Testes mostram como usar a API.

### BDD

- **Alinhamento.** Produto e engenharia conversam sobre comportamento esperado **antes** de codar.
- **Testes legíveis.** Mesmo quem não programa entende os testes.
- **Reduz mal-entendido.** Especificação concreta substitui "documento de requisitos" abstrato.

Os dois respondem a problemas diferentes. TDD é **disciplina de programação**; BDD é **disciplina de especificação**. Pode-se fazer TDD sem BDD (testes técnicos em vocabulário técnico). Pode-se fazer BDD sem TDD (especificar antes, codar depois sem ciclo curto). Mas se reforçam.

## Como aplicar

### TDD: o ciclo na prática

#### Exemplo: implementar "calcular desconto"

**Iteração 1, RED**

```ts
// discount.test.ts
import { calculateDiscount } from './discount';

describe('calculateDiscount', () => {
  it('returns 0 when total is below 100', () => {
    expect(calculateDiscount(50)).toBe(0);
  });
});
```

Rode os testes → falha (a função nem existe).

**Iteração 1, GREEN**

```ts
// discount.ts
export function calculateDiscount(total: number): number {
  return 0;   // mínimo para passar
}
```

Rode → passa.

**Iteração 2, RED**

```ts
it('returns 10% off when total is above 100', () => {
  expect(calculateDiscount(150)).toBe(15);
});
```

Falha.

**Iteração 2, GREEN**

```ts
export function calculateDiscount(total: number): number {
  return total > 100 ? total * 0.1 : 0;
}
```

Passa.

**Iteração 3, RED**

```ts
it('returns 20% off when total is above 1000', () => {
  expect(calculateDiscount(1500)).toBe(300);
});
```

Falha.

**Iteração 3, GREEN**

```ts
export function calculateDiscount(total: number): number {
  if (total > 1000) return total * 0.2;
  if (total > 100)  return total * 0.1;
  return 0;
}
```

**REFACTOR.** Função pequena e legível, pouco a fazer. Em casos reais, esse passo extrai constantes, renomeia, remove duplicação.

### Granularidade: quão pequeno o passo?

A regra do TDD clássico: **um passo por vez**. Se o teste novo for muito grande para passar com pouco código, divida o teste.

- **Iniciantes:** passos pequenos. Disciplina.
- **Avançados:** podem fazer passos um pouco maiores, voltando para passo menor quando ficam confusos.

### Inside-out vs Outside-in

Dois estilos de aplicar TDD:

#### Inside-out (Detroit / classicist)

Começa por **funções pequenas**, sobe até o caso de uso. Funciona bem com [funções puras](../foundations/pure-functions.md).

#### Outside-in (London / mockist)

Começa pelo **caso de uso** (interface externa), usa mocks para colaboradores, depois implementa os colaboradores. Ver [test doubles](./test-doubles.md).

Steve Freeman & Nat Pryce defendem essa abordagem em *Growing Object-Oriented Software, Guided by Tests* (2009).

### BDD: Gherkin e além

#### Sintaxe Gherkin

```gherkin
Feature: Order placement
  As a customer
  I want to place orders
  So that I can buy products

  Scenario: Successful order placement
    Given I have items in my cart
    When I place the order
    Then I receive an order confirmation
    And the inventory is decremented

  Scenario Outline: Discount based on cart total
    Given my cart total is <total>
    When I check the discount
    Then the applied discount is <discount>

    Examples:
      | total | discount |
      | 50    | 0        |
      | 150   | 15       |
      | 1500  | 300      |
```

Ferramentas (*Cucumber*, *SpecFlow*, *Behave*) ligam cada step a código:

```ts
Given('my cart total is {int}', (total: number) => {
  context.cartTotal = total;
});

When('I check the discount', () => {
  context.discount = calculateDiscount(context.cartTotal);
});

Then('the applied discount is {int}', (expected: number) => {
  expect(context.discount).toBe(expected);
});
```

#### BDD sem Gherkin

Você pode fazer BDD **sem Cucumber**. O essencial é:

- Conversa com produto antes do code.
- Testes nomeados em vocabulário do domínio.
- Foco em comportamento observável.

```ts
describe('Order placement', () => {
  describe('when customer has items in cart', () => {
    it('confirms the order', /* ... */);
    it('decrements inventory', /* ... */);
  });

  describe('when cart is empty', () => {
    it('refuses to place the order', /* ... */);
  });
});
```

Esse é BDD "estilizado" sem precisar de Gherkin. Para muitos times, é o ponto certo.

### Anti-padrões

#### TDD ritual

Escrever testes "porque mandaram" sem entender por quê. Resulta em testes ruins, frágeis e sem valor. TDD é uma ferramenta, não uma religião.

#### Testes que duplicam a implementação

```ts
// ❌ Repete a implementação, não verifica comportamento
it('calls add with 2 and 3', () => {
  add(2, 3);
  expect(addSpy).toHaveBeenCalledWith(2, 3);  // duh
});
```

#### Cobertura como meta

Testes escritos só para subir o número não pegam bugs reais. Foque em **comportamento crítico**, não em linhas tocadas.

#### Gherkin para tudo

Cucumber/Gherkin tem overhead. Use em testes que **conectam produto e engenharia**: não para testar funções internas que ninguém de produto entende.

### TDD no mundo real

Nem todo time pratica TDD ortodoxo. Variações comuns:

- **Test-after.** Escrever teste depois do código. Menos disciplina, ainda útil.
- **Test-first em features novas, test-after em refactor.** Pragmático.
- **TDD para lógica de domínio, sem TDD para glue code.** Maioria das equipes que afirmam fazer TDD na prática.

Vladimir Khorikov (*Unit Testing*, 2020) argumenta: o objetivo não é "fazer TDD", é **ter testes que sustentam evolução**. Se TDD ajuda, ótimo. Se não, encontre outro caminho.

## Quando *não* usar

### TDD

- **Exploratório / prova de conceito.** Quando você ainda não sabe a forma da solução, escrever testes engessa cedo. Use TDD depois que a forma emerge.
- **Spike técnico.** Pequenas pesquisas de viabilidade não exigem testes desde o início.
- **UI altamente visual.** Testes de pixel são frágeis demais; teste comportamental + revisão visual humana.

### BDD

- **Quando não há interlocutor de produto.** Gherkin sem audiência além de devs vira só "testes em texto natural".
- **Componentes técnicos internos.** Cucumber para testar parsing de URLs é ruído.

## Conceitos relacionados

- [Pirâmide de testes](./test-pyramid.md): TDD produz principalmente unitários.
- [Padrão AAA](./aaa-pattern.md), estrutura do teste resultante.
- [Test doubles](./test-doubles.md), escolha entre styles inside-out e outside-in.
- [Domain-Driven Design](../architecture/domain-driven-design.md): BDD e *ubiquitous language* andam juntos.

## Referências

- **Livro.** Kent Beck, *Test Driven Development: By Example* (Addison-Wesley, 2002). Texto fundador. Curto.
- **Livro.** Steve Freeman & Nat Pryce, *Growing Object-Oriented Software, Guided by Tests* (Addison-Wesley, 2009). TDD outside-in.
- **Livro.** Vladimir Khorikov, *Unit Testing Principles, Practices, and Patterns* (Manning, 2020). Crítica e refinamento.
- **Livro.** Liz Keogh, Dan North et al., *Behavior-Driven Development with Cucumber* (Addison-Wesley, 2018).
- **Livro.** Gojko Adzic, *Specification by Example* (Manning, 2011). Por que BDD/SBE funciona.
- **Artigo.** Dan North, ["Introducing BDD"](https://dannorth.net/introducing-bdd/) (2003). Texto seminal.
- **Artigo.** Martin Fowler, ["TestDrivenDevelopment"](https://martinfowler.com/bliki/TestDrivenDevelopment.html).
- **Artigo.** DHH, ["TDD is dead. Long live testing."](https://dhh.dk/2014/tdd-is-dead-long-live-testing.html) (2014). Crítica famosa; depois fez série [*Is TDD Dead?*](https://martinfowler.com/articles/is-tdd-dead/) com Fowler e Beck.
- **Documentação.** [Cucumber](https://cucumber.io/docs).
