# Alibaba EAS Deploy Notes

This is the remaining cloud-side path after the local Docker image build succeeds.

## What we verified

- The local image `tng-credit-score-refresh:latest` builds successfully.
- The container serves `GET /healthz` and `POST /score` locally.
- The current Alibaba profile is `finhack-ali`.
- There is no existing Container Registry instance in `ap-southeast-1`.
- There is no existing EAS service in `ap-southeast-1`.

## Recommended target region

- EAS: `ap-southeast-1`
- ACR: `ap-southeast-1`

This keeps the registry and the EAS service in the same region.

## 1. Create an ACR instance

Create the Container Registry instance in the Alibaba console first.

Suggested values:

- Region: `ap-southeast-1`
- Edition: Personal for demo or Enterprise for a safer hackathon setup

After the instance exists, create:

- Namespace: `tng-finhack`
- Repository: `credit-score-refresh`

## 2. Push the image

Example commands after ACR is ready:

```bash
docker tag tng-credit-score-refresh:latest REPLACE_WITH_ACR_IMAGE
docker push REPLACE_WITH_ACR_IMAGE
```

Expected final image format is typically:

```text
<registry-domain>/tng-finhack/credit-score-refresh:latest
```

## 3. Create the EAS service

Edit [eas-service.body.template.json](/Users/mkfoo/Desktop/FinHack-Touch-Code/ml/eas/eas-service.body.template.json:1)
with the pushed image URL, then run:

```bash
aliyun --profile finhack-ali --region ap-southeast-1 eas CreateService \
  --body "$(cat ml/eas/eas-service.body.template.json)"
```

## 4. Get the service endpoint

After creation:

```bash
aliyun --profile finhack-ali --region ap-southeast-1 eas ListServices
aliyun --profile finhack-ali --region ap-southeast-1 eas DescribeService \
  --ClusterId REPLACE_WITH_CLUSTER_ID \
  --ServiceName tng-credit-score-refresh
```

## 5. Feed the endpoint back into Terraform

Once you have the live EAS URL, update:

- [terraform.tfvars](/Users/mkfoo/Desktop/FinHack-Touch-Code/infra/alibaba/terraform.tfvars:1)

Set:

```hcl
eas_endpoint = "https://REPLACE_WITH_LIVE_EAS_URL"
```

Then re-apply:

```bash
terraform -chdir=infra/alibaba apply -auto-approve -no-color
```

## Practical sizing

For this Flask + Gunicorn demo service, `cpu=2`, `memory=4000`, `instance=1` is a
reasonable starting point. The Singapore EAS machine list we queried includes
small CPU-only options such as `ecs.c7.large`, `ecs.c7.xlarge`, and `ecs.c9i.large`.
