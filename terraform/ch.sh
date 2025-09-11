#!/usr/bin/env bash
set -euo pipefail

# Requisitos: awscli y jq
# Uso:
#   ./lambda-s3-link.sh --lambda NOMBRE_LAMBDA
#   ./lambda-s3-link.sh --bucket NOMBRE_BUCKET

REGION="us-east-1"
ENDPOINT="http://localhost:4566"
AWS_BASE_ARGS=(--region "$REGION" --endpoint-url "$ENDPOINT")

LAMBDA_NAME=""
BUCKET_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lambda) LAMBDA_NAME="$2"; shift 2 ;;
    --bucket) BUCKET_NAME="$2"; shift 2 ;;
    *) echo "Arg desconocido: $1"; exit 1 ;;
  esac
done

print_header() {
  printf "%-8s | %-40s | %-70s | %-30s | %-25s\n" "ORIGEN" "LAMBDA" "LAMBDA ARN" "BUCKET" "EVENTOS"
  printf -- "---------+------------------------------------------+----------------------------------------------------------------------+--------------------------------+---------------------------\n"
}

row() {
  local origen="$1" lname="$2" larn="$3" bucket="$4" events="$5"
  printf "%-8s | %-40s | %-70s | %-30s | %-25s\n" "$origen" "${lname:0:40}" "${larn:0:70}" "${bucket:0:30}" "${events:0:25}"
}

from_lambda_policy() {
  local fn="$1"
  local policy
  policy=$(aws lambda get-policy --function-name "$fn" "${AWS_BASE_ARGS[@]}" 2>/dev/null | jq -r '.Policy' 2>/dev/null || echo "")
  [[ -z "$policy" ]] && return 0

  # Busca buckets con permiso (SourceArn = arn:aws:s3:::bucket)
  echo "$policy" | jq -r '
    try ( .Statement[]?
      | select(.Principal.Service=="s3.amazonaws.com")
      | (.Condition // {}) as $c
      | ($c.ArnLike // $c.ArnEquals // {})
      | (."AWS:SourceArn" // empty)
    ) // empty' \
  | sed 's#"##g' \
  | while read -r s3arn; do
      [[ -z "$s3arn" ]] && continue
      local bucket="${s3arn#arn:aws:s3:::}"
      # Eventos no se ven en la policy, lo marcamos como "permiso"
      row "Policy" "$fn" "$(aws lambda get-function --function-name "$fn" "${AWS_BASE_ARGS[@]}" --query 'Configuration.FunctionArn' --output text)" "$bucket" "permiso"
    done
}

from_s3_notifications_by_lambda() {
  local fn="$1"
  local fn_arn
  fn_arn=$(aws lambda get-function --function-name "$fn" "${AWS_BASE_ARGS[@]}" --query 'Configuration.FunctionArn' --output text 2>/dev/null || true)
  [[ -z "$fn_arn" ]] && { echo "Lambda no encontrada: $fn"; return 0; }

  local buckets
  buckets=$(aws s3api list-buckets "${AWS_BASE_ARGS[@]}" --query 'Buckets[].Name' --output text 2>/dev/null || true)
  [[ -z "$buckets" ]] && return 0

  for b in $buckets; do
    cfg=$(aws s3api get-bucket-notification-configuration --bucket "$b" "${AWS_BASE_ARGS[@]}" 2>/dev/null || echo '{}')
    echo "$cfg" | jq -r --arg arn "$fn_arn" '
      (.LambdaFunctionConfigurations // [])
      | map(select(.LambdaFunctionArn==$arn)
            | {arn: .LambdaFunctionArn, events: (.Events // [])})
      | .[] | @base64' | while read -r line; do
        j() { echo "$line" | base64 -d | jq -r "$1"; }
        events=$(j '.events | join(",")')
        row "S3" "$fn" "$fn_arn" "$b" "${events:-(config)}"
      done
  done
}

from_bucket_notifications() {
  local bucket="$1"
  cfg=$(aws s3api get-bucket-notification-configuration --bucket "$bucket" "${AWS_BASE_ARGS[@]}" 2>/dev/null || echo '{}')
  echo "$cfg" | jq -r '
    (.LambdaFunctionConfigurations // [])
    | map({arn: .LambdaFunctionArn, events: (.Events // [])})
    | .[] | @base64' | while read -r line; do
      j() { echo "$line" | base64 -d | jq -r "$1"; }
      arn=$(j '.arn')
      events=$(j '.events | join(",")')
      # Nombre de Lambda (mejor esfuerzo)
      lname=$(aws lambda get-function --function-name "$arn" "${AWS_BASE_ARGS[@]}" --query 'Configuration.FunctionName' --output text 2>/dev/null || echo "-")
      row "S3" "$lname" "$arn" "$bucket" "${events:-(config)}"
    done
}

if [[ -n "$LAMBDA_NAME" && -n "$BUCKET_NAME" ]]; then
  echo "Elegí solo uno: --lambda o --bucket"; exit 1
fi

print_header

if [[ -n "$LAMBDA_NAME" ]]; then
  from_lambda_policy "$LAMBDA_NAME"
  from_s3_notifications_by_lambda "$LAMBDA_NAME"
  exit 0
fi

if [[ -n "$BUCKET_NAME" ]]; then
  from_bucket_notifications "$BUCKET_NAME"
  exit 0
fi

echo "Uso:
  $0 --lambda NOMBRE_LAMBDA
  $0 --bucket NOMBRE_BUCKET"
exit 1

