# Ansible End-to-End Setup Guide for DevSecOps Tools Installation

## Complete Automated Infrastructure Provisioning with Ansible

This guide covers automating the installation of all DevSecOps tools using Ansible for consistent, repeatable deployments.

---

## 📋 Prerequisites

### System Requirements
- **Control Node** (where Ansible runs):
  - macOS 10.15+ or Linux
  - Python 3.8+
  - Homebrew or apt
  
- **Managed Nodes** (target servers):
  - Linux (Ubuntu 20.04 LTS, CentOS 8, RHEL 8+)
  - SSH access enabled
  - Sudo privileges (passwordless preferred)
  - Internet connectivity

### Required Tools on Control Node
- [ ] Ansible 2.9+ installed
- [ ] SSH client
- [ ] Python 3.8+
- [ ] Git
- [ ] jinja2 templating

---

## 1️⃣ Install Ansible on Control Node

### macOS Installation

```bash
# Using Homebrew
brew install ansible

# Verify installation
ansible --version
# Output: ansible [core 2.13.0] or higher

ansible-inventory --version

# Install additional Python packages
pip3 install --upgrade pip
pip3 install jinja2 pyyaml netaddr dnspython
```

### Linux Installation (Ubuntu)

```bash
# Add Ansible PPA
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible

# Install Ansible
sudo apt install -y ansible

# Verify
ansible --version
```

### Linux Installation (CentOS/RHEL)

```bash
# Using EPEL repository
sudo yum install -y epel-release
sudo yum install -y ansible

# Or using pip3
sudo yum install -y python3-pip
sudo pip3 install ansible

# Verify
ansible --version
```

---

## 2️⃣ Setup SSH Key Authentication

### Generate SSH Keys on Control Node

```bash
# Generate RSA key (if not already exists)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ansible_rsa -N ""

# Verify key was created
ls -la ~/.ssh/ansible_rsa*
# Output:
# ansible_rsa (private key)
# ansible_rsa.pub (public key)
```

### Deploy Public Key to Managed Nodes

```bash
# Method 1: Using ssh-copy-id (recommended)
ssh-copy-id -i ~/.ssh/ansible_rsa.pub -p 22 ubuntu@192.168.1.10
ssh-copy-id -i ~/.ssh/ansible_rsa.pub -p 22 ubuntu@192.168.1.11
ssh-copy-id -i ~/.ssh/ansible_rsa.pub -p 22 ubuntu@192.168.1.12

# Method 2: Manual deployment
cat ~/.ssh/ansible_rsa.pub | \
  ssh -p 22 ubuntu@192.168.1.10 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"

# Test SSH connection without password
ssh -i ~/.ssh/ansible_rsa ubuntu@192.168.1.10
# Should login without prompting for password
```

### Configure Ansible SSH Settings

```bash
# Create SSH config file
cat > ~/.ssh/config << 'EOF'
Host ansible_hosts
  StrictHostKeyChecking=no
  UserKnownHostsFile=/dev/null
  IdentityFile ~/.ssh/ansible_rsa
  User ubuntu
  Port 22
EOF

chmod 600 ~/.ssh/config
```

---

## 3️⃣ Create Ansible Inventory

### Inventory File Structure

```bash
# Create directory for Ansible playbooks
mkdir -p ~/ansible-devops-setup
cd ~/ansible-devops-setup

# Create inventory directory
mkdir -p inventory

# Create inventory file
cat > inventory/hosts.ini << 'EOF'
# All hosts in one group
[all_servers]
dev-server-1     ansible_host=192.168.1.10 ansible_user=ubuntu ansible_port=22
dev-server-2     ansible_host=192.168.1.11 ansible_user=ubuntu ansible_port=22
staging-server   ansible_host=192.168.1.12 ansible_user=ubuntu ansible_port=22
prod-server-1    ansible_host=192.168.1.13 ansible_user=ubuntu ansible_port=22
prod-server-2    ansible_host=192.168.1.14 ansible_user=ubuntu ansible_port=22

# Group by environment
[dev]
dev-server-1
dev-server-2

[staging]
staging-server

[prod]
prod-server-1
prod-server-2

# Group by tool/role
[docker_hosts]
dev-server-1
dev-server-2
staging-server
prod-server-1
prod-server-2

[sonarqube_servers]
staging-server
prod-server-1
prod-server-2

[database_servers]
staging-server
prod-server-1
prod-server-2

[kubernetes_masters]
prod-server-1

[kubernetes_workers]
prod-server-2

# Variables for all hosts
[all:vars]
ansible_private_key_file=~/.ssh/ansible_rsa
ansible_ssh_extra_args="-o StrictHostKeyChecking=no"
ansible_python_interpreter=/usr/bin/python3

# Common variables
docker_version=24.0
kubernetes_version=1.28
sonarqube_version=10.2
postgresql_version=13
EOF

# Create YAML inventory (alternative format)
cat > inventory/hosts.yaml << 'EOF'
all:
  children:
    dev:
      hosts:
        dev-server-1:
          ansible_host: 192.168.1.10
          ansible_user: ubuntu
        dev-server-2:
          ansible_host: 192.168.1.11
          ansible_user: ubuntu
    
    staging:
      hosts:
        staging-server:
          ansible_host: 192.168.1.12
          ansible_user: ubuntu
    
    prod:
      hosts:
        prod-server-1:
          ansible_host: 192.168.1.13
          ansible_user: ubuntu
        prod-server-2:
          ansible_host: 192.168.1.14
          ansible_user: ubuntu
  
  vars:
    ansible_connection: ssh
    ansible_python_interpreter: /usr/bin/python3
    ansible_private_key_file: ~/.ssh/ansible_rsa
EOF

# Test inventory
ansible-inventory -i inventory/hosts.ini --list
ansible-inventory -i inventory/hosts.yaml --list
```

