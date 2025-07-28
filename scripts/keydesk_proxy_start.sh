#!/bin/bash
# starts ss-local as a local SOCKS5 proxy to ss server

set -e

# Args
# $1 = KEYDESK_NAME
# $2 = SS_SERVER
# $3 = SS_PORT
# $4 = SS_PASSWORD
# $5 = SS_METHOD
# $6 = LOCAL_PORT

KEYDESK_NAME="$1"
SS_SERVER="$2"
SS_PORT="$3"
SS_PASSWORD="$4"
SS_METHOD="$5"
LOCAL_PORT="$6"

ss-local \
  -s "$SS_SERVER" \
  -p "$SS_PORT" \
  -k "$SS_PASSWORD" \
  -m "$SS_METHOD" \
  -l "$LOCAL_PORT" \
  --fast-open \
  > "./tmp/ss-local-${KEYDESK_NAME}.log" 2>&1 &

PID=$!
echo $PID > "./tmp/ss-local-${KEYDESK_NAME}.pid"
echo "ss-local started on 127.0.0.1:$LOCAL_PORT (SOCKS5 proxy, log: /tmp/ss-local-${KEYDESK_NAME}.log)"