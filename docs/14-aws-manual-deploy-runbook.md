---
name: 14-aws-manual-deploy-runbook
description: Step-by-step manual AWS deploy checklist for the current repo, including install, apply, and smoke-test steps
owner: DevOps
status: active
depends-on: [05-aws-services, 12-build-tasks, 13-deployment]
last-updated: 2026-04-26
---

# AWS Manual Deploy Runbook

This is the **practical next move** for AWS from this repo.

The AWS path is no longer blocked by missing Terraform code. The remaining work is
mostly **manual operator setup**:

1. install the missing tools on your machine,
2. build the Lambda zip,
3. apply the AWS Terraform root,
4. capture the real bridge URL and Cognito JWKS output,
5. smoke-test the deployed inbound bridge.

## 1. Important scope check

What AWS gives you **today**:
- real DynamoDB, KMS, S3, Cognito, EventBridge, Secrets Manager resources,
- real Lambda deploys for:
  - `settle_batch`
  - `eb_cross_cloud_bridge_in`
  - `eb_cross_cloud_bridge_out`
- real AWS HTTP API route:
  - `POST /internal/alibaba/events`

What AWS does **not** give you yet:
- public `/v1/wallet/balance`
- public `/v1/score/refresh`
- public `/v1/tokens/settle` for the mobile app

Those app-facing `/v1/...` routes still belong to the Alibaba compute side, which is
not deployable yet from this repo. So for AWS, the main live test is the **bridge
endpoint**, not the wallet API.

## 2. What is left to do manually

If you want the AWS path live, the manual work left is only this:

1. Install `terraform`.
2. Install `aws` CLI.
3. Configure AWS credentials for the target AWS account.
4. Decide the secret inputs for:
   - `alibaba_access_key_id`
   - `alibaba_secret_access_key`
   - `alibaba_account_id`
   - `alibaba_ingest_url`
   - `bridge_hmac_secret`
5. Create `infra/aws/terraform.tfvars`.
6. Build the shared Lambda zip with `infra/aws/lambda/build_package.sh`.
7. Run `terraform init`.
8. Run `terraform plan`.
9. Run `terraform apply`.
10. Record:
    - `aws_bridge_invoke_url`
    - `cognito_jwks_uri`
11. Send a signed test request to the AWS bridge route.
12. Check Lambda logs and API Gateway response.

## 3. Step 1: verify or install the local tools

If `terraform` or `aws` is missing on your machine, install them first.

On macOS with Homebrew:

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
brew install awscli
```

Verify:

```bash
terraform version
aws --version
```

Expected:
- `terraform` should be `>= 1.5`
- `aws` CLI only needs to run successfully

## 4. Step 2: configure AWS credentials

Use an IAM user or SSO profile with permission to create:
- Lambda
- API Gateway v2
- DynamoDB
- KMS
- S3
- Cognito
- EventBridge
- Secrets Manager
- IAM roles and policies
- CloudWatch log groups

Configure the CLI with either IAM Identity Center or access keys:

```bash
aws configure sso
```

or:

```bash
aws configure
```

Use:
- region: `ap-southeast-1`
- output: `json`

Sanity-check identity:

```bash
aws sts get-caller-identity
```

Do not continue until that returns the expected AWS account.

## 5. Step 3: decide the Terraform inputs

Create [infra/aws/terraform.tfvars](/Users/mkfoo/Desktop/FinHack-Touch-Code/infra/aws/terraform.tfvars).

Use this template:

```hcl
aws_region    = "ap-southeast-1"
environment   = "demo"
project_prefix = "tng"
app_name       = "finhack"

aws_account_id = "YOUR_AWS_ACCOUNT_ID"

callback_urls = ["http://localhost:8080/callback"]
logout_urls   = ["http://localhost:8080/logout"]

alibaba_access_key_id     = "YOUR_ALIBABA_AK"
alibaba_secret_access_key = "YOUR_ALIBABA_SK"
alibaba_region            = "ap-southeast-3"
alibaba_account_id        = "YOUR_ALIBABA_ACCOUNT_ID"
alibaba_ingest_url        = "https://YOUR-ALIBABA-INGEST-ENDPOINT"