### Verify Connectivity

```bash
# Test ping to all hosts
ansible all -i inventory/hosts.ini -m ping
# Expected output:
# dev-server-1 | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }

# Test specific group
ansible docker_hosts -i inventory/hosts.ini -m ping

# Test with become (sudo)
ansible all -i inventory/hosts.ini -m shell -a "whoami" --become

# Check OS info
ansible all -i inventory/hosts.ini -m setup -a "filter=ansible_os_family"
```

---

## 4️⃣ Create Ansible Playbooks

### Directory Structure

```bash
cd ~/ansible-devops-setup

# Create directory structure
mkdir -p {roles,playbooks,vars,templates,files}

# Structure:
# ansible-devops-setup/
# ├── inventory/
# │   ├── hosts.ini
# │   └── hosts.yaml
# ├── roles/
# │   ├── common/
# │   ├── docker/
# │   ├── kubernetes/
# │   ├── azure-cli/
# │   ├── sonarqube/
# │   ├── snyk/
# │   └── postgresql/
# ├── playbooks/
# │   ├── site.yml
# │   ├── docker.yml
# │   ├── kubernetes.yml
# │   └── sonarqube.yml
# ├── vars/
# │   ├── common.yml
# │   ├── dev.yml
# │   ├── staging.yml
# │   └── prod.yml
# ├── templates/
# │   └── (configuration templates)
# ├── files/
# │   └── (static files)
# └── ansible.cfg
```

### Create ansible.cfg

```bash
cat > ansible.cfg << 'EOF'
[defaults]
inventory = inventory/hosts.ini
roles_path = roles
host_key_checking = False
force_color = True
timeout = 30
retry_files_enabled = False
log_path = ansible.log

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
control_path = /tmp/ansible-ssh-%%h-%%p-%%r
EOF

chmod 644 ansible.cfg
```

---

## 5️⃣ Create Ansible Roles

### Role: Common (Base Tools)

```bash
# Create role directory
mkdir -p roles/common/{tasks,templates,files,vars,defaults}

# Create tasks
cat > roles/common/tasks/main.yml << 'EOF'
---
- name: Update system packages
  apt:
    update_cache: yes
    upgrade: dist
  when: ansible_os_family == "Debian"
  become: yes

- name: Install basic tools
  apt:
    name:
      - curl
      - wget
      - git
      - vim
      - htop
      - net-tools
      - jq
      - zip
      - unzip
      - software-properties-common
      - apt-transport-https
      - ca-certificates
      - gnupg
      - lsb-release
      - sudo
    state: present
  become: yes
  when: ansible_os_family == "Debian"

- name: Install basic tools (RedHat)
  yum:
    name:
      - curl
      - wget
      - git
      - vim
      - htop
      - net-tools
      - jq
      - zip
      - unzip
      - epel-release
    state: present
  become: yes
  when: ansible_os_family == "RedHat"

- name: Create non-root user for Ansible operations
  user:
    name: "{{ ansible_user }}"
    shell: /bin/bash
    createhome: yes
    generate_ssh_key: yes
    ssh_key_type: rsa
  become: yes

- name: Add user to sudoers (passwordless)
  lineinfile:
    path: /etc/sudoers
    state: present
    line: "{{ ansible_user }} ALL=(ALL) NOPASSWD: ALL"
    validate: 'visudo -cf %s'
  become: yes

- name: Set timezone to UTC
  timezone:
    name: UTC
  become: yes

- name: Configure sysctl for Docker/Kubernetes
  sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    sysctl_set: yes
    state: present
  with_dict:
    vm.max_map_count: 262144
    net.bridge.bridge-nf-call-iptables: 1
    net.bridge.bridge-nf-call-ip6tables: 1
    net.ipv4.ip_forward: 1
  become: yes

- name: Create required directories
  file:
    path: "{{ item }}"
    state: directory
    mode: '0755'
  loop:
    - /opt/ansible
    - /opt/tools
    - /data/docker-volumes
    - /data/backups
  become: yes

- name: Set ulimits for services
  lineinfile:
    path: /etc/security/limits.conf
    line: "{{ item }}"
    state: present
  loop:
    - "* soft nofile 65536"
    - "* hard nofile 65536"
    - "* soft nproc 65536"
    - "* hard nproc 65536"
  become: yes
EOF

# Create defaults
cat > roles/common/defaults/main.yml << 'EOF'
---
ansible_user: ubuntu
timezone: UTC
system_update: true
EOF
```

