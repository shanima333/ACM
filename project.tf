################################################################
# Provider Configuration
################################################################

provider "aws"  {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

################################################################
# VPC creation
################################################################

variable "vpc" {
        type = map
        default = {
        "name" = "clb"
        "cidr" = "10.0.0.0/16"
        }
}

resource "aws_vpc" "vpc1" {
  cidr_block       = var.vpc.cidr
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc.name
  }
}


################################################################
# subnet variable declaration
################################################################

variable "subnet" {
        type = map
        default = {
        "name1" = "clb-public1"
	"name2" = "clb-public2"
	"name3" = "clb-private1"
       	"name4" = "clb-private2"
        "cidr1" = "10.0.0.0/18"
	"cidr2" = "10.0.64.0/18"
	"cidr3" = "10.0.128.0/18"
	"cidr4" = "10.0.192.0/18"
	"cidr" = "0.0.0.0/0"
        "zone1" = "us-east-1a"
	"zone2" = "us-east-1b"
	"zone3" = "us-east-1c"
	"zone4" = "us-east-1d"
	}
}


################################################################
#public subnet - 1  creation
################################################################

resource "aws_subnet" "public1" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = var.subnet.cidr1
  availability_zone = var.subnet.zone1
  map_public_ip_on_launch = true

  tags = {
    Name = var.subnet.name1
  }
}

resource "aws_subnet" "public2" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = var.subnet.cidr2
  availability_zone = var.subnet.zone2
  map_public_ip_on_launch = true

  tags = {
    Name = var.subnet.name2
  }
}

##################################################################
# Route 53
##################################################################

resource "aws_route53_zone" "website1" {
  name = "www.shanimakthahir.xyz"
}


################################################################
#private subnet - 1  creation
################################################################

resource "aws_subnet" "private1" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = var.subnet.cidr3
  availability_zone = var.subnet.zone3
  tags = {
    Name = var.subnet.name3
  }
}


resource "aws_subnet" "private2" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = var.subnet.cidr4
  availability_zone = var.subnet.zone4
  tags = {
    Name = var.subnet.name4
  }
}

################################################################
#internet gateway  creation
################################################################


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc1.id

  tags = {
    Name = "clb-igw"
  }
}

################################################################
#public route table  creation
################################################################

resource "aws_route_table" "public-RT" {
  vpc_id = aws_vpc.vpc1.id

  route {
    cidr_block = var.subnet.cidr
    gateway_id = aws_internet_gateway.igw.id
        }
   tags = {
        Name ="public-RT"
        }
}

################################################################
#public route table  association
################################################################

resource "aws_route_table_association" "public-RT" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public-RT.id
}

resource "aws_route_table_association" "public-RT2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public-RT.id
}


################################################################
#eip creation
################################################################

resource "aws_eip" "nat" {
  vpc      = true
  tags = {
    Name = "clb-eip"
  }
}


################################################################
#nat gateway creation
################################################################


resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public2.id

  tags = {
    Name = "clb-NAT"
  }
}

################################################################
#private route table  creation
################################################################

resource "aws_route_table" "private-RT" {
  vpc_id = aws_vpc.vpc1.id

  route {
    cidr_block = var.subnet.cidr
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "clb-private-RT"
         }
}


################################################################
#private subnet 1 to route table  association
################################################################

resource "aws_route_table_association" "private1-RT" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private-RT.id
}

resource "aws_route_table_association" "private2-RT" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private-RT.id
}


################################################################
#security group 
################################################################


resource "aws_security_group" "sg1" {
  name        = "clb-sg"
  description = "Allow from all"
  vpc_id      = aws_vpc.vpc1.id


ingress {
    description = "allow from all"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.subnet.cidr]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.subnet.cidr]
  }

  tags = {
    Name = "clb-sg"
  }
}

################################################################
#keypair
################################################################

variable "key" {
}

resource "aws_key_pair" "key" {
  key_name   = "ohio"
  public_key = var.key
}

#################################################################
# LC variable declaration
##################################################################

variable "lc" {
        type = map
        default = {
        image = "ami-04d29b6f966df1537"
        type = "t2.micro"

}
}

#################################################################
# Blue Launch Configuration
##################################################################

resource "aws_launch_configuration" "lc1" {

  image_id = var.lc.image
  instance_type = var.lc.type
  key_name = aws_key_pair.key.id
  security_groups = [ aws_security_group.sg1.id ]
  user_data = file("setup.sh")

  lifecycle {
    create_before_destroy = true
  }

}

#################################################################
#  ACM
##################################################################

resource "aws_acm_certificate" "cert" {
  domain_name       = "shanimakthahir.xyz"
  validation_method = "DNS"


  lifecycle {
    create_before_destroy = true
  }
}

#################################################################
#  ACM pending validation
##################################################################


resource "aws_route53_record" "website1" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.website1.zone_id
}

resource "aws_acm_certificate_validation" "website" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.website1 : record.fqdn]
}

##################################################################
#  Load balancer
##################################################################

variable "lb1" {
        type = map
        default = {
        "port" = "80"
	"port2" = "443"
        "protocol" = "http"
	"protocol2" = "https"
        "name" = "clb"
}
}

resource "aws_elb" "lb1" {
  name               = var.lb1.name
  security_groups = [aws_security_group.sg1.id]

  listener {
    instance_port      = var.lb1.port
    instance_protocol  = var.lb1.protocol
    lb_port            = var.lb1.port2
    lb_protocol        = var.lb1.protocol2
    ssl_certificate_id = "arn:aws:acm:us-east-1:957744656220:certificate/9492d8ec-b57f-4eff-a3e4-02c21374704e"

  }

 subnets = [aws_subnet.public1.id, aws_subnet.public2.id]

  cross_zone_load_balancing   = true
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/index.php"
    interval            = 15
  }
   tags = {
    Name = var.lb1.name
  }
}

##################################################################
# Autoscaling
##################################################################

variable "asg" {
        type = map
        default = {
        "name" = "clb-ASG"
        "min"     = "2"
        "desired" = "2"
        "max"     = "3"
        "period"  = "120"
        "type"    = "EC2"
        "value"   = "webserver"
}
}


  resource "aws_autoscaling_group" "asg1" {
  name                 = var.asg.name
  launch_configuration = aws_launch_configuration.lc1.name
  min_size             = var.asg.min
  desired_capacity     = var.asg.desired
  max_size             = var.asg.max
  health_check_grace_period = var.asg.period
  health_check_type         = var.asg.type
  load_balancers        = [aws_elb.lb1.id]
  vpc_zone_identifier = [aws_subnet.public1.id, aws_subnet.public2.id]
  tag {
    key = "Name"
    propagate_at_launch = true
    value = var.asg.value
  }
  lifecycle {
   create_before_destroy = true
  }
}

##################################################################
# Record
##################################################################

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.website1.zone_id
  name    = "www.shanimakthahir.xyz"
  type    = "CNAME"
  ttl     = "10"
  records = [aws_elb.lb1.dns_name]
}
