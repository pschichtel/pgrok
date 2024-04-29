podman build -t test .
podman run \
    --init \
    --rm \
    -it \
    -v "$PWD/ssh_host_ecdsa_key:/pgrok/hostkeys/ssh_host_ecdsa_key" \
    -v "$PWD/ssh_host_ed25519_key:/pgrok/hostkeys/ssh_host_ed25519_key" \
    -v "$PWD/ssh_host_rsa_key:/pgrok/hostkeys/ssh_host_rsa_key" \
    -v "$PWD/testing/users.yaml:/users.yaml" \
    -v "$PWD/testing/service-template.yaml:/service-template.yaml" \
    -v "$PWD/testing/ingress-template.yaml:/ingress-template.yaml" \
    -e 'PGROK_ENV_PATTERN=KUBERNETES_.+' \
    -e 'KUBERNETES_TEST=success' \
    -e "PGROK_INGRESS_DRIVER=k8s" \
    -p 2222:1024 \
    test

