# Versionamento de API

> **TL;DR.** APIs evoluem, clientes não acompanham na mesma velocidade. Versione com SemVer, sinalize *breaking changes* explicitamente e mantenha versões antigas o tempo necessário para a migração ser confortável.

## O quê

Versionamento de API é o conjunto de práticas para **evoluir contratos** sem quebrar clientes existentes. Cobre duas frentes:

1. **Versionamento do código/pacote** que implementa a API (importante quando o "framework" é consumido como dependência por outros serviços).
2. **Versionamento da interface exposta** ao cliente HTTP/gRPC.

Este documento foca em **(1)**: como versionar libraries e frameworks compartilhados. Para versionamento de endpoints HTTP, ver [API design: REST](./api-design-rest.md).

## Por quê

Em arquiteturas com framework compartilhado entre microsserviços, toda alteração afeta todos os consumidores. Versionamento descuidado leva a duas patologias:

- **Lock-step deploys**: um pequeno fix força todo mundo a atualizar e fazer deploy junto.
- **Quebras silenciosas**: alguém faz uma mudança "pequena", N serviços quebram em produção sem aviso.

Versionar bem dá:

- **Adoção incremental**: cada consumidor migra no ritmo dele.
- **Sinal claro de impacto**: *breaking changes* explícitas geram revisão extra.
- **Rastreabilidade**: bug em produção liga direto à versão em uso.

## Como aplicar

### SemVer: Semantic Versioning

Use `MAJOR.MINOR.PATCH`:

| Bump | Quando | Impacto no cliente |
|---|---|---|
| `PATCH` (`1.0.0 → 1.0.1`) | Bug fix retrocompatível | Atualizar é seguro |
| `MINOR` (`1.0.0 → 1.1.0`) | Nova funcionalidade retrocompatível | Atualizar é seguro |
| `MAJOR` (`1.0.0 → 2.0.0`) | Mudança que quebra contrato | Migração necessária |

Especificação completa: [semver.org](https://semver.org).

### Sinalize breaking changes explicitamente

Adote um marcador no título do PR que introduz quebra de contrato:

```
[BREAKING CHANGE][TASK-XXX] Remove method DeprecatedFoo()
```

Benefícios:

- PRs subsequentes ficam aguardando o merge dessa breaking change (a ordem importa).
- Reviewers entram em alerta, *breaking* exige análise diferente.
- A entry no CHANGELOG aparece com destaque visual.

Combine com [Conventional Commits](../collaboration/conventional-commits.md):

```
feat(auth)!: remove deprecated login() method

BREAKING CHANGE: The legacy login() method has been removed.
Use loginWithCredentials() instead. See migration guide.
```

O `!` após o tipo, e o trailer `BREAKING CHANGE:` no corpo, são lidos por ferramentas de release automation (semantic-release, Changesets) para forçar MAJOR bump.

### Pré-releases (a partir de uma branch)

Antes de mergear, dispare uma versão de pré-release para que outro serviço já possa **testar contra ela** sem que ela polua o registry de releases definitivas.

Convenção:

```
<última-release>-<nome-da-branch>-<n>
```

Exemplo:

```
Branch:           fix/task-388-profile-bug
Última release:   v1.3.3
Pré-release:      v1.3.4-fix-task-388-profile-bug-1
                  v1.3.4-fix-task-388-profile-bug-2  (incremento automático)
```

Cria apenas a *tag*, sem criar uma *release* no GitHub. Use um comando do Makefile para automatizar:

```bash
make post-version
```

### Releases definitivas

Geradas exclusivamente a partir de `main`/`master`, no formato `v1.3.3`:

- Crie a release pela interface do GitHub (ou via CLI: `gh release create v1.3.3`).
- O título da release é igual à tag.
- A descrição lista o **changelog objetivo** do que está na versão.

Estrutura recomendada para a descrição:

```markdown
## Added
- ...

## Changed
- ...

## Deprecated
- ...

## Removed
- ...

## Fixed
- ...

## Security
- ...
```

Padrão: [Keep a Changelog](https://keepachangelog.com).

### Automação: Changesets / Semantic Release

Em monorepos, escrever changelog à mão é gargalo. Ferramentas resolvem:

- **[Changesets](https://github.com/changesets/changesets)**: cada PR adiciona um arquivo `.changeset` descrevendo o impacto; na publicação, agrega tudo, calcula bump e gera CHANGELOG.
- **[semantic-release](https://semantic-release.gitbook.io)**: extrai o bump das mensagens de commit (depende de Conventional Commits).

Fluxo com Changesets:

```bash
# 1. Após mudança, registre o impacto
pnpx changeset
# (selecione lib afetada e tipo: patch | minor | major)

# 2. Antes de publicar, valide
nx affected --target=test  --all
nx affected --target=build --all

# 3. Calcule nova versão
pnpx changeset version

# 4. Publique
pnpx changeset publish
```

### Política de depreciação

Antes de remover algo em uma MAJOR:

1. **MINOR** com warning (`@deprecated` no JSDoc, log em runtime).
2. Manter por pelo menos uma versão MAJOR completa.
3. Documentar o substituto e a data alvo de remoção.
4. **MAJOR**: remoção definitiva, com migração documentada.

## Quando *não* usar

- **Aplicações monolíticas internas sem dependentes externos.** Versão de pacote tem pouco valor. Use `git tag` para release de deploy e basta.
- **APIs experimentais (`v0.x`).** SemVer trata `0.x.y` como "qualquer coisa pode mudar". Use enquanto estabiliza, e marque `v1.0.0` quando o contrato for público.
- **Mudanças puramente internas.** Refatorações que não afetam contrato público não exigem bump. Documente como "internal" no changelog.

## Conceitos relacionados

- [Conventional Commits](../collaboration/conventional-commits.md), convenção de mensagens que alimenta automação.
- [Pull Requests](../collaboration/pull-requests.md), onde a breaking change é sinalizada.
- [Estratégias de release](../delivery/release-strategies.md)

## Referências

- **Spec.** [Semantic Versioning 2.0.0](https://semver.org).
- **Spec.** [Keep a Changelog 1.1.0](https://keepachangelog.com).
- **Spec.** [Conventional Commits 1.0.0](https://www.conventionalcommits.org).
- **Documentação.** [Changesets](https://github.com/changesets/changesets/blob/main/docs/intro-to-using-changesets.md). Tutorial oficial.
- **Artigo.** Tom Preston-Werner, ["Semantic Versioning"](https://tom.preston-werner.com/2008/04/18/versioning.html). Texto original.
