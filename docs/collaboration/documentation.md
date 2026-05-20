# Documentação Técnica

> **TL;DR.** Documentação cumpre quatro funções (Divio framework): **tutoriais** (aprender), **how-to** (resolver problemas), **reference** (consultar), **explanation** (entender). Misturar as quatro num doc só confunde. Trate docs **como código**: vivem no Git, são revisadas em PR, são responsabilidade do time.

## O quê

**Documentação técnica** é tudo que ajuda outras pessoas (e seu eu futuro) a usar, manter ou evoluir o software. Há vários **tipos** com propósitos diferentes:

- **README**: o que é, como começar.
- **Tutoriais**: guias progressivos para iniciantes.
- **How-to guides**: receitas para problemas específicos.
- **Reference**: descrição precisa de APIs, comandos, opções.
- **Explanation**: discussão de conceitos, decisões, contexto.
- **ADRs**: registros de decisão arquitetural.
- **Runbooks**: passos para incidentes operacionais.
- **Postmortems**: análise após incidentes.

**Daniele Procida** ([divio.com, 2017](https://documentation.divio.com)) propôs um framework que mapeia os quatro principais tipos:

|  | Aprendendo | Resolvendo problema |
|---|---|---|
| **Orientação prática** | Tutorial | How-to |
| **Orientação teórica** | Explanation | Reference |

Cada tipo serve audiência e momento diferentes. **Misturar** = doc ruim.

## Por quê

Software sem documentação tem custos previsíveis:

- **Onboarding lento.** Cada nova pessoa redescobre tudo.
- **Bus factor baixo.** Conhecimento só na cabeça de alguém.
- **Decisões repetidas.** "Por que está assim?" → ninguém sabe → mude → quebra.
- **Operação dependente de heróis.** Só uma pessoa sabe responder ao incidente X.

Com docs vivas:

- **Onboarding rápido**: novo dev em produtivo em dias, não meses.
- **Diagnóstico rápido**: runbook diz exatamente o que fazer.
- **Decisões mantidas**: contexto sobrevive a rotatividade.
- **Conhecimento distribuído**: qualquer um pode operar.

> "Documentation is a love letter that you write to your future self."
> (Damian Conway)

## Como aplicar

### O Diátaxis framework: 4 tipos, 4 propósitos

[**Diátaxis**](https://diataxis.fr) (sucessor moderno do Divio framework) separa rigorosamente:

#### 1) Tutorials: aprender fazendo

**Audiência:** iniciante.
**Propósito:** ganhar competência básica.
**Estilo:** passo-a-passo, mão-dada.

```markdown
# Getting Started with API X

Let's create your first user.

1. Install the SDK: `npm install @ourorg/sdk`
2. Initialize the client:
   ```ts
   import { Client } from '@ourorg/sdk';
   const client = new Client({ apiKey: 'demo' });
   ```
3. Create a user:
   ```ts
   const user = await client.users.create({ email: '...' });
   ```
4. You should see: ...
```

**Não inclua:** alternativas, casos avançados, "por quês" profundos. Foco em **uma rota de sucesso**.

#### 2) How-to guides: resolver problema específico

**Audiência:** competente, com objetivo concreto.
**Propósito:** completar tarefa específica.
**Estilo:** receita, foco no resultado.

```markdown
# How to enable 2FA for users

## Prerequisites
- User has email verified
- Org has 2FA enabled in plan

## Steps
1. Call `POST /users/:id/2fa/setup` → returns QR code
2. User scans QR code in authenticator app
3. User submits 6-digit code: `POST /users/:id/2fa/verify`
4. Optional: enforce 2FA via `PATCH /orgs/:id/policy`
```

**Não inclua:** intro detalhada, justificativa de design. Quem está aqui já sabe o que quer.

#### 3) Reference: consulta precisa

**Audiência:** desenvolvedor usando a API.
**Propósito:** verificar detalhes, parâmetros, valores.
**Estilo:** descritivo, exaustivo, sistemático.

```markdown
## `client.users.create(input)`

Creates a new user.

### Parameters

| Name | Type | Required | Description |
|---|---|---|---|
| `input.email` | `string` | Sim | Email válido, máx. 255 chars |
| `input.name` | `string` | Não | Nome completo |
| `input.role` | `'admin' \| 'member' \| 'guest'` | Não | Default: `member` |

### Returns

`Promise<User>`

### Errors

- `400 invalid_email`: email malformado
- `409 user_exists`: email já cadastrado

### Example

```ts
const user = await client.users.create({ email: 'a@b.com' });
```
```

OpenAPI / TSDoc geram boa parte disso automaticamente, use.

#### 4) Explanation: entender conceitos

**Audiência:** desenvolvedor curioso/avançado.
**Propósito:** entender o porquê.
**Estilo:** discursivo, contextual.

```markdown
# Why we use UUIDs for primary keys

Our system uses UUIDs (v7) instead of auto-incrementing integers...
[discussão sobre opacidade, distribuição, trade-offs]
```

**Não inclua:** instruções passo-a-passo. Aqui é prosa, não receita.

### Onde cada tipo costuma viver

| Tipo | Local típico |
|---|---|
| README | Raiz do repo |
| Tutorial | `/docs/getting-started.md` ou site dedicado |
| How-to | `/docs/guides/<task>.md` |
| Reference | Gerado de código (OpenAPI, TSDoc, Sphinx) |
| Explanation | `/docs/explanation/` ou bloco de "Background" no doc |
| ADR | `/docs/adr/0001-*.md` (ver [ADRs](../architecture/architecture-decision-records.md)) |
| Runbook | `/docs/runbooks/<service>.md` |
| Postmortem | `/postmortems/2024-08-15-incident.md` |

### README: o cartão de visita

Toda repo de código tem README na raiz. **Mínimo:**

```markdown
# Project Name

One-line description.

## Status / Stability

Production / Beta / Experimental.

## Quick Start

```bash
make install
make dev
```

## Architecture

[Diagram ou link para C4]

## Documentation

- [Tutorial](./docs/getting-started.md)
- [Reference](./docs/reference/)
- [Contributing](./CONTRIBUTING.md)

## License
```

Para o detalhe: [makeareadme.com](https://www.makeareadme.com).

### Docs as code

Trate documentação **como código**:

- **Vive no Git.** Junto do código que documenta.
- **Revisada em PR.** Mudanças passam por code review.
- **Testada** quando possível. Doctests, link checkers, lint de markdown.
- **Deploy automatizado** via CI.
- **Versionada** com o produto.

Vantagens:

- Mudança de código + mudança de doc no mesmo PR, sem dessincronização.
- Histórico (git blame) explica evolução.
- Pull request facilita correções de qualquer um.

### Estática vs. wiki

| | Estática (Markdown em Git) | Wiki (Confluence, Notion) |
|---|---|---|
| **Versionada com código** | Sim | Não |
| **Revisão via PR** | Sim | Não |
| **Search universal** | Depende | Sim |
| **Edição não-dev** | Mais difícil | Fácil |
| **Atualização rápida** | PR | Edit |

Para docs **técnicas** que evoluem com código, estática vence. Para docs **organizacionais** (processo de RH, OKRs), wiki é melhor.

Em muitas organizações: docs técnicas no Git, deployadas em static site (Docusaurus, MkDocs, mdBook, Nextra). Docs gerais em Notion/Confluence.

### Geradores de static site

- **[Docusaurus](https://docusaurus.io)**: Meta. React. Bom para docs com versionamento.
- **[MkDocs](https://www.mkdocs.org)**: Python. Tema [Material](https://squidfunk.github.io/mkdocs-material/) é excelente.
- **[mdBook](https://rust-lang.github.io/mdBook/)**: Rust. Simples, usado por Rust docs.
- **[Nextra](https://nextra.site)**: Next.js. Bom para docs modernos.
- **[Hugo](https://gohugo.io)**: Go. Rápido.
- **[Astro Starlight](https://starlight.astro.build)**: Moderno, framework-agnóstico.

### Runbooks: operacional

Quando algo dá errado em produção, **runbook** diz exatamente o que fazer:

```markdown
# Runbook: Database connection pool exhausted

## Symptom
Application returns 500s; logs show "pool exhausted" errors.

## First response (< 5 min)

1. Confirm via dashboard: [Database connections graph](URL)
2. Check for runaway queries: `pg_stat_activity` query in [Notion](URL)
3. If queries blocking: kill long-running with `SELECT pg_terminate_backend(pid)`

## Mitigation

- Restart application pods (resets pool):
  ```bash
  kubectl rollout restart deploy/orders -n production
  ```

## Root cause investigation

- Check recent deploys for new endpoints
- Look at slow query logs from last 2 hours
- Check `pg_stat_statements` for new queries

## Escalation

If not resolved in 15 min, page DBA team via #db-oncall.
```

**Princípios:**

- **Atualizar após cada incidente.**
- **Linkar do alerta** ([alerting](../observability/alerting.md)).
- **Específico.** Vago não ajuda em pânico.
- **Mecanismo de quem-faz-o-quê**: qual comando rodar, com qual user, em qual cluster.

### Postmortems: depois do incidente

Após incidente significativo, escreva postmortem (sem culpa, *blameless*):

```markdown
# Postmortem: Orders Service outage: 2024-08-15

## Summary
Orders service unavailable for 23 minutes (10:15–10:38 UTC).

## Impact
- 1,247 failed checkouts
- Estimated revenue impact: ...
- 3 customer complaints

## Timeline
- 10:15, Deploy of v1.2.4 to production
- 10:17, Error rate metric started rising
- 10:19, On-call paged
- 10:25, Identified bad release as cause
- 10:31, Rollback initiated
- 10:38, Service recovered

## Root cause
Migration in 1.2.4 changed column type without backward compatibility.
Old pods continued reading old format; new format incompatible.

## What went well
- Alert fired within 4 minutes of issue
- On-call response < 5 min
- Rollback procedure worked as expected

## What went poorly
- Migration safety check missing in CI
- No canary deploy for schema changes

## Action items
- [ ] Add `migration-safety-checker` to CI (Owner: @alice: Due: 2024-08-22)
- [ ] Document expand-and-contract for all schema changes (Owner: @bob)
- [ ] Add canary stage for backend services (Owner: @carol)
```

**Princípios:**

- **Blameless.** Foco em sistema, não pessoas.
- **Honest.** Reconheça o que falhou.
- **Action items** com responsável e prazo.
- **Public dentro da org.** Apprendizado coletivo.

Ver [SRE Book: Postmortem Culture](https://sre.google/sre-book/postmortem-culture/).

### O que **não** documentar

- **O óbvio**: "esta função soma dois números" sobre `function add(a, b) { return a + b; }`.
- **O implementacional puro**: comentário "for loop iterates from 0 to n" sobre código que faz isso.
- **Decisões já documentadas no código.** Tipos, nomes claros, testes substituem comentários.

### Como manter docs vivas

Docs morrem por desatualização. Para evitar:

- **Reviews periódicos**: trimestralmente, alguém olha cada doc e marca como atual ou desatualizada.
- **Quem mexe no código mexe nos docs.** Política do PR: mudança que afeta doc requer atualização.
- **CI verifica links quebrados**: [lychee](https://github.com/lycheeverse/lychee), [markdown-link-check](https://github.com/tcort/markdown-link-check).
- **Ownership claro**: cada área tem dono.
- **"Last updated" visível**: leitor vê se está antigo.

### Documentação como acessibilidade

Não é "extra" para o time, é acessibilidade:

- Quem está em outro fuso horário não pode perguntar.
- Quem é júnior precisa de mapa.
- Quem voltou de férias precisa de contexto.
- Quem entrou ontem precisa de tudo.

Boa documentação **escala o time** ao reduzir interrupções.

## Quando *não* usar

- **Código que vai sumir em semanas**: POC, spike, demo descartável.
- **Detalhes voláteis**: APIs em flux. Documente quando estabilizar.
- **Quando seria mentira.** "Atualizaremos em breve" sem plano = melhor não publicar.

## Conceitos relacionados

- [ADRs](../architecture/architecture-decision-records.md), registros de decisão arquitetural.
- [C4 Model](../architecture/c4-model.md), diagramas de arquitetura.
- [Pull Requests](./pull-requests.md), onde docs também são revisadas.
- [Conventional Commits](./conventional-commits.md), tipo `docs:` separado.
- [Alerting](../observability/alerting.md), links para runbooks.

## Referências

- **Site.** [Diátaxis](https://diataxis.fr). Framework moderno (Procida).
- **Site.** [Divio Documentation System](https://documentation.divio.com). Versão anterior do Diátaxis.
- **Livro.** Andrew Etter, *Modern Technical Writing* (CreateSpace, 2016). Concise, docs-as-code.
- **Livro.** Mike Pope, *Developing Quality Technical Information* (IBM Press, 2014).
- **Site.** [Google: Technical Writing One](https://developers.google.com/tech-writing/one). Curso gratuito.
- **Site.** [Write the Docs](https://www.writethedocs.org). Comunidade.
- **Site.** [makeareadme.com](https://www.makeareadme.com). Template moderno.
- **Documentação.** [SRE Book: Postmortem Culture](https://sre.google/sre-book/postmortem-culture/). Blameless postmortems.
- **Artigo.** Tom Limoncelli, ["Documentation: Don't Wait Till the Last Minute"](https://queue.acm.org/detail.cfm?id=2349257) (ACM Queue).