### Role: Docker

```bash
mkdir -p roles/docker/{tasks,templates,files,vars,defaults}

cat > roles/docker/tasks/main.yml << 'EOF'
---
- name: Remove old Docker versions
  apt:
    name:
      - docker
      - docker.io
      - docker-engine
    state: absent
  become: yes
  when: ansible_os_family == "Debian"

- name: Add Docker GPG key
  apt_key:
    url: https://download.docker.com/linux/ubuntu/gpg
    state: present
  become: yes
  when: ansible_os_family == "Debian"

- name: Add Docker repository
  apt_repository:
    repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
    state: present
  become: yes
  when: ansible_os_family == "Debian"

- name: Install Docker packages
  apt:
    name:
      - docker-ce
      - docker-ce-cli
      - containerd.io
      - docker-compose-plugin
    state: present
    update_cache: yes
  become: yes
  when: ansible_os_family == "Debian"

- name: Install Docker Compose (standalone)
  shell: |
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  become: yes
  args:
    creates: /usr/local/bin/docker-compose

- name: Start Docker service
  systemd:
    name: docker
    state: started
    enabled: yes
  become: yes

- name: Add user to docker group
  user:
    name: "{{ ansible_user }}"
    groups: docker
    append: yes
  become: yes

- name: Configure Docker daemon
  template:
    src: docker-daemon.json.j2
    dest: /etc/docker/daemon.json
  become: yes
  notify: restart docker

- name: Create docker-compose directory
  file:
    path: /opt/docker-compose
    state: directory
    mode: '0755'
  become: yes

- name: Verify Docker installation
  shell: docker --version
  register: docker_version
  changed_when: false

- name: Display Docker version
  debug:
    msg: "Docker installed: {{ docker_version.stdout }}"
EOF

cat > roles/docker/defaults/main.yml << 'EOF'
---
docker_daemon_json:
  debug: false
  storage-driver: overlay2
  log-driver: json-file
  log-opts:
    max-size: "10m"
    max-file: "3"
  userland-proxy: false
EOF

cat > roles/docker/templates/docker-daemon.json.j2 << 'EOF'
{
  "debug": {{ docker_daemon_json.debug | lower }},
  "storage-driver": "{{ docker_daemon_json['storage-driver'] }}",
  "log-driver": "{{ docker_daemon_json['log-driver'] }}",
  "log-opts": {
    "max-size": "{{ docker_daemon_json['log-opts']['max-size'] }}",
    "max-file": "{{ docker_daemon_json['log-opts']['max-file'] }}"
  },
  "userland-proxy": {{ docker_daemon_json['userland-proxy'] | lower }}
}
EOF

cat > roles/docker/handlers/main.yml << 'EOF'
---
- name: restart docker
  systemd:
    name: docker
    state: restarted
    daemon_reload: yes
  become: yes
EOF
```

### Role: Azure CLI

```bash
mkdir -p roles/azure-cli/{tasks,templates,files,vars,defaults}

cat > roles/azure-cli/tasks/main.yml << 'EOF'
---
- name: Add Microsoft repository (Ubuntu)
  shell: |
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  args:
    creates: /usr/bin/az
  become: yes
  when: ansible_os_family == "Debian"

- name: Install Azure CLI (RedHat)
  yum:
    name: azure-cli
    state: present
  become: yes
  when: ansible_os_family == "RedHat"

- name: Verify Azure CLI installation
  shell: az --version
  register: azure_cli_version
  changed_when: false

- name: Display Azure CLI version
  debug:
    msg: "Azure CLI installed: {{ azure_cli_version.stdout_lines[0] }}"

- name: Create Azure CLI config directory
  file:
    path: /home/{{ ansible_user }}/.azure
    state: directory
    mode: '0755'
    owner: "{{ ansible_user }}"
    group: "{{ ansible_user }}"

- name: Add Azure CLI extensions
  shell: |
    az extension add --name aks-preview
    az extension add --name azure-devops
  environment:
    AZURE_SKIP_TOOLS_DEPENDENCY_INSTALL: 1
  become_user: "{{ ansible_user }}"
  ignore_errors: yes
EOF

cat > roles/azure-cli/defaults/main.yml << 'EOF'
---
azure_subscription_id: ""
azure_resource_group: ""
EOF
```

### Role: kubectl (Kubernetes)

