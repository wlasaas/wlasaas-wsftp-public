#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Iniciando correção de permissões para SFTPGo...${NC}"

# Verifica se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Por favor, execute este script como root (sudo)${NC}"
    exit 1
fi

# Diretórios base que precisam existir
BASE_DIRECTORIES=(
    "docker"
    "docker/static"
    "docker/static/img"
    "static"
    "static/locales"
)

# Diretórios que precisam ter permissões especiais
SECURE_DIRECTORIES=(
    "docker/data"
    "docker/backups"
    "docker/db"
)

echo -e "${YELLOW}Parando o serviço...${NC}"
docker-compose down

echo -e "${YELLOW}Removendo volumes antigos...${NC}"
docker volume rm $(docker volume ls -q | grep sftpgo) 2>/dev/null || true

echo -e "${YELLOW}Criando diretórios base...${NC}"
for dir in "${BASE_DIRECTORIES[@]}"; do
    mkdir -p "$dir"
    echo -e "${GREEN}✓ Diretório $dir verificado${NC}"
done

echo -e "${YELLOW}Criando diretórios seguros...${NC}"
for dir in "${SECURE_DIRECTORIES[@]}"; do
    mkdir -p "$dir"
    echo -e "${GREEN}✓ Diretório $dir verificado${NC}"
done

# Ajusta permissões base
echo -e "${YELLOW}Ajustando permissões base...${NC}"
chown -R 1000:1000 docker
chmod -R 755 docker
find docker -type f -exec chmod 644 {} \;

# Ajusta permissões especiais para diretórios de dados
echo -e "${YELLOW}Ajustando permissões especiais...${NC}"
for dir in "${SECURE_DIRECTORIES[@]}"; do
    chown -R 1000:1000 "$dir"
    chmod 755 "$dir"
    find "$dir" -type d -exec chmod 755 {} \;
    find "$dir" -type f -exec chmod 644 {} \;
done

# Configura o banco de dados SQLite
echo -e "${YELLOW}Configurando banco de dados...${NC}"
# rm -f docker/db/sftpgo.db
# touch docker/db/sftpgo.db
chown 1000:1000 docker/db/sftpgo.db
chmod 600 docker/db/sftpgo.db

chmod -R 777 docker

echo -e "${YELLOW}Iniciando o serviço...${NC}"
docker-compose up -d

echo -e "${GREEN}Processo concluído!${NC}"
echo -e "${YELLOW}Aguarde alguns segundos para o serviço inicializar completamente.${NC}"
echo -e "${YELLOW}Verificando logs do container:${NC}"
sleep 5
docker logs sftpgo

echo -e "${GREEN}Configuração concluída!${NC}"
echo -e "${YELLOW}Tente acessar: http://localhost:8888${NC}"