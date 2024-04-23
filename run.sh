podman build -t test .
podman run \
    --init \
    --rm \
    -it \
    -v "$PWD/ssh_host_ecdsa_key:/hostkeys/ssh_host_ecdsa_key" \
    -v "$PWD/ssh_host_ed25519_key:/hostkeys/ssh_host_ed25519_key" \
    -v "$PWD/ssh_host_rsa_key:/hostkeys/ssh_host_rsa_key" \
    -v "$PWD/authorized_keys:/hostkeys/authorized_keys" \
    -p 2222:1024 \
    test