```bash
mkdir -p roles/kubernetes/{tasks,templates,files,vars,defaults}

cat > roles/kubernetes/tasks/main.yml << 'EOF'
---
- name: Download kubectl
  shell: |
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
  args:
    creates: /usr/local/bin/kubectl
  become: yes

- name: Verify kubectl installation
  shell: kubectl version --client
  register: kubectl_version
  changed_when: false

- name: Display kubectl version
  debug:
    msg: "kubectl installed: {{ kubectl_version.stdout_lines[0] }}"

- name: Install kubectl completion
  shell: |
    kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
  become: yes

- name: Create .kube directory
  file:
    path: /home/{{ ansible_user }}/.kube
    state: directory
    mode: '0755'
    owner: "{{ ansible_user }}"
    group: "{{ ansible_user }}"

- name: Download and install Helm
  shell: |
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  args:
    creates: /usr/local/bin/helm
  become: yes

- name: Verify Helm installation
  shell: helm version
  register: helm_version
  changed_when: false

- name: Display Helm version
  debug:
    msg: "Helm installed: {{ helm_version.stdout_lines[0] }}"

- name: Add Helm repositories
  shell: |
    helm repo add stable https://charts.helm.sh/stable
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
  become_user: "{{ ansible_user }}"
EOF

cat > roles/kubernetes/defaults/main.yml << 'EOF'
---
kubernetes_version: "latest"
helm_version: "latest"
EOF
```

### Role: SonarQube

```bash
mkdir -p roles/sonarqube/{tasks,templates,files,vars,defaults}

cat > roles/sonarqube/tasks/main.yml << 'EOF'
---
- name: Create SonarQube directories
  file:
    path: "{{ item }}"
    state: directory
    mode: '0755'
  loop:
    - /opt/sonarqube
    - /opt/sonarqube/data
    - /opt/sonarqube/logs
    - /opt/sonarqube/extensions
    - /data/sonarqube-postgres
  become: yes

- name: Deploy SonarQube Docker Compose file
  template:
    src: sonarqube-docker-compose.yml.j2
    dest: /opt/sonarqube/docker-compose.yml
  become: yes

- name: Deploy PostgreSQL init script
  template:
    src: init-sonarqube-db.sql.j2
    dest: /opt/sonarqube/init-sonarqube-db.sql
  become: yes

- name: Start SonarQube with Docker Compose
  shell: |
    cd /opt/sonarqube
    docker-compose up -d
  environment:
    SONAR_JDBC_PASSWORD: "{{ sonarqube_db_password }}"
    SONAR_JDBC_URL: "{{ sonarqube_jdbc_url }}"
  become: yes

- name: Wait for SonarQube to start
  uri:
    url: http://localhost:9000/api/system/status
    status_code: 200
  register: result
  until: result.status == 200
  retries: 30
  delay: 10

- name: Get initial admin token
  uri:
    url: http://localhost:9000/api/users/current
    method: GET
    user: admin
    password: admin
    force_basic_auth: yes
  register: sonar_user
  changed_when: false

- name: Display SonarQube access info
  debug:
    msg: "SonarQube is running at http://{{ inventory_hostname }}:9000"
EOF

cat > roles/sonarqube/defaults/main.yml << 'EOF'
---
sonarqube_version: "10.2-community"
sonarqube_port: 9000
sonarqube_db_user: "sonar"
sonarqube_db_password: "sonar_secure_password_123"
sonarqube_jdbc_url: "jdbc:postgresql://postgres:5432/sonarqube"
EOF

cat > roles/sonarqube/templates/sonarqube-docker-compose.yml.j2 << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:13-alpine
    container_name: sonarqube-postgres
    environment:
      POSTGRES_USER: {{ sonarqube_db_user }}
      POSTGRES_PASSWORD: {{ sonarqube_db_password }}
      POSTGRES_DB: sonarqube
    volumes:
      - /data/sonarqube-postgres:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - sonarnet
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U {{ sonarqube_db_user }}"]
      interval: 10s
      timeout: 5s
      retries: 5

  sonarqube:
    image: sonarqube:{{ sonarqube_version }}
    container_name: sonarqube
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      SONAR_JDBC_URL: {{ sonarqube_jdbc_url }}
      SONAR_JDBC_USERNAME: {{ sonarqube_db_user }}
      SONAR_JDBC_PASSWORD: {{ sonarqube_db_password }}
      SONAR_ES_BOOTSTRAP_CHECKS_DISABLED: "true"
    volumes:
      - /opt/sonarqube/data:/opt/sonarqube/data
      - /opt/sonarqube/extensions:/opt/sonarqube/extensions
      - /opt/sonarqube/logs:/opt/sonarqube/logs
    ports:
      - "{{ sonarqube_port }}:9000"
    networks:
      - sonarnet

networks:
  sonarnet:
    driver: bridge
EOF
```

### Role: PostgreSQL (HA)

