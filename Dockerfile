FROM elixir:1.10-alpine AS builder

RUN apk add --update --no-cache nodejs yarn git build-base python && \
    mix local.rebar --force && \
    mix local.hex --force

ENV MIX_ENV=prod

WORKDIR /opt/app

COPY mix.exs mix.lock ./
RUN mix do deps.get --only $MIX_ENV, deps.compile

COPY assets assets
RUN (cd assets && yarn install && yarn deploy)

COPY config config
COPY lib lib
COPY priv priv
COPY grafana/dashboards grafana/dashboards

RUN mix do phx.digest, compile

RUN mkdir -p /opt/built && mix release --path /opt/built

########################################################################

FROM alpine:3.11 AS app

ENV LANG=C.UTF-8 \
    SRTM_CACHE=/opt/app/.srtm_cache \
    HOME=/opt/app

RUN apk add --update --no-cache bash openssl tzdata

WORKDIR $HOME

COPY --chown=nobody entrypoint.sh /
COPY --from=builder --chown=nobody /opt/built .
RUN mkdir .srtm_cache

EXPOSE 4000

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
CMD ["bin/teslamate", "start"]
