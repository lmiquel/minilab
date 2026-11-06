FROM alpine:3.20

RUN apk add --no-cache dbus dcron bash coreutils tzdata

COPY reboot.sh /usr/local/bin/reboot.sh
RUN chmod +x /usr/local/bin/reboot.sh \
  && echo "0 4 1 * * /usr/local/bin/reboot.sh >> /proc/1/fd/1 2>&1" > /etc/crontabs/root

CMD ["crond", "-f", "-l", "2"]
