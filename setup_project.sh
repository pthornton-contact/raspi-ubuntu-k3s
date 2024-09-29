#!/bin/bash

# Create directories
echo "Creating directories..."
mkdir -p ansible/inventories/production/group_vars
mkdir -p ansible/playbooks
mkdir -p ansible/roles/common/tasks
mkdir -p ansible/roles/network/tasks
mkdir -p config-scripts
mkdir -p terraform
mkdir -p application

# Create files with content
echo "Creating files..."

# ansible files
cat <<EOT > ansible/inventories/production/hosts.ini
[control]
192.168.1.10  # Control plane node

[workers]
192.168.1.11  # Worker node 1
192.168.1.12  # Worker node 2
EOT

cat <<EOT > ansible/inventories/production/group_vars/all.yml
---
ansible_user: pi
ansible_ssh_private_key_file: ~/.ssh/id_rsa

cluster_static_ips:
  - 192.168.1.10
  - 192.168.1.11
  - 192.168.1.12
EOT

cat <<EOT > ansible/playbooks/setup.yml
---
- name: Initial setup of Raspberry Pi cluster
  hosts: all
  become: yes
  roles:
    - common
    - network
EOT

cat <<EOT > ansible/playbooks/k3s-install.yml
---
- name: Install k3s on Raspberry Pi cluster
  hosts: control
  become: yes
  tasks:
    - name: Install k3s
      shell: curl -sfL https://get.k3s.io | sh -
      args:
        creates: /usr/local/bin/k3s
    - name: Join workers to k3s cluster
      hosts: workers
      become: yes
      tasks:
        - name: Join K3s cluster
          shell: curl -sfL https://get.k3s.io | K3S_URL=https://{{ groups['control'][0] }}:6443 K3S_TOKEN={{ hostvars[groups['control'][0]].node_token }} sh -
EOT

cat <<EOT > ansible/roles/common/tasks/main.yml
---
- name: Ensure hostname is set
  hostname:
    name: "{{ inventory_hostname }}"

- name: Install common packages
  apt:
    name:
      - curl
      - vim
      - git
    state: present
    update_cache: yes
EOT

cat <<EOT > ansible/roles/network/tasks/main.yml
---
- name: Configure static IP
  copy:
    content: |
      interface eth0
      static ip_address={{ item }}
      static routers=192.168.1.1
      static domain_name_servers=192.168.1.1
    dest: /etc/dhcpcd.conf
  with_items: "{{ cluster_static_ips }}"
EOT

# config-scripts files
cat <<EOT > config-scripts/setup-static-ip.sh
#!/bin/bash
# This script will configure static IPs for the Raspberry Pi cluster.

echo "Configuring static IP for the Raspberry Pi cluster..."

for IP in 192.168.1.10 192.168.1.11 192.168.1.12; do
  echo "Configuring IP \$IP"
  echo "interface eth0
  static ip_address=\$IP
  static routers=192.168.1.1
  static domain_name_servers=192.168.1.1" | sudo tee /etc/dhcpcd.conf
done
EOT

chmod +x config-scripts/setup-static-ip.sh

# terraform files
cat <<EOT > terraform/main.tf
provider "local" {}

resource "local_file" "ip_config" {
  content  = <<EOF
interface eth0
static ip_address=192.168.1.10
static routers=192.168.1.1
static domain_name_servers=192.168.1.1
EOF
  filename = "\${path.module}/ip_config.txt"
}
EOT

cat <<EOT > terraform/variables.tf
variable "static_ips" {
  type = list(string)
  default = ["192.168.1.10", "192.168.1.11", "192.168.1.12"]
}
EOT

cat <<EOT > terraform/providers.tf
provider "local" {}
EOT

# application files
cat <<EOT > application/docker-compose.yml
version: '3'

services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
EOT

echo "Project setup complete!"