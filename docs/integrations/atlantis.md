# Atlantis Integration

[Atlantis](https://www.runatlantis.io/) is a popular tool for Terraform pull request automation. OpenInfraQuote can be integrated with Atlantis to add cost estimates to your workflow.

## Custom Workflow Configuration

Add a custom workflow to your repo-config:

```yaml
workflows:
  default:
    plan:
      steps:
        - init
        - plan
        - run: terraform show -json $PLANFILE > $SHOWFILE
        - run: |
            ARCH=$(uname -m)
            if [ "$ARCH" = "x86_64" ]; then
              OIQ_ARCH="amd64"
            elif [ "$ARCH" = "aarch64" ]; then
              OIQ_ARCH="arm64"
            else
              exit 1
            fi

            LATEST_VERSION=$(curl -s https://api.github.com/repos/terrateamio/openinfraquote/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
            NEED_UPDATE=true

            if [ -f "/tmp/oiq" ]; then
              INSTALLED_VERSION=$(/tmp/oiq --version | sed 's/^v//')
              if [ "$INSTALLED_VERSION" = "$LATEST_VERSION" ]; then
                NEED_UPDATE=false
              fi
            fi

            if $NEED_UPDATE; then
              OIQ_TAR_URL="https://github.com/terrateamio/openinfraquote/releases/download/v${LATEST_VERSION}/oiq-linux-${OIQ_ARCH}-v${LATEST_VERSION}.tar.gz"
              curl -sL "$OIQ_TAR_URL" -o /tmp/oiq.tar.gz
              tar -xzf /tmp/oiq.tar.gz -C /tmp
              chmod +x /tmp/oiq
            fi

            PRICE_FILE="/tmp/prices.csv"
            PRICE_GZ_FILE="/tmp/prices.csv.gz"
            NEED_UPDATE=true

            if [ -f "$PRICE_FILE" ]; then
              LAST_MODIFIED=$(stat -c %Y "$PRICE_FILE")
              NOW=$(date +%s)
              AGE=$(( (NOW - LAST_MODIFIED) / 86400 ))
              if [ "$AGE" -lt 7 ]; then
                NEED_UPDATE=false
              fi
            fi

            if $NEED_UPDATE; then
              curl -s https://oiq.terrateam.io/prices.csv.gz -o "$PRICE_GZ_FILE"
              gunzip -f "$PRICE_GZ_FILE"
            fi
        - run: /tmp/oiq match --pricesheet /tmp/prices.csv $SHOWFILE | /tmp/oiq price --format=atlantis-comment

repos:
  - id: /.*/
    workflow: default
```
