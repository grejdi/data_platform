
```sh
# to build
docker buildx build --platform linux/arm64 --load --tag data_platform .
# to run
docker run --rm --volume $PWD:/data_platform:ro data_platform python -m data_platform.glue.incoming
```
