# Infrastructure as Code

> **TL;DR.** Infraestrutura definida em arquivos versionados em Git. Mudanças passam por PR como código. Estado real "converge" para o desejado via aplicação automática. Hoje, Terraform/OpenTofu lidera; alternativas modernas (Pulumi, CDK) usam linguagens reais; GitOps (Argo, Flux) leva o modelo a Kubernetes.

## O quê

**Infrastructure as Code (IaC)** é a prática de **descrever infraestrutura em arquivos** que vivem em controle de versão, e usar ferramentas para criar/atualizar a infraestrutura real a partir desses arquivos.

```hcl
# Em vez de clicar no console AWS:
resource "aws_s3_bucket" "uploads" {
  bucket = "myapp-uploads-prod"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
```

Versionado. Revisável. Reproduzível. Auditável.

O termo foi cunhado por **Andrew Clay Shafer** e ganhou popularidade em 2010 com a explosão de cloud. Hoje é padrão em qualquer ambiente sério.

## Por quê

Antes de IaC, infraestrutura era **clicada**:

- "Como esse load balancer foi configurado?" → ninguém sabe.
- "Por que dev não bate com prod?" → drifts manuais ao longo do tempo.
- "Vamos criar staging igual a prod" → impossível.
- "O quê mudou ontem que quebrou?" → não há git log.

Com IaC:

- **Idempotência**: rodar a aplicação repetidamente leva ao mesmo estado.
- **Revisão**: mudanças passam por PR.
- **Reuso**: módulos compartilhados entre apps/ambientes.
- **Recuperação**: se o ambiente sumir, recrie do código.
- **Auditoria**: quem mudou o quê, quando.
- **Paridade dev/prod**: mesma definição, parâmetros diferentes.

> "Snowflake servers are the enemy."
> (Martin Fowler)

## Como aplicar

### Declarative vs Imperative

Duas filosofias:

#### Declarative: descreva o **estado desejado**

```hcl
# Terraform
resource "aws_instance" "web" {
  ami           = "ami-abc"
  instance_type = "t3.micro"
  tags = { Name = "web-1" }
}
```

A ferramenta calcula o que precisa fazer para chegar a esse estado. Você diz "o quê", não "como".

**Vantagens:**
- Idempotente naturalmente.
- A ferramenta detecta drift (estado real ≠ desejado).
- Sem ordem de execução manual.

**Exemplos:** Terraform/OpenTofu, CloudFormation, Pulumi (em modo declarativo), Kubernetes YAML, Helm.

#### Imperative: descreva os **passos**

```bash
aws ec2 run-instances --image-id ami-abc --instance-type t3.micro
aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=web-1
```

Você escreve script. Roda uma vez. Se rodar de novo, precisa lógica para não duplicar.

**Quando usar:**
- Scripts ad-hoc.
- Migração one-shot.
- Configuração que muda raramente e não vale o overhead.

**Default moderno: declarative.** Imperative para casos pontuais.

### Ferramentas: landscape

#### Terraform / OpenTofu

