provider aws {
  region = "eu-north-1"
}

resource aws_vpc silly_vpc {
  cidr_block = "10.0.0.0/16"
}

# Internet Gateway
resource aws_internet_gateway igw {
  vpc_id = aws_vpc.silly_vpc.id
}

# Public Subnets in each Availability Zone
resource aws_subnet public_subnet_a {
  vpc_id            = aws_vpc.silly_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-north-1a"
  map_public_ip_on_launch = true
}

resource aws_subnet public_subnet_b {
  vpc_id            = aws_vpc.silly_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-north-1b"
  map_public_ip_on_launch = true
}

resource aws_subnet public_subnet_c {
  vpc_id            = aws_vpc.silly_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-north-1c"
  map_public_ip_on_launch = true
}

# Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.silly_vpc.id

  route {
    cidr_block = "0.0.0.0/0"  # All internet traffic
    gateway_id = aws_internet_gateway.igw.id  # Route to the Internet Gateway
  }

  tags = {
    Name = "public-route-table"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_subnet_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_c" {
  subnet_id      = aws_subnet.public_subnet_c.id
  route_table_id = aws_route_table.public_route_table.id
}

resource aws_security_group ec2_sg {
  vpc_id = aws_vpc.silly_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # All traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource aws_instance silly_demo_ec2 {
  ami                         = "ami-0bcf98c2c6db6c5f4" 
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnet_a.id
  security_groups             = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "silly-demo"
  }

  user_data = <<-EOF
              yum update -y
              yum install -y git nginx postgresql
              amazon-linux-extras install nginx1 -y
              systemctl enable nginx
              systemctl start nginx

              cat << 'EOL' > /etc/nginx/conf.d/silly-demo.conf
              server {
                  listen 80;
                  server_name _;

                  location / {
                      proxy_pass http://localhost:3000;  # Update if necessary
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;
                  }
              }
              EOL
              # Restart Nginx to apply the new configuration
              systemctl restart nginx
              EOF
}

# Security Group for RDS
resource aws_security_group rds_sg {
  vpc_id = aws_vpc.silly_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]  # Correctly reference security group
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # All traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource aws_db_subnet_group silly_demo_db_subnets {
  name       = "silly-demo-db-subnet-group"
  subnet_ids = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id, aws_subnet.public_subnet_c.id]
}

resource aws_db_instance silly_demo_rds {
  identifier              = "silly-demo-db"
  instance_class          = "db.t4g.micro"
  allocated_storage       = 20
  engine                  = "postgres"
  engine_version          = 13
  db_name                 = "sillydemo"
  username                = "admin1"
  password                = "admin123"
  parameter_group_name    = "default.postgres13"
  db_subnet_group_name    = aws_db_subnet_group.silly_demo_db_subnets.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  skip_final_snapshot     = true
  publicly_accessible     = false
}
