# Monitoramento de Microsserviços

> **TL;DR.** Documente cada serviço por **criticidade**, **dependências** e **métricas-chave**, e mantenha esse inventário vivo. É a fonte de verdade para alertas, runbooks e priorização durante incidentes.

## O quê

Monitoramento de microsserviços vai além de "graphs no Grafana". Envolve quatro camadas que **documentam o sistema** e **operacionalizam decisões**:

1. **Inventário**: lista de serviços, com responsabilidade e dependências.
2. **Criticidade**: impacto esperado de uma falha (justifica priorização).
3. **Métricas e limites**: o que medir, qual o valor "normal", qual o limite que dispara alerta.
4. **Playbook de diagnóstico**: comportamentos anômalos comuns e suas causas prováveis.

Este documento é um **template**. Em um projeto real, cada seção é preenchida com os serviços e infraestrutura específicos.

## Por quê

Sem inventário, todo incidente vira arqueologia. Sem criticidade documentada, todos os serviços parecem igualmente urgentes. Sem playbook, o diagnóstico depende da memória de quem está de plantão.

> "You can't manage what you can't measure."
> (Atribuído a Peter Drucker (controverso, mas reflete bem o ponto))

Documento vivo + revisão recorrente (em retros, post-mortems) garante que o conhecimento operacional sobrevive a rotatividade do time.

## Como aplicar

### 1) Inventário de serviços

Para cada microsserviço, documente:

- **Responsabilidade**: qual problema o serviço resolve.
- **Principais funcionalidades**: capacidades expostas (sem entrar em endpoint a endpoint).
- **Tecnologias**: linguagens, bancos, caches, brokers críticos.
- **Dependências críticas**: outros serviços ou recursos sem os quais o serviço não funciona.

#### Template

```markdown
### MS <nome>

- **Responsabilidade:** …
- **Principais funcionalidades:**
  - …
- **Tecnologias:**
  - …
- **Dependências críticas:**
  - …
```

### 2) Criticidade e impacto

Classifique cada serviço por **criticidade** (Alta / Média / Baixa) e descreva o **impacto** de uma indisponibilidade. Isso direciona priorização de alertas, runbooks e [SLOs](./slo-sli-sla.md).

| Microsserviço | Criticidade | Impacto em caso de falha |
|---|---|---|
| Auth | Alta | Usuários não conseguem acessar o sistema. |
| Profile | Alta | Usuários não conseguem acessar o sistema. |
| `<domínio crítico>` | Alta | Funcionalidade principal indisponível. |
| `<serviço de configuração>` | Média | Indisponibilidade ao ver/gerenciar a entidade em qualquer parte do sistema. |
| `<serviço auxiliar>` | Baixa | Indisponibilidade em feature isolada, sem impacto perceptível ao usuário final. |

### 3) Observabilidade: métricas essenciais

Todo serviço deve emitir, no mínimo:

- **Latência** das chamadas externas (banco, cache, APIs).
- **Taxa de erros** por endpoint e por dependência.
- **P95 / P99** do tempo de resposta HTTP.
- **Volume de requests** (RPM).

