# Postgres → Iceberg (REST) via OLake, queried with Spark

## Overview
This repo demonstrates a full pipeline:
- Postgres source (orders table) → OLake discover/sync → Iceberg tables in a REST catalog over MinIO → queried with Spark SQL.

## Architecture
Postgres (pg_src) → OLake (discover/sync) → Iceberg REST Catalog (http://localhost:8181/catalog) → MinIO (s3://warehouse) → Spark SQL / Notebook

## Prerequisites
- Docker & Docker Compose
- Ports free: 5433, 8181, 8888, 8080, 9000, 9001

## How to run
```bash
docker compose up -d
# verify Postgres source has data
docker exec -it pg_src psql -U olake -d source -c "SELECT count(*) FROM orders;"
# OLake discover & sync
docker run --pull=always -v "$PWD/olake:/mnt/config" olakego/source-postgres:latest discover --config /mnt/config/source.json
docker run --pull=always --network datazip_assignment_default -v "$PWD/olake:/mnt/config" olakego/source-postgres:latest sync --config /mnt/config/source.json --catalog /mnt/config/streams.json --destination /mnt/config/destination.json

# list all namespaces
docker run --rm --network datazip_assignment_default curlimages/curl -s http://iceberg-rest:8181/v1/namespaces
# show the olake_iceberg namespace
docker run --rm --network datazip_assignment_default curlimages/curl -s http://iceberg-rest:8181/v1/namespaces/olake_iceberg
# list tables in that namespace
docker run --rm --network datazip_assignment_default curlimages/curl -s http://iceberg-rest:8181/v1/namespaces/olake_iceberg/tables

# Query with Spark SQL (via your spark-iceberg container)
docker exec -it spark-iceberg spark-sql --conf spark.sql.catalog.rest=org.apache.iceberg.spark.SparkCatalog --conf spark.sql.catalog.rest.catalog-impl=org.apache.iceberg.rest.RESTCatalog --conf spark.sql.catalog.rest.uri=http://iceberg-rest:8181 --conf spark.sql.catalog.rest.io-impl=org.apache.iceberg.aws.s3.S3FileIO --conf spark.sql.catalog.rest.warehouse=s3://warehouse/ --conf spark.sql.catalog.rest.s3.endpoint=http://minio:9000 --conf spark.sql.catalog.rest.s3.path-style-access=true --conf spark.sql.catalog.rest.s3.region=us-east-1 --conf spark.sql.catalog.rest.aws.region=us-east-1

# Inside the shell:
USE rest.olake_iceberg;
SHOW TABLES;
SELECT * FROM orders LIMIT 20;