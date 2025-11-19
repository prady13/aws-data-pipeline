import os
import json
import datetime
import boto3
import requests
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize S3 Client
s3 = boto3.client('s3')

# Environment Variables (Set by Terraform/Lambda)
BUCKET_NAME = os.environ.get('BUCKET_NAME')
FILE_PATH = "/tmp/data.json"

def fetch_crypto_data():
    """Fetches Bitcoin data from CoinGecko API."""
    url = "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_last_updated_at=true"
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.RequestException as e:
        logger.error(f"Error fetching data: {e}")
        raise

def lambda_handler(event, context):
    """Main entry point for AWS Lambda."""
    logger.info("Starting data ingestion pipeline...")
    
    if not BUCKET_NAME:
        logger.error("BUCKET_NAME environment variable not set.")
        return {"statusCode": 500, "body": "Configuration Error"}

    # 1. Ingest
    raw_data = fetch_crypto_data()
    logger.info(f"Data fetched: {raw_data}")

    # 2. Process (Simple transformation: Add timestamp, flatten structure)
    processed_data = {
        "asset": "bitcoin",
        "price_usd": raw_data['bitcoin']['usd'],
        "source_timestamp": raw_data['bitcoin']['last_updated_at'],
        "ingested_at": datetime.datetime.utcnow().isoformat()
    }

    # 3. Store (Save to S3)
    # We define a partition key based on date for better organization: raw/YYYY-MM-DD/
    date_str = datetime.datetime.utcnow().strftime('%Y-%m-%d')
    file_name = f"raw/{date_str}/btc_price_{datetime.datetime.utcnow().timestamp()}.json"

    try:
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=file_name,
            Body=json.dumps(processed_data),
            ContentType='application/json'
        )
        logger.info(f"Successfully uploaded to s3://{BUCKET_NAME}/{file_name}")
    except Exception as e:
        logger.error(f"Failed to upload to S3: {e}")
        raise

    return {
        "statusCode": 200,
        "body": json.dumps(f"Ingestion successful: {file_name}")
    }
