# Alerting

> **TL;DR.** Alerte só o que é **acionável** e **urgente**. Alertas devem indicar **sintoma** (impacto no usuário), não causa. Separe canais: *page* (acorda alguém) vs *ticket* (vê de manhã). Fadiga de alerta mata observabilidade.

## O quê

**Alerting** é a prática de **notificar humanos** quando o sistema desvia do esperado. Vive sobre métricas, logs e traces, e é onde a observabilidade encontra ação humana.

Um alerta dispara quando uma condição é satisfeita:

```
Condição:  taxa_de_erro_5xx > 5% por 5 minutos
Ação:      notificar oncall via PagerDuty
```

A questão não é "o que dá pra alertar?", é "o que **deve** alertar?"

## Por quê

Alerting mal feito tem custos altos:

- **Fadiga de alerta.** Tudo apita, oncall ignora tudo, problemas reais passam.
- **Burnout.** Pessoas acordadas à noite para problemas que poderiam esperar.
- **Falsa segurança.** Alertas configurados mas que nunca disparam por algo real.

Alerting bem feito:

- **Disparado por sintomas.** Algo concreto está ruim para o usuário.
- **Acionável.** Quem recebe sabe o que fazer.
- **Priorizado.** Urgência condizente com o canal (page vs ticket).
- **Sustentável.** Volume baixo o suficiente para humanos manterem atenção.

> "Pages should be urgent, important, actionable, and real."
> (*Site Reliability Engineering*, Google)

## Como aplicar

### Sintoma vs causa

A regra-mestre: **alerte em sintomas, diagnostique em causas**.

| | Alerte | Não alerte (apenas dashboard) |
|---|---|---|
| **Sintoma** | "Taxa de erro 5xx > 5%" | |
| **Sintoma** | "Latência P99 > 2s" | |
| **Causa** | | "CPU > 80%" |
| **Causa** | | "Memória > 90%" |
| **Causa** | | "Tabela X com queries lentas" |

Por quê?

- **Sintomas são significativos por si.** Erro 5xx alto = usuário sofrendo. CPU alta não, pode ser normal sob carga.
- **Causas são contexto para diagnóstico**, não razão para acordar alguém. Use métricas de causa em dashboards, durante investigação.
- **Sintoma → causa** é tarefa do diagnóstico, não do alerta.

Exceção: causa **iminente** que **vai virar sintoma em pouco tempo**. Disco em 95% vai estourar logo, alerte.

### Page vs ticket

Defina canais por **urgência**, não importância:

| Canal | Quando | Resposta esperada |
|---|---|---|
| **Page** (PagerDuty, OpsGenie, telefone) | Algo crítico, agora, usuário impactado | < 15 minutos |
| **Ticket** (Slack, Jira, email) | Algo a investigar nas próximas horas | Próximo turno / dia útil |
| **Dashboard** (Grafana) | Acompanhamento contínuo | Olhar quando relevante |

> "If something can wait until the morning, it shouldn't page someone in the middle of the night."

### Alertas baseados em SLO: burn rate

A abordagem mais robusta (Google SRE Workbook): **alerte baseado em consumo de [error budget](./slo-sli-sla.md)**.

```
Burn rate = (taxa de erro atual / threshold de erro do SLO)

Burn rate 1×   → SLO é exatamente queimado no fim da janela
Burn rate 14×  → vai queimar 1 hora de budget em 5 minutos
```

#### Multi-window, multi-burn-rate

Recomendação Google:

| Janela | Burn rate | Severidade | Janela curta de confirmação |
|---|---|---|---|
| 1 hora | > 14.4× | Page | 5 minutos |
| 6 horas | > 6× | Page | 30 minutos |
| 1 dia | > 3× | Ticket | 2 horas |
| 3 dias | > 1× | Ticket | 6 horas |

Janela curta evita disparo em picos breves; janela longa pega problemas que se acumulam.

#### Exemplo em Prometheus

```yaml
- alert: HighErrorBudgetBurn
  expr: |
    (
      slo_burn_rate_1h{service="orders"} > 14.4
    AND
      slo_burn_rate_5m{service="orders"} > 14.4
    )
  for: 2m
  labels:
    severity: page
  annotations:
    summary: "Orders error budget burning 14.4× in last hour"
    runbook: "https://wiki.example.com/runbooks/orders-error-budget"
```

Note `AND` com janela curta, exige confirmação para evitar pico-instantâneo.

### Cada alerta precisa de runbook

Quando o alerta dispara, o oncall **não pode** precisar adivinhar:

- O que esse alerta significa?
- Como começar a investigar?
- Como mitigar enquanto se diagnostica?
- Quem é o owner se eu precisar escalar?

Anexe **runbook URL** em todo alerta:

```yaml
annotations:
  summary: "Database connection pool exhausted"
  runbook: "https://wiki.example.com/runbooks/db-pool-exhausted"
  description: |
    Pool of `orders` has all connections in use for > 5 min.
    
    Investigation:
    1. Check `pg_stat_activity` for long-running queries.
    2. Check recent deploys for new endpoints.
    
    Mitigation:
    - Restart pods: `kubectl rollout restart deploy/orders`.
    - If escalation needed, page DBA team.
```

