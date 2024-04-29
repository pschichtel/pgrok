#!/usr/bin/env bash

set -euo pipefail

command="${1?no command!}"
shift 1

perform_init() {
    echo "Valid!"
}

perform_deploy() {
    config="$(cat)"

    echo "Deploy:"
    jq <<< "$config"

    kubectl get services
    kubectl get ingress
    kubectl get pod "$HOSTNAME"
}

perform_shutdown() {
    config="$(cat)"

    echo "Deploy:"
    jq <<< "$config"
}

case "$command" in
    init)
        perform_init "$@"
        ;;
    deploy)
        perform_deploy "$@"
        ;;
    shutdown)
        perform_shutdown "$@"
        ;;
    *)
        echo "Unknown command: $command" >&2
        exit 1
        ;;
esac