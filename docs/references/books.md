# Livros de Referência

Bibliografia-âncora deste repositório. São as obras citadas com mais frequência nos documentos, todas escritas por autores de credibilidade reconhecida na engenharia de software.

A organização é por **tema**, não por relevância. Dentro de cada tema, os livros estão ordenados do mais fundamental ao mais especializado.

---

## Fundamentos e princípios

### *The Pragmatic Programmer* (20th Anniversary Edition)
**Andy Hunt & Dave Thomas**: Addison-Wesley, 2019.
Coletânea de práticas pragmáticas aplicáveis em qualquer linguagem ou domínio. Contém ideias como *DRY*, *tracer bullets* e *broken windows*. Boa porta de entrada.

### *Code Complete* (2ª ed.)
**Steve McConnell**: Microsoft Press, 2004.
Tratado abrangente sobre construção de software. Cobre nomenclatura, controle de fluxo, defensive programming, testes, integração. Denso e referência obrigatória.

### *Clean Code*
**Robert C. Martin**: Prentice Hall, 2008.
Práticas de código limpo: nomes, funções, comentários, formatação, classes. Algumas opiniões controversas, mas é leitura comum no mercado e influencia muitas convenções.

### *A Philosophy of Software Design* (2ª ed.)
**John Ousterhout**: Yaknyam Press, 2021.
Foco em complexidade, o que é, como surge, como reduzir. Apresenta o conceito de *deep modules*. Um contraponto inteligente a algumas ideias de Clean Code.

---

## Refatoração e código legado

### *Refactoring: Improving the Design of Existing Code* (2ª ed.)
**Martin Fowler**: Addison-Wesley, 2018.
Catálogo de refatorações com motivação, mecânica passo a passo e exemplo. A 2ª edição usa JavaScript. Referência inevitável para falar de mudança segura.

### *Working Effectively with Legacy Code*
**Michael Feathers**: Prentice Hall, 2004.
Técnicas para domesticar bases sem testes. Define *legacy code* como código sem testes, definição que ficou. Indispensável para refatoração no mundo real.

---

## Arquitetura

### *Patterns of Enterprise Application Architecture*
**Martin Fowler**: Addison-Wesley, 2002.
Catálogo de padrões para aplicações corporativas: camadas, mapeamento O/R (*Active Record*, *Data Mapper*, *Unit of Work*, *Identity Map*), distribuição, concorrência. Apesar da idade, continua sendo a referência canônica.

### *Clean Architecture*
**Robert C. Martin**: Prentice Hall, 2017.
Apresenta arquiteturas orientadas a uso (Hexagonal, Onion, Clean) com a regra de dependência apontando para o domínio. Boa introdução conceitual.

### *Domain-Driven Design: Tackling Complexity in the Heart of Software*
**Eric Evans**: Addison-Wesley, 2003.
A obra que cunhou DDD. Linguagem ubíqua, *bounded contexts*, *aggregates*, *value objects*. Denso. Para uma versão mais aplicada, ver Vernon.

### *Implementing Domain-Driven Design*
**Vaughn Vernon**: Addison-Wesley, 2013.
DDD aplicado, com exemplos em código. Complementa Evans com prática. Frequentemente recomendado *junto*, Evans para a teoria, Vernon para implementação.

### *Building Microservices* (2ª ed.)
**Sam Newman**: O'Reilly, 2021.
Cobertura completa de microsserviços: definição, comunicação, deploy, observabilidade, segurança, evolução. Trata também dos *trade-offs*, quando **não** usar microsserviços.

### *Monolith to Microservices*
**Sam Newman**: O'Reilly, 2019.
Estratégias para evoluir um monolito em direção a microsserviços. Padrões como *Strangler Fig*, *Branch by Abstraction*. Antídoto contra rewrites totais.

### *Software Architecture: The Hard Parts*
**Neal Ford, Mark Richards, Pramod Sadalage, Zhamak Dehghani**: O'Reilly, 2021.
Decisões arquiteturais difíceis: granularidade de serviços, distribuição de dados, contratos. Pragmático.

