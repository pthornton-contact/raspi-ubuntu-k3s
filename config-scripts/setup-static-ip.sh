#!/bin/bash
# This script will configure static IPs for the Raspberry Pi cluster.

echo "Configuring static IP for the Raspberry Pi cluster..."

for IP in 10.25.3.231 10.25.3.232 10.25.3.233; do
  echo "Configuring IP $IP"
  echo "interface eth0
  static ip_address=$IP
  static routers=10.25.3.1
  static domain_name_servers=8.8.8.8" | sudo tee /etc/dhcpcd.conf
done
