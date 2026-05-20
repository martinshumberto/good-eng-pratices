# Pull Requests

> **TL;DR.** PRs pequenos, focados, com descrição clara, testes inclusos e título no formato Conventional Commits. Responda rapidamente a feedback. Reviewer e autor têm responsabilidades distintas, ambos importam.

## O quê

**Pull Request** (ou *Merge Request* no GitLab) é o mecanismo central de revisão e integração de código em times modernos. Reúne em um lugar:

- A mudança proposta (diff).
- A discussão (comentários inline, revisões).
- A automação (CI, linters, deploys preview).
- A história (quem aprovou, quando, por quê).

Bons PRs são o multiplicador silencioso da produtividade do time, ruins, o gargalo invisível.

## Por quê

- **Qualidade.** Segunda mente olha o código antes da produção. Pega bugs, antipadrões, brechas.
- **Conhecimento compartilhado.** A pessoa que revisa aprende a parte do código. Reduz *bus factor*.
- **Mentoria.** Sênior comenta, júnior cresce. Júnior comenta, sênior repensa.
- **Documentação.** A descrição do PR vira histórico permanente do **por quê** uma mudança aconteceu, `git blame` aponta pro PR, PR explica o contexto.

## Como aplicar

### Antes de abrir

1. **Atualize sua branch contra a base:**

   ```bash
   git fetch origin
   git rebase origin/main   # ou merge se preferir manter merges
   ```

2. **Rode os testes localmente.** CI não é desculpa para ignorar feedback rápido.

3. **Revise seu próprio diff.** Olhe linha a linha como se fosse outra pessoa. Vai pegar 80% dos comentários que viriam do reviewer.

   ```bash
   git diff origin/main...HEAD
   ```

4. **Remova lixo.** `console.log`, código comentado, TODOs sem motivo.

### Criando o PR

#### Título: Conventional Commits + task ID

```
TASK-001 - feat(auth): add OAuth2 login flow
```

- Tipo no formato [Conventional Commits](./conventional-commits.md).
- Task ID quando o tracker for parte do fluxo.
- Conciso, detalhes na descrição.

#### Descrição: modelo

```markdown
### Task
[Link para a tarefa no tracker]

### O que muda
Resumo curto: o que esse PR faz e por quê.

### Como testar
Passos para validar manualmente, se aplicável.

### Evidências
Screenshots, gravações, ou exemplos de output.

### Notas
Decisões de design, alternativas consideradas, riscos conhecidos.

---
Antes de abrir o PR:
- [ ] Testes escritos e passando? (No tests, no approval.)
- [ ] Mudanças verificadas em ambiente local?
- [ ] PR está pronto para revisão? (Use *Draft* se ainda não estiver.)
```

### Boas práticas: como autor

#### PRs pequenos

PRs grandes recebem revisão superficial. Quem revisa 1000 linhas tende a aprovar para se livrar da tarefa.

Heurística (do Google):

| Linhas alteradas | Qualidade típica de revisão |
|---|---|
| < 200 | Atenta |
| 200–500 | Decente |
| > 500 | Superficial |
| > 1000 | "Looks good to me" |

Quando a mudança é grande, **divida em PRs sequenciais**. Cada um foca em uma camada (extração de função, refatoração, nova feature, testes).

#### Foco único

Um PR resolve **um problema**. Refatoração + feature + bug fix no mesmo PR é três PRs disfarçados.

#### Comente o não-óbvio

Se você fez uma escolha que parece estranha à primeira vista, comente, no código (se for permanente) ou no PR (se for contexto). Antecipa as perguntas do reviewer.

#### Responda rápido

Comentário do reviewer parado é PR parado. Trate como prioridade, bloqueia o trabalho do reviewer também, que precisa retornar mais tarde com contexto perdido.

#### Marque "resolved" só quando endereçar de verdade

Marcar `resolved` sem mudar nada nem responder é uma forma silenciosa de ignorar feedback. Ou implemente, ou responda explicando por que não.

### Boas práticas: como reviewer

#### Responda rápido também

