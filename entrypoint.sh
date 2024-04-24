#!/usr/bin/env bash

set -euo pipefail

auth_key_file="$PGROK_DIR/authorized_keys"

yq eval --output-format=json "$PGROK_USERS_FILE" \
    | jq -r 'to_entries | map(.key as $u | .value | map("environment=\"PGROK_USER=" + $u + "\" " + . + "\n")) | flatten | join("")' \
    > "$auth_key_file"

cat "$auth_key_file"

jq -nr 'env | to_entries | map(select(.key | startswith("PGROK_"))) | map("export " + .key + "=" + (.value | tojson) + "\n") | join("")' \
    > "$PGROK_CLIENT_HOME/.profile"
cat "$PGROK_CLIENT_HOME/.profile"

if [ $# -gt 0 ]
then
    "$@"
else
    bash
fi

