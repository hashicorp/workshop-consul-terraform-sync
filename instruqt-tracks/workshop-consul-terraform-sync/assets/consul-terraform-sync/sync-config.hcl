log_level = "info"

consul {
  address = "consul.example.com"
}

buffer_period {
  min = "5s"
  max = "20s"
}

task {
  name = "website-x"
  description = "automate services for website-x"
  source = "namespace/example/module"
  version = "1.0.0"
  providers = ["myprovider"]
  services = ["web", "api"]
  buffer_period {
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