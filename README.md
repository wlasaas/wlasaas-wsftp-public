# WSFTP — Guia de Implantação

WSFTP é uma solução de transferência de arquivos (SFTP, FTPS, HTTPS, WebDAV) baseada no SFTPGo, com
branding e idioma português do Brasil da WLA. Este repositório contém o necessário para **implantar nos
servidores dos clientes** (Linux Red Hat-based: RHEL, CentOS, Oracle Linux, AlmaLinux).

A imagem Docker já vem com **tudo customizado assado dentro** (branding, idioma pt, logos, favicon).
Aqui você só baixa a versão certa do registry e sobe — sem editar arquivos de configuração.

## Como a imagem é produzida (visão geral)

```
[bump FROM sftpgo:vX]  ->  release.sh  ->  ECR privado (:X + :latest)
   (repo privado WLA)      build+smoke+push          |
                                                      v
   VOCÊ (implantação):   install.sh  <-  este repo (.env: WSFTP_VERSION=X)
       (login ECR ro)    pull :X + up + healthz
```

A WLA builda e publica a imagem no ECR. Você recebe **credenciais IAM somente-leitura** para baixá-la e
implanta com o `install.sh`. Nada de imagem é compilado no servidor do cliente.

---

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

### Comandos administrativos do SFTPGo (dentro do container)

```bash
docker exec wsftp sftpgo <comando>
docker exec -it wsftp sftpgo <comando>   # quando for interativo
```

| Comando | Função |
|---------|--------|
| `resetpwd <usuário>` | Reseta a senha de um administrador |
| `ping` | Health check |
| `--version` | Versão do binário SFTPGo |
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
