# Estratégias de Release

> **TL;DR.** **Rolling** substitui instâncias progressivamente (default em K8s). **Blue-green** mantém duas versões e alterna. **Canary** envia tráfego para a nova versão gradualmente, vigiando métricas. **Shadow** roda a nova versão em paralelo sem afetar usuários. Combine com [feature flags](./feature-flags.md) para máxima flexibilidade.

## O quê

Quando uma versão nova precisa chegar a produção, há várias maneiras de **como** colocá-la lá. Cada estratégia tem trade-offs entre velocidade, segurança, custo e complexidade.

| Estratégia | Risco em prod | Custo extra | Complexidade |
|---|---|---|---|
| **Recreate** | Alto (downtime) | Zero | Trivial |
| **Rolling** | Médio | Baixo | Baixa |
| **Blue-Green** | Baixo | Alto (2× recursos) | Média |
| **Canary** | Muito baixo | Médio | Alta |
| **Shadow** | Quase zero | Alto | Alta |

A escolha depende de quão crítica é a app, quanto custo você pode pagar e quanto risco aceita.

## Por quê

Sem estratégia consciente, deploy em produção é "shutdown + boot da nova versão", com downtime e risco máximo. Estratégias modernas reduzem **ambos**:

- **Downtime zero**: usuários nunca veem indisponibilidade.
- **Rollback rápido**: voltar à versão anterior é uma ação simples.
- **Detecção precoce**: problemas aparecem com pequeno % de tráfego, não com 100%.
- **Confiança operacional**: deploys frequentes viáveis.

A escolha certa depende do **risk profile** da mudança:

- **Mudança não-arriscada** (bug fix pequeno, refator interno): rolling basta.
- **Mudança arriscada** (algoritmo novo, mudança de comportamento): canary com feature flag.
- **Mudança de schema de banco**: cuidado especial, ver [migrations](../data/migrations.md).

## Como aplicar

### Recreate

Encerre tudo, suba a versão nova.

```
v1 (10 instances) ─ shutdown ─→ ⛔ (downtime) ─→ start v2 (10 instances)
```

**Quando usar:**
- Aplicações offline (cron jobs, workers que toleram pausa).
- Quando incompatibilidade rolling-friendly não existe (raro mas acontece).

**Quando NÃO usar:**
- Qualquer serviço com usuários ativos.

### Rolling

Substitui instâncias **uma de cada vez** (ou em lotes), mantendo o serviço sempre disponível.

```
Start: v1 v1 v1 v1 v1
Step:  v2 v1 v1 v1 v1
       v2 v2 v1 v1 v1
       v2 v2 v2 v1 v1
       v2 v2 v2 v2 v1
End:   v2 v2 v2 v2 v2
```

**Configuração K8s:**

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1          # quantas extras subir antes
      maxUnavailable: 0    # quantas podem estar fora
