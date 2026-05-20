# Code Review

> **TL;DR.** Code review pega bugs, espalha conhecimento, mentora equipe e melhora design. Funciona quando autor escreve PRs pequenos e focados, e reviewer foca em correção/design (não estilo, que o linter cuida). Responda rápido. Comente código, não pessoa. Nem todo comentário precisa virar mudança.

## O quê

**Code review** é a prática de **outra pessoa olhar** seu código antes de ele entrar em produção. Geralmente acontece via **Pull Request** (ou *Merge Request*).

Fora do escopo deste doc: o **mecanismo** do PR, isso está em [pull requests](./pull-requests.md). Este documento foca em **princípios** e **comportamentos** do reviewer e autor.

Google publicou suas práticas de code review em ["Google Engineering Practices Documentation"](https://google.github.io/eng-practices/), que se tornou referência amplamente adotada. **Michaela Greiler** publicou *Code Reviewing Done Well* (2022). **Pinterest**, **Microsoft**, **Pivotal** e outras grandes também publicaram suas convenções.

## Por quê

Code review entrega múltiplos benefícios simultaneamente:

- **Qualidade.** Pega bugs, antipadrões, brechas de segurança antes de prod.
- **Conhecimento compartilhado.** Quem revisa aprende a parte; reduz *bus factor*.
- **Mentoria bidirecional.** Sênior comenta; júnior cresce. Júnior pergunta; sênior repensa.
- **Documentação viva.** Discussão no PR vira histórico permanente do **por quê**.
- **Cultura.** Times com revisão de qualidade têm mais confiança coletiva no código.

Pesquisa do **Microsoft Research** (Bacchelli & Bird, 2013) sobre o que de fato acontece em code review revelou: **descobertas de defeitos** são o motivo declarado, mas **transferência de conhecimento** é o que se entrega mais consistentemente.

## Como aplicar

### Como autor: escreva PRs revisáveis

A qualidade da revisão começa em quem **escreve** o PR.

#### Pequeno

PRs grandes recebem revisão superficial. Dados (Google):

| Linhas alteradas | Qualidade típica da revisão |
|---|---|
| < 200 | Atenta |
| 200–500 | Decente |
| > 500 | Superficial |
| > 1000 | "LGTM" reflexo |

Divida em PRs sequenciais que **se compõem** logicamente. Cada um focado em uma camada (extração, refactor, feature, testes).

#### Foco único

Um PR resolve **um problema**. Refactor + feature + bug fix juntos é três PRs disfarçados.

#### Auto-review primeiro

Antes de pedir review, **revise você mesmo**:

```bash
git diff origin/main...HEAD
```

Você pega 80% dos comentários do reviewer. Remove `console.log`, código comentado, TODOs sem motivo.

#### Descrição que ajuda

A descrição responde:

- **O quê** mudou.
- **Por quê**: qual problema resolve.
- **Como testar**: passos para validação.
- **Trade-offs**: alternativas consideradas e por que rejeitadas.

Quando difícil articular, frequentemente a mudança não está madura.

#### Comente o não-óbvio no próprio PR

Antes que o reviewer pergunte "por que isso?", deixe um comentário do tipo "I considered X but went with Y because Z".

### Como reviewer: onde focar

#### Em ordem de prioridade

1. **Correção.** O código faz o que diz?
2. **Segurança.** Brecha óbvia, injeção, autenticação esquecida?
3. **Design.** A abstração faz sentido? Vai escalar? Coesão/acoplamento?
4. **Testes.** Cobertura adequada para a complexidade?
5. **Performance.** N+1, lock excessivo, query pesada?
6. **Legibilidade.** Entendi sem precisar perguntar?
7. **Estilo.** Deixe pro linter; comente só inconsistências de naming/estrutura.

Não comente formatação se há linter configurado, é desperdício de tempo.

#### Distinga severidade

Convencione tags em comentários:

```
[must]    Bug, `null` não é tratado, vai quebrar em produção.
[should]  Considere extrair em função separada.
[nit]     Sugiro renomear `x` para algo mais descritivo.
[q]       O que acontece quando o array está vazio?
[praise]  Boa escolha de usar Result aqui, muito mais legível.
```

O autor sabe o que **precisa** mudar antes do merge, o que é **opinião**, o que é **pergunta**.

#### Pergunte, não acuse

```
❌ "Você está fazendo isso errado."
✅ "Esse trecho pode causar X em Y caso. Considerou Z?"

❌ "Não entendo por que escreveu assim."
✅ "Pode explicar a intenção desse trecho? Não consegui seguir."
```

Não saber alguma coisa é normal. Frasear como pergunta abre conversa em vez de defesa.

#### Comente o código, não a pessoa

```
❌ "Você sempre faz isso."
✅ "Esse padrão de [X] tem problema [Y], sugiro [Z]."
```

#### Aprove quando estiver pronto

"Approving in advance" para acelerar o merge transmite "não revisei direito". Se houve dúvida real, mantenha "request changes" ou "comment".

#### Não bloqueie por preferência pessoal

`[nit]` não deve travar merge. Reserve "request changes" para defeitos reais ou problemas de design significativos.

### Como autor: respondendo

#### Responda rápido

Comentário do reviewer parado é PR parado. Trate como prioridade.

#### Aceite ou explique

Para cada comentário:

- **Aceito:** implemente e responda "done".
- **Discordo:** explique educadamente. "Considerei X mas escolhi Y porque Z."
- **Não entendi:** peça esclarecimento.

Marcar `resolved` sem agir é ignorar. Não faça.

#### Mudanças incrementais

Push commits adicionais para o PR; o reviewer vê o diff desde a última revisão. Não force-push até estar pronto para a leitura final (perde histórico de mudanças).

#### Tom

O reviewer não está atacando você. O código não é você. Separe ego do código, você produz melhor assim.

> "The code is not you. A criticism of the code is not a criticism of you."
> (Comum em culturas de engenharia maduras)

### Tempo de revisão: fator crítico

Pesquisa DORA mostra: **lead time de PR** é fator-chave de produtividade. Como reviewer:

| Tempo de resposta | Cultura |
|---|---|
| < 4 horas úteis | Boa |
| 4–24 horas | Aceitável |
| > 24 horas | Problemática |

Estabeleça expectativa explícita no time. Trate PR como bloqueio do colega.

### Quando "Request Changes" vs "Comment" vs "Approve"

| Situação | Ação |
|---|---|
| Bug real, falha de segurança, design comprometido | **Request Changes** |
| Sugestões importantes, mas não bloqueantes | **Comment** com `[should]` |
| Pequenas sugestões de estilo | **Comment** com `[nit]` |
| Tudo bem | **Approve** |

Não use *Request Changes* para nits, bloqueia e desgasta.

### Code review como ferramenta de mentoria

Em times mistos, o code review é **principal canal de mentoria** assíncrona.

#### Para sênior revisando júnior

- **Explique o porquê.** Não diga "use map", diga "map é mais expressivo aqui porque...".
- **Aponte recursos.** Linke artigos, docs, capítulos de livro.
- **Não reescreva.** Pergunte "como você implementaria X?", não dê resposta pronta.

#### Para júnior revisando sênior

- **Pergunte com confiança.** Você tem perspectiva fresh que o sênior pode ter perdido.
- **Foco em legibilidade.** "Não entendi por que isso funciona" é feedback útil.
- **Não tenha medo.** Code review é diálogo, não hierarquia.

### Anti-padrões

#### "LGTM" sem leitura

PRs aprovados em segundos por alguém que claramente não leu. Pior que ausência de review, gera **falsa segurança**.

#### Bikeshedding

Discussão extensa sobre cor de botão / nome de variável trivial / formatação. Reserve energia para o que importa.

#### "Asynchronous war"

Comentário, resposta, contra-resposta, sub-comentário... durando dias. Quando ciclo passa de 2–3, **chamem call de 10 minutos**. Texto é ruim para resolver desacordo.

#### "Doer" reviewer

Reviewer que reescreve o código no PR. Não cresce ninguém, só centraliza.

#### Revisão sem contexto de produto

"Por que essa feature?" Não é sua pergunta a fazer no code review (é no design). Foque em **como** foi implementada.

#### "Strict police"

Reviewer que bloqueia tudo, nada passa. Em algum momento, time evita pedir review desse alguém. Calibre, nem todo nit precisa virar bloqueio.

### Ferramentas que ajudam

- **Linter / formatter** rodando no CI, não comente o que automatização cobre.
- **Type checker**: pega categoria inteira de bug.
- **Coverage report** anexado ao PR.
- **Storybook / preview deploys**: mostra mudança visual antes de aprovar.
- **Conventional commits + PR title**: autor declara natureza da mudança.

### Convenções de time

Documente em algum lugar central (CONTRIBUTING.md, wiki):

- Quem pode aprovar o quê (CODEOWNERS).
- Quantos approves são necessários.
- Tempo esperado de resposta.
- Convenção de tags (`[must]`, `[nit]`).
- O que vai pro linter, o que vai pro reviewer.

## Quando *não* usar

- **Hotfix crítico em produção**: quando minutos contam, faça e revise depois (post-mortem PR).
- **Trabalho exploratório / spike**: não merge prematuro; só vai pra main quando virar feature real.
- **Reformatação automática**: `prettier --write` em tudo não merece revisão linha-a-linha.

Para 99% do código que vai pra produção, code review é não-negociável.

## Conceitos relacionados

- [Pull Requests](./pull-requests.md), mecanismo do code review.
- [Git Flow / Trunk-Based](./git-flow.md), onde os PRs vivem.
- [Conventional Commits](./conventional-commits.md), comunica natureza da mudança.
- [Documentation](./documentation.md), discussões no PR viram doc viva.

## Referências

- **Documentação.** [Google Engineering Practices: Code Review](https://google.github.io/eng-practices/review/). Hub mais influente publicamente disponível.
- **Livro.** Michaela Greiler, *Code Reviewing Done Well* (2022). [michaelagreiler.com](https://www.michaelagreiler.com).
- **Livro.** Karl Wiegers, *Peer Reviews in Software* (Addison-Wesley, 2002). Clássico.
- **Paper.** Alberto Bacchelli & Christian Bird, ["Expectations: Outcomes, and Challenges of Modern Code Review"](https://www.microsoft.com/en-us/research/publication/expectations-outcomes-and-challenges-of-modern-code-review/) (ICSE, 2013, Microsoft Research). Estudo empírico.
- **Paper.** Caitlin Sadowski et al., ["Modern Code Review: A Case Study at Google"](https://research.google/pubs/pub47025/) (ICSE-SEIP, 2018).
- **Artigo.** Joel Spolsky, ["The Joel Test: 12 Steps to Better Code"](https://www.joelonsoftware.com/2000/08/09/the-joel-test-12-steps-to-better-code/) (2000). Item 9: code review.
- **Artigo.** [Pinterest: Code Review Best Practices](https://medium.com/pinterest-engineering/code-review-best-practices-c4ec19c41706).
- **Artigo.** [Atlassian: Best practices for code review](https://www.atlassian.com/agile/software-development/code-reviews).
- **Livro.** Nicole Forsgren, Jez Humble, Gene Kim, *Accelerate* (IT Revolution, 2018). DORA: lead time de review.
