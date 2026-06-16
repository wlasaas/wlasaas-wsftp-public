#!/usr/bin/env bash
#
# install.sh — instala/atualiza o WSFTP no servidor do cliente.
# Baixa a imagem personalizada do ECR (privado) e sobe via docker compose.
# À prova de falhas: aborta em qualquer erro, valida pré-requisitos e verifica a saúde no final.
#
# Uso:  sudo ./install.sh

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+] $1${NC}"; }
warn()  { echo -e "${YELLOW}[!] $1${NC}"; }
die()   { echo -e "${RED}[x] $1${NC}" >&2; exit 1; }
trap 'die "Falha na linha $LINENO. Instalação abortada."' ERR

cd "$(dirname "$0")"

# ---- Root -------------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "Rode como root (sudo ./install.sh)"

# ---- .env -------------------------------------------------------------------
if [ ! -f .env ]; then
  [ -f .env.example ] || die ".env.example não encontrado"
  cp .env.example .env
  warn ".env criado a partir do .env.example. REVISE a senha/versão/portas e rode novamente."
  exit 1
fi
set -a; . ./.env; set +a
: "${WSFTP_VERSION:?defina WSFTP_VERSION no .env}"
: "${AWS_REGION:?defina AWS_REGION no .env}"
: "${ECR_REGISTRY:?defina ECR_REGISTRY no .env}"
WSFTP_WEB_PORT="${WSFTP_WEB_PORT:-8031}"

# ---- Dependências -----------------------------------------------------------
# Instala apenas o que falta. NÃO faz "dnf update" do sistema inteiro (evita
# atualizar/reiniciar o Docker e derrubar outros containers no servidor).
install_pkg() { dnf install -y "$@" >/dev/null; }

command -v curl >/dev/null || install_pkg curl
command -v git  >/dev/null || install_pkg git

if ! command -v docker >/dev/null; then
  info "Instalando Docker..."
  dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null
  install_pkg docker-ce docker-ce-cli containerd.io
  systemctl enable --now docker
else
  info "Docker já instalado."
  systemctl is-active --quiet docker || systemctl enable --now docker
fi

# docker compose v2 (plugin) com fallback para docker-compose v1
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose >/dev/null; then
  DC="docker-compose"
else
  info "Instalando Docker Compose..."
  install_pkg docker-compose-plugin >/dev/null 2>&1 && DC="docker compose" || {
    curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    DC="docker-compose"
  }
fi
info "Usando: $DC"

command -v aws >/dev/null || { info "Instalando AWS CLI..."; install_pkg awscli; }

# ---- Credenciais AWS (read-only ECR, fornecidas pela WLA) -------------------
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  warn "Credenciais AWS não configuradas. Informe as chaves IAM read-only do ECR (fornecidas pela WLA):"
  read -r  -p "AWS Access Key ID: " aws_access_key
  read -rs -p "AWS Secret Access Key: " aws_secret_key; echo
  aws configure set aws_access_key_id "$aws_access_key"
  aws configure set aws_secret_access_key "$aws_secret_key"
  aws configure set region "$AWS_REGION"
  aws configure set output "json"
  aws sts get-caller-identity >/dev/null || die "Credenciais AWS inválidas"
fi
info "Credenciais AWS OK."

# ---- Login ECR + pull -------------------------------------------------------
info "Login no ECR ($AWS_REGION)..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

info "Baixando imagem WSFTP $WSFTP_VERSION..."
$DC pull

# ---- Diretórios de dados (perms do usuário do container: 1000:1000) ---------
mkdir -p docker/data docker/backups docker/db
chown -R 1000:1000 docker/data docker/backups docker/db

# ---- Sobe -------------------------------------------------------------------
info "Subindo o serviço..."
$DC up -d

# ---- Verificação de saúde ---------------------------------------------------
info "Verificando saúde (healthz) na porta $WSFTP_WEB_PORT..."
ok=""
for _ in $(seq 1 30); do
  if [ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$WSFTP_WEB_PORT/healthz" || true)" = "200" ]; then
    ok=1; break
  fi
  sleep 2
done
[ -n "$ok" ] || die "Serviço não respondeu healthz. Veja: $DC logs"

# ---- Resumo -----------------------------------------------------------------
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"; IP="${IP:-SEU_IP}"
echo -e "\n${GREEN}=== Instalação concluída (WSFTP $WSFTP_VERSION) ===${NC}"
echo -e "- Painel Web: http://$IP:$WSFTP_WEB_PORT"
echo -e "- SFTP:       sftp://$IP:${WSFTP_SFTP_PORT:-1222}"
echo -e "- Admin:      ${WSFTP_ADMIN_USER:-wlasaas} (senha definida no .env)"
echo -e "${YELLOW}Lembre: troque a senha padrão e configure o firewall.${NC}"
