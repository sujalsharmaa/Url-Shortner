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

# Security Groups
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Replace with specific IP ranges
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "alb-security-group"
    Environment = local.env
  }
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


# Node.js Server
# resource "aws_instance" "nodejs_server" {
#   ami                    = "ami-0866a3c8686eaeeba"
#   instance_type          = "t3.medium"
#   subnet_id              = aws_subnet.public_zone1.id
#   associate_public_ip_address = true
#   security_groups     = [aws_security_group.ec2_sg.id]

#     root_block_device {
#       volume_size = 30
#       volume_type = "gp3"
#     }

#   user_data = file("./userdata-nodejs.sh")

#   tags = {
#     Name = "NodeJS Server"
#   }
#   depends_on = [ aws_db_instance.postgres ]
# }

# # Python Server
# resource "aws_instance" "python_server" {
#   ami                    = "ami-0866a3c8686eaeeba"
#   instance_type          = "t3.medium"
#   subnet_id              = aws_subnet.public_zone2.id
#   associate_public_ip_address = true
#   security_groups     = [aws_security_group.ec2_sg.id]

#     root_block_device {
#       volume_size = 30
#       volume_type = "gp3"
#     }

#   user_data = file("./userdata-python.sh")

#   tags = {
#     Name = "Python Server"
#   }
#   depends_on = [ aws_db_instance.postgres ]

# }

# Monitoring Server
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

#---------------------------------------------ASG-----------------------------------#

# Launch Template for Node.js Server
resource "aws_launch_template" "nodejs_launch_template" {
  name_prefix   = "nodejs-launch-template"
  image_id      = "ami-0866a3c8686eaeeba"
  instance_type = "t3.medium"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 30
      volume_type = "gp3"
    }
  }

  user_data = base64encode(file("./userdata-nodejs.sh"))

  tags = {
    Name        = "NodeJS Launch Template"
    Environment = local.env
  }
}

# Autoscaling Group for Node.js Server
resource "aws_autoscaling_group" "nodejs_asg" {
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.nodejs_service.arn]
  vpc_zone_identifier = [aws_subnet.public_zone1.id, aws_subnet.public_zone2.id]

  launch_template {
    id      = aws_launch_template.nodejs_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "NodeJS ASG"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = local.env
    propagate_at_launch = true
  }

  depends_on = [aws_db_instance.postgres]
}

# Launch Template for Python Server
resource "aws_launch_template" "python_launch_template" {
  name_prefix   = "python-launch-template"
  image_id      = "ami-0866a3c8686eaeeba"
  instance_type = "t3.medium"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 30
      volume_type = "gp3"
    }
  }

  user_data = base64encode(file("./userdata-python.sh"))

  tags = {
    Name        = "Python Launch Template"
    Environment = local.env
  }
}

# Autoscaling Group for Python Server
resource "aws_autoscaling_group" "python_asg" {
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.python_service.arn]
  vpc_zone_identifier = [aws_subnet.public_zone1.id, aws_subnet.public_zone2.id]

  launch_template {
    id      = aws_launch_template.python_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "Python ASG"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = local.env
    propagate_at_launch = true
  }

  depends_on = [aws_db_instance.postgres]
}


#--------------------------------------ASG--------------------------------------------#

# Target Groups
resource "aws_lb_target_group" "python_service" {
  name     = "python-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  tags = {
    Name        = "python-target-group"
    Environment = local.env
  }
}

resource "aws_lb_target_group" "nodejs_service" {
  name     = "nodejs-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  tags = {
    Name        = "nodejs-target-group"
    Environment = local.env
  }
}


# CloudWatch Alarms and Scaling Policies for Node.js ASG
resource "aws_cloudwatch_metric_alarm" "nodejs_cpu_high" {
  alarm_name          = "nodejs-high-cpu-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "50"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.nodejs_asg.name
  }

  alarm_description = "This metric monitors nodejs ec2 cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.nodejs_scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "nodejs_cpu_low" {
  alarm_name          = "nodejs-low-cpu-utilization"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "20"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.nodejs_asg.name
  }

  alarm_description = "This metric monitors nodejs ec2 cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.nodejs_scale_down.arn]
}

resource "aws_autoscaling_policy" "nodejs_scale_up" {
  name                   = "nodejs-scale-up-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.nodejs_asg.name
}

resource "aws_autoscaling_policy" "nodejs_scale_down" {
  name                   = "nodejs-scale-down-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.nodejs_asg.name
}

