# AZ that are available to your account.
data "aws_availability_zones" "available_zones" {
  state = "available"
}

# Create VPC
resource "aws_vpc" "default" {
  cidr_block = "10.10.0.0/16"
}

# Subnet public
resource "aws_subnet" "public" {
  count                   = var.number_sub
  cidr_block              = cidrsubnet(aws_vpc.default.cidr_block, 8, 2 + count.index)
  availability_zone       = data.aws_availability_zones.available_zones.names[count.index]
  vpc_id                  = aws_vpc.default.id
  map_public_ip_on_launch = true
}

# Subnet private.
resource "aws_subnet" "private" {
  count             = var.number_sub
  cidr_block        = cidrsubnet(aws_vpc.default.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available_zones.names[count.index]
  vpc_id            = aws_vpc.default.id
}

# The internet gateway: allows communication between the VPC and the internet at all.
resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.default.id
}

# The route table public access
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.default.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gateway.id
}

resource "aws_eip" "gateway" {
  count      = var.number_sub
  vpc        = true
  depends_on = [aws_internet_gateway.gateway]
}

# NAT gateway: allows resources within the VPC to communicate with the internet.
resource "aws_nat_gateway" "gateway" {
  count         = var.number_sub
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  allocation_id = element(aws_eip.gateway.*.id, count.index)
}

# The route table private access
resource "aws_route_table" "private" {
  count  = var.number_sub
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.gateway.*.id, count.index)
  }
}

# Association route table in subnet
resource "aws_route_table_association" "private" {
  count          = var.number_sub
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

# The SG will only allow traffic to the LB on port 80
resource "aws_security_group" "lb" {
  name        = "example-alb-security-group"
  vpc_id      = aws_vpc.default.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Attaches it to the public subnet in each availability zone
resource "aws_lb" "default" {
  name            = "webapp-lb"
  subnets         = aws_subnet.public.*.id
  security_groups = [aws_security_group.lb.id]
}

# Forward incoming traffic on port 80 
resource "aws_lb_target_group" "webapp" {
  name        = "webapp80"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.default.id
  target_type = "ip"
}

resource "aws_lb_listener" "webapp" {
  load_balancer_arn = aws_lb.default.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.webapp.id
    type             = "forward"
  }
}

# The SG will only allow traffic on port 80
resource "aws_security_group" "webapp" {
  name        = "example-task-security-group"
  vpc_id      = aws_vpc.default.id

  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = [aws_security_group.lb.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}