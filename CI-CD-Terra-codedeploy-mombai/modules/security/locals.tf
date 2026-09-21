locals {
  database_sg = {
    mysql = {
      name = "internal-mysql-sg"
      port = 3306
    }

    mariadb = {
      name = "internal-mariadb-sg"
      port = 3306
    }

    postgresql = {
      name = "internal-postgresql-sg"
      port = 5432
    }

    oracle = {
      name = "internal-oracle-sg"
      port = 1521
    }

    mssql = {
      name = "internal-mssql-sg"
      port = 1433
    }

    redis = {
      name = "internal-redis-sg"
      port = 6379
    }
  }
}