```bash
mkdir -p roles/postgresql/{tasks,templates,files,vars,defaults}

cat > roles/postgresql/tasks/main.yml << 'EOF'
---
- name: Add PostgreSQL repository
  shell: |
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
  become: yes
  when: ansible_os_family == "Debian"

- name: Update package cache and install PostgreSQL
  apt:
    name:
      - postgresql-{{ postgres_version }}
      - postgresql-contrib
      - postgresql-{{ postgres_version }}-repack
    state: present
    update_cache: yes
  become: yes
  when: ansible_os_family == "Debian"

- name: Start PostgreSQL service
  systemd:
    name: postgresql
    state: started
    enabled: yes
  become: yes

- name: Create PostgreSQL data directories
  file:
    path: "{{ item }}"
    state: directory
    owner: postgres
    group: postgres
    mode: '0700'
  loop:
    - /var/lib/postgresql/{{ postgres_version }}/main_wal_archive
    - /var/lib/postgresql/backups
  become: yes

- name: Configure PostgreSQL for HA
  template:
    src: postgresql.conf.j2
    dest: /etc/postgresql/{{ postgres_version }}/main/postgresql.conf
    owner: postgres
    group: postgres
    mode: '0644'
  become: yes
  notify: restart postgresql

- name: Configure PostgreSQL pg_hba.conf
  template:
    src: pg_hba.conf.j2
    dest: /etc/postgresql/{{ postgres_version }}/main/pg_hba.conf
    owner: postgres
    group: postgres
    mode: '0640'
  become: yes
  notify: restart postgresql

- name: Create database backups directory
  file:
    path: /var/lib/postgresql/backups
    state: directory
    owner: postgres
    group: postgres
    mode: '0700'
  become: yes

- name: Create backup script
  template:
    src: backup-postgres.sh.j2
    dest: /usr/local/bin/backup-postgres.sh
    owner: root
    group: root
    mode: '0755'
  become: yes

- name: Add backup cron job
  cron:
    name: PostgreSQL backup
    hour: "2"
    minute: "0"
    job: "/usr/local/bin/backup-postgres.sh"
    user: postgres
  become: yes

- name: Verify PostgreSQL installation
  shell: psql --version
  register: postgres_version_check
  changed_when: false

- name: Display PostgreSQL version
  debug:
    msg: "PostgreSQL installed: {{ postgres_version_check.stdout }}"
EOF

cat > roles/postgresql/defaults/main.yml << 'EOF'
---
postgres_version: "13"
postgres_max_connections: 200
postgres_shared_buffers: "256MB"
postgres_effective_cache_size: "1GB"
postgres_wal_buffers: "16MB"
postgres_checkpoint_completion_target: 0.9
postgres_wal_level: replica
postgres_max_wal_senders: 3
postgres_hot_standby: "on"
EOF

cat > roles/postgresql/templates/postgresql.conf.j2 << 'EOF'
# PostgreSQL Configuration for High Availability

# Connection settings
max_connections = {{ postgres_max_connections }}
superuser_reserved_connections = 10

# Memory settings
shared_buffers = {{ postgres_shared_buffers }}
effective_cache_size = {{ postgres_effective_cache_size }}
wal_buffers = {{ postgres_wal_buffers }}
maintenance_work_mem = 64MB
random_page_cost = 1.1

# Checkpoint settings
checkpoint_completion_target = {{ postgres_checkpoint_completion_target }}
wal_buffers = {{ postgres_wal_buffers }}
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 512KB

# WAL settings
wal_level = {{ postgres_wal_level }}
max_wal_senders = {{ postgres_max_wal_senders }}
wal_keep_size = 1GB
hot_standby = {{ postgres_hot_standby }}
max_standby_streaming_delay = 300s
wal_receiver_timeout = 60s
wal_retrieve_retry_interval = 5s

# Replication settings
hot_standby_feedback = on
archive_mode = on
archive_command = 'test ! -f /var/lib/postgresql/{{ postgres_version }}/main_wal_archive/%f && cp %p /var/lib/postgresql/{{ postgres_version }}/main_wal_archive/%f'
archive_timeout = 900

# Logging
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_truncate_on_rotation = on
log_rotation_age = 24h
log_rotation_size = 100MB
log_min_duration_statement = 1000
log_connections = on
log_disconnections = on
log_statement = 'all'
EOF

cat > roles/postgresql/templates/pg_hba.conf.j2 << 'EOF'
# PostgreSQL Client Authentication Configuration
local   all             postgres                                trust
local   all             all                                     peer
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
host    replication     all             0.0.0.0/0               md5
host    replication     all             ::/0                    md5
EOF

cat > roles/postgresql/handlers/main.yml << 'EOF'
---
- name: restart postgresql
  systemd:
    name: postgresql
    state: restarted
    daemon_reload: yes
  become: yes
EOF
```

---

## 6️⃣ Create Main Playbooks

### Main Site Playbook

```bash
cat > playbooks/site.yml << 'EOF'
---
- name: DevSecOps Infrastructure Setup
  hosts: all_servers
  become: yes
  
  pre_tasks:
    - name: Display deployment information
      debug:
        msg: |
          Deploying to: {{ inventory_hostname }}
          Environment: {{ ansible_environment | default('unknown') }}
          OS: {{ ansible_os_family }}

  roles:
    - common
    - docker
    - azure-cli
    - kubernetes

  post_tasks:
    - name: System verification
      shell: |
        echo "=== System Info ==="
        uname -a
        echo ""
        echo "=== Installed Tools ==="
        docker --version
        az --version | head -1
        kubectl version --client | head -1
      register: system_info
    
    - name: Display system information
      debug:
        msg: "{{ system_info.stdout }}"
EOF
```

### SonarQube Deployment Playbook

