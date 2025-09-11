# tests/test_lambda_function.py
import json
import urllib.parse
import pytest
from src.app import lambda_handler  # ajusta si tu handler está en otro módulo

pytestmark = pytest.mark.ls  # etiqueta este archivo como "LocalStack integration"

def minimal_s3_event(bucket: str, key: str):
    # S3 envía el key URL-encoded
    return {
        "Records": [{
            "eventSource": "aws:s3",
            "awsRegion": "us-east-1",
            "s3": {
                "bucket": {"name": bucket},
                "object": {"key": urllib.parse.quote(key, safe="")}
            }
        }]
    }

@pytest.mark.parametrize("bucket,key", [
    ("s3-gts", "uploads/test1.txt"),
    ("s3-lab-3", "uploads/test2.txt"),
])
def test_lambda_handler_ok_against_localstack(s3, bucket, key):
    # Crea bucket si no existe
    existing = [b["Name"] for b in s3.list_buckets().get("Buckets", [])]
    if bucket not in existing:
        s3.create_bucket(Bucket=bucket)

    # Sube un objeto simulado (lo que normalmente dispara S3->Lambda)
    s3.put_object(Bucket=bucket, Key=key, Body=b"hola mundo")

    # Construye evento S3 y llama al handler
    event = minimal_s3_event(bucket, key)
    resp = lambda_handler(event, context={})

    # Valida respuesta estándar de API Gateway: statusCode + body
    assert isinstance(resp, dict)
    assert resp.get("statusCode") == 200
    assert "body" in resp

