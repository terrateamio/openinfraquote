# CLI Reference

This page describes all available OpenInfraQuote CLI commands and flags.

## Commands

### `match`

Parses a Terraform plan or state JSON file and matches resources to pricing entries.

```bash
oiq match --pricesheet prices.csv tfplan.json
```

#### Flags

- `--pricesheet <path>`  
  Path to a local `prices.csv` file. *(Required)*

- `--output <path>`  
  Write match output to a file for reuse.

- `--help`

---

### `price`

Computes price estimates from a previously matched file or piped input.

```bash
oiq price --region us-east-1 --format summary
```

#### Flags

- `--input <path>`  
  Read match results from a file (instead of stdin).

- `--region <region>`  
  Filter pricing by region.

- `--mq <match query>`  
  Advanced filter expression.

- `--usage <path>`  
  Path to `usage.json`.

- `--format <format>`  
  Output format:
    - `summary` *(default)*
    - `text`
    - `json`
    - `markdown`
    - `atlantis-comment`

- `--help`

---

## Environment Variables

| Flag               | Env Var             |
|--------------------|---------------------|
| `--pricesheet`     | `OIQ_PRICE_SHEET`   |
| `--format`         | `OIQ_OUTPUT_FORMAT` |
| `--region`         | `OIQ_REGION`        |

---

## Examples

```bash
# Match and price a plan file
oiq match --pricesheet prices.csv tfplan.json | \
  oiq price --region us-east-1 --format summary

# Match, save output, then price separately
oiq match --pricesheet prices.csv tfplan.json --output matched.json
oiq price --input matched.json --region us-east-1 --format json

# Use environment variables
export OIQ_REGION=us-west-2
export OIQ_PRICE_SHEET=prices.csv
export OIQ_OUTPUT_FORMAT=markdown

oiq match tfplan.json | oiq price
```