bridge_hmac_secret    = "REPLACE_WITH_LONG_RANDOM_SHARED_SECRET"
cognito_client_secret = ""

aws_bridge_custom_domain                 = ""
aws_bridge_custom_domain_certificate_arn = ""

stepfunctions_arn = ""
dlq_arn           = ""
```

Notes:
- `alibaba_ingest_url` can be a placeholder for now if you only want inbound AWS
  bridge testing, but `eb_cross_cloud_bridge_out` will need a real destination later.
- `bridge_hmac_secret` must exactly match the shared secret used on the Alibaba side.
- `terraform.tfvars` should stay local and uncommitted.

## 6. Step 4: run local AWS handler tests first

Before touching the cloud, verify the AWS handler logic locally from the repo root:

```bash
python3 -m pytest \
  backend/tests/test_settle_batch_lambda.py \
  backend/tests/test_eb_cross_cloud_bridge_in.py \
  backend/tests/test_eb_cross_cloud_bridge_out.py \
  backend/tests/test_aws_secrets.py -q
```

Current result in this workspace:
- `7 passed`

This does **not** prove the cloud deploy works, but it does prove the handler code,
signature checks, and secret-resolution logic are passing locally.

## 7. Step 5: build the Lambda package

From the repo root:

```bash
./infra/aws/lambda/build_package.sh infra/aws/lambda/dist/aws_lambda_bundle.zip
```

What this script does:
- copies `backend/aws_lambda`
- copies `backend/lib`
- vendors Linux-compatible dependencies from `requirements-lambda.txt`
- zips everything into one shared bundle for all AWS Lambdas

Success check:

```bash
ls -lh infra/aws/lambda/dist/aws_lambda_bundle.zip
```

You should see the zip file exist with a non-trivial size.

If this step fails:
- make sure `python3` works,
- make sure `pip` can download wheels,
- retry after installing `terraform` and `aws` CLI if your machine was only partially set up.

## 8. Step 6: initialize and review Terraform

Move into the AWS root:

```bash
cd infra/aws
terraform init
terraform validate
terraform plan \
  -var="lambda_package_zip=$(pwd)/lambda/dist/aws_lambda_bundle.zip"
```

What you should look for in the plan:
- `aws_lambda_function` resources
- `aws_iam_role` and `aws_iam_role_policy` for the Lambdas
- `aws_cloudwatch_log_group` for each Lambda
- `aws_apigatewayv2_api`, stage, route, integration, and permission
- outputs including `aws_bridge_invoke_url`

Do not apply if the plan still looks like scaffold-only outputs. It should show real
resource creation.

## 9. Step 7: apply AWS

Still inside `infra/aws`:

```bash
terraform apply \
  -var="lambda_package_zip=$(pwd)/lambda/dist/aws_lambda_bundle.zip"
```

Approve when the plan looks correct.

When apply completes, capture outputs:

```bash
terraform output
terraform output aws_bridge_invoke_url
terraform output cognito_jwks_uri
terraform output settle_batch_lambda_name
terraform output eb_cross_cloud_bridge_in_name
terraform output eb_cross_cloud_bridge_out_name
```

Record these values immediately in your deployment notes.

## 10. Step 8: confirm the deployed AWS resources exist

These are the first manual checks after apply:

```bash
aws lambda list-functions --region ap-southeast-1
aws apigatewayv2 get-apis --region ap-southeast-1
aws logs describe-log-groups --region ap-southeast-1 --log-group-name-prefix /aws/lambda/tng-finhack
```

You are looking for:
- Lambda names starting with `tng-finhack-`
- one HTTP API for the AWS bridge
- CloudWatch log groups for all deployed Lambdas

## 11. Step 9: smoke-test the inbound AWS bridge

The most important live AWS test is:
- send a `tokens.settle.requested` event to the real API Gateway URL,
- signed with the same HMAC secret stored in Terraform,
- expect HTTP `200`,
- expect a settlement completion response body.

### 11.1 Build the request body

Save this as `tmp/aws-bridge-event.json` from the repo root:

```json
{
  "detail-type": "tokens.settle.requested",
  "detail": {
    "batch_id": "batch-manual-001",
    "tokens": [],
    "ack_signatures": []
  }
}
```

This is a minimal connectivity test. It confirms:
- API Gateway route is live,
- Lambda invocation works,
- signature verification path works,
- JSON parsing works.

### 11.2 Create the HMAC signature

Generate a signature with the exact same shared secret used in `bridge_hmac_secret`:

```bash
python3 - <<'PY'
import hashlib
import hmac
from pathlib import Path

