#!/bin/bash
set -euo pipefail
ENDPOINT="http://localhost:4566"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
ACCOUNT_ID="000000000000"
LAMBDA_NAME="hello-ls"
ROLE_NAME="fake-lambda-role"

awsls(){ aws --endpoint-url="$ENDPOINT" --region "$REGION" "$@"; }

# Borrar APIs llamadas "demo-hello"
for id in $(awsls apigateway get-rest-apis --query "items[?name=='demo-hello'].id" --output text); do
  echo "Deleting REST API $id"
  awsls apigateway delete-rest-api --rest-api-id "$id" || true
done

# Borrar permiso y Lambda
awsls lambda remove-permission --function-name "$LAMBDA_NAME" --statement-id "apigw-invoke" >/dev/null 2>&1 || true
awsls lambda delete-function --function-name "$LAMBDA_NAME" || true

# Borrar role (si está sin políticas)
awsls iam delete-role --role-name "$ROLE_NAME" || true

echo "Cleanup done."

