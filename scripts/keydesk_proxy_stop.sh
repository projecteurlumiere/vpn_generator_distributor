#!/bin/bash
# stops keydesk proxies

NAME="$1"
PIDFILE="./tmp/proxies/ss-local-${NAME}.pid"

if [ ! -f "$PIDFILE" ]; then
  echo "No PID file found for $NAME"
  exit 0
fi

PID=$(cat "$PIDFILE")

if kill -0 "$PID" 2>/dev/null; then
  kill "$PID"
  echo "Killed ss-local PID $PID from $PIDFILE"
else
  echo "No process found for PID $PID from $PIDFILE (perhaps, it already exited)"
fi

rm -f "$PIDFILE"