# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = local.env
    Environment = local.env
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name        = "${local.env}-igw"
    Environment = local.env
  }
}

# Public and Private Subnets
resource "aws_subnet" "private_zone1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/19"
  availability_zone = local.zone1
  tags = {
    Name        = "${local.env}-private-${local.zone1}"
    Environment = local.env
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "private_zone2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.32.0/19"
  availability_zone = local.zone2
  tags = {
    Name        = "${local.env}-private-${local.zone2}"
    Environment = local.env
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "public_zone1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.64.0/19"
  availability_zone = local.zone1
  tags = {
    Name        = "${local.env}-public-${local.zone1}"
    Environment = local.env
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public_zone2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.96.0/19"
  availability_zone = local.zone2
  tags = {
    Name        = "${local.env}-public-${local.zone2}"
    Environment = local.env
    "kubernetes.io/role/elb" = "1"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name        = "${local.env}-nat"
    Environment = local.env
  }
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_zone1.id
  tags = {
    Name        = "${local.env}-nat"
    Environment = local.env
  }
}

# Second NAT Gateway for redundancy
resource "aws_eip" "nat_zone2" {
  domain = "vpc"
  tags = {
    Name        = "${local.env}-nat-zone2"
    Environment = local.env
  }
}

resource "aws_nat_gateway" "nat_zone2" {
  allocation_id = aws_eip.nat_zone2.id
  subnet_id     = aws_subnet.public_zone2.id
  tags = {
    Name        = "${local.env}-nat-zone2"
    Environment = local.env
  }
}

# Route Tables and Associations
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name        = "${local.env}-private"
    Environment = local.env
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name        = "${local.env}-public"
    Environment = local.env
  }
}

resource "aws_route_table_association" "private_zone1" {
  subnet_id      = aws_subnet.private_zone1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_zone2" {
  subnet_id      = aws_subnet.private_zone2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public_zone1" {
  subnet_id      = aws_subnet.public_zone1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_zone2" {
  subnet_id      = aws_subnet.public_zone2.id
  route_table_id = aws_route_table.public.id
}


resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Security group for EC2"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "ec2-security-group"
    Environment = local.env
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port                = 5432
    to_port                  = 5432
    protocol                 = "tcp"
    security_groups          = [aws_security_group.ec2_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "rds-security-group"
    Environment = local.env
  }
}


# RDS Configuration
resource "aws_db_subnet_group" "postgres-rds" {
  name       = "postgres-rds"
  subnet_ids = [aws_subnet.private_zone1.id, aws_subnet.private_zone2.id]
  tags = {
    Name        = "postgres-rds"
    Environment = local.env
  }
}


resource "aws_db_instance" "postgres" {
  identifier             = "postgres"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "16.3"
  username               = "postgres"
  password               = "postgres"
  db_subnet_group_name   = aws_db_subnet_group.postgres-rds.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
#   parameter_group_name   = aws_db_parameter_group.db_parameter_group.name
  publicly_accessible    = false
  skip_final_snapshot    = false
  backup_retention_period = 7
  tags = {
    Name        = "postgres-instance"
    Environment = local.env
  }
} 


resource "aws_instance" "monitoring" {
  ami                    = "ami-0866a3c8686eaeeba"
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public_zone1.id
  associate_public_ip_address = true
  security_groups    = [aws_security_group.ec2_sg.id]

    root_block_device {
      volume_size = 30
      volume_type = "gp3"
    }

  user_data = file("./userdata-monitoring.sh")

  tags = {
    Name = "Monitoring Server"
  }
}




resource "aws_route53_zone" "backend_postgres" {
  name          = "backend.postgres.com"
  vpc {
    vpc_id = aws_vpc.main.id
  }
}

resource "aws_route53_record" "postgres_rds" {
  zone_id = aws_route53_zone.backend_postgres.zone_id
  name    = "postgres.backend.postgres.com"  # Using a subdomain
  type    = "CNAME"
  ttl     = 300
  records = [replace(aws_db_instance.postgres.endpoint, ":5432", "")]  # Remove the port number from endpoint
}
# Python Backend Zone and Record






# Redis Backend Zone and Record
resource "aws_route53_zone" "backend_redis" {
  name          = "backend.redis.com"
  vpc {
    vpc_id = aws_vpc.main.id
  }
}

output "monitoring_instance_public_ip" {
  value       = aws_instance.monitoring.public_ip
  description = "The public IP of the monitoring instance"
}

resource "aws_route53_record" "backend_redis_record" {
  zone_id = aws_route53_zone.backend_redis.zone_id
  name    = "backend.redis.com"
  type    = "A"
  ttl     = 300
  records = [aws_instance.monitoring.public_ip]
}






