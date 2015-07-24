/**************************************************************************

# Overview:
  This module creates a web application environment, including a Elastic Load Balancer and Web Nodes

Inputs:
  Required:
    name - applicaition name.  Should contain only lower case letters and '-'
    vpc_id - VPC id for this application
    subnet_id - subnet id of the subnet to provision the node instances in
    ami - AMI ID to use when provisioning application nodes
    ssh_key - AWS public key to use when provision node instances
    environment - intended application environment (ex. staging/production). used for capistrano ec2 tag deployment
    roles - intended application environment (ex. staging/production). used for capistrano ec2 tag deployment
    project - intended application environment (ex. staging/production). used for capistrano ec2 tag deployment



  Optional:
    node_type - type of node to use. defaults to cache.m1.small
    port - port to run on.  defaults to 11211
    count - number of nodes in the cluster.  defaults to 1

Outputs:
  url - url for the Memcached cluster
  port - port the Memcached cluster is configured on
  security_group_id - security group assigned to the cluster

**************************************************************************/


#
# Module Inputs
#
variable "vpc_id" {}
variable "ami" {}
variable "ssh_key" {}
variable "subnet_id" {}
variable "name" {}
variable "environment" {}
variable "roles" {}
variable "project" {}

variable "instance_type" {
  default = "m3.medium"
}

variable "count" {
  default = "1"
}

variable "node_security_group" {
  default = "node_traffic"
}

resource "aws_security_group" "elb_web_traffic" {
  name = "${var.name}-${var.environment}-lb-traffic"
  vpc_id = "${var.vpc_id}"
  description = "Allow all inbound traffic to port 80 to ELB"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "node_web_traffic" {
  name = "${var.name}-${var.environment}-node-web-traffic"
  vpc_id = "${var.vpc_id}"
  description = "Allow all inbound traffic to port 80 from the LB"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = ["${aws_security_group.elb_web_traffic.id}"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_elb" "elb" {
  name = "${var.project}-${var.environment}"
  subnets = ["${var.subnet_id}"]
  count = 1

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:80/up"
    interval = 15
  }

  instances = ["${split(",", module.instance.instance_ids)}"]
  security_groups = [ "${aws_security_group.elb_web_traffic.id}" ]
}

module "instance" {
  source = "github.com/mondorobot/terraform-instance"

  vpc_id = "${var.vpc_id}"
  ami = "${var.ami}"
  ssh_key = "${var.ssh_key}"
  subnet_id = "${var.subnet_id}"
  name = "${var.name}"
  environment = "${var.environment}"
  roles = "${var.roles}"
  project = "${var.project}"
  additional_security_group_ids = "${aws_security_group.node_web_traffic.id}"
}



output "elb_hostname" {
  value = "${aws_elb.elb.dns_name}"
}


output "node_security_group_id" {
  value = "${module.instance.instance_security_group_id}"
}


/*
resource "aws_security_group" "ssh_traffic" {
  name = "${var.name}-${var.environment}-ssh-traffic"
  vpc_id = "${var.vpc_id}"
  description = "Allow all inbound traffic to port 22"
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "node_traffic" {
  name = "${var.node_security_group}"
  vpc_id = "${var.vpc_id}"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = ["${aws_security_group.web_traffic.id}"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_instance" "web" {
  ami = "${var.ami}"
  instance_type = "${var.instance_type}"
  key_name = "${var.ssh_key}"
  subnet_id = "${var.subnet_id}"
  count = "${var.count}"

  vpc_security_group_ids = [
    "${aws_security_group.ssh_traffic.id}",
    "${aws_security_group.node_traffic.id}"
  ]

  tags {
    Name = "${var.name} Web ${count.index+1} ${var.environment}"
    Project = "${var.project}"
    Roles = "${var.roles}"
    Stage = "${var.environment}"
  }
}
*/
