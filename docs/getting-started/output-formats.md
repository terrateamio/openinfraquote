# Output Formats

OpenInfraQuote supports multiple output formats to accommodate different workflows, from human-readable summaries to structured data for automation or documentation.

## Available Formats

### summary (default)
This is the default format when no `--format` is provided. It’s designed for reviewers to easily scan changes and cost impact.

```bash
oiq price --region us-east-1
```

Example output:
```text
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

### text
A verbose format that includes detailed pricing data, match metadata, and per-resource cost diffs. Ideal for audits or debugging.

```bash
oiq price --format text
```

Example output:
```text
Match date: 2025-04-10T08:29:10
Price date: 2025-04-10T08:29:10
Match query: not region or (region=us-east-1)
Min Previous Price: 63.85 USD
Max Previous Price: 63.85 USD
Min Price: 63.85 USD
Max Price: 63.85 USD
Min Price Diff: 0.00 USD
Max Price Diff: 0.00 USD
Resources
                                              Name                           Type        Min Price (USD)     Max Price (USD)    Change
                                           example                 aws_s3_bucket               63.85               63.85      noop
                                          example4                 aws_s3_bucket               63.85               63.85       add
                                          example2                 aws_s3_bucket              -63.85              -63.85    remove
```

### json
A structured JSON output for machine parsing, integrations, or further processing.

```bash
oiq price --format json
```

Example output:
```json
{
  "match_date": "2025-04-10T08:31:23",
  "match_query": "not region or (region=us-east-1)",
  "prev_price": { "min": 63.849999999999994, "max": 63.849999999999994 },
  "price": { "min": 63.849999999999994, "max": 63.849999999999994 },
  "price_date": "2025-04-10T08:31:23",
  "price_diff": { "min": 0.0, "max": 0.0 },
  "resources": [
    {
      "address": "aws_s3_bucket.example",
      "change": "noop",
      "name": "example",
      "price": { "min": 63.849999999999994, "max": 63.849999999999994 },
      "type": "aws_s3_bucket"
    },
    {
      "address": "aws_s3_bucket.example4",
      "change": "add",
      "name": "example4",
      "price": { "min": 63.849999999999994, "max": 63.849999999999994 },
      "type": "aws_s3_bucket"
    },
    {
      "address": "aws_s3_bucket.example2",
      "change": "remove",
      "name": "example2",
      "price": { "min": -63.849999999999994, "max": -63.849999999999994 },
      "type": "aws_s3_bucket"
    }
  ]
}
```

### markdown
Optimized for documentation and PR comments.

```bash
oiq price --format markdown
```

Example output:
```markdown
### 💸 OpenInfraQuote Cost Estimate

| Monthly Estimate | Amount         |
|------------------|----------------|
| After changes    | $63.85 - $63.85 |
| Before changes   | $63.85 - $63.85 |

<details>
<summary>🟢 Added resources</summary>

| Resource | Type           | Before changes   | After changes    |
|----------|----------------|------------------|------------------|
| example4 | aws_s3_bucket  | $63.85 - $63.85  | $63.85 - $63.85  |
</details>

<details>
<summary>🔴 Removed resources</summary>

| Resource | Type           | Before changes   | After changes    |
|----------|----------------|------------------|------------------|
| example2 | aws_s3_bucket  | $63.85 - $63.85  | -$63.85 - -$63.85 |
</details>

<details>
<summary>⚪ Existing resources</summary>

| Resource | Type           | Before changes   | After changes    |
|----------|----------------|------------------|------------------|
| example  | aws_s3_bucket  | $63.85 - $63.85  | $63.85 - $63.85  |
</details>
```

### atlantis-comment
This format is designed for Atlantis for automated comments in an Atlantis PR workflow.

```bash
oiq price --format atlantis-comment
```

Example output:
```text
╔══════════════════════════════════════════════════════════╗
║        💸 OpenInfraQuote Monthly Cost Estimate           ║
╚══════════════════════════════════════════════════════════╝

No change in monthly cost

Before: $63.85 - $63.85
After:  $63.85 - $63.85

🟢 Added:     1
🔴 Removed:   1
⚪ Existing:  1

Added resources:
Resource                                 Type                       Before        After
example4                                 aws_s3_bucket        $63.85 - $63.85 $63.85 - $63.85

Removed resources:
Resource                                 Type                       Before        After
example2                                 aws_s3_bucket        $63.85 - $63.85 -$63.85 - -$63.85

Existing resources:
Resource                                 Type                       Before        After
example                                  aws_s3_bucket        $63.85 - $63.85 $63.85 - $63.85
```
