#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
OUTPUT_ZIP="${1:-${SCRIPT_DIR}/dist/fc_bundle.zip}"
STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tng-ali-fc.XXXXXX")"

if [[ "${OUTPUT_ZIP}" != /* ]]; then
  OUTPUT_ZIP="$(pwd)/${OUTPUT_ZIP}"
fi

cleanup() {
  rm -rf "${STAGE_DIR}"
}

trap cleanup EXIT

mkdir -p "$(dirname "${OUTPUT_ZIP}")"

cp -R "${REPO_ROOT}/backend/fc" "${STAGE_DIR}/fc"
cp -R "${REPO_ROOT}/backend/lib" "${STAGE_DIR}/lib"
cp -R "${REPO_ROOT}/backend/aws_lambda" "${STAGE_DIR}/aws_lambda"
cp "${REPO_ROOT}/backend/"*_fc.py "${STAGE_DIR}/"

python3 -m pip install \
  --requirement "${SCRIPT_DIR}/requirements-fc.txt" \
  --target "${STAGE_DIR}" \
  --upgrade \
  --only-binary=:all: \
  --platform manylinux2014_x86_64 \
  --implementation cp \
  --python-version 3.10 \
  --abi cp310

find "${STAGE_DIR}" -type d -name "__pycache__" -prune -exec rm -rf {} +

(
  cd "${STAGE_DIR}"
  zip -qr "${OUTPUT_ZIP}" .
)

echo "Built ${OUTPUT_ZIP}"
