# Título do documento

> **TL;DR.** Uma ou duas frases que entregam a ideia central. Quem ler só isso já sai com algo útil.

## O quê

Definição precisa, sem rodeios. Se houver um termo técnico, explique-o em uma frase ou linke para o [glossário](../meta/glossary.md).

## Por quê

A motivação. Que problema isso resolve. Que sintoma aparece quando o conceito é ignorado. *Esta seção é a mais importante*, sem o "por quê", o leitor não sabe quando aplicar.

## Como aplicar

Diretrizes acionáveis em bullets. Exemplos curtos quando ajudarem a fixar.

```ts
// TypeScript é o idioma de exemplos padrão deste repositório.
// Use exemplos pequenos e auto-contidos.
function example() {
  return 'foco no conceito, não no domínio';
}
```

## Quando *não* usar

Limites, anti-padrões e custos. Todo padrão tem trade-offs, explicitá-los evita o uso religioso.

## Conceitos relacionados

- [Link interno para outro doc do repositório](../foundations/solid.md)
- [Outro conceito relacionado](../architecture/clean-architecture.md)

## Referências

- **Livro.** Autor, *Título* (Editora, ano), capítulo/seção específica quando relevante.
- **Artigo.** Autor, "Título do artigo", site/blog ([link](https://exemplo.com)).
- **Recurso.** Nome do recurso ([link](https://exemplo.com)), uma frase sobre por que vale a leitura.

---

## Convenções de redação

- **Idioma:** português. Termos técnicos consagrados ficam em inglês quando a tradução for forçada (ex.: *deadlock*, *throughput*).
- **Tom:** direto, técnico, sem floreio. Trate o leitor como engenheiro.
- **Tamanho:** prefira documentos curtos e focados. Se um arquivo passa de 400 linhas, considere dividir.
- **Citações:** toda afirmação forte ("isto é melhor que aquilo") deve ter fonte na seção de referências. Opiniões devem ser marcadas como tal.
- **Diagramas:** Mermaid quando possível (renderiza no GitHub). PNG/SVG ficam em `_assets/` ao lado do doc.
