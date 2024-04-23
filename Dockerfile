FROM docker.io/library/alpine:3.19

RUN apk add --update --no-cache openssh bash yq jq kubectl

COPY sshd_config /etc/ssh/sshd_config

RUN adduser -h /home/pgrok -s /bin/bash -D pgrok \
 && mkdir /hostkeys \
 && chown pgrok:pgrok /hostkeys \
 && chmod 700 /hostkeys

USER pgrok

CMD ["/usr/sbin/sshd", "-De"]

COPY pgrok.sh /usr/local/bin/pgrok.sh

