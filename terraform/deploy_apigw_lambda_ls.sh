#!/bin/bash
set -euo pipefail

# ---------- Config ----------
ENDPOINT="http://localhost:4566"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
ACCOUNT_ID="000000000000"              # LocalStack default
LAMBDA_NAME="hello-ls"
ROLE_NAME="fake-lambda-role"
STAGE_NAME="dev"
RESOURCE_PATH="hello"                  # quedará como /hello

awsls() { aws --endpoint-url="$ENDPOINT" --region "$REGION" "$@"; }

# ---------- 0) IAM role “fake” para Lambda (LocalStack lo acepta) ----------
echo "Creating IAM role (if not exists)..."
awsls iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1 || \
awsls iam create-role --role-name "$ROLE_NAME" \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]
  }' >/dev/null

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# ---------- 1) Empaquetar Lambda (Python) ----------
echo "Packaging Lambda..."
WORKDIR="$(mktemp -d)"
cat > "${WORKDIR}/lambda_function.py" << 'PY'
def lambda_handler(event, context):
    name = (event.get("queryStringParameters") or {}).get("name", "world")
    return {
        "statusCode": 200,
        "headers": {"Content-Type":"application/json"},
        "body": f'{{"message":"hello {name}"}}'
    }
PY
pushd "$WORKDIR" >/dev/null
zip -q lambda.zip lambda_function.py
popd >/dev/null

# ---------- 2) Crear/actualizar Lambda ----------
echo "Creating/Updating Lambda..."
if awsls lambda get-function --function-name "$LAMBDA_NAME" >/dev/null 2>&1; then
  awsls lambda update-function-code --function-name "$LAMBDA_NAME" --zip-file "fileb://${WORKDIR}/lambda.zip" >/dev/null
else
  awsls lambda create-function \
    --function-name "$LAMBDA_NAME" \
    --runtime python3.12 \
    --role "$ROLE_ARN" \
    --handler lambda_function.lambda_handler \
    --zip-file "fileb://${WORKDIR}/lambda.zip" >/dev/null
fi

# ---------- 3) Crear API Gateway (REST) ----------
echo "Creating REST API..."
API_ID=$(awsls apigateway create-rest-api --name "demo-hello" --query 'id' --output text)
ROOT_ID=$(awsls apigateway get-resources --rest-api-id "$API_ID" --query 'items[?path==`/`].id' --output text)

# Recurso /hello
RES_ID=$(awsls apigateway create-resource --rest-api-id "$API_ID" --parent-id "$ROOT_ID" --path-part "$RESOURCE_PATH" --query 'id' --output text)

# Método GET sin auth
awsls apigateway put-method --rest-api-id "$API_ID" --resource-id "$RES_ID" --http-method GET --authorization-type "NONE" >/dev/null

# Integración Lambda proxy
LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${LAMBDA_NAME}"
awsls apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$RES_ID" \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" >/dev/null

# (Opcional en LocalStack, pero lo incluimos) permiso para API GW -> Lambda
SOURCE_ARN="arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/GET/${RESOURCE_PATH}"
awsls lambda add-permission \
  --function-name "$LAMBDA_NAME" \
  --statement-id "apigw-invoke" \
  --action "lambda:InvokeFunction" \
  --principal apigateway.amazonaws.com \
  --source-arn "$SOURCE_ARN" >/dev/null || true

# Respuestas (requeridas por REST v1 aunque sea proxy)
awsls apigateway put-method-response \
  --rest-api-id "$API_ID" \
  --resource-id "$RES_ID" \
  --http-method GET \
  --status-code 200 \
  --response-models '{"application/json":"Empty"}' >/dev/null || true

awsls apigateway put-integration-response \
  --rest-api-id "$API_ID" \
  --resource-id "$RES_ID" \
  --http-method GET \
  --status-code 200 \
  --selection-pattern "" >/dev/null || true

# Deploy stage
awsls apigateway create-deployment --rest-api-id "$API_ID" --stage-name "$STAGE_NAME" >/dev/null

# ---------- 4) URL de invocación en LocalStack ----------
# Formato REST v1 en LocalStack:
#   http://localhost:4566/restapis/{apiId}/{stage}/_user_request_/{path}
INVOKE_URL="${ENDPOINT}/restapis/${API_ID}/${STAGE_NAME}/_user_request_/${RESOURCE_PATH}"
echo
echo "Invoke URL:"
echo "  ${INVOKE_URL}"
echo
echo "Test:"
echo "  curl '${INVOKE_URL}'"
echo "  curl '${INVOKE_URL}?name=Rodolfo'"

# Cleanup temporal
rm -rf "$WORKDIR"


