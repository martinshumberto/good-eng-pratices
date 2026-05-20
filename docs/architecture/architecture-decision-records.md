# Architecture Decision Records (ADRs)

> **TL;DR.** Documentos curtos que capturam **uma** decisão arquitetural significativa: contexto, opções consideradas, decisão e consequências. Vivem no Git, são imutáveis (mudanças geram novos ADRs), e respondem ao "por que decidimos assim" anos depois.

## O quê

Um **Architecture Decision Record (ADR)** é um documento curto (~1 página) que registra **uma decisão arquitetural específica** e o raciocínio por trás dela. Foram propostos por **Michael Nygard** em 2011 ([post original](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)).

A ideia surgiu de um problema concreto: equipes herdam codebases e encontram decisões aparentemente arbitrárias. Sem registro, ninguém sabe **por que** o sistema é assim, e o time:

- **Reverte sem entender** o que estava sendo evitado.
- **Mantém o status quo religiosamente** com medo de quebrar algo invisível.
- **Refaz a mesma análise** que alguém já tinha feito 2 anos atrás.

ADRs resolvem isso ao deixar o raciocínio versionado.

## Por quê

- **Memória institucional.** A pessoa que tomou a decisão vai embora; o ADR fica.
- **Onboarding.** Novo desenvolvedor lê os ADRs e entende o porquê de escolhas que pareceriam estranhas.
- **Discussão estruturada.** Forçar a escrever um ADR força a articular o raciocínio, frequentemente revela que a decisão não estava tão clara quanto parecia.
- **Mudança consciente.** Quando uma decisão precisa ser revisada, você sabe o que motivou a original e pode avaliar se o contexto mudou.

> "Nothing is more dangerous than an idea, when it's the only one you have."
> (Émile Chartier (citado por Nygard sobre ADRs))

ADRs **não** documentam:

- O quê o sistema **faz** (isso é [C4](./c4-model.md) ou README).
- **Como** está implementado (isso é o código).
- Decisões triviais ou puramente táticas (qual cor o botão deve ter).

ADRs documentam decisões com **impacto arquitetural**: que afetam estrutura, qualidade de longo prazo ou capacidades.

## Como aplicar

### Estrutura clássica de Nygard

Cada ADR é um arquivo Markdown com seções fixas:

```markdown
# ADR-NNNN: Título curto descritivo da decisão

## Status

Proposto | Aceito | Substituído por ADR-XXXX | Obsoleto

## Contexto

Qual é o problema? Que forças estão em jogo (técnicas, organizacionais,
de mercado)? Por que essa decisão precisa ser tomada agora?

## Decisão

A decisão tomada, em modo imperativo. Ex.: "Vamos usar PostgreSQL
como banco principal."

## Consequências

O que decorre dessa decisão, positivo, negativo e neutro.
Quais portas se fecham? Quais se abrem?
```

### Convenções

- **Numeração crescente.** `ADR-0001`, `ADR-0002`, …. Sem reusar números.
- **Imutáveis após aceitos.** Mudar de ideia? Crie um **novo** ADR que substitui o anterior; mude o status do antigo para "Substituído por ADR-XXXX".
- **Localização padrão.** `docs/adr/` ou `docs/architecture/decisions/`.
- **Versionados em Git**: junto com o código.
- **Nomes de arquivo.** `0001-use-postgres-for-main-database.md`.

### Exemplo completo

```markdown
# ADR-0007: Adotar PostgreSQL como banco relacional principal

## Status

Aceito, 2024-08-15

## Contexto

Precisamos escolher o banco relacional principal para os novos
microsserviços. Critérios:

- Maturidade (>10 anos em produção em escala).
- Suporte sólido em GCP (banco gerenciado).
- Capacidade de armazenar JSON (parte do schema é semi-estruturada).
- Comunidade ativa no Brasil (contratação).
- Licença open-source permissiva.

Opções consideradas:
- PostgreSQL
- MySQL / MariaDB
- CockroachDB
- AWS Aurora (RDS)

## Decisão

Vamos usar **PostgreSQL 15** como banco relacional principal,
hospedado no Cloud SQL (GCP).

## Consequências

### Positivas
- JSONB nativo cobre cenários semi-estruturados sem precisar de Mongo.
- Extensões (PostGIS, pg_partman) abrem caminho para necessidades futuras.
- Cloud SQL fornece backup automático e replicação.

### Negativas
- Cloud SQL tem limites de conexões mais baixos que self-hosted; precisamos
  de PgBouncer ou usar connection pooling cuidadoso.
- Migração futura para multi-region exige mais trabalho que CockroachDB.

### Neutras
- Equipe atual tem experiência majoritária em PostgreSQL.
- Necessidade de definir convenção para uso de JSONB vs colunas normais.
```

