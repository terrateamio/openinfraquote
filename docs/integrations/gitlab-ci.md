
# GitLab CI Integration

OpenInfraQuote can be integrated into your GitLab CI/CD pipelines to provide cost estimates for merge requests.

## Example `.gitlab-ci.yml`

If you're setting up a new pipeline, here's a minimal example:

```yaml
stages:
  - plan
  - cost

variables:
  PLAN_JSON: plan.json
  COST_MD: cost_estimate.md

plan:
  stage: plan
  image:
    name: hashicorp/terraform:1.2.9
    entrypoint: [""]
  script:
    - env
    - terraform init
    - terraform plan -out=tfplan.binary
    - terraform show -json tfplan.binary > ${PLAN_JSON}
  artifacts:
    paths:
      - ${PLAN_JSON}
    expire_in: 1 week
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      changes:
        - "**/*.tf"

cost-estimate:
  stage: cost
  image:
    name: ubuntu:22.04
  script:
    - env
    - apt-get update && apt-get install -y curl jq tar gzip
    - ARCH=$(uname -m)
    - 'if [ "$ARCH" = "x86_64" ]; then OIQ_ARCH="amd64"; elif [ "$ARCH" = "aarch64" ]; then OIQ_ARCH="arm64"; else exit 1; fi'
    - LATEST_VERSION=$(curl -s https://api.github.com/repos/terrateamio/openinfraquote/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    - OIQ_TAR_URL="https://github.com/terrateamio/openinfraquote/releases/download/v${LATEST_VERSION}/oiq-linux-${OIQ_ARCH}-v${LATEST_VERSION}.tar.gz"
    - curl -sL "$OIQ_TAR_URL" -o oiq.tar.gz
    - tar -xzf oiq.tar.gz
    - chmod +x oiq
    - PRICE_FILE="prices.csv"
    - PRICE_GZ_FILE="prices.csv.gz"
    - curl -s https://oiq.terrateam.io/prices.csv.gz -o "$PRICE_GZ_FILE"
    - gunzip -f "$PRICE_GZ_FILE"
    - ./oiq match --pricesheet "$PRICE_FILE" ${PLAN_JSON} | ./oiq price --format markdown > ${COST_MD}
  artifacts:
    paths:
      - ${COST_MD}
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      changes:
        - "**/*.tf"
  needs:
    - job: plan
      artifacts: true
  dependencies:
    - plan

cost-comment:
  stage: cost
  image: ubuntu:22.04
  script:
    - env
    - apt-get update && apt-get install -y curl
    - |
      curl -v --request POST --header "PRIVATE-TOKEN: ${GITLAB_OIQ_TOKEN}" --data-urlencode "body=$(cat ${COST_MD})" "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/merge_requests/${CI_MERGE_REQUEST_IID}/notes"
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
  needs:
    - job: cost-estimate
      artifacts: true
  dependencies:
    - cost-estimate
```

## What This Does

1. Runs `terraform plan` and converts the result to JSON
2. Downloads the latest OpenInfraQuote binary and pricing data
3. Runs `oiq match` and `oiq price` to estimate infrastructure costs
4. Posts the result as a comment on the merge request

## Requirements

- Define the `GITLAB_OIQ_TOKEN` secret in your GitLab project.
- The token must have:
    - **API scope**
    - At least **Reporter** access to the project (Reporter is sufficient to post comments).
