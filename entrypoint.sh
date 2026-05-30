#!/bin/sh
if [ "$1" = "--auth" ]; then
  # Run auth command
  exec bun run dist/main.js auth
elif [ -n "$GH_TOKEN" ]; then
  # Start with an explicit GitHub token when provided
  exec bun run dist/main.js start -g "$GH_TOKEN" "$@"
else
  # Start and use the persisted token file, or trigger interactive auth if missing
  exec bun run dist/main.js start "$@"
fi
