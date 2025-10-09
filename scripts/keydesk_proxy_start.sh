#!/bin/bash
# starts ss-local as a local SOCKS5 proxy to ss server

mkdir -p ./tmp/proxies

set -e

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
  > "./tmp/proxies/${LOCAL_PORT}_${KEYDESK_NAME}.log" 2>&1 &

PID=$!
echo $PID > "./tmp/proxies/ss-local-${KEYDESK_NAME}.pid"
echo "ss-local started on 127.0.0.1:$LOCAL_PORT (SOCKS5 proxy, log: /tmp/proxies/${LOCAL_PORT}_${KEYDESK_NAME}.log)"