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

Parses Terraform plan/state JSON and builds a set of normalized resource representations with metadata needed for pricing.

### Pricing Engine (`oiq_pricer.ml`)

Evaluates the matched resources against a local pricing sheet (CSV) and computes cost estimates.

### Pricing Data (`oiq_prices.ml`)

Parses the pricing CSV file into structured entries.

### Terraform Support (`oiq_tf.ml`)

Handles extraction of normalized resource representations from Terraform plan or state JSON.

### Usage Model (`oiq_usage.ml`)

Applies default or user-supplied `usage.json` values to usage-based resources, merging usage into each resource's context before pricing.

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