Runbook desatualizado é tão ruim quanto não-existente. Atualize após cada incidente.

### Estrutura de um alerta: campos essenciais

| Campo | Conteúdo |
|---|---|
| **name** | Identificador curto e estável |
| **severity** | `page` / `ticket` / `info` |
| **summary** | Uma linha, aparece na notificação |
| **description** | Detalhes do que aconteceu |
| **runbook** | URL do runbook |
| **dashboard** | URL do dashboard relevante |
| **owner / team** | Quem é responsável por esse serviço |
| **expr** | A condição (Prometheus, Datadog, etc.) |

### Anti-padrões comuns

#### Alertas demais

"500 alertas configurados; ninguém olha." Lei prática: se um alerta dispara semanalmente sem ação humana, ele **não deveria existir**. Apague ou converta em ticket de baixa prioridade.

#### Alertas que não param

Alerta que dispara e fica disparando até manualmente silenciar é ruído. Use *snoozing*, *grouping* e auto-resolução.

#### Alertas em causa, não sintoma

"CPU alta" sem impacto é informativo. Mover para dashboard.

#### Alertas sem dono

Ninguém sabe quem deve responder. Defina **routing claro** por serviço/equipe.

#### Alertas sem severidade

"Alerta médio" vira "ignorar até crítico". Use os 2–3 níveis com clareza.

#### Alertas que dependem de inferência

"Disco em 80% + tráfego em pico = possível problema." Inferências complexas em condições de alerta erram. Use métricas simples de impact direto.

### Routing: para quem vai cada alerta

Em sistemas com múltiplos times, **rote alertas para o time dono do serviço**:

```yaml
route:
  receiver: 'default'
  routes:
    - match: { team: orders }
      receiver: 'orders-team-pagerduty'
    - match: { team: payments }
      receiver: 'payments-team-pagerduty'
```

Adicione label `team` em todas as métricas via service discovery + labels do Prometheus.

### Cultura: postmortems e revisão

Toda página merece **revisão pós-incidente** (postmortem). Não para culpar, para aprender:

- O alerta disparou na hora certa?
- O runbook ajudou?
- A causa raiz foi descoberta rápido?
- Que monitoramento faltou?

Postmortems geram **action items** que melhoram o sistema.

> "We don't blame people. We blame the situation. We blame our systems."
> (Google SRE Book, cap. 15)

Veja também a prática de **blameless postmortems**.

### Quando reduzir alertas (alert pruning)

Periodicamente, faça **limpeza**:

- Alertas que dispararam mas não viraram ação → review e remover/converter.
- Alertas que nunca dispararam em 6 meses → verificar se ainda fazem sentido.
- Alertas redundantes (dois disparando juntos sempre) → consolidar.

### Ferramentas

| Ferramenta | Notas |
|---|---|
| **PagerDuty** | Padrão de mercado para paging. |
| **OpsGenie** (Atlassian) | Alternativa, integração com Jira. |
| **Grafana OnCall** | Open source moderno. |
| **AlertManager** (Prometheus) | Roteamento, deduplicação, silenciamento. |
| **Squadcast**, **Better Stack**, **Splunk On-Call** | Outras opções. |

## Quando *não* usar

- **Aplicações sem oncall.** Alertas para times que não atuam são apenas ruído.
- **Métricas insignificantes.** Não alerte "número de usuários online caiu 1%". Não é acionável.
- **Em desenvolvimento.** Alertas em ambientes não-produtivos viram fadiga rápida.

## Conceitos relacionados

- [SLO: SLI, SLA](./slo-sli-sla.md), alertas idealmente derivados de SLOs.
- [Os três pilares](./three-pillars.md), métricas são a fonte de alertas.
- [Monitoramento de microsserviços](./microservices-monitoring.md).
- [Health checks](./health-checks.md), sinal usado para alertas de availability.

## Referências

- **Livro.** Betsy Beyer et al. (eds.), *Site Reliability Engineering* (O'Reilly, 2016). Capítulo 6 ("Monitoring Distributed Systems") e 11 ("Being On-Call"). [Gratuito](https://sre.google/sre-book/).
- **Livro.** *The Site Reliability Workbook* (O'Reilly, 2018). [Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/).
- **Livro.** Mike Julian, *Practical Monitoring* (O'Reilly, 2017). Foco prático no design de alertas.
- **Livro.** John Allspaw, Jesse Robbins (eds.), *Web Operations* (O'Reilly, 2010). Capítulos sobre alerting e cultura.
- **Artigo.** Google, ["My Philosophy on Alerting"](https://docs.google.com/document/d/199PqyG3UsyXlwieHaqbGiWVa8eMWi8zzAn0YfcApr8Q/). Rob Ewaschuk, fonte do "page on symptoms".
- **Artigo.** Charity Majors, ["Test in production"](https://increment.com/testing/i-test-in-production/). Discute o relacionamento entre alerts, observabilidade e cultura.
- **Documentação.** [Prometheus AlertManager](https://prometheus.io/docs/alerting/latest/alertmanager/).
- **Documentação.** [Datadog: Alert configuration best practices](https://docs.datadoghq.com/monitors/guide/best-practices/).
