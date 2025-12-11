#!/bin/bash

set -euo pipefail

export PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin

if [ ! -e /dev/net/tun ]; then
    echo 'FATAL: cannot start ZeroTier One in container: /dev/net/tun not present.'
    exit 1
fi

# Start ZeroTier One in background
zerotier-one &

sleep 2

# Use environment variable ZT_NETWORK
# If no networks are joined yet, attempt to join the one provided by ZT_NETWORK
if ! zerotier-cli listnetworks | grep -q '[0-9a-f]\{16\}'; then
    if [ -z "${ZT_NETWORK:-}" ]; then
        echo "No network configured. Set ZT_NETWORK env variable."
        exit 1
    fi
    # Validate network id format (exactly 16 hex characters)
    if ! echo "${ZT_NETWORK}" | grep -Eiq '^[0-9a-f]{16}$'; then
        echo "Invalid ZT_NETWORK value: must be 16 hex characters (example: 8a7f1c2e3d4b5a6f). Current: '${ZT_NETWORK}'"
        exit 1
    fi

    # Inline join/authorization logic
    NETWORKID="${ZT_NETWORK:-}"
    APIKEY="${ZT_API_KEY:-}"
    APIURL="${ZT_API_URL:-https://my.zerotier.com/api}"
    HOSTNAME="${ZT_MEMBER_NAME:-}"
    DESCRIPTION="${ZT_MEMBER_DESCRIPTION:-}"
    JOIN_TIMEOUT="${ZT_JOIN_TIMEOUT:-30}"
    AUTHORIZE_TIMEOUT="${ZT_AUTHORIZE_TIMEOUT:-30}"
    VERBOSE="${ZT_VERBOSE:-0}"

    # Validate dependencies
    for cmd in curl zerotier-cli; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: '$cmd' is not installed or not in PATH" >&2
            exit 1
        fi
    done

    # Determine device ID / default hostname (prefer container hostname)
    if [[ -z "$HOSTNAME" ]]; then
        # Prefer the container short hostname
        HOSTNAME="$(hostname -s 2>/dev/null || true)"
        # If hostname is empty for some reason, fall back to ZeroTier node ID
        if [[ -z "$HOSTNAME" ]]; then
            MYID=$(zerotier-cli info 2>/dev/null | awk '{print $3}' || true)
            if [[ -n "$MYID" ]]; then
                HOSTNAME="$MYID"
            else
                # Last-resort default
                HOSTNAME="zerotier-node"
            fi
        fi
    fi

    # Normalize hostname
    HOSTNAME=$(echo "$HOSTNAME" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

    authorize_member() {
        echo "Authorizing member $MYID via API..."
        retries=${ZT_API_RETRIES:-10}
        interval=${ZT_RETRY_INTERVAL:-1}
        attempt=0
        resp_file="/tmp/zt_member_resp_$$"
        http_code=""
        body=""
        while (( attempt < retries )); do
            attempt=$((attempt+1))
            http_code=$(curl -sS -w "%{http_code}" -H "Authorization: Bearer $APIKEY" -o "$resp_file" "$APIURL/network/$NETWORKID/member/$MYID" 2>/dev/null || true)
            body=$(cat "$resp_file" 2>/dev/null || true)
            if [[ "$http_code" == "200" ]]; then
                break
            fi
            # If 404, the member may not yet be visible to the controller - retry
            if [[ "$http_code" == "404" ]]; then
                echo "API returned 404 (member not found), retrying (${attempt}/${retries})..." >&2
                sleep "$interval"
                continue
            fi
            # For other non-200 codes, break and report
            break
        done
        rm -f "$resp_file" || true

        if [[ "$http_code" != "200" ]]; then
            echo "Error: API request returned HTTP ${http_code}" >&2
            if [[ -n "$body" ]]; then
                echo "Response body: $body" >&2
            fi
            return 1
        fi

        response="$body"
        escaped_name="${HOSTNAME//\"/\\\"}"
        escaped_desc="${DESCRIPTION//\"/\\\"}"
        json=$(echo "$response" | sed -E '
            s/"authorized":\s*(true|false)/"authorized":true/
            s/"name":\s*"[^"]*"/"name":"'"$escaped_name"'"/
            s/"description":\s*"[^"]*"/"description":"'"$escaped_desc"'"/
        ')
        if [[ -z "$json" ]]; then
            echo "Error: Failed to build authorization payload" >&2
            return 1
        fi
        resp_file="/tmp/zt_member_resp_post_$$"
        http_code=$(curl -sS -w "%{http_code}" -X POST -H "Authorization: Bearer $APIKEY" -H "Content-Type: application/json" -d "$json" -o "$resp_file" "$APIURL/network/$NETWORKID/member/$MYID" 2>/dev/null || true)
        post_body=$(cat "$resp_file" 2>/dev/null || true)
        rm -f "$resp_file" || true
        if [[ "$http_code" != "200" && "$http_code" != "201" && "$http_code" != "204" ]]; then
            echo "Error: Failed to update member authorization (HTTP ${http_code})" >&2
            if [[ -n "$post_body" ]]; then
                echo "Response body: $post_body" >&2
            fi
            return 1
        fi

        echo -n "Waiting for authorization"
        timeout=${AUTHORIZE_TIMEOUT:-30}
        count=0
        while ! zerotier-cli listnetworks | grep -q "$NETWORKID.*OK"; do
            echo -n "."
            sleep 1
            ((count++))
            if ((count >= timeout)); then
                echo
                echo "Warning: Authorization timeout after ${timeout}s" >&2
                return 1
            fi
        done
        echo
    }

    echo "Using embedded join logic to join network ${NETWORKID}"
    if ! zerotier-cli join "$NETWORKID"; then
        echo "Error: Failed to join network" >&2
        # fall back to continue — we'll still list networks below
    else
        echo -n "Waiting for connection"
        timeout=${JOIN_TIMEOUT:-30}
        count=0
        while ! zerotier-cli listnetworks | grep -q "$NETWORKID"; do
            echo -n "."
            sleep 1
            ((count++))
            if ((count >= timeout)); then
                echo
                echo "Error: Join timeout after ${timeout}s" >&2
                break
            fi
        done
        echo
        echo "Joined network (awaiting authorization)"
        if [[ -n "$APIKEY" ]]; then
            MYIP=$(zerotier-cli get "$NETWORKID" ip 2>/dev/null || echo "")
            # attempt to authorize
            MYID=$(zerotier-cli info 2>/dev/null | awk '{print $3}' || true)
            authorize_member || true
            MYIP=$(zerotier-cli get "$NETWORKID" ip 2>/dev/null || echo "")
            echo "Device connected with IP: $MYIP"
        else
            echo "Manual authorization required (no API key provided)"
        fi
    fi
fi

zerotier-cli listnetworks

# Keep container running
tail -f /dev/null
