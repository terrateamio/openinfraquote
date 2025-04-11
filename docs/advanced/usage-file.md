# Usage File Format

OpenInfraQuote supports usage-based pricing for certain resources. The `usage.json` file allows you to override default usage assumptions and provide custom estimates.

## When to Use a Usage File

Many cloud resources have costs tied to usage volume, for example:

- API requests (S3, Lambda)
- Storage size (GB)
- Data transfer

If no usage file is provided, OpenInfraQuote uses conservative [default values](https://github.com/terrateamio/openinfraquote/blob/main/files/usage.json). To improve accuracy, you can pass your own usage file:

```bash
oiq price --usage usage.json
```