Esses são os ["RED metrics"](https://thenewstack.io/monitoring-microservices-red-method/) (Rate: Errors, Duration), popularizados por Tom Wilkie:

| Métrica | Pergunta que responde |
|---|---|
| **R**ate | Quantos requests por segundo? |
| **E**rrors | Quantos falharam? |
| **D**uration | Quanto tempo levaram? |

Para recursos compartilhados (banco, fila, cache), complementam-se com [USE metrics](https://www.brendangregg.com/usemethod.html) (Utilization: Saturation, Errors), Brendan Gregg.

| Microsserviço | Métricas essenciais | Indicadores de problema |
|---|---|---|
| Todos | Latência de queries ao banco | Aumento no tempo de resposta |
| Com cache | Latência ao cache, taxa de acerto | Queda no hit rate |

### 4) Infraestrutura e dependências

Mapeie cada componente compartilhado e o impacto de sua falha. Isso justifica alertas em recursos que não são "do serviço" mas afetam muitos.

| Componente | Criticidade | Impacto em caso de falha |
|---|---|---|
| Banco relacional (Postgres) | Alta | Nenhum serviço estará disponível. |
| Cache (Redis) | Alta | Nenhuma requisição autenticada retornará 200. |
| Banco NoSQL | Alta | Disponibilidade do domínio impactado falha. |
| Time-series DB | Média | Sem registro de auditoria/métricas. |
| Fila / pub-sub | Alta | Processamento assíncrono interrompido. |
| Object storage | Alta | Indisponibilidade em qualquer feature de upload. |
| OTEL Collector | Média | Indisponibilidade no envio de logs/traces/métricas; aumenta MTTR. |

### 5) Limites de alerta

Definir **limites concretos** evita alertas baseados em "feeling". Revise os limites trimestralmente.

| Componente | Métricas relevantes | Limites críticos |
|---|---|---|
| Banco relacional | Queries lentas, conexões ativas, tempo médio de resposta | CPU > 80%; storage > 80%; queries > 2s |
| Microsserviços (gerais) | P95 do HTTP | P95 acima de 1s |
| Serviços de orquestração | HTTP P95, Socket P95 | HTTP P95 > 2s; Socket P95 > 30s |
| Cache | Hit rate, latência, memória | Latência > 100ms; hit rate < 80% |
| NoSQL | Queries lentas, conexões ativas | CPU > 70%; storage > 60%; queries > 1s |
| Time-series DB | Hit rate, latência, memória | Latência > 100ms; hit rate < 80% |
| Filas | Mensagens em fila, tempo médio em fila | Mensagens paradas > 5 min |
| OTEL Collector | Timeouts | > 10% das requests com timeout |

### 6) Diagnóstico: comportamentos anômalos

Para cada classe de componente, documente os **sintomas mais comuns** e suas causas prováveis. Funciona como primeira parada do *runbook*.

#### Banco relacional

- **Alta latência em consultas:** índices ausentes, plano de execução ruim, locks concorrentes.
- **Deadlocks frequentes:** transações concorrentes segurando locks conflitantes.
- **Crescimento anormal de `pg_stat_statements`:** queries ineficientes acumulando.

#### Microsserviços (geral)

- **Aumento de tempo de resposta:** sobrecarga no banco, filas congestionadas.
- **Alto consumo de memória sem liberação:** vazamento de memória ou conexões não fechadas.
- **Erros intermitentes de comunicação:** timeout de dependências externas (APIs, banco, filas).
- **Picos inesperados de CPU:** loops infinitos, consultas pesadas, problemas de concorrência.
- **Falhas em inicialização / reinicializações constantes:** migrations sujas, dependências ausentes, health check falho.

#### Cache (Redis)

- **Alto consumo de memória com chave expirada lenta:** TTL mal configurado ou queries ineficientes.
- **Aumento de latência:** tráfego alto, falta de sharding.
- **Evictions frequentes:** cache pequeno descartando dados importantes; rotas autenticadas degradam.

#### Banco NoSQL

- **Aumento do tempo de resposta:** falta de índices, uso excessivo de joins / lookups, documentos grandes.
- **Alto consumo de disco:** rotina de migração para datalake falhando.
- **Bloqueios frequentes de escrita:** alta concorrência; pode exigir redesenho dos documentos.

#### Time-series DB

- **Latência nas inserções:** sobrecarga de disco.

#### Filas / pub-sub

- **Mensagens acumuladas sem consumo:** problema nas DLQs ou nas políticas de retenção.
- **Retries excessivos:** payload mal formado, verificar DLQ.
- **Fila crescendo sem diminuir:** consumidor sendo gargalo, verificar CPU/memória e replicação.

### 7) Métricas de negócio

Além das métricas técnicas, defina **métricas de negócio** que indicam se o produto está saudável. São o sinal mais cedo de impacto real.

| Indicador | O que mede |
|---|---|
| Taxa de sucesso no login | Disponibilidade do acesso ao aplicativo |
| Erros nas operações críticas | Possível impacto no faturamento ou em SLAs |
| Tempo médio de operação principal end-to-end | Saúde percebida pelo usuário final |

## Quando *não* usar

- **Aplicações monolíticas pequenas.** Inventário formal é overhead. Documente o necessário no README.
- **Sistemas sem incidente histórico que justifique.** Comece simples (RED metrics + dashboard básico) e cresça quando o sistema crescer.

## Conceitos relacionados

- [SLO: SLI, SLA](./slo-sli-sla.md), formaliza criticidade como compromisso mensurável.
- [Os três pilares, logs, métricas, traces](./three-pillars.md).
- [Alerting](./alerting.md).
- [Health checks](./health-checks.md).

## Referências

- **Livro.** *Site Reliability Engineering: How Google Runs Production Systems* (O'Reilly, 2016). Disponível em [sre.google/sre-book](https://sre.google/sre-book). Capítulos 4 (SLOs) e 6 (Monitoring Distributed Systems).
- **Livro.** *The Site Reliability Workbook* (O'Reilly, 2018). [sre.google/workbook](https://sre.google/workbook).
- **Livro.** Michael Nygard, *Release It!*, 2ª ed. (Pragmatic Bookshelf, 2018). Padrões de estabilidade.
- **Livro.** Cindy Sridharan, *Distributed Systems Observability* (O'Reilly, 2018). [PDF gratuito](https://www.oreilly.com/library/view/distributed-systems-observability/9781492033431/).
- **Artigo.** Tom Wilkie, ["The RED Method: How To Instrument Your Services"](https://www.weave.works/blog/the-red-method-key-metrics-for-microservices-architecture/).
- **Artigo.** Brendan Gregg, ["USE Method"](https://www.brendangregg.com/usemethod.html).
- **Site.** [microservices.io: Observability patterns](https://microservices.io/patterns/observability/).
