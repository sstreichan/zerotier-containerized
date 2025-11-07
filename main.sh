#!/bin/sh

export PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin

if [ ! -e /dev/net/tun ]; then
    echo 'FATAL: cannot start ZeroTier One in container: /dev/net/tun not present.'
    exit 1
fi

# Start ZeroTier One in background
zerotier-one &

sleep 2

# Use environment variable ZT_NETWORK
if ! zerotier-cli listnetworks | grep -q '[0-9a-f]\{16\}'; then
    if [ -z "$ZT_NETWORK" ]; then
        echo "No network configured. Set ZT_NETWORK env variable."
        exit 1
    fi
    zerotier-cli join "$ZT_NETWORK"
fi

zerotier-cli listnetworks

# Keep container running
tail -f /dev/null