```bash
cat > playbooks/sonarqube.yml << 'EOF'
---
- name: Deploy SonarQube and PostgreSQL
  hosts: sonarqube_servers
  become: yes

  roles:
    - docker
    - postgresql
    - sonarqube

  post_tasks:
    - name: Wait for SonarQube to be ready
      uri:
        url: "http://{{ inventory_hostname }}:9000/api/system/status"
        status_code: 200
      register: sonar_status
      until: sonar_status.status == 200
      retries: 30
      delay: 10

    - name: Display SonarQube access information
      debug:
        msg: |
          SonarQube is now available at: http://{{ inventory_hostname }}:9000
          Default credentials: admin / admin
          IMPORTANT: Change the default password on first login!
EOF
```

### Kubernetes Deployment Playbook

```bash
cat > playbooks/kubernetes.yml << 'EOF'
---
- name: Setup Kubernetes Cluster
  hosts: kubernetes_masters
  become: yes

  vars:
    kubernetes_pod_network_cidr: "10.244.0.0/16"

  roles:
    - common
    - docker
    - kubernetes

  tasks:
    - name: Initialize Kubernetes cluster
      shell: |
        kubeadm init \
          --pod-network-cidr={{ kubernetes_pod_network_cidr }} \
          --apiserver-advertise-address={{ ansible_default_ipv4.address }}
      register: kubeadm_init
      changed_when: "'Your Kubernetes control-plane has initialized successfully' in kubeadm_init.stdout"

    - name: Copy kubeconfig
      shell: |
        mkdir -p /home/{{ ansible_user }}/.kube
        cp /etc/kubernetes/admin.conf /home/{{ ansible_user }}/.kube/config
        chown {{ ansible_user }}:{{ ansible_user }} /home/{{ ansible_user }}/.kube/config
      become: yes

    - name: Install Flannel pod network
      become_user: "{{ ansible_user }}"
      shell: |
        kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
      environment:
        KUBECONFIG: /home/{{ ansible_user }}/.kube/config

    - name: Display cluster join command
      debug:
        msg: "Save this command for worker nodes: {{ kubeadm_init.stdout | regex_search('kubeadm join.*') }}"

- name: Join Kubernetes workers
  hosts: kubernetes_workers
  become: yes

  roles:
    - common
    - docker
    - kubernetes

  tasks:
    - name: Join worker to cluster
      shell: "{{ hostvars[groups['kubernetes_masters'][0]]['kubeadm_init'].stdout | regex_search('kubeadm join.*') }}"
      register: worker_join
      changed_when: "'Node joined successfully' in worker_join.stdout"
EOF
```

---

## 7️⃣ Create Variables Files

### Common Variables

```bash
cat > vars/common.yml << 'EOF'
---
# Common variables for all environments
timezone: UTC
ntp_servers:
  - 0.pool.ntp.org
  - 1.pool.ntp.org
  - 2.pool.ntp.org

# Docker settings
docker_storage_driver: overlay2
docker_log_driver: json-file

# System limits
system_limits:
  - "* soft nofile 65536"
  - "* hard nofile 65536"
  - "* soft nproc 65536"
  - "* hard nproc 65536"

# Ansible user
deploy_user: ubuntu
EOF

# Environment-specific variables
cat > vars/dev.yml << 'EOF'
---
environment: development
docker_version: 24.0
kubernetes_version: 1.28

# Resource limits (dev is smaller)
postgres_max_connections: 100
postgres_shared_buffers: "256MB"
EOF

cat > vars/staging.yml << 'EOF'
---
environment: staging
docker_version: 24.0
kubernetes_version: 1.28

# Resource limits (staging is medium)
postgres_max_connections: 200
postgres_shared_buffers: "512MB"
EOF

cat > vars/prod.yml << 'EOF'
---
environment: production
docker_version: 24.0
kubernetes_version: 1.28

# Resource limits (production is largest)
postgres_max_connections: 300
postgres_shared_buffers: "1024MB"
EOF
```

---

## 8️⃣ Run Ansible Playbooks

### Dry Run (Check Mode)

```bash
# Test without making changes
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check

# Show what would change
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check --diff

# Verbose output
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -vvv
```

### Execute Playbooks

```bash
# Deploy to all servers
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# Deploy to specific group
ansible-playbook -i inventory/hosts.ini playbooks/sonarqube.yml -l sonarqube_servers

# Deploy to specific hosts
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -l dev-server-1,dev-server-2

# Deploy with extra variables
ansible-playbook -i inventory/hosts.ini playbooks/site.yml \
  -e "environment=production" \
  -e "docker_version=24.0"

# Deploy with tags
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --tags docker,kubernetes
```

### Run with Limited Concurrency

```bash
# Deploy to one host at a time
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -f 1

# Deploy to 5 hosts in parallel
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -f 5
```

---

## 9️⃣ Verify Deployment

### Post-Deployment Checks

