FROM alpine:3.20

RUN apk add --no-cache mariadb-client dcron bash coreutils tar gzip

COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh \
  && echo "0 4 * * * /usr/local/bin/backup.sh >> /proc/1/fd/1 2>&1" > /etc/crontabs/root

CMD ["crond", "-f", "-l", "2"]
