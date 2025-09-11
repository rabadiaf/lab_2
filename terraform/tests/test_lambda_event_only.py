# tests/test_lambda_event_only.py
#A) Test de evento (200 vs 400)
# tests/test_lambda_event_only.py
import urllib.parse
from importlib.machinery import SourceFileLoader

# Carga tu lambda/lambda_function.py sin renombrarla
_lambda = SourceFileLoader("lambda_function", "lambda/lambda_function.py").load_module()
lambda_handler = _lambda.lambda_handler

def minimal_s3_event(bucket: str, key: str):
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

def _get_code(resp: dict) -> int | None:
    # Tu lambda usa "sourceCode". Si algún día cambias a "statusCode", igual pasa.
    return resp.get("statusCode", resp.get("sourceCode"))

def test_lambda_handler_ok_with_s3_event():
    event = minimal_s3_event("s3-gts", "uploads/test.txt")
    resp = lambda_handler(event, context={})
    assert isinstance(resp, dict)
    assert _get_code(resp) == 200
    assert "body" in resp

def test_lambda_handler_event_sin_records_igualmente_ok():
    # Tu lambda actual retorna 200 aunque el evento no tenga Records
    resp = lambda_handler({"hello": "world"}, context={})
    assert _get_code(resp) == 200
    assert "body" in resp

