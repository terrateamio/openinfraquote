# Basic Usage

OpenInfraQuote is designed to be simple to use. Here are the most common usage patterns:

## Downloading the Pricing Sheet

Before running OpenInfraQuote, you'll need a local pricing sheet. You can download the latest version with:

```bash
curl -s https://oiq.terrateam.io/prices.csv.gz | gunzip > prices.csv
```

This CSV file is required for the `match` command to map resources to pricing data.

## Using with Terraform

First, generate a Terraform plan:

```bash
terraform plan -out=tf.plan
```

Convert the binary plan to JSON format:

```bash
terraform show -json tf.plan > tfplan.json
```

Then run OpenInfraQuote on the plan:

```bash
oiq match --pricesheet prices.csv tfplan.json | oiq price --region us-east-1
```

## Using with Terraform State

You can also analyze an existing state file:

```bash
terraform state pull | terraform show -json > tfstate.json
oiq match --pricesheet prices.csv tfstate.json | oiq price --region us-east-1
```

## Common Options

### Output Format

By default, OpenInfraQuote outputs results in the `text` format. You can also choose from the following formats depending on your use case:

- `summary`: Human-friendly summary view (default)
- `text`: Verbose output
- `json`: Structured output for parsing
- `markdown`: For documentation or PR comments
- `atlantis-comment`: Optimized for Atlantis automation comments

Example usage:

```bash
oiq price tfplan.json --format json
oiq price tfplan.json --format markdown
oiq price tfplan.json --format summary
```

## Additional Options

### Providing a Usage File (Optional)

OpenInfraQuote uses a [built-in](https://github.com/terrateamio/openinfraquote/blob/main/files/usage.json) default usage profile for estimating costs on usage-based resources like EC2, S3 or Lambda. In most cases, you don't need to provide anything additional.

However, for more accurate estimates tailored to your workloads, you can provide a custom usage file:

```bash
oiq price tfplan.json --usage usage.json
```

This allows you to specify resource-specific metrics such as request volume, storage size, or execution time.
### Specifying Region

The `--region` flag helps apply pricing specific to a region. This is a shortcut for setting a match query:

```bash
oiq price tfplan.json --region us-east-1
```

### Match Query

You can use `--mq` (match query) to apply more advanced selection logic for pricing:

```bash
oiq price tfplan.json --mq '(type = aws_s3_bucket and region = us-east-1)'
```

### Writing Output Files

You can write the result of the `match` step to a file using the `--output` option, and then use that file as input to the `price` step:

```bash
oiq match --pricesheet prices.csv tfplan.json --output matched.json
oiq price --region us-east-1 --input matched.json --format json
```

This is useful when you want to separate the match and price steps or inspect the matched data before pricing.
