# terraform/main.tf
provider "local" {}

variable "static_ips" {
  type    = list(string)
  default = ["10.25.3.231", "10.25.3.232", "10.25.3.233"]
}

resource "local_file" "ip_configs" {
  count = length(var.static_ips)

  content  = <<EOF
interface eth0
static ip_address=${var.static_ips[count.index]}
static routers=10.25.3.1
static domain_name_servers=8.8.8.8
EOF

  filename = "${path.module}/ip_config_${count.index + 1}.txt"
}