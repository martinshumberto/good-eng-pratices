# Secrets Management

> **TL;DR.** Secrets **nunca** ficam em código-fonte, em `.env` versionado ou em logs. Use um *secret manager* (Vault, AWS SM, GCP SM, Doppler), injete em runtime, rotacione regularmente, audite acessos. Senhas vazadas custam caro.

## O quê

**Secrets** são valores que dão acesso a recursos críticos:

- Senhas de banco.
- API keys (Stripe, AWS, SendGrid).
- Tokens de autenticação inter-service.
- Chaves de criptografia.
- Certificados privados.
- Credenciais OAuth.

**Secrets management** é a disciplina de **armazenar, distribuir, rotacionar e auditar** esses valores ao longo do ciclo de vida do sistema.

## Por quê

Secrets vazados são uma das **vias mais comuns** para incidentes graves:

- **Repos públicos no GitHub** vazam diariamente milhares de tokens AWS, Stripe, etc.
- **Logs em sistemas centrais** ficam visíveis a equipes inteiras.
- **CI/CD logs** com variáveis impressas viram porta de entrada.
- **Dumps de banco** com cópias de configuração.
- **Backups antigos** com senhas obsoletas mas ainda válidas.

A categoria **A02, Cryptographic Failures** do [OWASP Top 10](./owasp-top-10.md) cobre boa parte disso.

> "The most common mistake is hard-coding secrets into source code."
> (GitHub Secret Scanning report (2023))

## Como aplicar

### Princípios fundamentais

#### Nunca em código-fonte

```ts
// ❌ Worst case
const STRIPE_KEY = 'sk_live_4eC39HqLyjWDarjtT1zdp7dc';

// ❌ Comum: env hardcoded
process.env.STRIPE_KEY = 'sk_live_...';

// ✅ Lê do ambiente, sem default em prod
const STRIPE_KEY = process.env.STRIPE_KEY;
if (!STRIPE_KEY) throw new Error('STRIPE_KEY not set');
```

#### Nunca em logs

Bibliotecas devem ter **redação automática**. Ver [structured logging](../observability/structured-logging.md).

```ts
const logger = pino({
  redact: {
    paths: [
      'req.headers.authorization',
      'req.headers.cookie',
      'req.body.password',
      'req.body.token',
      'req.body.cardNumber',
      '*.apiKey',
    ],
    censor: '[REDACTED]',
  },
});
```

#### Nunca em PR / commit / CI logs

```bash
# ❌ Vaza em log do CI
- run: echo "Deploying with key $STRIPE_KEY"

# ✅
- run: ./deploy.sh
  env:
    STRIPE_KEY: ${{ secrets.STRIPE_KEY }}
```

GitHub Actions mascara secrets automaticamente, mas só os que foram **registrados como secret**. Não imprima em texto.

#### Princípio do mínimo necessário

- **Cada serviço tem suas próprias credenciais**: sem compartilhar token entre serviços.
- **Cada ambiente tem suas próprias credenciais**: dev ≠ staging ≠ prod.
- **Cada role tem o escopo mínimo**: token de leitura para serviço que só lê.

### Onde guardar: vault central

Em produção, use um **secret manager dedicado**:

