# Guia de Implantação do WSFTP (Red Hat-based)

Este documento fornece um guia passo a passo para implantar o WSFTP — uma solução robusta de transferência de arquivos que suporta SFTP, FTPS, HTTPS e WebDAV — em um servidor Linux com base em Red Hat (RHEL, CentOS, Oracle Linux, AlmaLinux, etc) usando Docker e Docker Compose.

## Requisitos do Sistema

### Requisitos Mínimos
- Sistema operacional: RedHat, CentOS, Oracle Linux, AlmaLinux, etc
- Docker: versão 20.10 ou superior
- Docker Compose: versão 2.0 ou superior
- Acesso root ou sudo
- 2GB de RAM
- 20GB de espaço em disco

### Requisitos Recomendados
- 4GB de RAM ou mais
- 50GB de espaço em disco
- Processador com 2 núcleos ou mais
- Conexão de internet estável

---

## Instalação

### 1. Preparação do Ambiente

```bash
# Atualizar pacotes
sudo dnf update -y

# Instalar dependências básicas
sudo dnf install -y yum-utils device-mapper-persistent-data lvm2 curl
```

### 2. Instalar Docker e Docker Compose

```bash
# Adicionar repositório Docker
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Instalar Docker
sudo dnf install -y docker-ce docker-ce-cli containerd.io

# Iniciar e habilitar Docker
sudo systemctl enable --now docker
```

#### Docker Compose

```bash
# Baixar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Dar permissão de execução
sudo chmod +x /usr/local/bin/docker-compose

# Verificar versão
docker-compose --version
```

### 3. Instalar Git

```bash
# Instalar Git
sudo dnf install -y git

# Verificar a versão instalada
git --version
```

### 4. Instalar AWS Cli

```bash
# Instalar Git
sudo dnf install -y awscli

# Verificar a versão instalada
aws --version
```

### 4.1. Login no AWS Cli

```bash
aws configure
# Sera necesario informar o Access Key ID e Secret Access Key
```

### 4.2. Login no AWS ECR

```bash
aws ecr get-login-password --region sa-east-1 | docker login --username AWS --password-stdin 091448068257.dkr.ecr.sa-east-1.amazonaws.com
```

### 4.3. Baixar a imagem docker

```bash
docker pull 091448068257.dkr.ecr.sa-east-1.amazonaws.com/wlasaas/wsftp:latest
docker tag 091448068257.dkr.ecr.sa-east-1.amazonaws.com/wlasaas/wsftp:latest wlasaas/wsftp-wla:latest
```

---

### 5. Clonar o Projeto WSFTP

```bash
git clone https://github.com/wlasaas/wlasaas-wsftp-public.git wlasaas-wsftp
```

---

### 6. Configurar docker-compose.yml

Edite o arquivo \`docker-compose.yml\` para ajustar:

- Portas da interface web e do SFTP
- Usuário e senha do admin (por padrão \`wlasaas/wlasaas\`)

---

### 7. Iniciar o WSFTP

```bash
# Corrigir permissões
sudo sh ./fix-permissions.sh

# Subir o serviço
docker-compose up -d
```

---

### 8. Acesso Inicial

- Painel web: \`http://IP_DO_SERVIDOR:PORTA\` (porta definida no docker-compose.yml)
- Acesso SFTP: \`sftp://IP_DO_SERVIDOR:PORTA\` (ex: FileZilla) (porta definida no docker-compose.yml)
- Usuário/senha padrão: \`wlasaas / wlasaas\`

---

### 9. Customizações e Gerenciamento

#### 1. Personalização da Interface

Painel: **Server manager > Configurations**
- Altere nome e logo

#### 2. Gerenciamento de Usuários

Painel: **Users > Add**
- Campos obrigatórios: \`Username\`, \`Password\`, \`File system Storage\`
- File system Storage do tipo SFTP exige:
  - \`Endpoint\` (IP e porta)
  - \`Username\`, \`Password\`
  - (opcional) \`SFTP root directory\`

#### 3. Grupos

Em **Groups** você cria grupos de usuários com acesso compartilhado a pastas específicas.

#### 4. Perfis (Roles)

Em **Roles**, defina escopos de administração para segmentar o controle entre administradores diferentes.

---

### 10. Logs e Monitoramento

```bash
# Ver status
docker-compose ps

# Logs
docker-compose logs -f

# Recursos
docker stats
```
