# #################################################################################
data "aws_region" "site_region" {}

output "aws_region" {
  value = "${data.aws_region.site_region.name}"
}

# #################################################################################

data "aws_availability_zones" "site_avz" {}

output "aws_availability_zones" {
  value = "${data.aws_availability_zones.site_avz.names}"
}

# #################################################################################

module "site" {
  source          = "../terraform/site"

  region          = "${data.aws_region.site_region.name}"
  vpc_cidr        = "${var.vpc_cidr["${var.env}"]}"

  project         = "${var.project}"
  environment     = "${var.env}"
  domain_name     = "${var.domainname}"

  ssh_pri_key     = "${var.static_ssh["priv"]}"
  ssh_pub_key     = "${var.static_ssh["pub"]}"
}

module "key_pair" {
  source          = "../terraform/key_pair"

  ssh_name_key    = "${module.site.project}-${module.site.environment}-keypair"
  ssh_pub_key     = "${module.site.ssh_pub_key}"
}

# #################################################################################

module "subnet_public" {
  source            = "../terraform/subnet"

  name              = "Public"

  vpc_id            = "${module.site.aws_vpc_id}"
  project           = "${module.site.project}"
  environment       = "${module.site.environment}"

  cidr_block        = [ "${var.subnet_public}" ]
  
  availability_zone = [ "${data.aws_availability_zones.site_avz.names}" ]

  map_public_ip     = true                         
}

output "subnet_public" {
  value = "${module.subnet_public.id}"
}

# ##################################################################################

module "sg_ingress_etcd" {
  source            = "../terraform/sg_ingress_map"
  sg_name           = "${module.site.project}-${module.site.environment}-ETCD"
  aws_vpc_id        = "${module.site.aws_vpc_id}"

  ingress = [
    {
      from_port     = 2379
      to_port       = 2379
      protocol      = "TCP"
      cidr_blocks   = [ "${var.vpc_cidr["${var.env}"]}" ]
    },
    {
      from_port     = 2380
      to_port       = 2380
      protocol      = "TCP"
      cidr_blocks   = [ "${var.vpc_cidr["${var.env}"]}" ]
    }    
  ]
}

module "sg_ingress" {
  source            = "../terraform/sg_ingress_map"

  sg_name           = "${module.site.project}-${module.site.environment}-ingress"
  aws_vpc_id        = "${module.site.aws_vpc_id}"

  ingress = [
    {
      from_port     = 0
      to_port       = 0
      protocol      = "-1"
      cidr_blocks   = [ "${var.vpc_cidr["${var.env}"]}" ]
    },    
    {
      from_port     = 22
      to_port       = 22
      protocol      = "TCP"
      cidr_blocks   = [ "0.0.0.0/0" ]
    },
    {
      from_port     = 80
      to_port       = 80
      protocol      = "TCP"
      cidr_blocks   = [ "0.0.0.0/0" ]      
    },
    {
      from_port     = 443
      to_port       = 443
      protocol      = "TCP"
      cidr_blocks   = [ "0.0.0.0/0" ]      
    }
  ]
}

module "sg_egress" {
  source            = "../terraform/sg_egress_map"

  sg_name           = "${module.site.project}-${module.site.environment}-egress"
  aws_vpc_id        = "${module.site.aws_vpc_id}"

  egress = [
    {
      cidr_blocks   = [ "0.0.0.0/0" ]
      from_port     = 0
      to_port       = 0
      protocol      = "-1"
    }
  ]
}

################################################################################

module "ssl_key_ca" {
  source              = "../terraform/ssl_private_key"
}

module "ssl_cert_ca" {
  source              = "../terraform/ssl_self_signed_cert"

  private_key_pem     = "${module.ssl_key_ca.private_key_pem}"
  common_name         = "kube-ca"
  organization        = "${module.site.project}-${module.site.environment}"

  is_ca_certificate   = true

  allowed_uses = [
    "key_encipherment",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}

module "ssl_key_etcd" {
  source              = "../terraform/ssl_private_key"
}

module "ssl_csr_etcd" {
  source              = "../terraform/ssl_cert_request"

  private_key_pem     = "${module.ssl_key_etcd.private_key_pem}"

  common_name         = "*"
  organization        = "Etcd-member" 
  organizational_unit = "Etcd-member"
  street_address      = [ ]
  locality            = "Amsterdam"
  province            = "Noord-Holland"
  country             = "NL"