```

**Vantagens:**
- Sem downtime (com `maxUnavailable: 0`).
- Custo mínimo (poucas instâncias a mais durante transição).
- Default sensato.

**Cuidados:**
- Versão antiga e nova rodam simultaneamente durante o rollout → contratos devem ser compatíveis.
- Rollback exige fazer outro rolling deploy (não é instantâneo).
- Bug na versão nova pode chegar a 100% se métricas não pegam rápido.

**É a estratégia default na maioria dos sistemas.**

### Blue-Green

Mantém **dois ambientes paralelos** (Blue = atual, Green = novo). Tráfego alterna em uma operação.

```
Antes:  Tráfego → Blue (v1) [Green vazio]
Setup:  Tráfego → Blue (v1) [Green (v2) sendo testado]
Switch: Tráfego → Green (v2) [Blue (v1) standby]
Cleanup: Tráfego → Green (v2) [Blue desligado ou pronto para próximo]
```

**Vantagens:**
- **Rollback instantâneo**: basta voltar o switch.
- Testes contra Green antes do switch.
- Sem coexistência de versões em produção.

**Custos:**
- **2× a infra** durante a janela.
- Sessões podem se perder se não houver session affinity adequada.
- Migrations de banco compartilhadas precisam ser backward-compat.

**Quando usar:**
- Mudança grande, com risco alto.
- Rollback ágil é crítico.
- Você pode pagar 2× infra durante a janela.

### Canary

Envia **uma fração do tráfego** para a versão nova, observa métricas, expande progressivamente.

```
Step 1: 99% v1, 1%  v2  → monitor 10min
Step 2: 95% v1, 5%  v2  → monitor 10min
Step 3: 80% v1, 20% v2  → monitor 30min
Step 4: 50% v1, 50% v2  → monitor 1h
Step 5: 0%  v1, 100% v2
```

Se métricas degradam em qualquer etapa → **rollback automático**.

**Vantagens:**
- Falhas aparecem com pequeno % afetado.
- Detecção precoce baseada em **métricas reais** de prod.
- Auto-rollback possível.

**Custos:**
- Complexidade de infra (load balancer + observability + automation).
- Precisa de métricas confiáveis para decidir avançar.

**Tooling:**
- [Argo Rollouts](https://argoproj.github.io/argo-rollouts/) (K8s), canary declarativo com análise automática.
- [Flagger](https://flagger.app) (K8s), análise via Prometheus/Datadog.
- [Spinnaker](https://spinnaker.io), canary + análise.
- AWS CodeDeploy, canary nativo para ECS/Lambda.

**Exemplo Argo Rollouts:**

```yaml
spec:
  strategy:
    canary:
      steps:
      - setWeight: 5
      - pause: { duration: 10m }
      - setWeight: 20
      - pause: { duration: 30m }
      - setWeight: 50
      - pause: { duration: 1h }
      - setWeight: 100
      analysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: orders-service
```

**Análise automática:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata: { name: success-rate }
spec:
  metrics:
  - name: success-rate
    interval: 5m
    successCondition: result[0] >= 0.95
    failureLimit: 3
    provider:
      prometheus:
        query: |
          sum(rate(http_requests_total{service="orders",status!~"5.."}[5m]))
          /
          sum(rate(http_requests_total{service="orders"}[5m]))
```

Se taxa de sucesso < 95% → falha → rollback automático.

### Shadow / Mirror

Roda a nova versão **em paralelo**, recebendo cópia do tráfego, **sem afetar a resposta** ao usuário.

```
Request → v1 (responde ao usuário)
        ↓ cópia
        → v2 (processa em paralelo, resposta descartada/comparada)
```

**Vantagens:**
- Zero impacto em usuários.
- Validação contra tráfego de produção real.
- Excelente para mudanças de algoritmo (busca, ranking, ML).

**Custos:**
- 2× capacidade computacional para o tráfego espelhado.
- Side effects da v2 precisam ser **suprimidos** (não dobre envio de email).
- Comparação de resultados é não-trivial.

**Tooling:**
- Istio / Envoy, mirror traffic nativo.
- AWS App Mesh.
- Loja própria via reverse proxy.

### Combinações poderosas

#### Canary + Feature Flag

```
1. Mergeie código novo com flag desligada → deploy normal (sem risco).
2. Ligue a flag para 1% dos usuários → observe.
3. 10% → 50% → 100%.
4. Remova a flag.
```

[Feature flags](./feature-flags.md) tornam canary **muito mais barato**: você não precisa de infra paralela, controla via flag.

#### Blue-Green para mudança maior, Canary para risk profile específico

Mistura é possível. Use blue-green para isolar grandes mudanças e canary para subset de tráfego dentro.

### Database migrations: caso especial

Estratégias acima assumem que **antigo e novo podem coexistir**. Para schema:

