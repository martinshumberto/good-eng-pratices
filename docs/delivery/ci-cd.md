# CI/CD

> **TL;DR.** **CI** automatiza testar cada commit. **CD** automatiza o caminho até produção. As métricas DORA mostram que deploys frequentes e pequenos correlacionam com sistemas **mais estáveis**, não menos. Construa pipeline que vá do `git push` ao deploy sem mãos.

## O quê

| Sigla | Significa |
|---|---|
| **CI**: Continuous Integration | Cada commit é integrado à branch principal frequentemente; build + testes automatizados a cada push. |
| **CD**: Continuous Delivery | Cada commit que passa nos testes está **pronto para produção**: deploy é um clique humano. |
| **CD**: Continuous Deployment | Cada commit que passa nos testes vai **automaticamente** para produção. |

CI e CD foram codificadas por **Jez Humble & David Farley** em *Continuous Delivery* (Addison-Wesley, 2010). Pesquisa subsequente (DORA, *Accelerate*, 2018) confirmou empiricamente: times que fazem CD bem entregam **mais rápido** *e* **com menos defeitos**.

## Por quê

Mítica clássica: "fazer deploy frequente é arriscado". Pesquisa DORA mostra o oposto.

> "We can now say with confidence that high-performing organizations are decisively outperforming their lower-performing peers in terms of throughput, stability, and quality."
> (Forsgren, Humble, Kim, *Accelerate* (IT Revolution, 2018))

Times com deploy contínuo:

- **Recuperam-se mais rápido** de incidentes (MTTR baixo).
- **Quebram menos** ao deploar (change failure rate baixo).
- **Aprendem mais rápido** (lead time baixo).
- **Estão menos estressados** (porque mudanças são pequenas e reversíveis).

A intuição confirmada: **batches pequenos** + **automação** + **monitoramento** > **deploys grandes raros** "para reduzir risco".

## Como aplicar

### As 4 métricas DORA

Pesquisa identificou as 4 métricas que diferenciam alta vs baixa performance:

| Métrica | Pergunta | Alto desempenho |
|---|---|---|
| **Deployment Frequency** | Com que frequência deploys vão para produção? | On-demand (várias vezes ao dia) |
| **Lead Time for Changes** | Tempo do commit até estar em produção? | < 1 dia |
| **Change Failure Rate** | % de deploys que causa falha em prod? | 0–15% |
| **Mean Time to Recover (MTTR)** | Quanto tempo para recuperar de falha? | < 1 hora |