  dns_names           = [ "etcd",
                          "etcd.default",
                          "etcd.test",
                          "etcd.default.svc",
                          "127.0.0.1"
                        ]
  ip_addresses          = [
                          "127.0.0.1",
                        ]
}

module "ssl_cert_etcd" {
  source                = "../terraform/ssl_locally_signed_cert"

  cert_request_pem      = "${module.ssl_csr_etcd.cert_request_pem}"
  ca_private_key_pem    = "${module.ssl_key_etcd.private_key_pem}"
  ca_cert_pem           = "${module.ssl_cert_ca.cert_pem}"
}

################################################################################

data "aws_ami" "ubuntu_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "template_file" "machine_default" {
  template             = "${file("templates/template_machine_role.tpl")}"
}

data "template_file" "machine_default_policy" {
  template             = "${file("templates/template_machine_role_policy.tpl")}"
}

module "role_iam" {
  source              = "../terraform/iam_role"

  name                = "${module.site.project}-${module.site.environment}-role-machine" 
  assume_role_policy  = "${data.template_file.machine_default.rendered}"
}

module "role_iam_policy" {
  source              = "../terraform/iam_role_policy"

  name                = "${module.site.project}-${module.site.environment}-policy-machine"
  role                = "${module.role_iam.id}"
  policy              = "${data.template_file.machine_default_policy.rendered}"
}

module "iam_instance_profile" {
  source              = "../terraform/iam_instance_profile"

  name                = "${module.site.project}-${module.site.environment}-instance"
  role                = "${module.role_iam.id}"
}

data "template_file" "instance-worker" {
  template              = "${file("templates/worker-cloud-config.tpl")}"

  vars {
    ssl_client_cert       = "${module.ssl_cert_etcd.cert_pem}"
    ssl_client_key        = "${module.ssl_key_etcd.private_key_pem}"
    ssl_ca_cert           = "${module.ssl_cert_ca.cert_pem}"
  }
}

module "instance_etcd" {
  source                  = "../terraform/instance"

  availability_zone       = "${element(data.aws_availability_zones.site_avz.names, 0)}"
  
  count                   = 2

  tags = {
    etcd                  = true
  }

  instance_name           = "etcd"
  environment             = "${module.site.environment}"
  aws_subnet_id           = "${element(module.subnet_public.id, 0)}"

  ssh_user                = "ubuntu"
  ssh_name_key            = "${module.key_pair.ssh_name_key}"
  ssh_pri_key             = "${module.site.ssh_pri_key}"

  region                  = "${module.site.region}"

  aws_ami                 = "${data.aws_ami.ubuntu_ami.id}"

  iam_instance_profile    = "${module.iam_instance_profile.name}"

  root_block_device_size  = "20"

  security_groups_ids     = [ "${module.sg_ingress.id}",
                              "${module.sg_ingress_etcd.id}",
                              "${module.sg_egress.id}" ]

  aws_instance_type       = "t2.micro"
  associate_public_ip_address = true

  user_data               = "${data.template_file.instance-worker.rendered}"
}

output "worker_public_ip" {
  value = "${module.instance_etcd.public_ip}"
}

output "worker_private_ip" {
  value = "${module.instance_etcd.private_ip}"
}

output "worker_public_dns" {
  value = "${module.instance_etcd.public_dns}"
}

# #####################################################################################

# module "elb_etcd" {
#   source                  = "../terraform/elb_map"
#   project                 = "${module.site.project}"
#   environment             = "${module.site.environment}"

#   name                    = "ELB-etcd"

#   tags = {
#     Name                  = "ELB-etcd"
#   }

#   internal                = true

#   subnet_ids              = [ "${module.subnet_public.id}" ]
#   security_group_ids      = [ "${module.sg_ingress_etcd.id}" ,
#                               "${module.sg_egress.id}"]

#   instances               = [ "${module.instance_etcd.id}" ]

#   listener = [
#     {
#       instance_port       = "2379"
#       instance_protocol   = "HTTP"
#       lb_port             = "2379"
#       lb_protocol         = "HTTP"
#     },
#     {
#       instance_port       = "2380"
#       instance_protocol   = "HTTP"
#       lb_port             = "2380"
#       lb_protocol         = "HTTP"
#     }
#   ]

#   health_check = [
#     { 
#       healthy_threshold   = 2
#       unhealthy_threshold = 2
#       timeout             = 3
#       target              = "HTTP:2379/health"
#       interval            = 15
#     }
#   ]
# }

# output "elb-etcd" {
#   value = "${module.elb_etcd.dns_name}"
# }

# #####################################################################################
