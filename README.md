
```sh
# to build
docker buildx build --platform linux/arm64 --load --tag data_platform .
# to run
docker run --rm --volume $PWD:/data_platform:ro data_platform python -m data_platform.glue.incoming
```


After running `terraform apply`, do the following, in the AWS Console:
* Change RDS master password.
* Update the AWS Secrets Manager secret: https://console.aws.amazon.com/secretsmanager/home?region=us-east-1#!/secret?name=data_platform_db
username:  postgres
password:  {new-master-password}
engine  postgres
host  {aws_db_instance.data_platform.address}
port  5432
dbname  dataplatform
dbInstanceIdentifier  dataplatform