# Instruqt Lab for Consul Terraform Sync

## Resources

https://github.com/hashicorp/consul-terraform-sync

https://www.consul.io/docs/nia/installation/configuration 


## Overview:

Consul/VMs <> F5 BIG-IP <> PANOS <> Internet
     |            ^          ^
     |____________|__________|
      consul-terraform-sync
         MGMT Network

## Lab Workflow

### Challenge #1 - Review Architecture

Provisioned:
* Consul Cluster
* Traditional VM App w/ Consul agent
* F5 BIG-IP
* PANOS

Diagram showing ITIL 'Continuous Disappointment'


### Challenge #2 - Install consul-terraform-sync

Provisioned VM, add shell tab.
Steps:

1) Start consul-terraform-sync 

```sh
consul-terraform-sync -config-file terraform-sync.hcl

```

2) Review consul-terraform-sync process/configuration

Example:
```
log_level = "info"
consul {
    address = "consul.example.com"
}
buffer_period {
    min = "5s"
    max = "20s"
}
service {
    name = "api"
    datacenter = "dc1"
}
task {
    name = "website-x"
    description = "automate services for website-x"
    source = "namespace/example/module"
    version = "1.0.0"
    providers = ["myprovider"]
    services = ["web", "api"]
    wait {
        min = "10s"
    }
}
driver "terraform" {
    required_providers {
        myprovider = {
            source = "namespace/myprovider"
            version = "1.3.0"
        }
    }
}
provider "myprovider" {
    address = "myprovider.example.com"
}
```


### Challenge #3 - xxxx


### Challenge #4 - xxxx


### Challenge #5 - xxxx

