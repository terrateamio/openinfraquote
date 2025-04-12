# Architecture Overview

This document provides an overview of OpenInfraQuote's internal architecture, components, and source layout.

## High-Level Overview

OpenInfraQuote is implemented in OCaml and organized around a modular, functional pipeline:

```
Terraform Plan/State → Match → Price → Output
                      │        │       │
                      ▼        ▼       ▼
                 Match Set   Pricing  Format
```

## Components

### Match Step (`oiq_match_file.ml`)

Provides file-level presentation logic. The actual match logic is implemented in `oiq.ml`.

### Pricing Engine (`oiq_pricer.ml`)

Connects matched resources to pricing logic and computes cost estimates.

### Pricing Data (`oiq_prices.ml`)

Parses the pricing CSV file into structured entries.

### Terraform Support (`oiq_tf.ml`)

Handles extraction of normalized resource representations from Terraform plan or state JSON.

### Usage Model (`oiq_usage.ml`)

Contains usage model representation and utility functionality.

### CLI Interface (`oiq_cli/oiq_cli.ml`)

Implements the command-line interface and subcommands (`match`, `price`).

### Match Query Language

Defined in:

- `oiq_match_query.ml`
- `oiq_match_query_parser.ml`
- `oiq_match_query_lexer.ml`

This custom expression language allows advanced resource filtering using selectors like:

```text
(type = aws_instance and region = us-east-1)
```

Used internally and via `--mq` and `--region` CLI flags.
