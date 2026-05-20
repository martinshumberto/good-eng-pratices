# Git Flow

> **TL;DR.** Modelo de branches com `main`/`homolog` protegidas, `feature/*` ramificadas de `homolog`, `hotfix/*` ramificadas de `main`, e `release/*` para congelar versões. Hoje em dia, **Trunk-Based Development** é a alternativa mais usada em times com CI maduro.

## O quê

**Git Flow** é um modelo de branching publicado por **Vincent Driessen** em 2010. Define cinco tipos de branches com regras claras de origem, destino e propósito:

- `main` (ou `master`), versão em produção.
- `homolog` (ou `develop`), integração contínua de features.
- `feature/*`: desenvolvimento de novas funcionalidades.
- `release/*`: congelamento de versão para homologação.
- `hotfix/*`: correções urgentes em produção.

> "A successful Git branching model."
> (Vincent Driessen, [post original](https://nvie.com/posts/a-successful-git-branching-model/) (2010))

**Importante:** o próprio Driessen [reconheceu em 2020](https://nvie.com/posts/a-successful-git-branching-model/#note-of-reflection-march-5-2020) que Git Flow foi pensado para software com releases versionadas (apps mobile, libraries), e que **para aplicações web entregues continuamente, Trunk-Based Development tende a ser melhor**.

## Por quê

Git Flow brilha quando:

- Existem **múltiplas versões em produção simultaneamente** (apps mobile sem auto-update, bibliotecas, software embarcado).
- Releases são **eventos discretos** com QA pesado.
- O time tem o costume de proteger `main`/`homolog` como ambientes (cada branch ≈ um ambiente).

Para web SaaS com deploy contínuo, Git Flow adiciona cerimônia desnecessária. Ainda assim, é o modelo dominante em muitos times, vale conhecê-lo.

## Como aplicar

### 1) Branches de desenvolvimento

#### `feature/**`

- **Objetivo:** desenvolver novas funcionalidades.
- **Origem:** ramificada a partir de `homolog`.
- **Destino:** mergeada de volta para `homolog` quando concluída.
- **Convenção de nome:** `feature/TASK-001-short-description`.

```bash
git checkout homolog
git pull
git checkout -b feature/TASK-001-login-system
# ... desenvolve, commita ...
git push -u origin feature/TASK-001-login-system
# abre PR para homolog
```

#### `hotfix/**`

- **Objetivo:** correções urgentes em produção.
- **Origem:** ramificada de `main`.
- **Destino:** mergeada para `main` **e** para `homolog` (para não regressar na próxima release).
- **Convenção:** `hotfix/TASK-XXX-short-description`.

### 2) Branches de release

#### `release/**`

- **Objetivo:** preparar uma nova versão para produção.
- **Origem:** ramificada de `homolog` quando ela está estável.
- **Destino:** mergeada para `homolog` (com pequenos ajustes de QA) e depois para `main`.

A função: **congelar** a versão para QA enquanto `homolog` continua recebendo features para a próxima release.

### 3) Branches de ambiente

#### `main`

- **Objetivo:** reflete a versão em produção.
- **Regras:**
  - Sem commits diretos.
  - Sem merge sem Pull Request aprovado.
  - Cada merge dispara tag de versão (`v1.2.3`) e deploy.

#### `homolog`

- **Objetivo:** reflete a versão em homologação.
- **Regras:** mesmas de `main`.

### Notas adicionais

- **Tags de versão**: crie tag SemVer no merge para `main`.
- **Release freeze**: quando `homolog` estiver estável com as features desejadas, ramifique `release/x.y.z` e siga só com bugs ali; `homolog` segue recebendo features da próxima release.

### Boas práticas (universais, independem do modelo)

1. **Nomes descritivos.** Inicie com o tipo, depois código da tarefa, depois resumo. `feature/TASK-001-login-system`.
2. **Commits atômicos.** Cada commit representa uma mudança lógica e completa, facilitando leitura do histórico e rollback.
3. **Sincronize regularmente.** `git pull` (ou `rebase`) frequente evita conflitos enormes.
4. **Code review obrigatório.** Sem exceções, incluindo hotfix (com revisão expressa quando crítico).
5. **Testes antes do merge.** CI verde é pré-requisito.
6. **Sem merge direto em branches protegidas.** Apenas via PR.
7. **Delete branches mergeadas.** Higiene do remoto.

---

## Alternativa: Trunk-Based Development (TBD)

Para times com CI/CD maduro, **TBD** é a recomendação atual de figuras como **Dave Farley**, **Jez Humble** e do estudo [DORA](https://dora.dev).

### Resumo

- **Uma única branch principal** (`main` ou `trunk`).
- **Branches muito curtas** (horas a 1–2 dias), nomeadas livremente.
- **Merges frequentes** para `main` (pequenos, contínuos).
- **Feature toggles** desacoplam *deploy* de *release*, código pode ir para produção desativado.

```bash
git checkout main
git pull
git checkout -b add-product-search
# ... commit, commit ...
git push
# abre PR pequeno, revisa, merge para main no mesmo dia
```

### Por que TBD funciona com CI/CD

- Branches curtas reduzem conflitos drasticamente.
- Feature flags permitem entregar código incompleto sem ativar.
- Releases viram um *configurar uma flag*, não um *git merge ceremônia*.

### Quando TBD não serve

- Múltiplas versões em produção simultâneas (apps mobile, libraries).
- Time sem cobertura de testes adequada (não dá pra confiar no `main` sempre verde).
- Compliance que exige separação física de "develop" e "release".

---

## Quando *não* usar Git Flow

- **Web SaaS com deploy contínuo.** Cerimônia demais. Prefira [Trunk-Based Development](https://trunkbaseddevelopment.com).
- **Time pequeno (1–3 pessoas).** Branches longas viram fricção sem benefício. Trabalhe em `main` com cuidado.
- **Sem necessidade de QA manual sincronizado.** Se o release é automático após CI, `release/*` não tem propósito.

## Conceitos relacionados

- [Conventional Commits](./conventional-commits.md)
- [Pull Requests](./pull-requests.md)
- [Versionamento de API](../backend/api-versioning.md), onde as tags entram.

## Referências

- **Artigo.** Vincent Driessen, ["A successful Git branching model"](https://nvie.com/posts/a-successful-git-branching-model/) (2010). Texto original do Git Flow + nota de reflexão de 2020.
- **Site.** [trunkbaseddevelopment.com](https://trunkbaseddevelopment.com). Paul Hammant detalha TBD.
- **Livro.** Jez Humble & David Farley, *Continuous Delivery* (Addison-Wesley, 2010). Capítulo sobre VCS strategy.
- **Livro.** Nicole Forsgren, Jez Humble, Gene Kim, *Accelerate* (IT Revolution, 2018). Pesquisa DORA mostra correlação entre TBD e alta performance.
- **Artigo.** Martin Fowler, ["Patterns for Managing Source Code Branches"](https://martinfowler.com/articles/branching-patterns.html). Panorama completo dos padrões.
- **Artigo.** Atlassian, ["Gitflow Workflow"](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow). Boa referência visual.