```bash
# Check if all hosts are reachable
ansible all -i inventory/hosts.ini -m ping

# Verify Docker installation across all hosts
ansible docker_hosts -i inventory/hosts.ini -m shell -a "docker --version"

# Check Kubernetes status
ansible kubernetes_masters -i inventory/hosts.ini -m shell -a "kubectl get nodes"

# Verify SonarQube service
ansible sonarqube_servers -i inventory/hosts.ini -m uri -a "url=http://localhost:9000/api/system/status"

# Collect system facts
ansible all -i inventory/hosts.ini -m setup -a "filter=ansible_*"
```

### Create Verification Playbook

```bash
cat > playbooks/verify.yml << 'EOF'
---
- name: Verify All Installations
  hosts: all_servers

  tasks:
    - name: Check Docker
      shell: docker --version
      register: docker_check
      failed_when: docker_check.rc != 0

    - name: Check Azure CLI
      shell: az --version | head -1
      register: azure_check
      failed_when: azure_check.rc != 0

    - name: Check kubectl
      shell: kubectl version --client | head -1
      register: kubectl_check
      failed_when: kubectl_check.rc != 0

    - name: Display verification results
      debug:
        msg: |
          Docker: {{ docker_check.stdout }}
          Azure CLI: {{ azure_check.stdout }}
          kubectl: {{ kubectl_check.stdout }}

    - name: Generate verification report
      copy:
        content: |
          Installation Verification Report
          ==================================
          Date: {{ ansible_date_time.iso8601 }}
          Host: {{ inventory_hostname }}
          
          Docker: {{ docker_check.stdout }}
          Azure CLI: {{ azure_check.stdout }}
          kubectl: {{ kubectl_check.stdout }}
          
          OS: {{ ansible_os_family }}
          Kernel: {{ ansible_kernel }}
          Uptime: {{ ansible_uptime_seconds }}
        dest: /opt/ansible/verification-report-{{ inventory_hostname }}.txt
      become: yes
EOF

# Run verification
ansible-playbook -i inventory/hosts.ini playbooks/verify.yml
```

---

## 🔟 Advanced Ansible Features

### Conditionals and Loops

```yaml
---
- name: Example with conditionals
  hosts: all_servers
  tasks:
    - name: Install packages for Debian
      apt:
        name: "{{ item }}"
        state: present
      loop:
        - curl
        - git
        - vim
      when: ansible_os_family == "Debian"

    - name: Create users conditionally
      user:
        name: "{{ item }}"
        shell: /bin/bash
      loop:
        - devops
        - monitoring
        - backup
      when: inventory_hostname in groups['prod']

    - name: Configure service based on environment
      template:
        src: "service-{{ environment }}.conf.j2"
        dest: /etc/service/config
      when: environment is defined
```

### Error Handling and Retries

```yaml
---
- name: Example with retries and error handling
  hosts: all_servers
  tasks:
    - name: Retry task with backoff
      shell: |
        curl -f http://sonarqube:9000/api/system/status
      retries: 5
      delay: 10
      register: sonar_result
      until: sonar_result is successful

    - name: Continue on error
      shell: some-command
      ignore_errors: yes
      register: result

    - name: Check result
      debug:
        msg: "Task failed, continuing..."
      when: result is failed

    - name: Block with error handling
      block:
        - name: Risky task
          shell: risky-command
      rescue:
        - name: Handle failure
          debug:
            msg: "Error occurred, running cleanup..."
      always:
        - name: Always run
          debug:
            msg: "Cleanup complete"
```

### Variables and Jinja2 Templating

```yaml
---
- name: Example with variables and templating
  hosts: all_servers
  vars:
    service_ports:
      sonarqube: 9000
      postgres: 5432
      kubernetes: 6443
  
  tasks:
    - name: Output with variable
      debug:
        msg: "SonarQube running on port {{ service_ports.sonarqube }}"

    - name: Loop with condition
      debug:
        msg: "{{ item.key }} on port {{ item.value }}"
      when: item.value > 5000
      loop: "{{ service_ports | dict2items }}"

    - name: Template with calculations
      template:
        src: config.yml.j2
        dest: /etc/service/config.yml
      vars:
        memory_gb: 8
        shared_buffers_mb: "{{ (memory_gb * 1024) // 4 }}"
```

---

## 1️⃣1️⃣ Ansible Best Practices

```yaml
---
# Good Ansible practices

# 1. Use descriptive task names
- name: Install Docker and Docker Compose packages
  apt:
    name:
      - docker-ce
      - docker-compose-plugin
    state: present

# 2. Use become judiciously
- name: Start service (requires sudo)
  systemd:
    name: docker
    state: started
    enabled: yes
  become: yes
  become_user: root

# 3. Use handlers for service restarts
- name: Update Docker config
  template:
    src: daemon.json.j2
    dest: /etc/docker/daemon.json
  notify: restart docker

- name: restart docker
  systemd:
    name: docker
    state: restarted

# 4. Use variables for DRY (Don't Repeat Yourself)
- name: Create multiple directories
  file:
    path: "{{ item }}"
    state: directory
  loop:
    - /opt/ansible
    - /opt/tools
    - /data/backups

# 5. Use block for grouping related tasks
- block:
    - name: Task 1
      shell: command1
    - name: Task 2
      shell: command2
  when: ansible_distribution == "Ubuntu"

# 6. Register and use results
- name: Get current user
  shell: whoami
  register: current_user
  changed_when: false

- name: Display current user
  debug:
    msg: "Running as: {{ current_user.stdout }}"
```

