# Supported Platforms

OpenInfraQuote currently supports the following providers:

## Cloud Providers

### AWS (Amazon Web Services)
OpenInfraQuote has first-class support for AWS resources, including:

- EC2
- EBS volumes
- S3 storage
- RDS databases
- Lambda functions
- ECS services
- And more...

## Coming Soon

We are actively working on adding support for:

- GCP
- Azure
- DigitalOcean
- Oracle Cloud
- IBM Cloud
- Alibaba Cloud

## Resource Coverage

For each provider, we aim to cover the most commonly used resources first. If you find a resource that's not supported, please [open an issue](https://github.com/terrateamio/openinfraquote/issues/new) or contribute to the project!

## Custom Pricing Support

OpenInfraQuote uses a flexible, user-defined `prices.csv` file to match resources to pricing. This format enables:

- Full control over pricing logic for any supported resource
- Use internal pricing models such as team chargebacks or negotiated discounts
- Extension to unsupported platforms or custom services

Each row in `prices.csv` defines a match condition and pricing metadata. Example entries:

```
AmazonRDS,Database Instance,type=aws_db_instance&values.engine=oracle-se2&values.instance_class=db.t3.medium&values.multi_az=false,end_usage_amount=Inf&purchase_option=reserved&region=ap-south-1&service_class=instance&service_provider=aws&start_usage_amount=0,0.0343000000,t,USD
AmazonRDS,Database Instance,type=aws_db_instance&values.engine=aurora-postgresql&values.instance_class=db.r5.24xlarge&values.multi_az=false,end_usage_amount=Inf&purchase_option=reserved&region=eu-west-2&service_class=instance&service_provider=aws&start_usage_amount=0,5.1442000000,t,USD
```

This allows OpenInfraQuote to operate entirely offline, using your own definitions of price, region, tier, usage, and service behavior.
