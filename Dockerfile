## Final fixed version: build and runtime separation correctly handled

FROM debian:bookworm-slim as builder

RUN apt-get update && apt-get install -y curl gnupg ca-certificates
RUN curl -s https://install.zerotier.com/ | bash

# Copy script AFTER installation so chmod succeeds
COPY main.sh /var/lib/zerotier-one/main.sh
RUN chmod 0755 /var/lib/zerotier-one/main.sh

FROM debian:bookworm-slim

LABEL description="Containerized ZeroTier One"

EXPOSE 9993/udp

COPY --from=builder /usr/lib/x86_64-linux-gnu/libssl.so.3 /usr/lib/x86_64-linux-gnu/libssl.so.3
COPY --from=builder /usr/lib/x86_64-linux-gnu/libcrypto.so.3 /usr/lib/x86_64-linux-gnu/libcrypto.so.3

COPY --from=builder /usr/sbin/zerotier-cli /usr/sbin/zerotier-cli
COPY --from=builder /usr/sbin/zerotier-idtool /usr/sbin/zerotier-idtool
COPY --from=builder /usr/sbin/zerotier-one /usr/sbin/zerotier-one
COPY --from=builder /var/lib/zerotier-one/main.sh /main.sh

USER root:root

ENTRYPOINT ["/main.sh"]