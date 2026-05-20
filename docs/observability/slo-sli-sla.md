# SLO, SLI, SLA

> **TL;DR.** **SLI** = a métrica (ex.: % de requests 200). **SLO** = a meta interna (ex.: 99.9% mensal). **SLA** = compromisso externo + consequência (ex.: 99.9% ou crédito ao cliente). O **error budget** = quanto você pode falhar dentro do SLO, funciona como "permissão para mudar".

## O quê

Vocabulário definido pelo Google em *Site Reliability Engineering* (O'Reilly, 2016):

| Sigla | Significa | Para quem |
|---|---|---|
| **SLI**: Service Level Indicator | A **métrica** que mede qualidade do serviço | Time técnico (medição) |
| **SLO**: Service Level Objective | A **meta** que o SLI deve atender | Time técnico (compromisso interno) |
| **SLA**: Service Level Agreement | O **compromisso contratual** + consequência (crédito, multa) | Cliente externo |

A relação:

```
SLA (ex.: 99.9% por contrato)
  └── SLO (ex.: 99.95% interno, mais apertado que SLA)
       └── SLI (ex.: % de requests com status < 500 e latência < 500ms)
```

Boa prática: **SLO mais apertado que SLA**: assim você quebra o SLA antes de quebrar o contrato.

## Por quê

Sem essas definições, conversas de "está rápido" e "está estável" são opinião. Com SLI/SLO:

- **Alinhamento.** Engenharia, produto e ops concordam no que significa "OK".
- **Decisões objetivas.** "Posso deployar essa feature arriscada?" depende do error budget.
- **Comunicação com cliente.** SLAs explicitam o que se promete.
- **Cultura saudável.** SLO 100% é impossível; tentar atingir gera burnout. SLO realista permite trade-offs conscientes.

> "100% is the wrong reliability target for basically everything."
> (*Site Reliability Engineering*, Google)

## Como aplicar

### 1) Escolhendo o SLI

Um bom SLI:

- **Mede o que o usuário sente.** Latência percebida, taxa de sucesso. Não CPU, não disco.
- **É proporção** (sucesso/total). Facilita o cálculo do SLO.
- **É implementável.** Você consegue medir o que diz que mede.

**Categorias comuns:**

| Categoria | Exemplos de SLI |
|---|---|
| **Disponibilidade** | % de requests com status < 500 |
| **Latência** | % de requests com duração < 500ms (p95, p99) |
| **Throughput** | requests por segundo durante períodos esperados |
| **Frescor** | tempo desde a última atualização de uma projeção |
| **Corretude** | % de relatórios sem inconsistência |

**Definição formal de SLI:**

```
SLI = good_events / valid_events
```

```
Disponibilidade = (requests com status < 500) / (todos os requests válidos)
Latência       = (requests com duração < 500ms) / (todos os requests válidos)
```

`valid_events` deve excluir o que **não conta**: requests de health check, requests de IPs maliciosos, requests que o usuário cancelou.

### 2) Definindo o SLO

Um SLO bom:

- **Tem janela temporal.** "99.9% no mês corrente." Sem janela, é meta vaga.
- **É **mais apertado** que o SLA** (se houver). Margem operacional.
- **É realista.** SLO 99.99% custa N× mais que 99.9%, só vale para sistemas críticos.

#### Tabela de tempo permitido

| SLO | Downtime mensal | Downtime anual | Custo relativo |
|---|---|---|---|
| 99% (two nines) | 7h 18min | 3.65 dias | Baixo |
| 99.5% | 3h 39min | 1.83 dia | Baixo |
| 99.9% (three nines) | 43.8min | 8.76h | Médio |
| 99.95% | 21.9min | 4.38h | Alto |
| 99.99% (four nines) | 4.38min | 52.6min | Muito alto |
| 99.999% (five nines) | 26.3s | 5.26min | Extremo (raro) |

A diferença entre 99.9% e 99.99% costuma significar **mudança de arquitetura** (multi-region, replicação síncrona, fallbacks redundantes), com custo proporcional.

### 3) Error budget

**Error budget** é o complemento do SLO:

```
Error Budget = 100% - SLO
```

Para SLO de 99.9% mensal:

```
Error Budget = 0.1% = 43.8 minutos de downtime/mes
```

O conceito é poderoso porque transforma o budget em **moeda operacional**:

- **Budget intacto** → time pode deploar features arriscadas, fazer mudanças de infra, etc.
- **Budget queimado** → freeze de mudanças até o SLO se recompor.

Isso resolve o conflito clássico entre **dev (quer entregar)** e **ops (quer estabilidade)**: ambos olham para o mesmo número.

> "If we have an error budget left, we're free to take risks."
> (Google SRE Book)

#### Burn rate

Não basta medir o budget em fatias mensais, alertas precisam disparar **antes** de tudo ser queimado.

**Burn rate** = taxa de consumo do budget.

```
Burn rate 1x = no ritmo certo, vai bater o budget no fim do mês
Burn rate 14.4x = vai queimar 1h de budget em 5min
```

Configuração típica (multi-window, multi-burn-rate, Google SRE Workbook):

| Janela | Burn rate | Reação |
|---|---|---|
| 1 hora | > 14.4x | Page (acordar alguém) |
| 6 horas | > 6x | Page |
| 24 horas | > 3x | Ticket (manhã) |
| 72 horas | > 1x | Ticket |

Ver [Alerting](./alerting.md).

### 4) Implementação prática

#### Em Prometheus

```promql
# SLI de disponibilidade: % de requests não-5xx nos últimos 28 dias
1 - (
  sum(rate(http_requests_total{status=~"5.."}[28d]))
  /
  sum(rate(http_requests_total[28d]))
)

# Error budget consumido
1 - (slo_threshold - sli_value) / (1 - slo_threshold)
```

#### Ferramentas

- **[Sloth](https://sloth.dev)**: gerador de alerts e dashboards a partir de SLOs declarados em YAML.
- **[Pyrra](https://github.com/pyrra-dev/pyrra)**: operator para Kubernetes.
- **[Nobl9](https://www.nobl9.com)**: plataforma SaaS de SLOs.
- **Grafana SLO**: recurso nativo no Grafana Cloud.
- **Datadog SLOs**, **New Relic SLM**: em plataformas managed.

#### Exemplo de SLO em Sloth

```yaml
version: prometheus/v1
service: orders-service
slos:
  - name: availability
    objective: 99.9
    description: "99.9% of HTTP requests should be successful over 28 days"
    sli:
      events:
        error_query: sum(rate(http_requests_total{job="orders",status=~"5.."}[{{.window}}]))
        total_query: sum(rate(http_requests_total{job="orders"}[{{.window}}]))
    alerting:
      page_alert:
        labels:
          severity: page
      ticket_alert:
        labels:
          severity: ticket
```

### 5) SLA: quando entra?

SLA = SLO + **consequência contratual**. Geralmente:

- **B2B com cliente pagante**: SLA com créditos / multas por descumprimento.
- **Plataforma interna**: geralmente só SLO, sem contrato formal.

**Práticas:**

- **SLA mais frouxo que o SLO**: você quer estourar o SLO antes do SLA.
- **SLA simples para o cliente**: uma frase ("99.9% de uptime").
- **SLO técnico mais detalhado** internamente.

### 6) Anti-padrões

#### SLO 100%

Impossível. Tentar significa que toda mudança é uma ameaça, ninguém deploya, time vira refém da estabilidade. **99.99% é frequentemente perto demais do limite**; vá apenas até onde o negócio justifica.

#### SLI sem ligação com experiência do usuário

CPU em 80% não é problema do usuário. O usuário sente latência, sente erro. Meça isso.

#### SLO sem error budget consumido

SLO é meta, mas sem usar o budget como ferramenta de decisão, vira número decorativo.

#### Mudança de SLO arbitrária

"Estávamos batendo demais a meta, aumentei para 99.95%". Mudanças de SLO devem ser **decisões conscientes**, não retroativas para "esconder problema".

#### SLO sem janela temporal

"99.9%" sem dizer "por mês"/"por trimestre" não diz nada, depende de quanto tráfego e quando.

## Quando *não* usar

- **Aplicações em desenvolvimento inicial** sem usuários reais. SLO ainda não tem dados para basear.
- **Sistemas internos sem expectativa formal.** Métricas simples sem SLO formal já bastam.
- **Quando o time não usa.** SLO escrito mas ignorado durante incidentes é trabalho perdido.

## Conceitos relacionados

- [Os três pilares](./three-pillars.md), métricas alimentam SLIs.
- [Alerting](./alerting.md), alertas baseados em burn rate.
- [Monitoramento de microsserviços](./microservices-monitoring.md), onde SLO se documenta.
- [Health checks](./health-checks.md), uma faceta da disponibilidade.

## Referências

- **Livro.** Betsy Beyer et al. (eds.), *Site Reliability Engineering* (O'Reilly, 2016). Capítulo 4 ("Service Level Objectives"). [Gratuito online](https://sre.google/sre-book/service-level-objectives/).
- **Livro.** *The Site Reliability Workbook* (O'Reilly, 2018). Capítulos 2–5 sobre SLOs práticos. [Gratuito](https://sre.google/workbook/).
- **Livro.** Alex Hidalgo, *Implementing Service Level Objectives* (O'Reilly, 2020). Tratado moderno e prático.
- **Site.** [sre.google](https://sre.google). Hub Google de material.
- **Artigo.** Google, ["Multi-Burn-Rate: Multi-Window Alerts"](https://sre.google/workbook/alerting-on-slos/#multiwindow-multi-burn-rate-alerts). Burn rate explicado.
- **Documentação.** [Sloth: SLO Generator for Prometheus](https://sloth.dev).
- **Artigo.** [Atlassian: SLA vs SLO vs SLI](https://www.atlassian.com/incident-management/kpis/sla-vs-slo-vs-sli).