### Quando criar um ADR

Bons candidatos a ADR:

- Escolha de **tecnologia core** (banco, linguagem, framework, message broker).
- Escolha de **padrão arquitetural** (Layered vs Hexagonal vs Clean).
- **Decisões de organização** (monolito modular vs microsserviços; monorepo vs polyrepo).
- **Mudanças em contratos públicos** de longo prazo (versionamento de API, formato de evento).
- **Política de segurança / compliance** (onde guardar secrets, criptografia em repouso).

Maus candidatos:

- "Que linter usar" (resolve no `package.json`).
- "Que nome dar à variável" (resolve no PR).
- Decisões reversíveis em minutos.

### Templates alternativos

Vários templates surgiram a partir do original. Vale conhecer:

- **MADR (Markdown Any Decision Record)**: mais elaborado, com seções "Drivers", "Options", "Pros/Cons of the Options". Bom quando há muitas opções a comparar. Ver [adr.github.io](https://adr.github.io/madr/).
- **Y-statement**: formato curto inspirado em arquitetura de microservices: "In context X, facing Y concerns, we decided Z to achieve W, accepting downsides V."

Use o que se encaixa no time. **Consistência é mais importante que sofisticação.**

### Tooling

- **[adr-tools](https://github.com/npryce/adr-tools)**: CLI clássica para criar/listar/atualizar ADRs. `adr new "Use Postgres"` cria o arquivo numerado.
- **[Log4brains](https://github.com/thomvaill/log4brains)**: gera site estático navegável a partir dos ADRs em Markdown.
- **[adr-viewer](https://github.com/mrwilson/adr-viewer)**: alternativa para gerar site.
- **Templates como repositório.** [joelparkerhenderson/architecture-decision-record](https://github.com/joelparkerhenderson/architecture-decision-record), coleção de templates.

### Boas práticas

- **Escreva no momento da decisão.** ADRs escritos meses depois perdem o raciocínio fresco.
- **Curto.** Uma página. Se passou de 3, está virando especificação, não registro.
- **Honesto sobre alternativas.** "Considere apenas Postgres" parece sólido mas é fraco, sem comparação, não dá pra avaliar o trade-off.
- **Linguagem decisiva.** "Vamos usar X", não "Talvez usemos X".
- **Status sempre atualizado.** ADRs obsoletos sem marcação confundem mais que ajudam.
- **Linke ADRs relacionados.** ADR-0010 que substitui ADR-0005 deve referenciar o outro.

## Quando *não* usar

- **Projetos pequenos sem complexidade arquitetural.** Comentário num issue basta.
- **Decisões reversíveis sem custo.** Lint config, identação. Vai versus README.
- **Como ata de reunião.** ADR é o resultado destilado, não a transcrição.

## Conceitos relacionados

- [C4 Model](./c4-model.md), documenta **o quê**; ADRs documentam **por quê**.
- [Documentação](../collaboration/documentation.md).
- [Pull Requests](../collaboration/pull-requests.md): ADRs frequentemente nascem em discussões de PR.

## Referências

- **Artigo.** Michael Nygard, ["Documenting Architecture Decisions"](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) (2011). Texto original.
- **Site.** [adr.github.io](https://adr.github.io). Hub com templates, ferramentas e exemplos.
- **GitHub.** [joelparkerhenderson/architecture-decision-record](https://github.com/joelparkerhenderson/architecture-decision-record). Coleção robusta de templates.
- **Documentação.** [MADR (Markdown Any Decision Record)](https://adr.github.io/madr/). Template mais elaborado.
- **Artigo.** ThoughtWorks Tech Radar, ["Lightweight Architecture Decision Records"](https://www.thoughtworks.com/radar/techniques/lightweight-architecture-decision-records) (Adopt, 2016). Endosso da prática.
- **Livro.** Mark Richards & Neal Ford, *Fundamentals of Software Architecture* (O'Reilly, 2020). Capítulo 19 trata de ADRs.
