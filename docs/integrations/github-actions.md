
# GitHub Actions Integration

OpenInfraQuote can be easily integrated into your GitHub Actions workflow to provide cost estimates for every pull request. See [our official GitHub Action](https://github.com/terrateamio/openinfraquote-action) for details.

## Example `.github/workflows/terrateam-plan.yml`

If you're setting up a new workflow, here's a minimal example:

```yaml
name: Terraform Plan

on:
  pull_request:
    paths:
      - '**.tf'
      - '**.tfvars'

permissions:
  pull-requests: write

jobs:
  plan:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan -out=tfplan.binary

      - name: Convert plan to JSON
        run: terraform show -json tfplan.binary > tfplan.json

      - name: Run OpenInfraQuote
        uses: terrateamio/openinfraquote-action@v1
        with:
          plan-path: tfplan.json
          comment-on-pr: true
```

## What This Does

1. Triggers on pull requests that change Terraform files
1. Checks out the code, sets up Terraform, and generates a plan
1. Generates an OpenInfraQuote cost estimate in Markdown format
1. Comments on the PR with the cost estimate
