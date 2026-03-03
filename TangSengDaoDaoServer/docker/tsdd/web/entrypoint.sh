#!/bin/sh
set -eu

API_URL_VALUE="${API_URL:-http://127.0.0.1:8090/v1/}"
case "$API_URL_VALUE" in
  */) ;;
  *) API_URL_VALUE="${API_URL_VALUE}/" ;;
esac

printf 'const apiURL = "%s"\n' "$API_URL_VALUE" > /srv/web/js/config.js

exec python3 -m http.server 80 --directory /srv/web
