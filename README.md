# WSFTP — Guia de Implantação

WSFTP é uma solução de transferência de arquivos (SFTP, FTPS, HTTPS, WebDAV) com
branding e idioma português do Brasil da WLA. Este repositório contém o necessário para **implantar nos
servidores dos clientes** (Linux Red Hat-based: RHEL, CentOS, Oracle Linux, AlmaLinux).

A imagem Docker já vem com **tudo customizado assado dentro** (branding, idioma pt, logos, favicon).
Aqui você só baixa a versão certa do registry e sobe — sem editar arquivos de configuração.

## Requisitos

| | Mínimo | Recomendado |
|-|--------|-------------|
| SO | RHEL/CentOS/Oracle/AlmaLinux | idem |
| RAM | 2 GB | 4 GB+ |
| Disco | 20 GB | 50 GB+ |
| Acesso | root/sudo | root/sudo |

Mais: Docker 20.10+, Docker Compose v2, e **credenciais IAM read-only do ECR** (fornecidas pela WLA).
O `install.sh` instala Docker/Compose/Git/AWS CLI se faltarem.

---

## Instalação

```bash
# 1. Clonar
sudo dnf install -y git
git clone https://github.com/wlasaas/wlasaas-wsftp-public.git wsftp
cd wsftp

# 2. Configurar (versão, portas, senha)
cp .env.example .env
nano .env            # ajuste WSFTP_VERSION, portas e WSFTP_ADMIN_PASSWORD

# 3. Instalar (pede as credenciais IAM read-only do ECR na 1ª vez)
chmod +x install.sh
sudo ./install.sh
```

> Na primeira execução, se o `.env` não existir, o script o cria a partir do `.env.example` e pede para
> revisar — rode `sudo ./install.sh` de novo após ajustar.

### Acesso inicial

- Painel Web: `http://IP_DO_SERVIDOR:8031` (ou a `WSFTP_WEB_PORT` do `.env`)
- SFTP: `sftp://IP_DO_SERVIDOR:1222` (ou a `WSFTP_SFTP_PORT`)
- Admin: `wlasaas` / senha definida no `.env`

Troque a senha padrão e configure o firewall após o primeiro acesso.

---

## Comandos de linha (operação)

Rode dentro da pasta do projeto. Use `docker compose` (v2); se sua máquina só tiver o antigo, troque por
`docker-compose`.

| Ação | Comando |
|------|---------|
| Status dos containers | `docker compose ps` |
| Logs (seguir) | `docker compose logs -f` |
| Uso de recursos | `docker stats wsftp` |
| Parar | `docker compose down` |
| Iniciar | `docker compose up -d` |
| Reiniciar | `docker compose restart` |
| **Atualizar versão** | editar `WSFTP_VERSION` no `.env` → `sudo ./install.sh` (ou `docker compose pull && docker compose up -d`) |
| **Rollback** | voltar `WSFTP_VERSION` p/ a tag anterior no `.env` → `docker compose up -d` |
| Limpar imagens antigas | `docker image prune -f` |

### Backup e restore dos dados

```bash
# Backup (com o serviço parado, para consistência do SQLite)
docker compose down
tar czf wsftp-backup-$(date +%F).tgz docker/data docker/db docker/backups
docker compose up -d

# Restore
docker compose down
tar xzf wsftp-backup-AAAA-MM-DD.tgz
chown -R 1000:1000 docker/data docker/db docker/backups
docker compose up -d
```

### Comandos administrativos (dentro do container)

```bash
docker exec wsftp sftpgo <comando>
docker exec -it wsftp sftpgo <comando>   # quando for interativo
```

