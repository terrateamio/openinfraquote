# Environment Variables

OpenInfraQuote supports environment variables that can be used to simplify configuration in scripts and CI pipelines.

## Available Environment Variables

### `OIQ_PRICE_SHEET`

Path to the local pricing sheet (`prices.csv`).

```bash
export OIQ_PRICE_SHEET=./prices.csv
```

### `OIQ_OUTPUT_FORMAT`

Specifies the output format for the `price` command.

Supported values:

- `summary` (default)
- `text`
- `json`
- `markdown`
- `atlantis-comment`

```bash
export OIQ_OUTPUT_FORMAT=markdown
```

### `OIQ_REGION`

Sets the region to use when estimating prices.

```bash
export OIQ_REGION=us-west-2
```
