
resource "aws_secretsmanager_secret" "data_platform_db" {
  name = "data_platform_db"
}

resource "aws_db_subnet_group" "data_platform" {
  name       = "data_platform"
  subnet_ids = [aws_subnet.data_platform.id, aws_subnet.data_platform_d.id]

  tags = {}
}

resource "aws_db_instance" "data_platform" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "12.5"
  instance_class       = "db.t3.micro"
  name                 = "dataplatform"
  username             = "postgres"
  password             = "temptemptemptemp"
  parameter_group_name = "default.postgres12"
  db_subnet_group_name = aws_db_subnet_group.data_platform.name

  skip_final_snapshot                 = true
  iam_database_authentication_enabled = true
  auto_minor_version_upgrade          = false
  copy_tags_to_snapshot               = false


  availability_zone = "us-east-1c"
  backup_retention_period = 0
  customer_owned_ip_enabled = false
  delete_automated_backups = true
  deletion_protection = false
  enabled_cloudwatch_logs_exports = []
  identifier = "dataplatform"
  multi_az = false
  performance_insights_enabled = false
  publicly_accessible = false
  storage_encrypted = false
  storage_type = "gp2"
  tags = {}
  vpc_security_group_ids = ["sg-0c3b81d8c1f090942"]

}

resource "aws_db_proxy" "data_platform" {
  name                   = "dataplatform"
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.data_platform_rds_proxy.arn
  vpc_security_group_ids = [ "sg-0c3b81d8c1f090942" ]
  vpc_subnet_ids         = [aws_subnet.data_platform.id, aws_subnet.data_platform_d.id]

  auth {
    auth_scheme = "SECRETS"
    description = "data_platform_db_password"
    iam_auth    = "REQUIRED"
    secret_arn  = aws_secretsmanager_secret.data_platform_db.arn
  }

  tags = {}

  timeouts {
    create = null
    delete = null
    update = null
  }
}

resource "aws_db_proxy_default_target_group" "data_platform" {
  db_proxy_name = aws_db_proxy.data_platform.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    init_query                   = ""
    max_connections_percent      = 100
    max_idle_connections_percent = 50
    session_pinning_filters      = []
  }

  timeouts {
    create = null
    update = null
  }
}

resource "aws_db_proxy_target" "data_platform" {
  db_instance_identifier = aws_db_instance.data_platform.id
  db_proxy_name          = aws_db_proxy.data_platform.name
  target_group_name      = aws_db_proxy_default_target_group.data_platform.name
}
