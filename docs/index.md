# What is OpenInfraQuote?

**OpenInfraQuote** is an open source CLI tool that estimates the cost of your infrastructure using Terraform plans and state files, entirely offline and under your control.

[Get Started →](./getting-started/installation.md)

## Why OpenInfraQuote?

!!! note ""
    - **Fully Open Source**: No proprietary components, API keys, or usage limits
    - **Local Processing**: No data is sent to external servers
    - **Plan & State Support**: Works directly with Terraform plans and state files
    - **CI/CD Ready**: Simple CLI that integrates easily into existing workflows

## How It Works

OpenInfraQuote analyzes your Terraform plan or state files to identify resources that will be created, modified, or destroyed. It then uses local pricing data to estimate the cost of those resources. This process happens in two steps:

1. **Match**: Parse a Terraform plan or state file and match resources to pricing data.
2. **Price**: Estimate cost using a pricing sheet.

The output gives a per-resource cost breakdown, helping teams understand and optimize their infrastructure budget.

### Estimate Costs from a Terraform Plan

```text
$ terraform plan -out=tf.plan
$ terraform show -json tf.plan > tfplan.json
$ oiq match --pricesheet prices.csv tfplan.json | oiq price --region us-east-1

💸 OpenInfraQuote: Monthly Cost Estimate

Monthly cost increased by $25.00 📈

Before: $63.85 - $63.85
After:  $88.85 - $88.85

🟢 Added: 1   🔴 Removed: 0    ⚪ Existing: 1

Added resources:
 Resource                                                       Monthly Cost
 ------------------------------------------------------------+--------------
 aws_db_instance.example-db                                     $25.00

Existing resources:
 Resource                                                       Monthly Cost
 ------------------------------------------------------------+--------------
 aws_s3_bucket.example-bucket                                    $63.85
```

### Estimate Costs from Terraform State

```text
$ terraform state pull | terraform show --json > tfstate.json
$ oiq match --pricesheet prices.csv tfstate.json | oiq price --region us-east-1

💸 OpenInfraQuote: Monthly Cost Estimate

No change in monthly cost

Total: $127.70

Resources:
 Resource                                                       Monthly Cost
 ------------------------------------------------------------+--------------
 aws_s3_bucket.example                                           $63.85
 aws_s3_bucket.example2                                          $63.85
```

## Development

OpenInfraQuote is maintained by [Terrateam](https://github.com/terrateamio/terrateam).
Join the community on [Slack](https://terrateam.io/slack) or open an issue on [GitHub](https://github.com/terrateamio/openinfraquote/issues).
