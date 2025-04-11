# Installation

OpenInfraQuote can be installed in several ways depending on your environment and preferences. Choose the option that best fits your workflow.

## Homebrew (macOS)

```bash
brew tap terrateamio/openinfraquote
brew install openinfraquote
```

## Direct Download

You can manually download a specific version from the [OpenInfraQuote GitHub Releases page](https://github.com/terrateamio/openinfraquote/releases).

### Linux (x86_64 and arm64)

```bash
# Get the latest release tag
LATEST_VERSION=$(curl -s https://api.github.com/repos/terrateamio/openinfraquote/releases/latest | grep -o '"tag_name": ".*"' | cut -d'"' -f4)

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  ARCH="amd64"
elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
  ARCH="arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# Download and install
curl -L "https://github.com/terrateamio/openinfraquote/releases/download/${LATEST_VERSION}/oiq-linux-${ARCH}-${LATEST_VERSION}.tar.gz" -o "oiq.tar.gz"
tar -xzf oiq.tar.gz
chmod +x oiq
sudo mv oiq /usr/local/bin/
rm oiq.tar.gz
```

### macOS (Apple Silicon)

```bash
# Get the latest release tag
LATEST_VERSION=$(curl -s https://api.github.com/repos/terrateamio/openinfraquote/releases/latest | grep -o '"tag_name": ".*"' | cut -d'"' -f4)

# Download and install
curl -L "https://github.com/terrateamio/openinfraquote/releases/download/${LATEST_VERSION}/oiq-macos-arm64-${LATEST_VERSION}.tar.gz" -o "oiq.tar.gz"
tar -xzf oiq.tar.gz
chmod +x oiq
sudo mv oiq /usr/local/bin/
rm oiq.tar.gz
```

## Run with Docker

If you prefer not to install anything locally, you can run OpenInfraQuote using Docker:

```bash
docker run --rm -i \
  -v $(pwd)/prices.csv:/prices.csv \
  -v $(pwd)/tfplan.json:/tfplan.json \
  ghcr.io/terrateamio/openinfraquote:latest \
  match --pricesheet /prices.csv /tfplan.json \
  | docker run --rm -i \
    ghcr.io/terrateamio/openinfraquote:latest \
    price --region us-east-1
```

This runs both `match` and `price` steps using the latest container.  
Make sure your `prices.csv` and `tfplan.json` files are in the current working directory.

## Verify Installation

Once installed, confirm that OpenInfraQuote is available by checking the version:

```bash
oiq --version
```

This should display the installed version number.
