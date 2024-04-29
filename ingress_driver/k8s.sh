#!/usr/bin/env bash

set -euo pipefail

command="${1?no command!}"
shift 1

perform_init() {
    echo "Valid!"
}

make_resource_name() {
    local config="${1?no config path!}"
    echo "pgrok-$(jq -r .prefix <<< "$config" | idn | sed -e 's/-/--/g' -e 's/\./-/g')"
}

perform_deploy() {
    local config
    config="$(< "${1?no config path!}")"

    local service_template ingress_template
    service_template="$(yq eval --output-format=json /service-template.yaml)"
    ingress_template="$(yq eval --output-format=json /ingress-template.yaml)"
    local ingress_class_name="${PGROK_K8S_DEFAULT_INGRESS_CLASS:-"nginx"}"

    local resource_name
    resource_name="$(make_resource_name "$config")"

    local domain
    domain="$(jq -r .domain <<< "$config" | idn)"

    local service_file ingress_file
    service_file="$(mktemp)"
    ingress_file="$(mktemp)"

    jq -r \
        --argjson config "$config" \
        --arg name "$resource_name" \
        '
        .metadata.name = $name |
        .spec.ports = [
            {
                port: $config.port,
                targetPort: $config.port,
                protocol: "TCP",
            }
        ]
        ' \
        <<< "$service_template" \
        > "$service_file"

    jq -r \
        --argjson config "$config" \
        --arg name "$resource_name" \
        --arg domain "$domain" \
        --arg ingressClass "$ingress_class_name" \
        '
        .metadata.name = $name |
        if ($config.redirect_www) then (.metadata.labels["nginx.ingress.kubernetes.io/from-to-www-redirect"] = "true") else (.) end |
        if ($config.tls_mode == "redirect" or $config.tls_mode == "only") then (.metadata.labels["nginx.ingress.kubernetes.io/force-ssl-redirect"] = "true") else (.) end |
        .spec.ingressClassName = $ingressClass |
        .spec.rules = [
            {
                host: $domain,
                http: {
                    paths: [
                        {
                            path: "/",
                            pathType: "Prefix",
                            backend: {
                                service: {
                                    name: $name,
                                    port: {
                                        number: $config.port,
                                    },
                                },
                            },
                        }
                    ],
                },
            }
        ] |
        if ($config.tls_mode == "disabled") then (.) else (
            .spec.tls = [
                {
                    hosts: ([ $config.domain ] + if ($config.redirect_www) then [("www." + $config.domain)] else ([]) end),
                    secretName: ($domain + "-tls")
                }
            ]
        ) end
        ' \
        <<< "$ingress_template" \
        > "$ingress_file"


    echo "Deploy:"
    jq <<< "$config"

    echo "Service: $(< "$service_file")"
    echo "Ingress: $(< "$ingress_file")"

    kubectl apply --overwrite --server-side -f "$service_file"  -f "$ingress_file"
}

perform_shutdown() {
    config="$(cat)"

    echo "Deploy:"
    jq <<< "$config"

    local resource_name
    resource_name="$(make_resource_name "$config")"

    kubectl delete "service/$resource_name" "ingress/$resource_name"
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