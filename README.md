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

### 1. Instalar Git

```bash
sudo dnf install -y git
```

---

### 2. Clonar o Projeto WSFTP

```bash
git clone https://github.com/wlasaas/wlasaas-wsftp-public.git wlasaas-wsftp
```

---

### 3. Configurar docker-compose.yml

Caso queira editar as portas WEB e SFTP edit arquivo \`docker-compose.yml\`

---

### 4. Iniciar o WSFTP

```bash
# acessar pasta
cd wlasaas-wsftp-public
# iniciar instalação
sudo sh ./install.sh

```

---

### 5. Acesso Inicial

- Painel web: \`http://IP_DO_SERVIDOR:PORTA\` (8031 ou a porta definida no docker-compose.yml)
- Acesso SFTP: \`sftp://IP_DO_SERVIDOR:PORTA\` (ex: FileZilla) (1222 ou porta definida no docker-compose.yml)
- Usuário/senha padrão: \`wlasaas / wlasaas\`

---

### 6. Customizações e Gerenciamento

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

### 7. Logs e Monitoramento

```bash
# Ver status
docker-compose ps

# Logs
docker-compose logs -f

# Recursos
docker stats
```
