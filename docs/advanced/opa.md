# Using with Open Policy Agent

[Open Policy Agent (OPA)](https://www.openpolicyagent.org/) is a general-purpose policy engine that can be used to enforce cost policies. The [`conftest`](https://www.conftest.dev/) CLI makes it easy to run these checks as part of your CI/CD workflow.

By combining OpenInfraQuote with Conftest, you can evaluate infrastructure changes for cost compliance before deployment.

## Workflow Overview

1. Use OpenInfraQuote to generate a cost estimate in `json` format
2. Use Conftest to evaluate that estimate against a Rego policy
3. Block the pipeline if the policy fails

## Generate Cost Estimate

Use the `--format=json` flag to produce a structured cost estimate compatible with Conftest:

```bash
oiq match --pricesheet prices.csv tfplan.json | oiq price --region us-east-1 --format=json > estimate.json
```

## Example Policy

```rego
package terraform.cost

default allow = true

deny[msg] {
  input.price.max > 1000
  msg := sprintf("Total monthly cost $%.2f exceeds budget", [input.price.max])
}
```

Save this as `policy/terraform/cost.rego`

## Running the Policy with Conftest

```bash
conftest test estimate.json --policy policy/ --namespace terraform.cost
```

If the policy fails, `conftest` will exit with a non-zero status and print the violation message. This makes it easy to integrate with CI pipelines like GitHub Actions or GitLab CI.
