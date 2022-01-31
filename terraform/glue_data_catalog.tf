
resource "aws_glue_catalog_table" "data_platform_incoming__vendor__sample" {
  name          = "incoming__vendor__sample"
  database_name = aws_glue_catalog_database.data_platform.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification" = "csv"
    "skip.header.line.count" = "1"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_platform.id}/incoming/vendor/SAMPLE/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"

      parameters = {
        "separatorChar" = ","
      }
    }

    columns {
      name = "sample_id"
      type = "int"
    }

    columns {
      name = "sample_name"
      type = "string"
    }

    columns {
      name    = "inserted_dtm"
      type    = "string"
    }

    columns {
      name    = "updated_dtm"
      type    = "string"
    }
  }
}

resource "aws_glue_catalog_table" "data_platform_springboard__vendor__sample" {
  name          = "springboard__vendor__sample"
  database_name = aws_glue_catalog_database.data_platform.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification" = "parquet"
  }

  partition_keys {
    name    = "snapshot"
    type    = "string"
  }

  partition_keys {
    name    = "identifier"
    type    = "string"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_platform.id}/output/vendor/SAMPLE.parquet/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "sample_id"
      type = "int"
    }

    columns {
      name = "sample_name"
      type = "string"
    }

    columns {
      name    = "inserted_dtm"
      type    = "string"
    }

    columns {
      name    = "updated_dtm"
      type    = "string"
    }

    columns {
      name    = "snapshot"
      type    = "string"
    }

    columns {
      name    = "identifier"
      type    = "string"
    }
  }
}
resource "aws_glue_partition_index" "data_platform_springboard__vendor__sample_snapshot" {
  database_name = aws_glue_catalog_database.data_platform.name
  table_name    = aws_glue_catalog_table.data_platform_springboard__vendor__sample.name

  partition_index {
    index_name = "snapshot"
    keys       = ["snapshot"]
  }
}
resource "aws_glue_partition_index" "data_platform_springboard__vendor__sample_snapshot_identifier" {
  database_name = aws_glue_catalog_database.data_platform.name
  table_name    = aws_glue_catalog_table.data_platform_springboard__vendor__sample.name

  partition_index {
    index_name = "snapshot_identifier"
    keys       = ["snapshot", "identifier"]
  }
}

resource "aws_glue_catalog_table" "data_platform_incoming__vendor__sample__cdc" {
  name          = "incoming__vendor__sample__cdc"
  database_name = aws_glue_catalog_database.data_platform.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification" = "csv"
    "skip.header.line.count" = "1"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_platform.id}/incoming/vendor/SAMPLE__cdc/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"

      parameters = {
        "separatorChar" = ","
      }
    }

    columns {
      name = "seq"
      type = "string"
    }

    columns {
      name = "oper"
      type = "string"
    }

    columns {
      name = "timestamp"
      type = "string"
    }

    columns {
      name = "sample_id"
      type = "int"
    }

    columns {
      name = "sample_name"
      type = "string"
    }

    columns {
      name    = "inserted_dtm"
      type    = "string"
    }

    columns {
      name    = "updated_dtm"
      type    = "string"
    }
  }
}

resource "aws_glue_catalog_table" "data_platform_springboard__vendor__sample__cdc" {
  name          = "springboard__vendor__sample__cdc"
  database_name = aws_glue_catalog_database.data_platform.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification" = "parquet"
  }

  partition_keys {
    name    = "snapshot"
    type    = "string"
  }

  partition_keys {
    name    = "identifier"
    type    = "string"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_platform.id}/output/vendor/SAMPLE__cdc.parquet/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "seq"
      type = "string"
    }

    columns {
      name = "oper"
      type = "string"
    }

    columns {
      name = "timestamp"
      type = "string"
    }

    columns {
      name = "sample_id"
      type = "int"
    }

    columns {
      name = "sample_name"
      type = "string"
    }

    columns {
      name    = "inserted_dtm"
      type    = "string"
    }

    columns {
      name    = "updated_dtm"
      type    = "string"
    }
  }
}
