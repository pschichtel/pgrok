#!/usr/bin/env bash

set -euo pipefail

command="${1?no command!}"
shift 1

perform_deploy() {
    config="$1"
    
    echo "Current ENV:"
    env

    echo "Deploy Config:"
    jq < "$config"

    echo "Deploy Input:"
    if [ $# -gt 1 ]
    then
        echo "$2"
    else
        echo "none"
    fi
}

perform_shutdown() {
    config="$1"

    echo "Current ENV:"
    env

    echo "Shutdown Config:"
    jq < "$config"
}

perform_validate() {
    echo "Current ENV:"
    env
    echo "Valid!"
}

case "$command" in
    deploy)
        perform_deploy "$@"
        ;;
    shutdown)
        perform_shutdown "$@"
        ;;
    validate)
        perform_validate "$@"
        ;;
    *)
        echo "Unknown command: $command" >&2
        exit 1
        ;;
esac

