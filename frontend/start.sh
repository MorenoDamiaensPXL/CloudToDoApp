#!/bin/sh
set -eu
API="${API_URL:-http://localhost:8080}"
find /usr/share/nginx/html -type f -name "*.js" -exec sed -i "s|{APIURL}|$API|g" {} +
exec nginx -g 'daemon off;'