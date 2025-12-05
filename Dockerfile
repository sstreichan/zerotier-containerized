## Cross-platform ZeroTier container supporting ARM64 and AMD64
## Build with: docker buildx build --platform linux/arm64,linux/amd64 -t your-tag .

FROM debian:bookworm-slim AS builder

# Install dependencies including SSL libraries for both architectures
RUN apt-get update && apt-get install -y curl gnupg ca-certificates libssl3 build-essential

# Install ZeroTier
RUN curl -s https://install.zerotier.com/ | bash

FROM debian:bookworm-slim

LABEL description="Cross-platform Containerized ZeroTier One (ARM64/AMD64)"
LABEL maintainer="zerotier-containerized"
LABEL org.opencontainers.image.title="ZeroTier One"
LABEL org.opencontainers.image.description="ZeroTier One networking virtualization platform containerized for ARM64 and AMD64"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.vendor="ZeroTier, Inc."
LABEL org.opencontainers.image.licenses="EPL-2.0"

EXPOSE 9993/udp

# Install libssl3 for runtime dependencies
RUN apt-get update && apt-get install -y libssl3 && rm -rf /var/lib/apt/lists/*

# Copy ZeroTier binaries
COPY --from=builder /usr/sbin/zerotier-cli /usr/sbin/zerotier-cli
COPY --from=builder /usr/sbin/zerotier-idtool /usr/sbin/zerotier-idtool
COPY --from=builder /usr/sbin/zerotier-one /usr/sbin/zerotier-one
COPY main.sh /main.sh

# Copy SSL libraries - this works because we install libssl3 in final stage
# The library paths will be automatically resolved by the system
COPY --from=builder /usr/lib/*/libssl.so.3 /usr/lib/*/libssl.so.3
COPY --from=builder /usr/lib/*/libcrypto.so.3 /usr/lib/*/libcrypto.so.3

# Make scripts executable
RUN chmod +x /main.sh /usr/sbin/zerotier-cli /usr/sbin/zerotier-idtool /usr/sbin/zerotier-one
RUN sed -i 's/\r$//' /main.sh

# Create ZeroTier data directory
RUN mkdir -p /var/lib/zerotier-one

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD ["/usr/sbin/zerotier-one", "--version"] || exit 1

USER root:root

ENTRYPOINT ["sh", "/main.sh"]