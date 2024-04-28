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
echo "Original command: $command"
parsed_command="$(jq -cMR 'def parse($i): if ($i >= (. | length)) then ([]) else (if ($i % 2 == 1) then ([.[$i]] + parse($i + 1)) else (.[$i] | split(" ") | map(select(. != ""))) + parse($i + 1) end) end; split("(?<!\\\\)\""; "") | map(gsub("\\\\\""; "\""; "")) | parse(0) | map(split("=") | {key: .[0], value: (if ((. | length) > 1) then (.[1:] | join("=")) else null end)}) | from_entries' <<< "$command")"
echo "Args:"
jq <<< "$parsed_command"

hostname="$(jq -r '.hostname // ""' <<< "$parsed_command" | idn)"
echo "Hostname: $hostname"

user="$PGROK_USER"
echo "User: $user"
domain_suffix="$PGROK_DOMAIN_SUFFIX"
echo "Domain suffix: $domain_suffix"
user_domain="$user$domain_suffix"
echo "User domain: $user_domain"

ingress_config="$(jq -n "{}")"

on_exit() {
    "$PGROK_INGRESS_DRIVER_PATH" shutdown <<< "$ingress_config"
    touch "/tmp/$session_id"
    exit 0
}
on_int_quit_term() {
    trap '' EXIT
    on_exit
}

if "$PGROK_INGRESS_DRIVER_PATH" deploy <<< "$ingress_config"
then
    trap on_exit EXIT
    trap on_int_quit_term INT QUIT TERM HUP

    while kill -0 "$parent_pid"
    do
        sleep 1
    done
fi