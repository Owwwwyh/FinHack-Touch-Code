#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
OUTPUT_ZIP="${1:-${SCRIPT_DIR}/dist/aws_lambda_bundle.zip}"
STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tng-aws-lambda.XXXXXX")"

if [[ "${OUTPUT_ZIP}" != /* ]]; then
  OUTPUT_ZIP="$(pwd)/${OUTPUT_ZIP}"
fi

cleanup() {
  rm -rf "${STAGE_DIR}"
}

trap cleanup EXIT

mkdir -p "$(dirname "${OUTPUT_ZIP}")"

cp -R "${REPO_ROOT}/backend/aws_lambda" "${STAGE_DIR}/aws_lambda"
cp -R "${REPO_ROOT}/backend/lib" "${STAGE_DIR}/lib"

python3 -m pip install \
  --requirement "${SCRIPT_DIR}/requirements-lambda.txt" \
  --target "${STAGE_DIR}" \
  --upgrade \
  --only-binary=:all: \
  --platform manylinux2014_x86_64 \
  --implementation cp \
  --python-version 3.12 \
  --abi cp312

find "${STAGE_DIR}" -type d -name "__pycache__" -prune -exec rm -rf {} +

(
  cd "${STAGE_DIR}"
  zip -qr "${OUTPUT_ZIP}" .
)

echo "Built ${OUTPUT_ZIP}"
