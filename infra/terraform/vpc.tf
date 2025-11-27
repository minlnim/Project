########################################
# VPC & Networking
########################################

# 기존 Seoul 인프라의 VPC를 사용하므로 VPC 생성 로직은 비활성화
# main.tf의 remote state에서 vpc_id와 subnet_ids를 가져옴

locals {
  # AZ 목록
  azs = ["ap-northeast-2a", "ap-northeast-2c"]
  
  # 기존 VPC 사용 (새로 생성하지 않음)
  create_vpc = false
}

# VPC 생성 (비활성화)
resource "aws_vpc" "this" {
  count = local.create_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, {
    Name = "${local.project}-${local.env}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  count = local.create_vpc ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  tags = merge(local.tags, {
    Name = "${local.project}-${local.env}-igw"
  })
}

# Public Subnets (NAT Gateway용)
resource "aws_subnet" "public" {
  count = local.create_vpc ? length(local.azs) : 0

  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name                     = "${local.project}-${local.env}-public-${local.azs[count.index]}"
    "kubernetes.io/role/elb" = "1"
  })
}

# Private Subnets (EKS, RDS, NLB용)
resource "aws_subnet" "private" {
  count = local.create_vpc ? length(local.azs) : 0

  vpc_id            = aws_vpc.this[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]

  tags = merge(local.tags, {
    Name                              = "${local.project}-${local.env}-private-${local.azs[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count = local.create_vpc ? length(local.azs) : 0

  domain = "vpc"

  tags = merge(local.tags, {
    Name = "${local.project}-${local.env}-nat-eip-${local.azs[count.index]}"
  })
}

# NAT Gateway
resource "aws_nat_gateway" "this" {
  count = local.create_vpc ? length(local.azs) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.tags, {
    Name = "${local.project}-${local.env}-nat-${local.azs[count.index]}"
  })

  depends_on = [aws_internet_gateway.this]
}

# Public Route Table
resource "aws_route_table" "public" {
  count = local.create_vpc ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = merge(local.tags, {
    Name = "${local.project}-${local.env}-public-rt"
  })
}

# Public Route Table Association
resource "aws_route_table_association" "public" {
  count = local.create_vpc ? length(local.azs) : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Private Route Tables (각 AZ별)
resource "aws_route_table" "private" {
  count = local.create_vpc ? length(local.azs) : 0

  vpc_id = aws_vpc.this[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge(local.tags, {
    Name = "${local.project}-${local.env}-private-rt-${local.azs[count.index]}"
  })
}

# Private Route Table Association
resource "aws_route_table_association" "private" {
  count = local.create_vpc ? length(local.azs) : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
