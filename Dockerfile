FROM docker.io/library/alpine:3.24.2@sha256:3cf95fe0816180395592b8373f3ec60663f076127617bbacb4eacf9667afe2e9

RUN apk add --update --no-cache openssh bash yq jq kubectl libidn uuidgen

ENV PGROK_DOMAIN_SUFFIX=".example.org" \
    PGROK_USERS_FILE="/users.yaml" \
    PGROK_CLIENT_HOME="/home/pgrok" \
    PGROK_DIR="/pgrok"

COPY sshd_config /etc/ssh/sshd_config

RUN adduser -h "$PGROK_CLIENT_HOME" -s /bin/bash -D pgrok \
 && mkdir /pgrok "$PGROK_DIR/hostkeys" \
 && chown -R pgrok:pgrok "$PGROK_DIR" \
 && chmod -R 700 "$PGROK_DIR"

USER pgrok

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-De"]

COPY entrypoint.sh /entrypoint.sh
COPY pgrok.sh /usr/local/bin/pgrok.sh
COPY ingress_driver/ "$PGROK_DIR/ingress_driver/"

