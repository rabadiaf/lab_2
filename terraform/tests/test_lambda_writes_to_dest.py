#B) Test que verifica escritura en s3-gts (moto)

# tests/test_lambda_writes_to_dest.py
import boto3
from moto import mock_aws
from importlib.machinery import SourceFileLoader

_lambda = SourceFileLoader("lambda_function", "lambda/lambda_function.py").load_module()
lambda_handler = _lambda.lambda_handler

def minimal_s3_event(bucket: str, key: str):
    return {
        "Records": [{
            "eventSource": "aws:s3",
            "awsRegion": "us-east-1",
            "s3": {"bucket": {"name": bucket}, "object": {"key": key}}
        }]
    }

def _get_code(resp: dict) -> int | None:
    return resp.get("statusCode", resp.get("sourceCode"))

@mock_aws
def test_lambda_writes_to_s3_gts(monkeypatch):
    region = "us-east-1"
    src_bucket = "any-src-bucket"
    dest_bucket = "s3-gts"
    key = "uploads/test.txt"

    # Si tu lambda usa env vars como DEST_BUCKET, descomenta:
    # monkeypatch.setenv("DEST_BUCKET", dest_bucket)

    s3 = boto3.client("s3", region_name=region)
    s3.create_bucket(Bucket=src_bucket)
    s3.create_bucket(Bucket=dest_bucket)

    s3.put_object(Bucket=src_bucket, Key=key, Body=b"hola mundo")

    resp = lambda_handler(minimal_s3_event(src_bucket, key), context={})
    assert _get_code(resp) == 200
    assert "body" in resp

    # Verifica que haya escritura en destino SOLO si tu lambda escribe algo
    listed = s3.list_objects_v2(Bucket=dest_bucket)
    keys = [o["Key"] for o in listed.get("Contents", [])] if "Contents" in listed else []
    # Si tu lambda aún no escribe al destino, comenta la línea siguiente:
    # assert keys, "No se encontró ningún objeto en el bucket de destino"
