💸💰

# OpenInfraQuote

![Comedian, Chelsea Lately, faces the camera and says, "I am a bold artistic voice", with a brief pause before saying, "with a lot of credit card debt"](files/bold_artistic_voice.gif)

Infrastructure cost estimation from Terraform plans and state files

[![Stars](https://img.shields.io/github/stars/terrateamio/openinfraquote)](https://github.com/terrateamio/openinfraquote/stargazers)
[![Slack](https://img.shields.io/badge/slack-join%20chat-blue)](https://terrateam.io/slack)
[![Latest Release](https://img.shields.io/github/v/release/terrateamio/openinfraquote?color=%239F50DA)](https://github.com/terrateamio/openinfraquote/releases)
[![Docs](https://img.shields.io/badge/docs-read%20the%20docs-6F42C1)](https://openinfraquote.readthedocs.io)
[![OCaml](https://img.shields.io/badge/OCaml-EC6813?logo=ocaml&logoColor=fff)](https://ocaml.org)
[![License: MPL-2.0](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](https://opensource.org/licenses/MPL-2.0)

---

OpenInfraQuote is a lightweight, open-source CLI tool for estimating infrastructure costs using Terraform plan and state files. It runs locally or in CI/CD. No backend, no API keys, no external services.

Built for teams that care about flexibility, privacy, and control.

---

## Why OpenInfraQuote

- 100% open-source (MPL-2.0)
- No API keys or rate limits
- Self-contained CLI, data does not leave your system
- Works with your existing Terraform plans and state files
- Easy to integrate into any CI/CD pipeline

Currently supports AWS. GCP and Azure are on the way.

---

## Documentation

Full documentation is available at [openinfraquote.readthedocs.io](https://openinfraquote.readthedocs.io)

Includes:
- Installation guides
- CI/CD integrations
- Cost diffing
- Usage customization
- Output formats
- Policy enforcement with OPA

---

## Getting Started

You can install OpenInfraQuote by downloading the binary.

### Download Pricing Sheet

Before running a cost estimate, download the latest pricing sheet:

```sh
curl -s https://oiq.terrateam.io/prices.csv.gz | gunzip > prices.csv
```

### Install OpenInfraQuote

Download the latest release for your system:

1. Go to the [OpenInfraQuote releases page](https://github.com/terrateamio/openinfraquote/releases).
2. Download the binary for your architecture.
3. Unarchive and copy it to one of the directories in your $PATH, e.g. /usr/local/bin
4. Confirm it’s working:

   ```bash
   oiq --help
   ```

---

## Examples

### Estimate Costs from a Terraform Plan

```sh
terraform plan -out=tf.plan
terraform show -json tf.plan > tfplan.json
oiq match --pricesheet prices.csv tfplan.json | oiq price --region us-east-1
```

Example output:
```
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

In JSON format:
```sh
oiq match --pricesheet prices.csv tfplan.json | oiq price --region us-east-1 --format=json
```

### Estimate Current Costs from Terraform State

```sh
terraform state pull | terraform show --json > tfstate.json
oiq match --pricesheet prices.csv tfstate.json | oiq price --region us-east-1
```

---

## Region and Usage Configuration

### Region Handling

By default, OpenInfraQuote shows pricing across all regions. If you know which region to use, pass it explicitly with the `--region` flag. This is optional.

Plan and state files do not contain region information, so it must be provided manually if you want region-specific estimates.

### Usage-Based Estimates

Some cloud resources are priced based on usage, such as storage size or number of requests. OpenInfraQuote includes default estimates for common usage patterns to help provide directional cost data. You can customize these assumptions by providing your own `usage.json` file.

See an example usage file [here](https://github.com/terrateamio/openinfraquote/blob/main/files/usage.json).

---

## Running with Docker

To run OpenInfraQuote with Docker:

```sh
docker run --rm -i \
  -v $(pwd)/prices.csv:/prices.csv \
  -v $(pwd)/tfplan.json:/tfplan.json \
  ghcr.io/terrateamio/openinfraquote:latest \
  match --pricesheet /prices.csv /tfplan.json \
  | docker run --rm -i \
    ghcr.io/terrateamio/openinfraquote:latest \
    price --region us-east-1
```

---

## FAQ

### Is OpenInfraQuote 100% open-source?

Yes. There are no proprietary components or hidden features.

### Which cloud providers are supported?

Currently AWS. GCP and Azure support is coming soon.

### How accurate are the estimates?

Estimates are based on pricing data from official cloud provider APIs. OpenInfraQuote uses a pricing sheet (`prices.csv`) that is updated daily to reflect the latest public pricing. This file is downloaded and used locally, so your estimates stay current without needing a backend service.

Final costs depend on actual usage and any applicable discounts.

### Where can I report issues or request features?

Open an issue on [GitHub](https://github.com/terrateamio/openinfraquote/issues) or join our [Slack](https://terrateam.io/slack) community.
