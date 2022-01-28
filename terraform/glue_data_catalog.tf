
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
      name = "SAMPLE_ID"
      type = "int"
    }

    columns {
      name = "SAMPLE_NAME"
      type = "string"
    }

    columns {
      name    = "INSERTED_DTM"
      type    = "string"
    }

    columns {
      name    = "UPDATED_DTM"
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
    name    = "SNAPSHOT"
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
      name = "SAMPLE_ID"
      type = "int"
    }

    columns {
      name = "SAMPLE_NAME"
      type = "string"
    }

    columns {
      name    = "INSERTED_DTM"
      type    = "string"
    }

    columns {
      name    = "UPDATED_DTM"
      type    = "string"
    }
  }
}

resource "aws_glue_catalog_table" "data_platform_incoming__vendor__sample__ct" {
  name          = "incoming__vendor__sample__ct"
  database_name = aws_glue_catalog_database.data_platform.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification" = "csv"
    "skip.header.line.count" = "1"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_platform.id}/incoming/vendor/SAMPLE__ct/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"

      parameters = {
        "separatorChar" = ","
      }
    }

    columns {
      name = "SEQ"
      type = "string"
    }

    columns {
      name = "OPER"
      type = "string"
    }

    columns {
      name = "TIMESTAMP"
      type = "string"
    }

    columns {
      name = "SAMPLE_ID"
      type = "int"
    }

    columns {
      name = "SAMPLE_NAME"
      type = "string"
    }

    columns {
      name    = "INSERTED_DTM"
      type    = "string"
    }

    columns {
      name    = "UPDATED_DTM"
      type    = "string"
    }
  }
}

resource "aws_glue_catalog_table" "data_platform_springboard__vendor__sample__ct" {
  name          = "springboard__vendor__sample__ct"
  database_name = aws_glue_catalog_database.data_platform.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification" = "parquet"
  }

  partition_keys {
    name    = "SNAPSHOT"
    type    = "string"
  }

  partition_keys {
    name    = "IDENTIFIER"
    type    = "string"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_platform.id}/output/vendor/SAMPLE__ct.parquet/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "SEQ"
      type = "string"
    }

    columns {
      name = "OPER"
      type = "string"
    }

    columns {
      name = "TIMESTAMP"
      type = "string"
    }

    columns {
      name = "SAMPLE_ID"
      type = "int"
    }

    columns {
      name = "SAMPLE_NAME"
      type = "string"
    }

    columns {
      name    = "INSERTED_DTM"
      type    = "string"
    }

    columns {
      name    = "UPDATED_DTM"
      type    = "string"
    }
  }
}
