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

if ! "$PGROK_INGRESS_DRIVER_PATH" init
then
    echo "Ingress driver validation failed! This is a misconfiguration." >&2
    exit 1
fi

base_env_pattern='(?:PGROK_.+|HOSTNAME)'
if [ -n "${PGROK_ENV_PATTERN:-}" ]
then
    env_pattern="^(?:${base_env_pattern}|(?:${PGROK_ENV_PATTERN}))$"
else
    env_pattern="^${base_env_pattern}$"
fi
jq -nr --arg pattern "$env_pattern" 'env | to_entries | map(select(.key | test($pattern))) | map("export " + .key + "=" + (.value | tojson) + "\n") | join("")' \
    > "$PGROK_CLIENT_HOME/.profile"
cat "$PGROK_CLIENT_HOME/.profile"

if [ $# -gt 0 ]
then
    "$@"
else
    bash
fi