Meça as 4. Melhore as que estão piores. Ver [dora.dev](https://dora.dev).

### Pipeline típico

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  git push   │────→│   CI (build │────→│  Deploy to  │────→│   Deploy    │
│             │     │   + testes) │     │   staging   │     │   to prod   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                          ↓                     ↓                   ↓
                    Unit + Lint           Integration         Smoke tests
                    Types check           E2E                 Canary
                    Build artifacts       Performance         Monitoring
                                          Security scan       Auto-rollback
```

### CI: boas práticas

#### Estágios paralelos e rápidos

```yaml
# .github/workflows/ci.yml
jobs:
  lint:    { runs-on: ubuntu-latest, steps: [/* fast */] }
  types:   { runs-on: ubuntu-latest, steps: [/* fast */] }
  test:    { runs-on: ubuntu-latest, steps: [/* unit */] }
  build:   { runs-on: ubuntu-latest, steps: [/* artifacts */] }
  integration:
    needs: build
    steps: [/* slower */]
```

Feedback **rápido**. CI que demora 30 min ninguém respeita.

#### Roda em **todo PR e branch principal**

- Pré-merge (PR): bloqueia se quebrar.
- Pós-merge (main/master): regenera artifacts oficiais.

#### Falhas atômicas, não silenciosas

Lint warning não deve passar como sucesso. Severity:

- **Erro** → bloqueia merge.
- **Warning** → mostra mas não bloqueia (use com parcimônia).

#### Caching

- **Dependências** (node_modules, pip, gradle), cacheie por hash do lock file.
- **Docker layers**: buildx, BuildKit.
- **Build incremental**: Nx, Turborepo cacheiam por afinidade.

#### Reprodutibilidade

```bash
# Mesmo comando local e no CI
make test
make build
```

Sem mágica oculta no CI. Devs reproduzem localmente.

### Deploy estratégias: ver [release strategies](./release-strategies.md)

- **Blue-green**: duas versões; alterna tráfego.
- **Canary**: 1% → 10% → 50% → 100% gradualmente.
- **Rolling**: substitui instâncias progressivamente.
- **Feature flags**: separa deploy de release; ver [feature flags](./feature-flags.md).

### Pipeline de release

#### Mínimo viável

```
git push → build → unit tests → docker image → deploy staging → manual approve → deploy prod
```

#### Maduro

```
git push (PR)
  → lint, types, unit
  → build (parallel for matrix)
  → integration tests
  → security scan (SAST, deps audit)
  → docker image with SBOM
  → push to registry
  
merge to main
  → re-build
  → deploy to staging (auto)
  → E2E in staging
  → contract test verification
  → smoke tests pass
  → deploy to prod canary (auto, 5%)
  → monitor metrics (5 min)
  → if green: roll forward to 100% (auto)
  → if red: auto-rollback
  → notify team
```

### Trunk-Based Development

Para CD funcionar bem, prefira [**Trunk-Based Development**](../collaboration/git-flow.md#alternativa-trunk-based-development-tbd):

- Branches curtas (horas a 1 dia).
- Merge para `main` frequente.
- Feature flags desacoplam *deploy* de *release*.

Git Flow tradicional com `develop` + `release` brigam com CD.

### Testes na pipeline

Ordem por **velocidade** e **custo**:

1. **Lint / format / types**: milissegundos.
2. **Unit tests**: segundos.
3. **Build**: segundos a minutos.
4. **Integration tests**: minutos.
5. **E2E em staging**: minutos.
6. **Smoke tests em prod**: segundos pós-deploy.

Falhe **cedo**. Não rode E2E se lint quebrou.

Ver [pirâmide de testes](../testing/test-pyramid.md).

### Security na pipeline (DevSecOps)

- **SAST** (Static Application Security Testing), análise estática do código (Semgrep, SonarQube, CodeQL).
- **Dependency scanning**: Dependabot, Snyk, Trivy.
- **Container scanning**: Trivy, Grype.
- **Secret scanning**: gitleaks, GitHub native.
- **IaC scanning**: Checkov, tfsec.

Integre **mas não bloqueie tudo**. Bloqueio só em **critical/high**; warnings devem virar tickets, não freeze de merge.

### Artifacts: imutáveis e identificáveis

Cada build produz **um artifact único**:

- Container image com tag = git SHA.
- Versão semântica + build metadata: `1.2.3+abc123`.
- SBOM (Software Bill of Materials) acompanhando.

Promove **o mesmo artifact** entre ambientes, não rebuild.

```bash
# Build uma vez
docker build -t myapp:abc123 .
docker push myregistry/myapp:abc123

# Deploy em vários ambientes: mesmo artifact
helm upgrade staging ./chart --set image.tag=abc123
helm upgrade prod    ./chart --set image.tag=abc123
```

Diferenças entre ambientes = **config**, não código.

### Ambientes

| Ambiente | Propósito | Quem deploya | Dados |
|---|---|---|---|
| **Dev** | Trabalho diário | Cada dev | Fake |
| **Staging** | Pré-prod, integração | CI (automático após merge) | Fake / sample |
| **Prod** | Produção | CI (automático após staging green) | Real |

**Ambientes ephemêros** (per-PR): cada PR sobe um ambiente próprio para review. Excelente para testes manuais sem fila.

### Rollback rápido > prevenção perfeita

> "It's not about avoiding failure. It's about recovering quickly when failure happens."
> (DORA team)

Estratégias:

- **Manter N versões anteriores** prontas no registry.
- **One-click rollback** ou auto-rollback baseado em alertas.
- **Forward-fix** quando rollback é caro (migrations de banco), corrija e redeploy rapidamente.

### Database migrations: caso especial

Migrations **acopladas** ao deploy:

- ✅ Backward-compatible migrations primeiro; código novo depois.
- ✅ Migrations rodadas como [admin process](./twelve-factor-app.md#xii-admin-processes--run-adminmanagement-tasks-as-one-off-processes).
- ❌ Migrations destrutivas no mesmo deploy do código que usa.

Ver [migrations](../data/migrations.md) e [expand-and-contract](https://martinfowler.com/bliki/ParallelChange.html).

### Plataformas e ferramentas

| Categoria | Opções |
|---|---|
| **CI/CD** | GitHub Actions, GitLab CI, CircleCI, Buildkite, Jenkins, Drone |
| **Container registry** | GitHub Packages, GitLab Container Registry, Docker Hub, ECR, GCR, ACR |
| **Deploy** | ArgoCD, Flux, Spinnaker, Octopus, Helm |
| **Feature flags** | LaunchDarkly, Unleash, Flagsmith, ConfigCat |
| **Monitoring de deploy** | Datadog, Honeycomb, Sentry, Grafana |

### Anti-padrões

#### CI que não bloqueia

Build "amarelo" mergeable. Time se acostuma a ignorar. Eventually nada está verde.

#### Deploy aprovado manualmente para "segurança"

Manual approval **não acrescenta segurança**: apenas latência. Use **automation + monitoring + rollback** em vez.

#### Tudo em um repo, tudo deploya junto

Monolito de deploy → falha de qualquer parte bloqueia o resto. Quebre em pipelines independentes onde fizer sentido.

#### CI lento sem mitigação

> 15 min de CI = ninguém roda local; só descobre erro depois. Otimize agressivamente: cache, paralelização, affected-only (Nx).

#### Sem rollback testado

Plano de rollback que nunca rodou em prod **não existe**. Pratique periodicamente (game days).

## Quando *não* usar

- **Scripts triviais / one-shot.** Não precisa de pipeline.
- **Sistemas regulados extremos** (aviônica, equipamentos médicos), CD nem sempre é viável; processos diferentes.
- **Quando a infraestrutura ainda está sendo construída**: CI pode esperar; instale antes.

Mas para 99% dos sistemas web/backend modernos, CI/CD não é opcional, é higiene.

## Conceitos relacionados

- [Git Flow / Trunk-Based Development](../collaboration/git-flow.md).
- [Pull Requests](../collaboration/pull-requests.md), onde CI dispara.
- [Feature flags](./feature-flags.md), separa deploy de release.
- [Release strategies](./release-strategies.md), como o deploy chega aos usuários.
- [Pirâmide de testes](../testing/test-pyramid.md), em quais estágios cada nível roda.
- [Twelve-Factor App](./twelve-factor-app.md), fatores I, V, X.

## Referências

- **Livro.** Jez Humble & David Farley, *Continuous Delivery* (Addison-Wesley, 2010). Texto fundador.
- **Livro.** Nicole Forsgren, Jez Humble, Gene Kim, *Accelerate* (IT Revolution, 2018). Pesquisa DORA, base científica.
- **Livro.** Gene Kim, Jez Humble, Patrick Debois, John Willis, *The DevOps Handbook*, 2ª ed. (IT Revolution, 2021).
- **Site.** [dora.dev](https://dora.dev). Métricas DORA atualizadas.
- **Site.** [continuousdelivery.com](https://continuousdelivery.com). Hub de Jez Humble & Dave Farley.
- **Artigo.** Martin Fowler, ["ContinuousIntegration"](https://martinfowler.com/articles/continuousIntegration.html). Texto canônico de CI.
- **Artigo.** Martin Fowler, ["ContinuousDelivery"](https://martinfowler.com/bliki/ContinuousDelivery.html).
- **Documentação.** [GitHub Actions docs](https://docs.github.com/actions).
- **Documentação.** [GitLab CI/CD](https://docs.gitlab.com/ee/ci/).
- **Documentação.** [ArgoCD](https://argo-cd.readthedocs.io/). GitOps moderno.