| Comando | Função |
|---------|--------|
| `resetpwd <usuário>` | Reseta a senha de um administrador |
| `ping` | Health check |
| `--version` | Versão do binário |
| `initprovider` | Inicializa/migra o banco |
| `revertprovider` | Reverte o provider à versão anterior |
| `acme run` | Emite certificados TLS (Let's Encrypt) |
| `smtptest` | Testa a configuração SMTP |
| `gen completion \| man` | Gera autocomplete / man pages |

Exemplos:

```bash
docker exec wsftp sftpgo ping
docker exec wsftp sftpgo resetpwd wlasaas
docker exec wsftp sftpgo --version
```

---

## Gerenciamento pelo painel

- **Personalização**: Server Manager → Configurations (nome, logo — persiste no banco).
- **Usuários**: Users → Add (obrigatórios: `Username`, `Password`, `File system Storage`).
- **Grupos**: Groups (acesso compartilhado a pastas).
- **Perfis (Roles)**: Roles (segmentação de administração).
- **Idioma**: seletor no rodapé do login → **Português (Brasil)**.

---

## Tipos de storage suportados

Cada usuário (ou pasta virtual) pode usar um storage diferente, configurado em **Users → Add → File System**.

| Tipo | Descrição |
|------|-----------|
| **Local** | Disco local do servidor — padrão, zero configuração extra |
| **Local criptografado** | Disco local com criptografia transparente em repouso |
| **S3 Compatible** | AWS S3 ou qualquer storage compatível (MinIO, Wasabi, Backblaze B2…) |
| **Google Cloud Storage** | GCS — requer Service Account JSON |
| **Azure Blob Storage** | Azure Blob — requer account name + key ou SAS |
| **SFTP remoto** | Outro servidor SFTP como backend (endpoint, usuário e senha) |
| **HTTP filesystem** | Backend via API HTTP/S customizada |

> Para a maioria dos clientes: **Local** ou **S3 Compatible**. Os demais exigem credenciais do provedor de nuvem correspondente.

---

## Mapeando diretórios reais do host para usuários

Por padrão os arquivos ficam em `docker/data/<usuário>/` (dentro da pasta do projeto).
Se quiser que cada usuário SFTP use um diretório já existente no host (ex: `/wlasaas/caio`),
são necessários dois ajustes:

### 1. Adicionar o volume no `docker-compose.yml`

```yaml
volumes:
  - ./docker/data:/srv/sftpgo/data
  - ./docker/backups:/srv/sftpgo/backups
  - ./docker/db:/var/lib/sftpgo
  - /wlasaas:/wlasaas          # ← monta a raiz dos diretórios dos usuários
```

Depois recriar o container:

```bash
docker compose up -d
```

### 2. Configurar o Root directory do usuário no painel

Em **Users → Add/Edit → File System**:
- **Storage**: `Local disk`
- **Root directory**: `/wlasaas/<usuario>` (ex: `/wlasaas/caio`)

### 3. Ajustar permissões no host

O container roda como uid `1000`. Os diretórios dos usuários no host devem ser acessíveis por esse uid:

```bash
chown -R 1000:1000 /wlasaas/caio
# ou para todos de uma vez:
chown -R 1000:1000 /wlasaas
```

> **Por que é necessário o volume?** O container enxerga apenas os paths montados via `volumes`.
> Sem o mount de `/wlasaas`, o path `/wlasaas/caio` não existe dentro do container e o login SFTP
> falha com `realpath .: no such file`.

---

## Notificações via webhook (Event Manager)

O WSFTP dispara um `POST` HTTP num endpoint seu a cada evento de arquivo (recebido, enviado, apagado…).
É **nativo** (Event Manager) — configurado no painel, sem plugin e sem rebuild. São 2 passos:

### 1. Criar a Ação — `Event Manager → Actions → Add`

- **Name**: `webhook-eventos`
- **Type**: `HTTP`
- **Server URL**: o endpoint que recebe (ex: `https://seu-endpoint/webhook`)
- **HTTP headers**: `Content-Type` = `application/json`
- **Method**: `POST`
- **Body** (placeholders são substituídos automaticamente):

```json
{
  "evento": "{{.Event}}",
  "usuario": "{{.Name}}",
  "caminho": "{{.VirtualPath}}",
  "tamanho": {{.FileSize}},
  "protocolo": "{{.Protocol}}",
  "ip": "{{.IP}}",
  "timestamp": "{{.Timestamp}}",
  "status": "{{.StatusString}}"
}
```

→ **Save**

### 2. Criar a Regra — `Event Manager → Rules → Add`

- **Name**: `regra-webhook`
- **Trigger**: `Filesystem events`
- **Fs events**: marque os que quer notificar:
  - `upload` → arquivo **recebido**
  - `download` → arquivo **enviado**
  - `delete` → arquivo **apagado**
  - (outros: `rename`, `mkdir`, `rmdir`, `copy`, `first-upload`…)
- (opcional) **Path/Protocol filters**: restringe a pastas ou protocolos específicos
- **Actions**: selecione `webhook-eventos`

→ **Save**. Pronto — a cada evento marcado, o WSFTP faz `POST` no seu URL.

### Placeholders disponíveis

`{{.Event}}` · `{{.Name}}` (usuário) · `{{.VirtualPath}}` · `{{.FsPath}}` · `{{.ObjectName}}` ·
`{{.FileSize}}` · `{{.Protocol}}` · `{{.IP}}` · `{{.Timestamp}}` · `{{.StatusString}}` (`OK`/`KO`).

### Observações

- **Assíncrono por padrão** (não atrasa a transferência). Para validar **antes** (eventos `pre-upload`,
  `pre-delete`), marque **Synchronous execution** na ação dentro da regra.
- Tudo persiste no banco do WSFTP — vale por servidor, não precisa rebuild da imagem.
- **Testar**: faça um upload (ver seção abaixo) e confira a chamada no seu endpoint; erros aparecem em
  `docker compose logs -f`.

---

## Testar envio via SFTP

Crie um usuário no painel (Users → Add) e teste a transferência. Substitua `IP`, a porta
(`WSFTP_SFTP_PORT`, padrão `1222`) e o usuário pelos seus.

### 1. Cliente `sftp` (interativo)

```bash
sftp -P 1222 USUARIO@IP_DO_SERVIDOR
# senha quando pedir
sftp> put /caminho/local/arquivo.txt    # envia
sftp> ls -l                             # confere no servidor
sftp> get arquivo.txt baixado.txt       # baixa de volta
sftp> bye
```

### 2. Batch (não-interativo, ex: validação rápida)

```bash
echo "teste $(date)" > /tmp/teste.txt
sftp -P 1222 USUARIO@IP_DO_SERVIDOR <<'EOF'
put /tmp/teste.txt
ls -l
bye
EOF
```

### 3. Roundtrip automatizado com senha (sshpass)

Faz upload + download + compara — útil para um smoke test de transferência:

```bash
echo "wsftp smoke $(date)" > /tmp/up.txt
SSHPASS='SENHA' sshpass -e \
  sftp -P 1222 -oStrictHostKeyChecking=no -oPreferredAuthentications=password \
  USUARIO@IP_DO_SERVIDOR <<'EOF'
put /tmp/up.txt
get up.txt /tmp/down.txt
bye
EOF
diff /tmp/up.txt /tmp/down.txt && echo "OK: upload/download íntegros"
```

> `sshpass` só para automação/teste. No uso normal prefira digitar a senha ou usar chave pública.

### 4. Via `scp`

```bash
scp -P 1222 /caminho/local/arquivo.txt USUARIO@IP_DO_SERVIDOR:/    # envia
scp -P 1222 USUARIO@IP_DO_SERVIDOR:/arquivo.txt ./                 # baixa
```

### 5. Cliente gráfico (FileZilla, WinSCP)

- Protocolo: **SFTP - SSH File Transfer Protocol**
- Host: `IP_DO_SERVIDOR` · Porta: `1222` (ou a sua `WSFTP_SFTP_PORT`)
- Usuário/senha: os do usuário criado no painel

> Os arquivos enviados ficam em `docker/data/<usuário>/` no servidor.

---

## Troubleshooting

| Sintoma | Causa provável / solução |
|---------|--------------------------|
| `healthz` não responde 200 | Ver `docker compose logs -f`. Porta web ocupada? Ajuste `WSFTP_WEB_PORT` no `.env`. |
| Falha no login do ECR | Credenciais IAM inválidas/expiradas. Rode `aws sts get-caller-identity`. Peça novas chaves à WLA. |
| `port is already allocated` | Outra aplicação usa a porta. Troque `WSFTP_WEB_PORT`/`WSFTP_SFTP_PORT` no `.env` e `docker compose up -d`. |
| Permissão negada em `docker/data` | `chown -R 1000:1000 docker/data docker/db docker/backups`. |
| Mudou a versão e não atualizou | `docker compose pull` antes do `up -d`; confira `WSFTP_VERSION` no `.env`. |
| Esqueceu a senha do admin | `docker exec wsftp sftpgo resetpwd <usuário>`. |

---

## Atualização — passo a passo seguro

```bash
# 1. Backup
docker compose down
tar czf wsftp-backup-$(date +%F).tgz docker/data docker/db docker/backups

# 2. Fixar a nova versão
nano .env            # WSFTP_VERSION=<nova>

# 3. Baixar e subir
sudo ./install.sh    # faz login no ECR, pull e up com verificação de saúde

# 4. Conferir
docker compose ps
docker exec wsftp sftpgo --version
```

Problema? **Rollback**: volte `WSFTP_VERSION` para a tag anterior no `.env` e `docker compose up -d`.