- **Expand-and-contract** ([Martin Fowler: Parallel Change](https://martinfowler.com/bliki/ParallelChange.html)):
  1. **Expand**: adicione coluna nova nullable.
  2. App nova escreve em ambas; app antiga lê coluna velha.
  3. Backfill se necessário.
  4. App nova lê coluna nova.
  5. **Contract**: remove coluna velha quando ninguém mais usa.

Cada passo é uma release; nunca quebra. Ver [migrations](../data/migrations.md).

### Métricas para decidir avanço

Em canary ou rolling, **observe enquanto promove**:

- **Error rate** (5xx, exceções).
- **Latência** (P95, P99).
- **Throughput** (RPS).
- **Métricas de negócio críticas** (conversão de checkout, login success).
- **Logs de erro** novos.

Se qualquer um piorar → halt + rollback.

### Rollback: sem isso, deploy é torcida

| Estratégia | Como rollback |
|---|---|
| **Recreate** | Deploy versão antiga (downtime de novo) |
| **Rolling** | Rolling deploy reverso (não-instantâneo) |
| **Blue-Green** | Toggle switch (instantâneo) |
| **Canary** | Reverter setWeight (rápido) ou auto-rollback (Argo, Flagger) |
| **Shadow** | Desligar v2 (instantâneo) |

**Praticar rollback** periodicamente. Plano que nunca rodou em prod **não existe**.

### Anti-padrões

#### Strategy mais complexa que necessário

Canary com 7 passos e análise ML para deploy de typo fix. Use rolling.

#### Estratégia sem monitoring

Canary sem dashboards e alertas = recreate disfarçado de canary.

#### Migrations destrutivas no mesmo deploy

`DROP COLUMN` no mesmo deploy do código que para de usar. Coexistência impossível. Use expand-and-contract.

#### "Acertou no 1%, vai dar certo no 100%"

Bugs de carga só aparecem em escala. Métricas de canary **incluem** comportamento sob carga (latência, throughput), não só correctness.

#### Rollback é "estresse": só usar em última necessidade

Errado. Rollback deve ser **operação rotineira**. Quanto mais natural, melhor a confiança no deploy.

## Quando *não* usar (cada estratégia)

- **Recreate**: em sistemas com usuários. Quase nunca.
- **Blue-Green**: quando custo de 2× infra é proibitivo. Quando mudanças de schema impossibilitam coexistência.
- **Canary**: quando o sistema não tem métricas confiáveis para decisão. Quando volume de tráfego é tão baixo que 1% não estatisticamente significativo.
- **Shadow**: quando v2 tem side effects difíceis de suprimir (envia email, debita conta).

## Conceitos relacionados

- [CI/CD](./ci-cd.md), onde estratégias se aplicam.
- [Feature flags](./feature-flags.md), combinação poderosa com canary.
- [Os três pilares](../observability/three-pillars.md), métricas que sustentam decisão.
- [Migrations](../data/migrations.md), schema em release coordenado.
- [SLO/SLI](../observability/slo-sli-sla.md), base para análise automática.

## Referências

- **Livro.** Jez Humble & David Farley, *Continuous Delivery* (Addison-Wesley, 2010). Capítulos 10–11.
- **Livro.** Nicole Forsgren, Jez Humble, Gene Kim, *Accelerate* (IT Revolution, 2018). Por que deploys frequentes funcionam.
- **Artigo.** Martin Fowler, ["BlueGreenDeployment"](https://martinfowler.com/bliki/BlueGreenDeployment.html). Bliki canônico.
- **Artigo.** Martin Fowler, ["CanaryRelease"](https://martinfowler.com/bliki/CanaryRelease.html).
- **Artigo.** Martin Fowler, ["ParallelChange"](https://martinfowler.com/bliki/ParallelChange.html). Expand-and-contract.
- **Documentação.** [Kubernetes Deployment strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/).
- **Documentação.** [Argo Rollouts](https://argoproj.github.io/argo-rollouts/).
- **Documentação.** [Flagger](https://flagger.app).
- **Artigo.** Google, ["Mitigating risk with progressive delivery"](https://cloud.google.com/architecture/application-deployment-and-testing-strategies).
- **Artigo.** Netflix, ["Automated Canary Analysis"](https://netflixtechblog.com/automated-canary-analysis-at-netflix-with-kayenta-3260bc7acc69).
