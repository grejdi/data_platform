
resource "aws_glue_catalog_table" "data_platform_incoming__grejdi__sample" {
  name          = "incoming__grejdi__sample"
  database_name = aws_glue_catalog_database.data_platform.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification" = "csv"
    "skip.header.line.count" = "1"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_platform.id}/incoming/grejdi/SAMPLE/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"

      parameters = {
        "separatorChar" = ","
      }
    }

    columns {
      name = "id"
      type = "int"
    }

    columns {
      name = "name"
      type = "string"
    }

    columns {
      name    = "created"
      type    = "string"
    }

    columns {
      name    = "modified"
      type    = "string"
    }
  }
}

resource "aws_glue_catalog_table" "data_platform_springboard__grejdi__sample" {
  name          = "springboard__grejdi__sample"
  database_name = aws_glue_catalog_database.data_platform.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification" = "parquet"
  }

  partition_keys {
    name    = "snapshot"
    type    = "string"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_platform.id}/output/grejdi/SAMPLE.parquet/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "id"
      type = "int"
    }

    columns {
      name = "name"
      type = "string"
    }

    columns {
      name    = "created"
      type    = "string"
    }

    columns {
      name    = "modified"
      type    = "string"
    }
  }
}
resource "aws_glue_partition_index" "data_platform_springboard__grejdi__sample_snapshot" {
  database_name = aws_glue_catalog_database.data_platform.name
  table_name    = aws_glue_catalog_table.data_platform_springboard__grejdi__sample.name

  partition_index {
    index_name = "snapshot"
    keys       = [ "snapshot" ]
  }
}
