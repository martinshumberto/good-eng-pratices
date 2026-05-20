# Sites e Recursos Online

Recursos canônicos consultados ao longo do repositório. Curadoria, não tudo que existe, mas o que **vale ser lido**.

---

## Catálogos de padrões e referência

### [martinfowler.com](https://martinfowler.com)
Bliki, ensaios e referência permanente. Buscável. Quase qualquer termo central da engenharia tem uma definição autoral aqui.

### [refactoring.guru](https://refactoring.guru)
Catálogo visual de padrões de projeto (GoF) e de *code smells / refactorings*. Tradução PT-BR disponível. Excelente como referência rápida.

### [microservices.io](https://microservices.io)
Catálogo mantido por Chris Richardson cobrindo padrões de microsserviços: comunicação, transações distribuídas (Saga), descoberta, observabilidade. Cada padrão tem motivação, solução, trade-offs e exemplos.

### [c4model.com](https://c4model.com)
Modelo C4 para diagramação de arquitetura (Context → Container → Component → Code) por Simon Brown. Pragmático e amplamente adotado.

### [Patterns of Distributed Systems](https://martinfowler.com/articles/patterns-of-distributed-systems/)
Catálogo de padrões para sistemas distribuídos (Unmesh Joshi, no site do Fowler): *write-ahead log*, *leader and followers*, *generation clock*, *idempotent receiver*.

---

## Fundamentos e arquitetura

### [12factor.net](https://12factor.net)
A *Twelve-Factor App*, manifesto sobre como construir aplicações SaaS portáteis e resilientes. Mais de uma década e continua válido.

### [The Cathedral and the Bazaar](http://www.catb.org/~esr/writings/cathedral-bazaar/)
Eric Raymond, ensaio fundador sobre modelos de desenvolvimento.

---

## Operação e SRE

### [sre.google/books](https://sre.google/books)
*Site Reliability Engineering*, *The Site Reliability Workbook* e *Building Secure & Reliable Systems*, gratuitos online, escritos pela equipe que opera Google em escala.

### [dora.dev](https://dora.dev)
DORA, *DevOps Research and Assessment*. Métricas que diferenciam times de alta vs. baixa performance: *deployment frequency*, *lead time*, *change failure rate*, *MTTR*.

### [aws.amazon.com/builders-library](https://aws.amazon.com/builders-library)
Amazon Builders' Library, ensaios técnicos da AWS sobre operação em escala. Excelentes textos sobre *timeouts*, *retries*, *jitter*, *idempotência*, *caching*.

### [allthingsdistributed.com](https://www.allthingsdistributed.com)
Blog de Werner Vogels (CTO Amazon). Decisões arquiteturais por trás de S3, DynamoDB, etc.

---

## Segurança

### [owasp.org](https://owasp.org)
Open Web Application Security Project. Top 10 de vulnerabilidades web, ASVS, cheat sheets, *Threat Dragon*. Referência obrigatória.

### [cheatsheetseries.owasp.org](https://cheatsheetseries.owasp.org)
Guias rápidos cobrindo autenticação, autorização, *secure coding*, criptografia. Excelente como checklist por tópico.

### [Mozilla Web Security Guidelines](https://infosec.mozilla.org/guidelines/web_security)
Diretrizes consolidadas: TLS, headers de segurança (CSP, HSTS), cookies.

---

## Dados

### [ben-stopford.com](https://www.ben-stopford.com)
Ben Stopford (Confluent), sistemas baseados em eventos, event sourcing, design para escalabilidade.

### [jepsen.io](https://jepsen.io)
Kyle Kingsbury, análise empírica de garantias de consistência em bancos distribuídos. Leitura obrigatória antes de assumir que um banco "é consistente".

---

## Linguagem e código

### [google.github.io/styleguide](https://google.github.io/styleguide)
Style guides do Google para múltiplas linguagens. Mesmo discordando de pontos específicos, o nível de detalhe é referência.

### [google.github.io/eng-practices](https://google.github.io/eng-practices)
Práticas de engenharia do Google, em especial o guia de *code review* (lado de quem escreve e lado de quem revisa).

### [Conventional Commits](https://www.conventionalcommits.org)
Especificação para mensagens de commit semânticas.

### [Keep a Changelog](https://keepachangelog.com)
Convenção para manter um `CHANGELOG.md` legível.

### [Semantic Versioning (SemVer)](https://semver.org)
Especificação de versionamento `MAJOR.MINOR.PATCH`.

---

## Comunidades e fontes contínuas

### [InfoQ](https://www.infoq.com)
Curadoria de palestras técnicas e artigos. Boa fonte para acompanhar tendências sem ruído.

### [thoughtworks.com/insights/blog](https://www.thoughtworks.com/insights/blog) e [thoughtworks.com/radar](https://www.thoughtworks.com/radar)
*Technology Radar* da Thoughtworks, recomendações atualizadas a cada 6 meses sobre técnicas, ferramentas, plataformas e linguagens. *Adopt / Trial / Assess / Hold*.

### [ACM Queue](https://queue.acm.org)
Revista da ACM voltada para engenharia em produção. Artigos longos, escritos por praticantes.

### [The Morning Paper](https://blog.acolyer.org)
Adrian Colyer resume papers acadêmicos diariamente (arquivo). Forma rápida de acompanhar pesquisa relevante.

---

## Diagramação

### [mermaid.js.org](https://mermaid.js.org)
Diagramas como texto, renderizam nativamente no GitHub. Padrão deste repositório.

### [excalidraw.com](https://excalidraw.com)
Diagramas à mão livre quando Mermaid for limitado.

### [draw.io](https://app.diagrams.net) / [diagrams.net](https://diagrams.net)
Open source, para diagramas estruturados (C4, fluxos).
