resource "aws_instance" "music_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.small"
  iam_instance_profile   = aws_iam_instance_profile.ec2_s3_profile.name
  vpc_security_group_ids = [aws_security_group.music_server.id]

  root_block_device {
    volume_size = 25
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/mount-s3.sh", {
    s3_bucket = var.s3_bucket_name
  })

  tags = {
    Name = "swing-music-server"
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "ec2_s3_role" {
  name = "ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "ec2-s3-access-policy"
  role = aws_iam_role.ec2_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "ec2-s3-profile"
  role = aws_iam_role.ec2_s3_role.name
}

resource "aws_security_group" "music_server" {
  name = "music-server-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 1970
    to_port     = 1970
    protocol    = "tcp"
    cidr_blocks = [var.allowed_swingmusic_cidr]
  }

  # TODO: So deus saberá quando eu vou comprar DNS e criar um certificado SSL
  # ingress {
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "music-server-sg"
  }
}

output "ec2_public_ip" {
  value       = aws_instance.music_server.public_ip
  description = "Public IP of the EC2 instance"
}

output "ec2_private_ip" {
  value       = aws_instance.music_server.private_ip
  description = "Private IP of the EC2 instance"
}
