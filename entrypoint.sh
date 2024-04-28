#!/usr/bin/env bash

set -euo pipefail

auth_key_file="$PGROK_DIR/authorized_keys"

yq eval --output-format=json "$PGROK_USERS_FILE" \
    | jq -r 'to_entries | map(.key as $u | .value | map("environment=\"PGROK_USER=" + $u + "\" " + . + "\n")) | flatten | join("")' \
    > "$auth_key_file"

cat "$auth_key_file"

ingress_driver_name="${PGROK_INGRESS_DRIVER:-"dummy"}"
ingress_driver_dir="$PGROK_DIR/ingress_driver"
ingress_driver_bin="$ingress_driver_dir/$ingress_driver_name"
ingress_driver_script="$ingress_driver_bin.sh"
if [ -x "$ingress_driver_bin" ]
then
    export PGROK_INGRESS_DRIVER_PATH="$ingress_driver_bin"
elif [ -x "$ingress_driver_script" ]
then
    export PGROK_INGRESS_DRIVER_PATH="$ingress_driver_script"
else
    echo "The ingress driver $ingress_driver_name does not exist or is not executable! This is a misconfiguration." >&2
    exit 1
fi

if ! "$PGROK_INGRESS_DRIVER_PATH" validate
then
    echo "Ingress driver validation failed! This is a misconfiguration." >&2
    exit 1
fi

jq -nr 'env | to_entries | map(select(.key | startswith("PGROK_"))) | map("export " + .key + "=" + (.value | tojson) + "\n") | join("")' \
    > "$PGROK_CLIENT_HOME/.profile"
cat "$PGROK_CLIENT_HOME/.profile"

if [ $# -gt 0 ]
then
    "$@"
else
    bash
fi

