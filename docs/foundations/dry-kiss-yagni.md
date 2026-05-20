# DRY, KISS, YAGNI

> **TL;DR.** Três princípios curtos e clássicos: não repita conhecimento (DRY), prefira o simples (KISS), e não implemente o que ninguém pediu (YAGNI).

## O quê

Três acrônimos onipresentes na engenharia de software:

- **DRY (*Don't Repeat Yourself***) toda peça de conhecimento deve ter uma representação única, não-ambígua e autoritativa dentro do sistema.
- **KIS (*Keep It Simple***) entre soluções equivalentes, escolha a mais simples. (Originalmente *KISS, Keep It Simple, Stupid*, na engenharia da Lockheed nos anos 60.)
- **YAGNI (*You Aren't Gonna Need It***) não adicione funcionalidade até que ela seja realmente necessária.

## Por quê

Os três combatem o mesmo inimigo: **complexidade acidental**. A complexidade que não vem do problema, vem das nossas escolhas, duplicação que sai do sincronismo, abstrações montadas para necessidades imaginárias, código "flexível" que ninguém pediu.

> "Build the simplest thing that could possibly work."
> (Kent Beck, *Extreme Programming Explained*)

## Como aplicar

### DRY

DRY é sobre **conhecimento**, não sobre **caracteres**. Trechos idênticos que representam decisões independentes não violam DRY, vão divergir naturalmente no futuro.

```ts
// ❌ Falsa duplicação: dois cálculos que parecem iguais mas têm motivações diferentes
function calculateInvoiceTax(amount: number)  { return amount * 0.1; }
function calculateInsurancePremium(amount: number) { return amount * 0.1; }
// Se a taxa muda só para invoices, "extrair" um helper criaria acoplamento espúrio.
```

Aplique DRY quando o conhecimento for o mesmo:

```ts
// ✅ Conhecimento único: regra de cálculo do imposto sobre vendas
const SALES_TAX_RATE = 0.1;
function calculateTax(amount: number) { return amount * SALES_TAX_RATE; }
```

> **Cuidado:** DRY ao extremo gera abstrações que existem para servir 2 chamadores e tornam a leitura mais difícil. Veja [code smells](./code-smells.md).

### KISS

- A primeira escolha deve ser sempre a mais simples que resolve o problema atual.
- Abordagens complexas precisam justificar seu custo.
- Complexidade tem efeito composto: cada camada extra de indireção que parece "pequena" cobra juros ao longo dos anos.

> "Simplicity is prerequisite for reliability."
> (Edsger Dijkstra)

### YAGNI

- Não construa o "framework de plugins" antes do segundo plugin existir.
- Não adicione um parâmetro opcional "para o futuro".
- Não generalize antes de ter três casos concretos.

Quando uma necessidade real surgir, você terá **mais informação** sobre a forma certa do abstrato. Decisões prematuras tendem a errar.

## Quando *não* usar

- **DRY:** quando dois trechos são iguais por coincidência (têm motivações diferentes). Forçar reuso acopla mudanças que deveriam ser independentes.
- **KISS:** quando "simples agora" significa custo enorme depois. Simplicidade aparente que ignora restrições reais (concorrência, escala, segurança) é dívida disfarçada.
- **YAGNI:** quando a mudança custa 10× se feita depois (ex.: tipo de identificador, formato de evento persistido, contrato de API público). O custo da mudança importa.

## Conceitos relacionados

- [Code smells](./code-smells.md), *Speculative Generality* é o YAGNI violado; *Duplicated Code* é o DRY violado.
- [Coesão e acoplamento](./cohesion-coupling.md)
- [SOLID](./solid.md)

## Referências

- **Livro.** Andy Hunt & Dave Thomas, *The Pragmatic Programmer*, 20th Anniversary Edition (Addison-Wesley, 2019). DRY é apresentado no Tópico 9.
- **Livro.** Kent Beck, *Extreme Programming Explained: Embrace Change*, 2ª ed. (Addison-Wesley, 2004). Origem do YAGNI como prática XP.
- **Artigo.** Martin Fowler, ["Yagni"](https://martinfowler.com/bliki/Yagni.html), martinfowler.com (2015).
- **Artigo.** Martin Fowler, ["BeckDesignRules"](https://martinfowler.com/bliki/BeckDesignRules.html). As 4 regras de design simples de Kent Beck.
