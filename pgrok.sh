#!/usr/bin/env bash

set -euo pipefail

source "$HOME/.profile"

current_pid="$$"
parent_pid="$(grep PPid "/proc/${current_pid}/status" | tr -d '\t' | cut -d':' -f2)"

readarray -t forwarded_ports <<< "$(bc <<< "ibase=16; $(grep ': 00000000' "/proc/${parent_pid}/net/tcp" | grep -v ': 00000000:0400' | cut -d' ' -f5 | cut -d':' -f2)")"

echo "Ports: ${#forwarded_ports}"
if [ "${#forwarded_ports}" = 0 ]
then
    echo "No port forwarded!" >&2
    exit 1
elif [ "${#forwarded_ports}" -gt 2 ]
then
    echo "A maximum of 2 ports may be forward!" >&2
    exit 1
fi

echo "Forwarded port: ${forwarded_ports[*]}"

command="$SSH_ORIGINAL_COMMAND"
echo "Original command: $command"
parsed_command="$(jq -cMR 'def parse($i): if ($i >= (. | length)) then ([]) else (if ($i % 2 == 1) then ([.[$i]] + parse($i + 1)) else (.[$i] | split(" ") | map(select(. != ""))) + parse($i + 1) end) end; split("(?<!\\\\)\""; "") | map(gsub("\\\\\""; "\""; "")) | parse(0) | map(split("=") | {key: .[0], value: (if ((. | length) > 1) then (.[1:] | join("=")) else null end)}) | from_entries' <<< "$command")"
echo "Args:"
jq <<< "$parsed_command"

user="$PGROK_USER"
echo "User: $user"
domain_suffix="$PGROK_DOMAIN_SUFFIX"
echo "Domain suffix: $domain_suffix"
user_domain="$user$domain_suffix"
echo "User domain: $user_domain"

pre_exit() {
    echo "Bye!" > /proc/1/fd/1
}

trap pre_exit EXIT

while true
do
    sleep 120
done
