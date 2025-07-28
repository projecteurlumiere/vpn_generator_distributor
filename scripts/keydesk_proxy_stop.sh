#!/bin/bash
# stops keydesk proxies

set -9

for pidfile in ./tmp/ss-local-*.pid; do
  [ -e "$pidfile" ] || continue  # skip if no match
  pid=$(cat "$pidfile")
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid"
    echo "Killed ss-local PID $pid from $pidfile"
  else
    echo "No process found for PID $pid from $pidfile"
  fi
  rm -f "$pidfile"
done
