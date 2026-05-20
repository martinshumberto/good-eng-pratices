# Conventional Commits

> **TL;DR.** Mensagens de commit no formato `tipo(escopo)?: descrição`: `feat`, `fix`, `chore` etc. Permite gerar changelog automático e calcular versão SemVer a partir do histórico.

## O quê

**Conventional Commits** é uma especificação leve para mensagens de commit, definida em [conventionalcommits.org](https://www.conventionalcommits.org). O formato:

```
<tipo>[(<escopo>)]: <descrição>

[<corpo opcional>]

[<rodapé(s) opcional(is)>]
```

Exemplos:

```
feat(auth): add OAuth2 login flow
fix(checkout): correct tax calculation for international orders
docs: update README with installation steps
chore(deps): bump axios from 1.5.0 to 1.6.0

feat(api)!: drop support for v1 endpoints

BREAKING CHANGE: v1 endpoints removed. See migration guide.
```

## Por quê

Mensagens padronizadas viabilizam:

- **Changelog automático**: ferramentas como [Changesets](https://github.com/changesets/changesets) e [semantic-release](https://semantic-release.gitbook.io) agregam os commits e geram um CHANGELOG legível.
- **Versionamento automático**: `feat` → MINOR, `fix` → PATCH, `BREAKING CHANGE` → MAJOR.
- **Histórico legível**: `git log` filtrado por tipo entrega exatamente o que importa naquele momento.
- **Comunicação consistente**: quem revisa o PR sabe o impacto pelo título.

> "Conventional Commits is a specification for adding human and machine readable meaning to commit messages."
> (conventionalcommits.org)

## Como aplicar

### Tipos canônicos

| Tipo | Uso |
|---|---|
| `feat` | Nova funcionalidade. |
| `fix` | Correção de bug. |
| `chore` | Tarefas que não alteram código de produção (deps, config, ferramentas). |
| `refactor` | Mudança que não altera comportamento externo. |
| `docs` | Apenas documentação. |
| `perf` | Melhoria de performance. |
| `style` | Formatação, whitespace, sem mudar significado do código. |
| `test` | Adicionar ou corrigir testes. |
| `build` | Sistema de build ou dependências externas (`npm`, `gulp`, etc.). |
| `ci` | Configurações de CI (GitHub Actions, CircleCI, etc.). |

Tipos podem ser estendidos pelo time (`env`, `i18n`, `seed`), mas mantenha consistência.

### Escopo (opcional)

Indica a parte do projeto afetada:

```
feat(auth): ...
fix(checkout): ...
docs(api): ...
```

Use o nome do módulo, lib, ou feature. Em monorepos, o escopo costuma ser o nome do pacote.

### Descrição

- **Modo imperativo**: "Add button", não "Adding button" nem "Added button".
- **Sem ponto final.**
- **Conciso, até ~50 caracteres** no título. Detalhes vão no corpo.
- **Lowercase** após o tipo (estilo do conventional commits original).

### Corpo (opcional)

Detalhes sobre **o quê** e **por quê**. Reserve "como" para os comentários no código.

- Linhas em até **72 caracteres** para legibilidade em terminais.
- Pule uma linha entre o título e o corpo.

```
fix(checkout): correct rounding on tax calculation

The previous implementation truncated values before applying tax,
causing 0.01 differences on totals above 100. Fixed by rounding only
on the final amount.

Refs: TASK-1234
```

### Breaking changes

Duas formas equivalentes:

#### Com `!` no tipo

```
feat(api)!: remove deprecated v1 endpoints
```

#### Com trailer `BREAKING CHANGE`

```
feat(api): remove deprecated v1 endpoints

BREAKING CHANGE: All v1 endpoints (/api/v1/*) have been removed.
Clients must migrate to v2 endpoints. See docs/migrations/v1-to-v2.md.
```

As duas podem ser combinadas. A presença do `!` ou do trailer força bump MAJOR nas ferramentas automáticas.

### Mensagens ruins: o que evitar

```
❌ "fixed stuff"          , não diz o quê
❌ "asd"                  , não diz nada
❌ "Bug fix"              , vago
❌ "WIP"                  , não commite WIP em main; use draft PR ou stash
❌ "Updates"              , múltiplas mudanças mal descritas
❌ "Fixing attempt"       , experimente em branch separada, não no histórico
```

```
✅ "fix(login): allow empty password reset code retry after 30s"
✅ "feat(profile): add avatar upload with image cropper"
✅ "perf(query): reduce N+1 in order listing"
```

### Mensagem na criação de um Pull Request

Ao abrir um PR, o título também deve seguir Conventional Commits. Frequentemente o **squash merge** consolida tudo em um único commit usando o título do PR, então ele precisa estar formatado.

Convenção comum em times: prefixar com a task ID do tracker:

```
TASK-001 - feat(auth): add OAuth2 login flow
```

## Quando *não* usar

- **Repositórios pessoais ou protótipos.** A cerimônia não se paga.
- **Quando o time não tem disciplina coletiva.** Convenção parcialmente aplicada confunde mais do que ajuda. Adote 100% ou nada.
- **Times pequenos sem changelog público.** Se você não precisa gerar release notes automáticas, pode bastar boas mensagens descritivas (modo imperativo, claras).

## Conceitos relacionados

- [Git Flow](./git-flow.md) e Trunk-Based Development.
- [Pull Requests](./pull-requests.md)
- [Versionamento de API](../backend/api-versioning.md), onde Conventional Commits alimenta automação.

## Referências

- **Spec.** [Conventional Commits 1.0.0](https://www.conventionalcommits.org). Especificação completa.
- **Spec.** [Semantic Versioning 2.0.0](https://semver.org). Combina naturalmente com Conventional Commits.
- **Spec.** [Keep a Changelog](https://keepachangelog.com). Formato de CHANGELOG.
- **Documentação.** [semantic-release](https://semantic-release.gitbook.io). Automação completa baseada em Conventional Commits.
- **Documentação.** [Changesets](https://github.com/changesets/changesets). Alternativa popular em monorepos.
- **Documentação.** [commitlint](https://commitlint.js.org). Linter para mensagens, bloqueia commits fora do padrão.