# CloudWatch Alarms and Scaling Policies for Python ASG
resource "aws_cloudwatch_metric_alarm" "python_cpu_high" {
  alarm_name          = "python-high-cpu-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "50"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.python_asg.name
  }

  alarm_description = "This metric monitors python ec2 cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.python_scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "python_cpu_low" {
  alarm_name          = "python-low-cpu-utilization"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "20"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.python_asg.name
  }

  alarm_description = "This metric monitors python ec2 cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.python_scale_down.arn]
}

resource "aws_autoscaling_policy" "python_scale_up" {
  name                   = "python-scale-up-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.python_asg.name
}

resource "aws_autoscaling_policy" "python_scale_down" {
  name                   = "python-scale-down-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.python_asg.name
}




# Application Load Balancer
resource "aws_lb" "nodejs-lb" {
  name               = "nodejs-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_zone1.id, aws_subnet.public_zone2.id]
  tags = {
    Name        = "nodejs-load-balancer"
    Environment = local.env
  }
}


resource "aws_lb" "python-lb" {
  name               = "python-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_zone1.id, aws_subnet.public_zone2.id]
  tags = {
    Name        = "python-load-balancer"
    Environment = local.env
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.nodejs-lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nodejs_service.arn
  }
  tags = {
    Name        = "http-listener"
    Environment = local.env
  }
}

resource "aws_lb_listener" "python-listener" {
  load_balancer_arn = aws_lb.python-lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.python_service.arn
  }
  tags = {
    Name        = "http-listener"
    Environment = local.env
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_lb.nodejs-lb.dns_name
    origin_id   = "NodeJSALB"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]

      # Add custom headers to allow CORS from origin
      origin_read_timeout    = 60
      origin_keepalive_timeout = 60
    }

    # Add custom origin headers if needed
    custom_header {
      name  = "Access-Control-Allow-Origin"
      value = "*"
    }
  }

  enabled = true
  
  default_cache_behavior {
    target_origin_id       = "NodeJSALB"
    viewer_protocol_policy = "redirect-to-https"
    
    # Allow all HTTP methods
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    
    # Min TTL of 0 to ensure OPTIONS requests aren't cached too long
    min_ttl          = 0
    default_ttl      = 3600
    max_ttl          = 86400
    
    forwarded_values {
      query_string = true
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
      
      cookies {
        forward = "none"
      }
    }

    # Add response headers for CORS
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_policy.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "cdn-distribution"
    Environment = local.env
  }
}

# Create a response headers policy for CORS
resource "aws_cloudfront_response_headers_policy" "cors_policy" {
  name    = "cors-policy"
  comment = "CORS policy for CloudFront distribution"

  cors_config {
    access_control_allow_credentials = false
    
    access_control_allow_headers {
      items = ["*"]
    }
    
    access_control_allow_methods {
      items = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    }
    
    access_control_allow_origins {
      items = ["*"]
    }
    
    origin_override = true
  }

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains        = true
      override                  = true
    }
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
resource "aws_route53_zone" "backend_python" {
  name          = "backend.python.com"
  vpc {
    vpc_id = aws_vpc.main.id
  }
}

resource "aws_route53_zone" "backend_nodejs" {
  name          = "backend.nodejs.com"
  vpc {
    vpc_id = aws_vpc.main.id
  }
}
resource "aws_route53_record" "python_lb" {
  zone_id = aws_route53_zone.backend_python.zone_id
  name    = "backend.python.com"
  type    = "A"
  alias {
    name                   = aws_lb.python-lb.dns_name
    zone_id               = aws_lb.python-lb.zone_id
    evaluate_target_health = true
  }
}


resource "aws_route53_record" "nodejs-lb" {
  zone_id = aws_route53_zone.backend_nodejs.id
  name    = "backend.nodejs.com"
  type    = "A"
  alias {
    name                   = aws_lb.nodejs-lb.dns_name
    zone_id               = aws_lb.nodejs-lb.zone_id
    evaluate_target_health = true
  }
}
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



output "aws_cloudfront_distribution" {
  value = "http://${aws_cloudfront_distribution.cdn.domain_name}"
  description = "The domain name of cloudfront"
  depends_on = [aws_cloudfront_distribution.cdn]
}