[Terraform](https://www.terraform.io) (HashiCorp) é o **mais usado**. [OpenTofu](https://opentofu.org) é o fork open source mantido pela comunidade após mudança de licença em 2023.

```hcl
# main.tf
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "uploads" {
  bucket = "myapp-uploads-${var.env}"
}

variable "env" { type = string }
output "bucket_name" { value = aws_s3_bucket.uploads.id }
```

```bash
terraform init    # baixa providers
terraform plan    # mostra o que vai fazer
terraform apply   # aplica
```

**Pontos fortes:**
- Suporte a praticamente toda cloud + serviço.
- Comunidade gigante; muitos módulos prontos.
- Stateful, sabe o que existe (`terraform.tfstate`).

**Cuidados:**
- HCL é DSL própria, não tem força de linguagem real.
- State file precisa ser **gerenciado com cuidado** (remote state em S3, locking via DynamoDB).
- Drift detection requer rodar `plan` periodicamente.

#### Pulumi / AWS CDK / CDK for Terraform

Definem infra em **linguagens de programação reais** (TypeScript, Python, Go, C#).

```ts
// Pulumi, TypeScript
import * as aws from "@pulumi/aws";

const bucket = new aws.s3.Bucket("uploads", {
  bucket: `myapp-uploads-${pulumi.getStack()}`,
});

export const bucketName = bucket.id;
```

**Vantagens:**
- Loops, condicionais, funções, força total da linguagem.
- IDE com autocomplete, tipos.
- Reuso via NPM, PyPI.

**Cuidados:**
- Pode complicar demais quando devs aplicam padrões de aplicação a infra.
- Curva de aprendizado se equipe não conhece a linguagem.

#### CloudFormation (AWS), Azure Resource Manager, Google Deployment Manager

Nativos da cloud. **Não-portáteis** entre clouds, mas integrados profundamente.

#### Ansible / Chef / Puppet: configuration management

Diferente de IaC stricto. Foca em **configurar máquinas existentes** (instalar pacotes, criar usuários, copiar arquivos), não em provisionar infra.

Em mundo de containers, perdeu protagonismo, mas ainda usado para servidores tradicionais e provisioning de VMs.

### State management: crítico no Terraform

`terraform.tfstate` é o **mapa entre código e recursos reais**. Não pode:
- Ficar em git (contém segredos).
- Ficar local (perda = perda do mapa).
- Ser editado manualmente sem cuidado.

**Solução padrão, remote state:**

```hcl
terraform {
  backend "s3" {
    bucket         = "myorg-terraform-state"
    key            = "prod/network.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"   # evita execução paralela
    encrypt        = true
  }
}
```

State no S3, lock no DynamoDB. Encryption habilitada.

### Modularização

Não escreva tudo em um arquivo. Organize:

```
infra/
├─ modules/
│  ├─ vpc/
│  │  ├─ main.tf
│  │  ├─ variables.tf
│  │  └─ outputs.tf
│  ├─ rds/
│  └─ s3-bucket/
├─ envs/
│  ├─ dev/
│  │  └─ main.tf      # usa modules + valores dev
│  ├─ staging/
│  └─ prod/
└─ global/
   └─ iam/
```

Cada módulo é reutilizável:

```hcl
module "uploads_bucket" {
  source = "../../modules/s3-bucket"
  name   = "uploads"
  env    = "prod"
  tags   = { project = "myapp" }
}
```

### Multi-environment

Estratégias:

#### Workspaces

```bash
terraform workspace new dev
terraform workspace new prod
terraform apply -var "env=prod"
```

Estados separados, código único. Funciona para infra simples.

#### Diretórios separados

```
envs/dev/main.tf
envs/prod/main.tf
```

Mais explícito. Diferença entre ambientes é **visível**.

Para sistemas grandes, **diretórios** é preferível, drift de ambiente fica evidente.

### Drift detection

**Drift** = estado real diverge do código. Causa: mudança manual no console, falha de aplicação parcial, modificação fora do Terraform.

Detecção:

```bash
terraform plan -detailed-exitcode
# exit 0: sem drift
# exit 1: erro
# exit 2: drift detectado
```

Rode no CI **periodicamente** (nightly, weekly). Alerta se drift > 0.

Ferramentas dedicadas: [driftctl](https://driftctl.com), [Spacelift](https://spacelift.io), [env0](https://www.env0.com).

### Secrets em IaC

**Nunca commitar secrets em código de infra.**

```hcl
# ❌
variable "db_password" {
  default = "supersecret123"
}

# ✅: vem do secret manager
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "prod/db-credentials"
}

resource "aws_db_instance" "main" {
  password = jsondecode(data.aws_secretsmanager_secret_version.db.secret_string).password
}
```

Ver [secrets management](../security/secrets-management.md).

### GitOps: IaC para Kubernetes

[**GitOps**](https://www.gitops.tech) leva IaC a Kubernetes: o que está em Git **É** o cluster.

```
Git repository (declarações YAML)
        ↓ pull contínuo
[Argo CD / Flux] no cluster
        ↓ aplica
   Kubernetes resources
```

**Vantagens:**
- Estado real do cluster é **sempre** o que está no Git.
- Mudanças requerem PR.
- Rollback = revert no Git.
- Audit log via git log.

**Ferramentas:**
- **[Argo CD](https://argo-cd.readthedocs.io)**: UI rica, popular.
- **[Flux](https://fluxcd.io)**: CNCF, mais minimalista.

Combina com Helm/Kustomize para templating.

### CI/CD para IaC

Pipeline típico:

```
PR:
  → terraform fmt -check   (lint)
  → terraform validate     (syntax)
  → terraform plan         (preview, posta no PR)
  → security scan (tfsec, Checkov)

Merge to main:
  → terraform apply        (auto ou manual approval)
```

Manual approval em prod é prática conservadora. Auto em ambientes lower é OK.

**Tooling:**
- [Atlantis](https://www.runatlantis.io), orquestra `plan` e `apply` via PR comments.
- [Terraform Cloud / Enterprise](https://www.hashicorp.com/products/terraform).
- [Spacelift](https://spacelift.io).
- [env0](https://www.env0.com).

### Security scanners para IaC

Análise estática de Terraform/CloudFormation/K8s YAML:

- **[tfsec](https://github.com/aquasecurity/tfsec)**: Terraform.
- **[Checkov](https://www.checkov.io)**: múltiplas IaC tools.
- **[Trivy](https://github.com/aquasecurity/trivy)**: multi-tool, inclui IaC.
- **[KICS](https://kics.io)**: Open source, multi-platform.

Pegam: buckets públicos sem intenção, security groups muito abertos, encryption desligada, etc.

### Anti-padrões

#### "ClickOps" + IaC retroativa

Time clica no console; alguém depois tenta capturar em código. Sempre divergente. Vire a regra: **só por código**.

#### State file local

Perde = recrie infra do zero. Em qualquer cenário sério, use remote state.

#### Sem locking

Dois engineers rodam `apply` simultâneo → corrupção de state. Use locking nativo (DynamoDB no AWS).

#### Mudanças manuais "rapidinhas"

"Só clico agora, depois atualizo o código." Nunca atualiza. Drift acumula.

#### Módulo gigante "godfather"

Um módulo que faz tudo. Quebre por responsabilidade (rede, compute, dados, IAM).

#### Aplicar direto em prod

Sempre passe por **plan + revisão**. Em prod, frequentemente com aprovação manual.

## Quando *não* usar

- **Recursos genuinamente one-shot** (criar usuário admin inicial, gerar uma chave). Script imperativo é OK.
- **Quando o overhead supera o benefício** (uma máquina virtual de hobby).
- **Em sistemas onde mudança manual no console é o fluxo aceito** (raríssimo em produção séria).

Em qualquer organização com mais de uma pessoa mexendo em infra, IaC é higiene.

## Conceitos relacionados

- [CI/CD](./ci-cd.md), pipeline de IaC.
- [Twelve-Factor App](./twelve-factor-app.md): V. Build, Release, Run.
- [Secrets management](../security/secrets-management.md).
- [Release strategies](./release-strategies.md), onde IaC encontra aplicação.
- [ADRs](../architecture/architecture-decision-records.md), decisões de arquitetura de infra.

## Referências

- **Livro.** Kief Morris, *Infrastructure as Code*, 2ª ed. (O'Reilly, 2020). Texto canônico moderno.
- **Livro.** Yevgeniy Brikman, *Terraform: Up & Running*, 3ª ed. (O'Reilly, 2022). Tutorial e referência prático.
- **Livro.** Sam Newman, *Building Microservices*, 2ª ed. (O'Reilly, 2021). Capítulos sobre deploy e infra.
- **Documentação.** [Terraform](https://www.terraform.io/docs).
- **Documentação.** [OpenTofu](https://opentofu.org/docs/).
- **Documentação.** [Pulumi](https://www.pulumi.com/docs/).
- **Documentação.** [Argo CD](https://argo-cd.readthedocs.io/).
- **Documentação.** [Flux](https://fluxcd.io/docs/).
- **Site.** [gitops.tech](https://www.gitops.tech). Princípios de GitOps.
- **Artigo.** Martin Fowler, ["SnowflakeServer"](https://martinfowler.com/bliki/SnowflakeServer.html). Por que servidores únicos são problema.
- **Artigo.** ThoughtWorks Tech Radar, múltiplas entradas sobre IaC tools.
