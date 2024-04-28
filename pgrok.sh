#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC1091
source "$HOME/.profile"

session_id="$(uuidgen)"
echo "Session: $session_id"

current_pid="$$"
parent_pid="$(grep PPid "/proc/${current_pid}/status" | tr -d '\t' | cut -d':' -f2)"

readarray -t forwarded_ports <<< "$(bc <<< "ibase=16; $(grep ': 00000000' "/proc/${parent_pid}/net/tcp" | grep -v ': 00000000:0400' | cut -d' ' -f5 | cut -d':' -f2)")"

port_count="${#forwarded_ports[@]}"
echo "Number of requested ports: $port_count"
for p in "${forwarded_ports[@]}"
do
    echo "Requested Port: $p"
done

if [ "$port_count" = 0 ]
then
    echo "No port forwardings requested!" >&2
    exit 1
elif [ "$port_count" -gt 1 ]
then
    echo "Only a single forwarding can be requested!" >&2
    exit 1
fi

port="${forwarded_ports[0]}"
echo "Forwarded port: $port"

command="$SSH_ORIGINAL_COMMAND"
# shellcheck disable=SC2016
command_parser='
    def parse($i): if ($i >= (. | length)) then (
        []
    ) else (
        if ($i % 2 == 1) then (
            [.[$i]] + parse($i + 1)
        ) else (
            (.[$i] | split(" ") | map(select(. != ""))) + parse($i + 1)
        ) end
    ) end;
    
    split("(?<!\\\\)\""; "") | map(gsub("\\\\\""; "\""; "")) | parse(0) | map(split("=") | {key: .[0], value: (if ((. | length) > 1) then (.[1:] | join("=")) else null end)}) | from_entries
'
parsed_command="$(jq -cMR "$command_parser" <<< "$command")"


user="$PGROK_USER"
echo "User: $user"

domain_suffix="$PGROK_DOMAIN_SUFFIX"
hostname="$(jq -r '.hostname // ""' <<< "$parsed_command")"
echo "Domain suffix: $domain_suffix"
if [ -n "$hostname" ]
then
    echo "Hostname: $hostname"
    full_domain="$hostname.$user$domain_suffix"
else
    full_domain="$user$domain_suffix"
fi
echo "Full domain: $full_domain"

tls_mode="$(jq -r 'if has("tls") then (.tls // "only") else ("disabled") end' <<< "$parsed_command")"
if ! [[ "$tls_mode" =~ ^(only|redirect|disabled)$ ]]
then
    echo "If the 'tls' option is given it must either be one of 'only', 'redirect' or 'disabled'. No value is equivalent to 'only'." >&2
    exit 1
fi
echo "TLS mode: $tls_mode"

www_mode="$(jq -r 'has("www")' <<< "$parsed_command")"
echo "Redirect www.$full_domain: $www_mode"

ingress_config="$(mktemp)"
jq -n \
    --arg user "$user" \
    --arg domain "$full_domain" \
    --arg prefix "${full_domain%"$domain_suffix"}" \
    --arg tls_mode "$tls_mode" \
    --argjson www_mode "$www_mode" \
'{
    user: $user,
    domain: $domain,
    prefix: $prefix,
    tls_mode: $tls_mode,
    redirect_www: $www_mode,
}' > "$ingress_config"

on_exit() {
    "$PGROK_INGRESS_DRIVER_PATH" shutdown "$ingress_config"
    exit 0
}
on_int_quit_term() {
    trap '' EXIT
    on_exit
}

deploy_args=("$ingress_config")
deploy_input="$(head -c 1024)"
if [ -n "$deploy_input" ]
then
    deploy_args+=("$deploy_input")
fi

if ! "$PGROK_INGRESS_DRIVER_PATH" deploy "${deploy_args[@]}"
then
    echo "Failed to deploy the ingress!" >&2
    exit 1
fi

trap on_exit EXIT
trap on_int_quit_term INT QUIT TERM HUP

while kill -0 "$parent_pid"
do
    sleep 1
done
