#!/bin/bash

#Utils
sudo apt-get install unzip


#Download Consul
CONSUL_VERSION="1.8.0+ent"
curl --silent --remote-name https://releases.hashicorp.com/consul/$${CONSUL_VERSION}/consul_$${CONSUL_VERSION}_linux_amd64.zip

#Install Consul
unzip consul_$${CONSUL_VERSION}_linux_amd64.zip
sudo chown root:root consul
sudo mv consul /usr/local/bin/
consul -autocomplete-install
complete -C /usr/local/bin/consul consul


#Download consul-terraform-sync
curl --silent --remote-name https://releases.hashicorp.com/consul-terraform-sync/0.1.0-techpreview1/consul-terraform-sync_0.1.0-techpreview1_linux_amd64.zip

#Install consul-terraform-sync
unzip *.zip
sudo chown root:root consul
sudo mv consul-terraform-sync /usr/local/bin/

#Create Consul Terraorm Sync User
sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul
sudo chown --recursive consul:consul /opt/consul

#Create Systemd Config for Consul
sudo cat << EOF > /etc/systemd/system/consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target

[Service]
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent  -bind '{{ GetInterfaceIP "eth0" }}' -config-dir=/etc/consul.d/
ExecReload=/usr/local/bin/consul reload
KillMode=process
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

#Create Systemd Config for Consul Terraform Sync
sudo cat << EOF > /etc/systemd/system/consul-terraform-sync.service
[Unit]
Description="HashiCorp Consul Terraform Sync - A Network Infra Automation solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target

[Service]
User=consul-terraform-sync
Group=consul-terraform-sync
ExecStart=/usr/local/bin/consul-terraform-sync -config-file=/etc/consul.d/consul-terraform-sync.hcl
KillMode=process
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

#Create config dir
sudo mkdir --parents /etc/consul.d
sudo touch /etc/consul.d/consul.hcl
sudo chown --recursive consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/consul.hcl

sudo mkdir --parents /etc/consul-terraform-sync.d
sudo touch /etc/consul-terraform-sync.d/consul-terraform-sync.hcl
sudo chown --recursive consul:consul /etc/consul-terraform-sync.d
sudo chmod 640 /etc/consul-terraform-sync.d/consul-terraform-sync.hcl

cat << EOF > /etc/consul.d/ca.pem
${ca_cert}
EOF

cat << EOF > /etc/consul.d/hcs.json
${consulconfig}
EOF

cat << EOF > /etc/consul.d/zz_override.hcl
data_dir = "/opt/consul"
ui = true
ca_file = "/etc/consul.d/ca.pem"
acl = {
  tokens = {
    default = "${consul_token}"
  }
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
}
EOF

cat << EOF /etc/consul-terraform-sync.d/consul-terraform-sync.hcl
log_level = "debug"
consul {
  address = "11eb1ad2-5ddc-1591-ad95-0242ac110009.consul.11eb1ad2-2609-d45e-8896-0242ac110007.az.hashicorp.cloud:8500"
}
buffer_period {
  min = "5s"
  max = "20s"
}
task {
  name = "AS3-Fake-Service-Website"
  description = "automate F5 BIG-IP Pool Members Ops for Fake Service Website"
  source = "f5devcentral/bigip/app-consul-sync-nia"
  providers = ["bigip"]
  services = ["web", "app"]
}
driver "terraform" {
  log = true
  required_providers {
    bigip = {
      source = "F5Networks/bigip"
    }
  }
}
provider "bigip" {
  address = "52.224.196.91:8443"
  username = "f5admin"
  password = "sZ@w4XXxHJz3WhQb0zD7kUi7"
}
EOF

#Enable the service
sudo systemctl enable consul
sudo service consul start
sudo service consul status

#Enable the service
sudo systemctl enable consul-terraform-sync
sudo service consul-terraform-sync start
sudo service consul-terraform-sync status