| Ferramenta | Notas |
|---|---|
| **[HashiCorp Vault](https://www.vaultproject.io)** | Veterano, open source, on-prem ou managed. Dynamic secrets. |
| **AWS Secrets Manager** | Native AWS. Rotação automática para RDS, Redshift, DocumentDB. |
| **GCP Secret Manager** | Native GCP. Simples e barato. |
| **Azure Key Vault** | Native Azure. |
| **[Doppler](https://www.doppler.com)** | SaaS focado em DX. Sync para múltiplos destinos. |
| **[1Password Secrets Automation](https://1password.com/secrets-automation)** | Para times que já usam 1Password. |
| **[Infisical](https://infisical.com)** | Open source moderno. |

### Como distribuir: injetar em runtime

**Não copie secrets para máquina/container.** Injete em runtime:

#### Variáveis de ambiente

Padrão histórico. Funcional, mas tem riscos:

- Aparece em `ps`/`/proc/<pid>/environ`.
- Frequentemente em dumps de configuração.

```yaml
# Kubernetes via Secret
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: database-url
```

#### Arquivos secret

Em vez de env, monte como arquivo:

```yaml
volumeMounts:
- name: secrets
  mountPath: /run/secrets
  readOnly: true
volumes:
- name: secrets
  secret:
    secretName: app-secrets
```

App lê `fs.readFileSync('/run/secrets/database-url', 'utf8')`. Menos exposição em `env`.

#### SDKs do secret manager

App **busca em runtime**:

```ts
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

async function getSecret(id: string): Promise<string> {
  const client = new SecretsManagerClient({});
  const result = await client.send(new GetSecretValueCommand({ SecretId: id }));
  return result.SecretString!;
}

const dbUrl = await getSecret('prod/db-url');
```

Vantagens: rotação trivial, audit nativo. Custo: ~10ms a cada boot do app.

#### CSI Driver (Kubernetes)

[Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io) busca secrets do vault e monta como arquivo. App não precisa de SDK.

### Como versionar configuração: sem expor secrets

Você quer versionar **estrutura** (que secrets existem, onde estão referenciados) sem versionar **valor**.

#### SOPS: encrypted secrets in Git

[Mozilla SOPS](https://github.com/getsops/sops) criptografa apenas os **valores**, mantendo as chaves visíveis para diff:

```yaml
# secrets.enc.yaml (committed to git)
database:
    url: ENC[AES256_GCM,data:abc...,iv:def...,tag:ghi...]
    password: ENC[AES256_GCM,data:...,iv:...,tag:...]
```

Decriptação requer chave (KMS, age, GPG). Permite versionar config sem vazar secret.

Ferramentas que combinam com SOPS: [Helm Secrets](https://github.com/jkroepke/helm-secrets), [Flux](https://fluxcd.io).

#### sealed-secrets

[Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets), alternativa para Kubernetes. Você criptografa offline; só o controller in-cluster consegue decriptar.

#### age / direnv

Para dev local: [age](https://github.com/FiloSottile/age) (sucessor moderno do GPG) + [direnv](https://direnv.net), carrega `.envrc` ao entrar na pasta, valores decriptados sob demanda.

### Rotação

Secrets devem **expirar** e **ser substituídos** periodicamente. Sem rotação:

- Vazamento antigo continua válido indefinidamente.
- Ex-funcionários têm chaves após saída.
- Compromisso de uma única chave compromete tudo.

#### Estratégias

- **Rotação automática**: AWS Secrets Manager rotaciona RDS sozinho. Vault tem dynamic secrets.
- **Rotação manual programada**: quarterly para secrets críticos.
- **Rotação por evento**: após incidente, após saída de membro.

#### Overlap de validade

Para evitar downtime, **ambas as chaves** funcionam durante a janela de rotação:

```
T0:   Chave A válida
T0:   Chave B criada, também válida
T1:   App passa a usar B (deploy)
T2:   Chave A revogada
```

### Detection: git secret scanning

Mesmo com disciplina, secrets vazam. Use scanners:

| Tool | Notas |
|---|---|
| **[gitleaks](https://github.com/gitleaks/gitleaks)** | OSS, pre-commit hook + CI. |
| **[git-secrets](https://github.com/awslabs/git-secrets)** | AWS Labs. |
| **GitHub Secret Scanning** | Nativo no GitHub. Encontra automaticamente em repos públicos. |
| **TruffleHog** | Encontra entropy-high strings em histórico. |
| **Snyk**, **GitGuardian**, **Mend** | SaaS dedicados. |

**Pre-commit hook** com gitleaks pega problemas antes do push. Não é à prova de bala, mas reduz drasticamente.

### Quando secret vaza: incidente

Plano de resposta:

1. **Revogar imediatamente** o secret comprometido.
2. **Rotacionar** para nova credencial.
3. **Identificar exposição**: onde apareceu? Por quanto tempo?
4. **Auditar uso**: quem acessou usando essa credencial? Houve abuso?
5. **Postmortem**: como o vazamento aconteceu? Como prevenir?

`git reset/rebase` ou `BFG Repo-Cleaner` **não bastam**: se o repo foi público, assuma que o secret foi capturado. Rotacione sempre.

### Boas práticas operacionais

#### Audit log

Quem acessou qual secret, quando, de onde. Vaults modernos têm audit log nativo. Conecte ao SIEM.

#### Princípio "secret-less" quando possível

Algumas autenticações **substituem secrets por identidade**:

- **AWS IAM Role** para EC2/EKS, sem precisar de API key.
- **Workload Identity** no GKE, pod assume role do GCP.
- **OIDC entre GitHub Actions e cloud**: token efêmero, sem secret.

Sempre prefira identidade sobre secret quando o cloud suporta.

#### Dev local

Para desenvolvimento local, ofereça:

- `.env.example` versionado (sem valores reais).
- Script que **gera** secrets locais (não compartilha com prod).
- Doppler / Vault em modo dev integrado.

#### Configuração consciente de ambiente

```ts
function loadConfig() {
  const env = process.env.NODE_ENV;

  if (env === 'production' && process.env.DATABASE_URL?.includes('localhost')) {
    throw new Error('Refuse to run production with localhost DATABASE_URL');
  }

  // ... etc
}
```

### Cuidados

- **Secret em URL**: query strings vão para logs de proxy, CDN, etc. Evite.
- **Secret em payload de request**: log do servidor pode capturar.
- **Secret transmitido sem TLS**: ouvido na rede.
- **Secret em dump de produção para dev**: dev tem cópia indevida.

## Quando *não* usar

- **Aplicações sem segredos.** Não invente vault para um script que não precisa.
- **Dev local trivial**: `.env.local` ignorado por gitignore (com secrets falsos) é prática aceitável aqui.
- **Quando o vault vira gargalo**: vault central caído derruba toda a app. Tenha fallback ou cache de TTL curto.

## Conceitos relacionados

- [OWASP Top 10: A02](./owasp-top-10.md)
- [Autenticação e autorização](../backend/authentication-authorization.md)
- [Twelve-Factor App: III. Config](../delivery/twelve-factor-app.md)
- [Structured logging](../observability/structured-logging.md), redação de secrets em logs.

## Referências

- **Site.** [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html). Referência completa.
- **Documentação.** [HashiCorp Vault](https://developer.hashicorp.com/vault/docs).
- **Documentação.** [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html).
- **Documentação.** [GCP Secret Manager](https://cloud.google.com/secret-manager/docs).
- **Documentação.** [SOPS](https://github.com/getsops/sops). Mozilla.
- **Documentação.** [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets). Bitnami.
- **Documentação.** [gitleaks](https://github.com/gitleaks/gitleaks).
- **Spec.** [SLSA Framework](https://slsa.dev). Supply chain security mais amplo.
- **Artigo.** GitHub, ["Keeping your API credentials secure"](https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning).
- **Artigo.** Doppler, ["The Definitive Guide to Secrets Management"](https://www.doppler.com/blog/the-definitive-guide-to-secrets-management).
