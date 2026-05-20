# Ferramentas de Trabalho

> **TL;DR.** Ferramentas auxiliares que aparecem repetidamente no dia a dia de engenharia mas não pertencem a um doc temático específico. Use como referência rápida.

## O quê

Esta página agrupa **ferramentas operacionais**: utilitários que ajudam a diagnosticar, debugar e inspecionar sistemas em desenvolvimento. Não cobre setup de ambiente, IDEs ou linguagens, que ficam no README do projeto.

## Por quê

Boas ferramentas eliminam horas de tentativa-e-erro. Conhecer as opções consolidadas é parte da maturidade técnica, em vez de tentar adivinhar por que um request HTTP está falhando, abra um proxy e veja o tráfego real.

## Como aplicar

### Debug de rede: Proxyman

[Proxyman](https://proxyman.io) é a ferramenta recomendada para inspecionar tráfego HTTP/HTTPS durante o desenvolvimento. Atua como proxy entre cliente (browser, app mobile, CLI) e servidor, exibindo todo o tráfego de forma legível.

#### Capacidades

- Inspecionar request/response de qualquer cliente HTTP (apps iOS/Android no simulador, browser, CLI, scripts).
- Decrypt de HTTPS via certificado instalado no dispositivo/emulador.
- **Map Local / Map Remote**: substituir respostas em tempo real para testar cenários sem mexer no backend.
- **Breakpoints**: pausar uma request antes do envio (editar headers/body) ou pausar a response antes do retorno.
- **Repeat**: reenviar uma request capturada com alterações.

#### Configuração para iOS Simulator

Documentação: [Proxyman, iOS Simulator](https://docs.proxyman.io/debug-devices/ios-simulator).

Resumo:

1. Abra o Proxyman antes do simulador.
2. **Certificate → Install Certificate on iOS → Simulator**: instale o cert root.
3. No simulador: **Settings → General → About → Certificate Trust Settings**: habilite o cert do Proxyman.
4. Inicie a app, o tráfego aparece automaticamente no Proxyman.

#### Configuração para Android Emulator

Documentação: [Proxyman: Android](https://docs.proxyman.io/debug-devices/android-device).

Resumo:

1. Abra o Proxyman antes do emulador.
2. **Certificate → Install Certificate on Android → Emulator**: siga as instruções para o nível de API.
3. A partir do Android 7, apps que usam *Network Security Config* precisam declarar permissão explícita para certificados de usuário em debug builds.

#### Boas práticas

- **Nunca confie no certificado em produção.** Proxyman só em desenvolvimento. Remova o cert depois do uso.
- **Filtre por host.** Em uma app real, telemetria/analytics escondem os requests que importam.
- **Salve sessões úteis.** Sessões com bugs reproduzidos podem ser exportadas e anexadas a tickets para acelerar diagnóstico.
- **Map Local para reproduzir bugs.** Quando o problema está no backend mas você quer testar o cliente, substitua a response capturada por um payload modificado.

### Alternativas a Proxyman

| Ferramenta | Plataforma | Notas |
|---|---|---|
| **[Proxyman](https://proxyman.io)** | macOS: Windows, Linux | Recomendado. UI moderna, gratuito com limites; pago para uso pesado. |
| **[Charles Proxy](https://www.charlesproxy.com)** | Cross-platform | Veterano. Robusto: UI mais datada. |
| **[mitmproxy](https://mitmproxy.org)** | CLI / Web | Open source. Excelente para automação e scripting (Python). |
| **[Burp Suite Community](https://portswigger.net/burp/communitydownload)** | Cross-platform | Focado em segurança. Útil também para inspeção. |
| **DevTools, Network Panel** | Browser | Built-in. Para requests do próprio browser, basta. |

### Outras ferramentas úteis

#### Inspeção de bancos

- **[DBeaver](https://dbeaver.io)**: multi-banco, open source.
- **[DataGrip](https://www.jetbrains.com/datagrip/)**: JetBrains, comercial.
- **[TablePlus](https://tableplus.com)**: UI mais leve, popular no macOS.
- **[psql](https://www.postgresql.org/docs/current/app-psql.html)**: CLI nativo do Postgres. Aprenda os atalhos (`\d`, `\df`, `\timing`).

#### Inspeção de filas/brokers

- **[Kafka UI](https://github.com/provectus/kafka-ui)**: UI web para Apache Kafka.
- **[RedisInsight](https://redis.io/insight/)**: UI oficial do Redis.

#### HTTP clients para testes manuais

- **[Insomnia](https://insomnia.rest)**: popular, open source.
- **[Bruno](https://www.usebruno.com)**: open source, salva collections como arquivos versionáveis em Git (vantagem importante vs. Postman).
- **[Postman](https://www.postman.com)**: onipresente; collections no cloud podem ser questão para alguns times.
- **[HTTPie](https://httpie.io)**: CLI elegante (`http GET httpbin.org/get`).

#### Geração de carga / load testing

- **[k6](https://k6.io)**: moderno, scripts em JavaScript, integra com CI.
- **[wrk](https://github.com/wg/wrk)**: minimalista e rápido.
- **[Vegeta](https://github.com/tsenart/vegeta)**: CLI, gera relatórios HTML/JSON.

#### Observabilidade local

- **[Grafana Tempo / Loki / Prometheus](https://grafana.com)**: stack open source para traces, logs, métricas.
- **[Jaeger](https://www.jaegertracing.io)**: UI para tracing distribuído.

## Quando *não* usar

- **Proxy MITM em redes corporativas.** Algumas redes detectam e bloqueiam. Use só na sua máquina/emulador.
- **Ferramentas pesadas para tarefas pequenas.** Para um curl rápido, `curl -v` ou DevTools já bastam, não abra Proxyman.

## Conceitos relacionados

- [Os três pilares de observabilidade](../observability/three-pillars.md), debug local complementa, não substitui, observabilidade contínua.
- [Tratamento de erros](../backend/error-handling.md), inspecionar respostas malformadas é caso de uso comum.

## Referências

- **Documentação.** [Proxyman: Overview](https://docs.proxyman.io).
- **Documentação.** [mitmproxy docs](https://docs.mitmproxy.org).
- **Artigo.** [HTTPie vs curl](https://httpie.io/cli), comparação de UX.
