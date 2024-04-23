#!/usr/bin/env bash

set -euo pipefail

current_pid="$$"
parent_pid="$(cat "/proc/${current_pid}/status" | grep PPid | tr -d '\t' | cut -d':' -f2)"

forwarded_port="$(bc <<< "ibase=16; $(cat "/proc/${parent_pid}/net/tcp" | grep ': 00000000' | grep -v ': 00000000:0400' | cut -d' ' -f5 | cut -d':' -f2)")"

if [ -z "$forwarded_port" ]
then
    echo "No port forwarded!" >&2
    exit 1
fi

echo "Args: $*"
echo "Original Command: ${SSH_ORIGINAL_COMMAND:-}"
echo "Env:"
env

echo "Forwarded port: $forwarded_port"

pre_exit() {
    echo "Bye!" > /proc/1/fd/1
}

trap pre_exit EXIT

while true
do
    sleep 120
done
