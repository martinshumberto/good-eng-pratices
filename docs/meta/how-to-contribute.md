# Como contribuir

Este repositório é uma coleção de **documentos de referência** sobre fundamentos e convenções de engenharia de software. O objetivo não é ensinar do zero, mas servir de consulta, denso, conciso, com fontes.

---

## Antes de escrever

1. **Confira se já existe.** Procure no índice (`docs/README.md`) e no glossário (`meta/glossary.md`).
2. **Decida o lugar certo.** Cada tópico vive em **uma** das pastas numeradas. Se não souber qual, abra uma issue para discussão.
3. **Leia o template.** Todo documento segue `meta/document-template.md`.

---

## Padrão de redação

### Idioma e tom

- **Português** no corpo. Termos consagrados em inglês podem ficar em inglês (*deadlock*, *throughput*, *idempotência*).
- **Tom técnico e direto.** Sem "aprenderemos a seguir" ou "vamos ver". Vá ao ponto.
- **Sem marketing.** Não venda o conceito, explique-o.

### Exemplos de código

- **Padrão: TypeScript.** Mantém a base consistente e cobre tanto backend quanto frontend.
- Use TypeScript mesmo para conceitos de backend (Node ou pseudo-runtime). Quando o conceito for específico de outra linguagem (ex.: GIL em Python, channels em Go), use a linguagem que faz sentido e explique no texto.
- Exemplos devem ser **curtos** (idealmente < 20 linhas) e **auto-contidos**. O leitor não deve precisar abrir outro arquivo para entender.

### Tamanho

- Cada documento foca em **um conceito**. Se ele estiver crescendo para mais de ~400 linhas, separe.
- TL;DR no topo é obrigatório. Bibliografia no fim é obrigatória.

### Citações e referências

- Toda afirmação forte tem fonte. "Microsserviços escalam melhor" sem fonte é opinião disfarçada.
- Quando citar Fowler/Beck/Evans/Martin etc., aponte o livro e capítulo, não só o autor.
- Links externos devem ser estáveis, prefira sites de autores conceituados (martinfowler.com, refactoring.guru, microservices.io) a posts de blog passageiros.

### Diagramas

- Prefira [Mermaid](https://mermaid.js.org), renderiza nativamente no GitHub.
- PNG/SVG são aceitos quando Mermaid não dá conta; coloque em `_assets/` ao lado do `.md`.

---

## Processo

1. **Branch:** `docs/<tópico-curto>` (ex.: `docs/clean-architecture`).
2. **Commit:** Conventional Commits (`docs: add clean architecture`).
3. **PR:** descrição com:
   - O que o documento cobre.
   - Quais referências bibliográficas foram consultadas.
   - Por que o tópico merece um doc próprio (em vez de uma seção em doc existente).
4. **Revisão:** ao menos uma aprovação. Foco da revisão: precisão técnica, fontes e aderência ao template.

---

## Bibliografia obrigatória do projeto

Antes de criar um doc novo, considere consultar pelo menos uma das obras-âncora em [`references/books.md`](../references/books.md). Se o seu documento não pode citar nenhum livro nem autor da [`references/people.md`](../references/people.md), é provável que o tema seja específico demais para este repositório.
