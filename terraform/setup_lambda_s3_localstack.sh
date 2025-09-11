#!/bin/bash
shopt -s expand_aliases
alias awsls='aws --endpoint-url=http://localhost:4566'

# Preguntar al usuario
read -p "👉 Ingresa el nombre de la función Lambda: " LAMBDA_NAME
read -p "👉 Ingresa el archivo ZIP de la Lambda (ej: lambda/lambda.zip): " LAMBDA_ZIP
read -p "👉 Ingresa el bucket S3: " S3_BUCKET

# Step 1: Create Lambda
echo "📦 Creando Lambda function: $LAMBDA_NAME"
awsls lambda create-function \
  --function-name "$LAMBDA_NAME" \
  --runtime python3.12 \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://"$LAMBDA_ZIP"

# Step 2: Give S3 permission to invoke Lambda
echo "🔐 Agregando permiso para que S3 invoque la Lambda"
awsls lambda add-permission \
  --function-name "$LAMBDA_NAME" \
  --statement-id s3invoke \
  --action "lambda:InvokeFunction" \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::"$S3_BUCKET"

# Step 3: Configure S3 trigger → Lambda
echo "🔔 Configurando notificación de S3 ($S3_BUCKET) hacia Lambda ($LAMBDA_NAME)"
awsls s3api put-bucket-notification-configuration \
  --bucket "$S3_BUCKET" \
  --notification-configuration "{
    \"LambdaFunctionConfigurations\": [
      {
        \"LambdaFunctionArn\": \"arn:aws:lambda:us-east-1:000000000000:function:$LAMBDA_NAME\",
        \"Events\": [\"s3:ObjectCreated:*\"]

      }
    ]
  }"

echo "✅ Configuración completa: Lambda $LAMBDA_NAME conectada a S3 $S3_BUCKET."