---

## Sistemas distribuídos e dados

### *Designing Data-Intensive Applications*
**Martin Kleppmann**: O'Reilly, 2017.
Praticamente um clássico moderno. Cobre replicação, particionamento, transações, consenso, processamento batch e stream. Indispensável para qualquer pessoa que trabalha com dados em escala.

### *Release It!* (2ª ed.)
**Michael Nygard**: Pragmatic Bookshelf, 2018.
Padrões e antipadrões para sistemas em produção: *circuit breaker*, *bulkhead*, *steady state*, *fail fast*. Lições aprendidas em catástrofes reais.

### *Database Internals*
**Alex Petrov**: O'Reilly, 2019.
Como bancos funcionam por dentro: estruturas de armazenamento, replicação, distribuição. Complementa Kleppmann.

---

## Testes

### *Test Driven Development: By Example*
**Kent Beck**: Addison-Wesley, 2002.
Livro curto que introduz TDD com exemplos concretos.

### *Growing Object-Oriented Software, Guided by Tests*
**Steve Freeman & Nat Pryce**: Addison-Wesley, 2009.
TDD aplicado a sistemas reais com mock objects e *outside-in*. Referência para quem quer ir além do "test pyramid".

### *xUnit Test Patterns*
**Gerard Meszaros**: Addison-Wesley, 2007.
Catálogo de padrões de teste: doubles, fixtures, custom assertions. Linguagem comum.

---

## Operação, entrega e cultura

### *Site Reliability Engineering: How Google Runs Production Systems*
**Betsy Beyer, Chris Jones, Jennifer Petoff, Niall Richard Murphy (eds.)**: O'Reilly, 2016.
SLO, SLI, *error budget*, *toil*. Disponível gratuitamente em [sre.google/sre-book](https://sre.google/sre-book).

### *The Site Reliability Workbook*
**Beyer, Murphy, Rensin, Kawahara, Thorne (eds.)**: O'Reilly, 2018.
Companion prático do SRE Book. Também disponível em [sre.google/workbook](https://sre.google/workbook).

### *The DevOps Handbook* (2ª ed.)
**Gene Kim, Jez Humble, Patrick Debois, John Willis**: IT Revolution, 2021.
Síntese de práticas DevOps com casos reais. Complementa *The Phoenix Project* (que é narrativa).

### *Accelerate*
**Nicole Forsgren, Jez Humble, Gene Kim**: IT Revolution, 2018.
Pesquisa que sustenta os DORA metrics (lead time, deployment frequency, MTTR, change failure rate). Base científica para conversas sobre produtividade de engenharia.

### *Continuous Delivery*
**Jez Humble & David Farley**: Addison-Wesley, 2010.
Como entregar software de forma confiável e frequente. Pipeline de deploy, testes automatizados, controle de configuração.

---

## Segurança

### *Threat Modeling: Designing for Security*
**Adam Shostack**: Wiley, 2014.
Como pensar em ameaças durante o design. STRIDE e outras frameworks.

### *The Web Application Hacker's Handbook* (2ª ed.)
**Dafydd Stuttard & Marcus Pinto**: Wiley, 2011.
Vulnerabilidades web do ponto de vista do atacante. Idoso mas ainda relevante para os fundamentos.

---

## Liderança técnica e processo

### *The Mythical Man-Month*
**Frederick P. Brooks Jr.**: Addison-Wesley, 1975 (edição 20º aniversário, 1995).
"Adicionar pessoas a um projeto atrasado o atrasa ainda mais". Ensaios sobre engenharia de software como atividade humana.

### *Peopleware* (3ª ed.)
**Tom DeMarco & Timothy Lister**: Addison-Wesley, 2013.
Os problemas dos projetos são quase sempre humanos, não técnicos.

### *Team Topologies*
**Matthew Skelton & Manuel Pais**: IT Revolution, 2019.
Organização de times para entrega rápida. Conceitos de *stream-aligned*, *platform*, *enabling*, *complicated-subsystem* teams.