---

## 1️⃣2️⃣ Troubleshooting Ansible

```bash
# Enable debug logging
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -vvvv

# Check syntax
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --syntax-check

# Test connectivity to all hosts
ansible all -i inventory/hosts.ini -m ping -vvv

# Check what would change
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check --diff

# Run specific tasks with tags
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --tags docker

# Limit to specific hosts
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -l dev-server-1

# Debug variable values
ansible dev-server-1 -i inventory/hosts.ini -m debug -a "var=hostvars[inventory_hostname]"

# Get all facts about a host
ansible dev-server-1 -i inventory/hosts.ini -m setup | grep -i docker

# Ad-hoc command on specific group
ansible sonarqube_servers -i inventory/hosts.ini -m shell -a "ps aux | grep sonarqube"

# Check logs
tail -f /var/log/syslog  # On managed node
tail -f ansible.log      # On control node (if enabled)
```

---

## 1️⃣3️⃣ Full Example: Deploy Everything

```bash
#!/bin/bash

# Complete deployment script
set -e

echo "=== DevSecOps Ansible Deployment ==="
echo ""

# 1. Verify Ansible installation
echo "Step 1: Verifying Ansible installation..."
ansible --version
echo "✓ Ansible is installed"
echo ""

# 2. Test inventory
echo "Step 2: Testing inventory connectivity..."
ansible all -i inventory/hosts.ini -m ping
echo "✓ All hosts are reachable"
echo ""

# 3. Pre-flight checks
echo "Step 3: Pre-flight checks..."
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check
echo "✓ Pre-flight checks passed"
echo ""

# 4. Deploy base infrastructure
echo "Step 4: Deploying base infrastructure..."
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
echo "✓ Base infrastructure deployed"
echo ""

# 5. Deploy SonarQube
echo "Step 5: Deploying SonarQube..."
ansible-playbook -i inventory/hosts.ini playbooks/sonarqube.yml -l sonarqube_servers
echo "✓ SonarQube deployed"
echo ""

# 6. Deploy Kubernetes (optional)
echo "Step 6: Deploying Kubernetes cluster..."
ansible-playbook -i inventory/hosts.ini playbooks/kubernetes.yml
echo "✓ Kubernetes cluster deployed"
echo ""

# 7. Verification
echo "Step 7: Verifying installations..."
ansible-playbook -i inventory/hosts.ini playbooks/verify.yml
echo "✓ Verification complete"
echo ""

echo "=== Deployment Complete ==="
echo "All infrastructure is ready for DevSecOps pipeline!"
```

---

## 📋 Ansible Inventory Summary

```
Inventory File Structure:
├── inventory/
│   ├── hosts.ini          (INI format)
│   └── hosts.yaml         (YAML format)
│
Host Groups:
├── all_servers            (All hosts)
├── dev                    (Development)
├── staging                (Staging)
├── prod                   (Production)
├── docker_hosts           (Docker enabled)
├── sonarqube_servers      (SonarQube)
├── database_servers       (PostgreSQL)
├── kubernetes_masters     (K8s masters)
└── kubernetes_workers     (K8s workers)
```

---

## ✅ Verification Checklist

```
Ansible Setup:
  ☐ Ansible installed on control node
  ☐ SSH keys configured for all hosts
  ☐ Inventory file created and verified
  ☐ Connectivity to all managed nodes working

Playbooks:
  ☐ Role structure created
  ☐ Common role functional
  ☐ Docker role functional
  ☐ Azure CLI role functional
  ☐ Kubernetes role functional
  ☐ SonarQube role functional
  ☐ PostgreSQL role functional

Execution:
  ☐ Dry run successful (--check mode)
  ☐ Main playbook executed
  ☐ SonarQube deployed
  ☐ Kubernetes cluster operational
  ☐ All services running
  ☐ Verification playbook passed

Post-Deployment:
  ☐ All tools installed
  ☐ Services started and healthy
  ☐ Backup scripts running
  ☐ Monitoring configured
  ☐ Access credentials secured
```

---

## 📚 Resources

- **Ansible Documentation**: https://docs.ansible.com/
- **Ansible Galaxy**: https://galaxy.ansible.com/
- **Ansible Best Practices**: https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html
- **Community Support**: https://www.ansible.com/community

---

## 🚀 Next Steps

1. ✅ Install Ansible on control node
2. ✅ Setup SSH keys to managed nodes
3. ✅ Create inventory file with your servers
4. ✅ Test connectivity (ansible all -m ping)
5. ✅ Run playbooks in check mode first
6. ✅ Execute full deployment
7. ✅ Verify all installations
8. ✅ Setup backup and monitoring
9. ✅ Integrate with CI/CD pipeline

---

**Ansible DevSecOps Setup Complete!** 🎉

You now have a fully automated, repeatable infrastructure deployment system.