secret = b"REPLACE_WITH_LONG_RANDOM_SHARED_SECRET"
body = Path("tmp/aws-bridge-event.json").read_bytes()
print(hmac.new(secret, body, hashlib.sha256).hexdigest())
PY
```

Copy the printed hex value.

### 11.3 Call the deployed endpoint

Replace `YOUR_AWS_BRIDGE_URL` and `YOUR_SIGNATURE`:

```bash
curl -i \
  -X POST "YOUR_AWS_BRIDGE_URL" \
  -H "Content-Type: application/json" \
  -H "x-tng-signature: YOUR_SIGNATURE" \
  --data-binary @tmp/aws-bridge-event.json
```

Expected result:
- HTTP `200`
- JSON body containing a settlement completion event structure

### 11.4 Failure cases worth testing immediately

Bad signature:

```bash
curl -i \
  -X POST "YOUR_AWS_BRIDGE_URL" \
  -H "Content-Type: application/json" \
  -H "x-tng-signature: bad-signature" \
  --data-binary @tmp/aws-bridge-event.json
```

Expected:
- HTTP `403`
- error code similar to `FORBIDDEN`

Bad event type:
- change `detail-type` to anything else

Expected:
- HTTP `400`

These checks prove the bridge is not just reachable, but enforcing the intended guardrails.

## 12. Step 10: inspect logs after the smoke test

If the endpoint responded unexpectedly, pull the Lambda logs:

```bash
aws logs tail /aws/lambda/tng-finhack-eb-cross-cloud-bridge-in \
  --since 10m \
  --region ap-southeast-1
```

Also inspect the outbound bridge Lambda if EventBridge rules start firing later:

```bash
aws logs tail /aws/lambda/tng-finhack-eb-cross-cloud-bridge-out \
  --since 10m \
  --region ap-southeast-1
```

If settlement logic is involved, inspect:

```bash
aws logs tail /aws/lambda/tng-finhack-settle-batch \
  --since 10m \
  --region ap-southeast-1
```

## 13. Step 11: record the values the rest of the project needs

After AWS is live, write down:

1. `aws_bridge_invoke_url`
2. `cognito_jwks_uri`
3. deployed Lambda names
4. chosen `bridge_hmac_secret`
5. AWS region and account id used

These are the values the Alibaba side will eventually need for:
- inbound bridge calls to AWS,
- JWT verification against Cognito,
- cross-cloud event signing.

## 14. What counts as “AWS done”

For this repo, AWS is practically done when all of this is true:

- `terraform plan` shows real Lambda and API Gateway resources
- `terraform apply` succeeds
- `terraform output aws_bridge_invoke_url` returns a real URL
- signed `curl` to that URL returns HTTP `200`
- bad-signature `curl` returns HTTP `403`
- CloudWatch logs show the Lambda was invoked

That is enough to say the AWS path is **deployed and manually validated**.

It is **not** enough to claim full end-to-end mobile demo readiness, because the
Alibaba public compute layer is still missing.

## 15. Short answer: what is left manually for AWS

Only this:

1. install `terraform` and `aws`,
2. create `infra/aws/terraform.tfvars`,
3. build `infra/aws/lambda/dist/aws_lambda_bundle.zip`,
4. run `terraform init/plan/apply`,
5. save `aws_bridge_invoke_url` and `cognito_jwks_uri`,
6. test the bridge endpoint with a signed `curl`,
7. inspect CloudWatch logs.

That is the remaining AWS operator work, step by step.
