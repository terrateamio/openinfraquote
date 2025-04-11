# Building OpenInfraQuote from Source

This guide explains how to build OpenInfraQuote (OIQ) from source code. OpenInfraQuote is built using OCaml and uses the OPAM package manager for dependencies.

## Prerequisites

Before you begin, ensure you have the following prerequisites installed:

- Git
- Make
- OCaml and OPAM package manager
- Build essentials (gcc, etc.)
- m4

## System Dependencies

```bash
apt-get update
apt-get install -y git opam ca-certificates wget m4 build-essential
```

## Setting Up OPAM

Initialize OPAM if you haven't already:

```bash
opam init --disable-sandboxing -a -y
eval "$(opam env)"
```

## Installing Dependencies

OpenInfraQuote requires several OCaml libraries. Install them using OPAM:

```bash
opam install -y ISO8601 cmdliner containers csv duration logs pds ppx_blob ppx_deriving ppx_deriving_yojson uri yojson
```

## Building from Source

### Clone the repository

```bash
git clone https://github.com/terrateamio/openinfraquote.git
cd openinfraquote
```

### Build the project

```bash
eval "$(opam env)"
pds
make release
```

The built binary will be available at `build/release/oiq_cli/oiq_cli.native`.

## Running the Application

After building, you can run the application directly:

```bash
./build/release/oiq_cli/oiq_cli.native
```

Or install it to your path:

```bash
cp build/release/oiq_cli/oiq_cli.native /usr/local/bin/oiq
```

## Using Docker

You can also build and run OpenInfraQuote using Docker:

### Build the Docker image

```bash
docker build -t openinfraquote:latest .
```

### Run the container

```bash
docker run openinfraquote:latest
```
