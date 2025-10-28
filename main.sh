#!/bin/sh

export PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin

if [ ! -e /dev/net/tun ]; then
    echo 'FATAL: cannot start ZeroTier One in container: /dev/net/tun not present.'
    exit 1
fi

exec "$@"

zerotier-one -d
sleep 2

if ! zerotier-cli listnetworks | grep -q '[0-9a-f]\{16\}'; then
    echo "No network connected. Please enter a ZeroTier network ID to join:"
    read NET_ID
    zerotier-cli join "$NET_ID"
else
    zerotier-cli listnetworks
fi

tail -f /dev/null