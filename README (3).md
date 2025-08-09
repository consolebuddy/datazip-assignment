# Data Engineering Pipeline – PostgreSQL → OLake → Apache Iceberg → Spark

## Overview
This project demonstrates a local data engineering workflow that:
1. **Extracts** data from PostgreSQL.  
2. **Loads** it into Apache Iceberg format using **OLake**.  
3. **Stores** Iceberg tables in an **S3-compatible MinIO warehouse**.  
4. **Queries** the data through **Iceberg REST Catalog** using **Apache Spark**.

---

## Architecture
```
PostgreSQL → OLake Source Connector → Iceberg REST Catalog (MinIO backend) → Spark SQL
```

---

## Setup Steps

### 1. Clone the Repository
```bash
git clone https://github.com/datazip-inc/olake.git
cd olake
```

---

### 2. Start Services
We use Docker Compose to spin up:
- **PostgreSQL** (source DB)  
- **MinIO** (S3-compatible object storage)  
- **Iceberg REST Catalog** (metadata API)

```bash
docker compose up -d
```

---

### 3. Create & Populate the Orders Table
```bash
docker exec -it postgres psql -U postgres
```
Inside `psql`:
```sql
CREATE DATABASE mydb;
\c mydb;

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    product_name TEXT,
    quantity INT,
    price DECIMAL
);

INSERT INTO orders (product_name, quantity, price) VALUES
('Laptop', 2, 1200.50),
('Mouse', 10, 25.00),
('Keyboard', 5, 45.00),
('Monitor', 3, 300.00),
('Phone', 4, 650.00),
('Tablet', 6, 400.00),
('Headphones', 8, 75.00),
('Webcam', 2, 150.00),
('Speaker', 5, 120.00),
('Printer', 1, 200.00),
('Desk', 2, 500.00),
('Chair', 4, 220.00);
```
Exit:
```bash
\q
```

---

### 4. Prepare OLake Config Files

**`source.json`**
```json
{
  "type": "POSTGRES",
  "host": "postgres",
  "port": 5432,
  "database": "mydb",
  "username": "postgres",
  "password": "postgres",
  "schemas": ["public"]
}
```

**`destination.json`**
```json
{
  "type": "ICEBERG",
  "writer": {
    "catalog_type": "rest",
    "rest_catalog_url": "http://iceberg-rest:8181",
    "iceberg_s3_path": "warehouse",
    "iceberg_db": "olake_iceberg",
    "iceberg_properties": {
      "warehouse": "s3://warehouse/",
      "io-impl": "org.apache.iceberg.aws.s3.S3FileIO",
      "s3.endpoint": "http://minio:9000",
      "s3.path-style-access": "true",
      "s3.region": "us-east-1",
      "aws.region": "us-east-1",
      "s3.access-key-id": "admin",
      "s3.secret-access-key": "password"
    }
  }
}
```

---

### 5. Discover the Schema
```bash
docker run --pull=always --network datazip_assignment_default   -v "$PWD/olake:/mnt/config" olakego/source-postgres:latest   discover --config /mnt/config/source.json > olake/streams.json
```

---

### 6. Sync Data from Postgres → Iceberg
```bash
docker run --pull=always --network datazip_assignment_default   -v "$PWD/olake:/mnt/config" olakego/source-postgres:latest   sync --config /mnt/config/source.json        --catalog /mnt/config/streams.json        --destination /mnt/config/destination.json
```
✅ You should see logs ending with:
```
Successfully committed data for thread: 85
```

---

### 7. Verify via Iceberg REST API
List namespaces:
```bash
docker run --rm --network datazip_assignment_default curlimages/curl -s   http://iceberg-rest:8181/v1/namespaces
```
List tables in `olake_iceberg`:
```bash
docker run --rm --network datazip_assignment_default curlimages/curl -s   http://iceberg-rest:8181/v1/namespaces/olake_iceberg/tables
```

---

### 8. Query in Spark
Run the following in a **Jupyter Notebook** or Python script:

```python
from pyspark.sql import SparkSession

spark = (
    SparkSession.builder
    .appName("IcebergQuery")
    .config("spark.sql.catalog.local", "org.apache.iceberg.spark.SparkCatalog")
    .config("spark.sql.catalog.local.type", "rest")
    .config("spark.sql.catalog.local.uri", "http://iceberg-rest:8181")
    .config("spark.sql.catalog.local.io-impl", "org.apache.iceberg.aws.s3.S3FileIO")
    .config("spark.sql.catalog.local.warehouse", "s3://warehouse/")
    .config("spark.sql.catalog.local.s3.endpoint", "http://minio:9000")
    .config("spark.sql.catalog.local.s3.path-style-access", "true")
    .config("spark.sql.catalog.local.s3.access-key-id", "admin")
    .config("spark.sql.catalog.local.s3.secret-access-key", "password")
    .getOrCreate()
)

df = spark.sql("SELECT * FROM local.olake_iceberg.orders")
df.show()
```

---

## Screenshots

**Spark SQL Output Example**
![Spark SQL Output](screenshots/spark_sql_output.png)

**Spark UI Job Execution**
![Spark UI](screenshots/spark_ui.png)

---

## Challenges Faced
- **Incorrect REST API paths** – Initially used `/v1/{catalog}/namespaces` instead of `/v1/namespaces`. Fixed after reading Iceberg REST spec.  
- **AWS Region Mismatch** – Had to set both `AWS_REGION` and `aws.region` in configs to avoid SDK errors.  
- **Schema Discovery** – Forgot to redirect discovery output into `streams.json`, which caused sync failures.

---

## Improvements Suggested
- Automate the entire pipeline in a **single `docker-compose.yml`** (including OLake).  
- Enable **CDC (Change Data Capture)** for real-time updates from Postgres.  
- Add **Grafana dashboard** connected to Iceberg via Trino/Presto for visualization.  
- Create a **Jupyter notebook** that runs end-to-end from extract to query.

---
