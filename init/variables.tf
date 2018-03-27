variable "env" {
  default            = "dev"
}

variable "domainname" {
  default            = "digiwhite"
}

variable "project" {
  default            = "etcd"
}

variable "ssl_arn" {
  default            = ""
}

variable "vpc_cidr" {
  default            = {
    dev              = "10.11.0.0/16"
    acc              = "10.12.0.0/16"
    prd              = "10.13.0.0/16"
  }
}

variable "subnet_private" {
  default = { 
      dev.eu-west-1a = "10.11.1.0/24"
      dev.eu-west-1b = "10.11.11.0/24"
      dev.eu-west-1c = "10.11.21.0/24"
      acc.eu-west-1a = "10.12.2.0/24"
      acc.eu-west-1b = "10.12.12.0/24"
      acc.eu-west-1c = "10.12.22.0/24"
      prd.eu-west-1a = "10.13.3.0/24"
      prd.eu-west-1b = "10.13.13.0/24"
      prd.eu-west-1c = "10.13.23.0/24"
  }
}

variable "subnet_public" {
  default = {
      dev.eu-west-1a = "10.11.101.0/24"
      dev.eu-west-1b = "10.11.111.0/24"
      dev.eu-west-1c = "10.11.121.0/24"
      acc.eu-west-1a = "10.12.102.0/24"
      acc.eu-west-1b = "10.12.112.0/24"
      acc.eu-west-1c = "10.12.122.0/24"
      prd.eu-west-1a = "10.13.103.0/24"
      prd.eu-west-1b = "10.13.113.0/24"
      prd.eu-west-1c = "10.13.123.0/24"
  }
}
