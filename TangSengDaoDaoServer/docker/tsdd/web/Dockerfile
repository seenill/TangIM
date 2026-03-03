FROM python:3.12-alpine

WORKDIR /srv/web

COPY assets/web/ /srv/web/
COPY docker/tsdd/web/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