A pesquisa DORA mostra: tempo de revisão de PR é fator-chave de *lead time*. Estabeleça expectativa no time (ex.: "PRs revisados em até 4h úteis").

#### Distinga "must fix" de "nit"

```
[must]   Esse código tem um bug, `null` não é tratado.
[should] Considere extrair em função separada.
[nit]    Sugiro renomear `x` para algo mais descritivo.
[q]      O que acontece quando o array está vazio?
[praise] Boa escolha de usar Result aqui, muito mais legível.
```

Convenção explícita poupa briga: o autor sabe o que **precisa** mudar antes do merge, o que é **opinião**, o que é **pergunta**.

#### Comente o código, não a pessoa

```
❌ "Você está fazendo isso errado."
✅ "Esse código pode causar X em Y caso, considere Z."

❌ "Não entendo por que você escreveu assim."
✅ "Esse trecho está difícil de seguir. Pode esclarecer a intenção?"
```

#### Aprove quando estiver de fato pronto

"Approving in advance" para acelerar o merge transmite "não revisei direito". Se houve dúvida, mantenha "request changes" ou "comment" até estar resolvida.

#### Foque no que importa

Em ordem de prioridade:

1. **Correção**: o código faz o que diz que faz?
2. **Segurança**: alguma porta aberta?
3. **Design**: a abstração faz sentido? Vai escalar?
4. **Testes**: cobertura adequada?
5. **Performance**: N+1, locks, queries pesadas?
6. **Legibilidade**: entendi sem precisar perguntar?
7. **Estilo**: formatação, naming. Deixe pro linter quando possível.

### Depois de criar

- **Acompanhe.** Notificações ligadas. PR esquecido é dívida acumulando.
- **Faça as correções incrementais.** Push commits adicionais; o reviewer vê o que mudou desde a última revisão.
- **Squash ou rebase no merge?** Convenção do time. *Squash* mantém `main` limpo; *rebase* preserva commits individuais. Documente a escolha e siga.

### Quando "Request Changes" vs "Comment"

| Situação | Ação |
|---|---|
| Bug, falha de segurança, design comprometido | **Request Changes** |
| Sugestões importantes, mas não bloqueantes | **Comment** com `[should]` |
| Pequenas sugestões de estilo | **Comment** com `[nit]` |
| Tudo bem, pronto pra merge | **Approve** |

Não use *Request Changes* para nits, bloqueia o autor e desgasta a relação.

## Quando *não* usar

- **Trabalho solo em projetos pessoais.** Cerimônia sem multiplicador.
- **Hotfix crítico em produção.** Em situações extremas, faça merge direto e abra PR "post-mortem" depois para registrar. Use com parcimônia.
- **Refatorações puramente mecânicas** (rename via IDE, code mod). Algumas equipes aceitam push direto ou *Auto-merge* após CI verde.

## Conceitos relacionados

- [Git Flow](./git-flow.md) e Trunk-Based Development.
- [Conventional Commits](./conventional-commits.md)
- [Code review](./code-review.md), princípios mais profundos sobre como revisar.

## Referências

- **Site.** [Google Engineering Practices: Code Review](https://google.github.io/eng-practices/review/). Guia de revisão mais influente publicamente disponível.
- **Livro.** Michaela Greiler, *Code Reviewing Done Well* (2022). Disponível em [michaelagreiler.com](https://www.michaelagreiler.com).
- **Livro.** Karl Wiegers, *Peer Reviews in Software* (Addison-Wesley, 2002). Texto clássico.
- **Artigo.** Caitlin Sadowski et al. (Google), ["Modern Code Review: A Case Study at Google"](https://research.google/pubs/pub47025/) (2018). Pesquisa empírica.
- **Artigo.** Pinterest, ["Pinterest Code Review Standards"](https://medium.com/pinterest-engineering/code-review-best-practices-c4ec19c41706).
- **Livro.** Nicole Forsgren, Jez Humble, Gene Kim, *Accelerate* (IT Revolution, 2018). Pesquisa DORA, incluindo lead time de PR.