resource "aws_cloudwatch_dashboard" "infrastructure_dashboard" {
  dashboard_name = "${local.env}-advanced-infrastructure-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      // EC2 Metrics - Node.js ASG
      {
        type   = "metric",
        x      = 0,
        y      = 0,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/EC2",
             "CPUUtilization",
              "AutoScalingGroupName", 
              "${aws_autoscaling_group.nodejs_asg.id}"],
            [".", "NetworkIn", ".", "."],
            [".", "NetworkOut", ".", "."],
            [".", "DiskReadOps", ".", "."],
            [".", "DiskWriteOps", ".", "."],
            [".", "StatusCheckFailed", ".", "."]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = "${local.region}",
          title   = "Node.js Server - Detailed Metrics",
          period  = 300
        }
      },
      
      // EC2 Metrics - Python ASG
      {
        type   = "metric",
        x      = 12,
        y      = 0,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "${aws_autoscaling_group.python_asg.name}"],
            [".", "NetworkIn", ".", "."],
            [".", "NetworkOut", ".", "."],
            [".", "DiskReadOps", ".", "."],
            [".", "DiskWriteOps", ".", "."],
            [".", "StatusCheckFailed", ".", "."]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = "${local.region}",
          title   = "Python Server - Detailed Metrics",
          period  = 300
        }
      },
      
      // RDS Metrics
      {
        type   = "metric",
        x      = 0,
        y      = 6,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.postgres.identifier],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeStorageSpace", ".", "."],
            [".", "ReadIOPS", ".", "."],
            [".", "WriteIOPS", ".", "."],
            [".", "EngineUptime", ".", "."]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = "${local.region}",
          title   = "PostgreSQL RDS - Advanced Metrics",
          period  = 300
        }
      },
      
      // Load Balancer Metrics - Node.js
      {
        type   = "metric",
        x      = 12,
        y      = 6,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.nodejs-lb.arn],
            [".", "TargetResponseTime", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."],
            [".", "HealthyHostCount", ".", "."],
            [".", "UnHealthyHostCount", ".", "."],
            [".", "ActiveConnectionCount", ".", "."],
            [".", "ProcessedBytes", ".", "."]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = "${local.region}",
          title   = "Node.js Load Balancer - Detailed Metrics",
          period  = 300
        }
      },
      
      // Load Balancer Metrics - Python
      {
        type   = "metric",
        x      = 0,
        y      = 12,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.python-lb.arn],
            [".", "TargetResponseTime", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."],
            [".", "HealthyHostCount", ".", "."],
            [".", "UnHealthyHostCount", ".", "."],
            [".", "ActiveConnectionCount", ".", "."],
            [".", "ProcessedBytes", ".", "."]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = "${local.region}",
          title   = "Python Load Balancer - Detailed Metrics",
          period  = 300
        }
      },
      
      // Auto Scaling Group Metrics
      {
        type   = "metric",
        x      = 12,
        y      = 12,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/AutoScaling", "GroupTotalInstances", "AutoScalingGroupName", aws_autoscaling_group.nodejs_asg.name],
            [".", "GroupInServiceInstances", ".", "."],
            [".", "GroupPendingInstances", ".", "."],
            [".", "GroupTerminatingInstances", ".", "."],
            [".", "GroupTotalInstances", "AutoScalingGroupName", aws_autoscaling_group.python_asg.name],
            [".", "GroupInServiceInstances", ".", "."],
            [".", "GroupPendingInstances", ".", "."],
            [".", "GroupTerminatingInstances", ".", "."]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = "${local.region}",
          title   = "Auto Scaling Group - Comprehensive Metrics",
          period  = 300
        }
      },
      
      // CloudFront Metrics
      {
        type   = "metric",
        x      = 0,
        y      = 18,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", aws_cloudfront_distribution.cdn.domain_name],
            [".", "BytesDownloaded", ".", "."],
            [".", "BytesUploaded", ".", "."],
            [".", "TotalErrorRate", ".", "."],
            [".", "4xxErrorRate", ".", "."],
            [".", "5xxErrorRate", ".", "."]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = "us-east-1",
          title   = "CloudFront Distribution - Performance Metrics",
          period  = 300
        }
      },
      
      // Network Metrics
      {
        type   = "metric",
        x      = 12,
        y      = 18,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/VPC", "ActiveConnections", "VpcId", aws_vpc.main.id],
            [".", "PacketsIn", ".", "."],
            [".", "PacketsOut", ".", "."],
            ["AWS/NATGateway", "BytesOut", "NatGatewayId", aws_nat_gateway.nat.id],
            [".", "BytesIn", ".", "."],
            [".", "PacketsOut", ".", "."]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = "${local.region}",
          title   = "Network & NAT Gateway Metrics",
          period  = 300
        }
      }
    ]
  })
}

# Data source for current region
data "aws_region" "current" {}

# Output the dashboard name
output "cloudwatch_dashboard_name" {
  value       = aws_cloudwatch_dashboard.infrastructure_dashboard.dashboard_arn
  description = "Name of the created advanced CloudWatch dashboard"
}