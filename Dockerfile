ARG VERSION="dev"

FROM debian:stable-20250317 AS builder

# Install system dependencies
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        git opam ca-certificates wget m4 build-essential && \
    rm -rf /var/lib/apt/lists/*

# Initialize OPAM and install packages
RUN opam init --disable-sandboxing -a -y && \
    eval "$(opam env)" && \
    opam install -y \
        ISO8601 \
        cmdliner \
        containers \
        csv \
        duration \
        logs \
        pds \
        ppx_blob \
        ppx_deriving \
        ppx_deriving_yojson \
        uri \
        yojson

# Copy the source code and build
WORKDIR /oiq
COPY ./ /oiq
RUN eval "$(opam env)" && \
    pds && \
    echo "${VERSION}" > version && \
    make release

# Final image
FROM gcr.io/distroless/base-debian12
COPY --from=builder /oiq/build/release/oiq_cli/oiq_cli.native /usr/local/bin/oiq
ENTRYPOINT ["/usr/local/bin/oiq"]
