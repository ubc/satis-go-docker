FROM golang:1.12 as builder
RUN go get -d -v github.com/benschw/satis-go
WORKDIR /go/src/github.com/benschw/satis-go/
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o satis-go .


FROM node as builder1
RUN mkdir -p /opt/satis-go/admin-ui && \
    wget -qO- https://github.com/benschw/satis-admin/archive/master.tar.gz | \
        tar xzv --strip-components=1 -C /opt/satis-go/admin-ui
WORKDIR /opt/satis-go/admin-ui
RUN npm i bower && \
    node_modules/.bin/bower i --allow-root


FROM composer/satis

ENV SATIS_GO_BIND 0.0.0.0:8080
ENV SATIS_GO_DB_PATH /opt/satis-go/data
ENV SATIS_GO_REPOUI_PATH /usr/share/nginx/htlm
ENV SATIS_GO_REPO_NAME "My Satis"
ENV SATIS_GO_REPO_HOST http://localhost:8080
ENV PATH="/satis/bin:${PATH}"
ENV LANG=C.UTF-8

# based on https://github.com/frol/docker-alpine-glibc/blob/master/Dockerfile
# also added envsubst based on https://github.com/cirocosta/alpine-envsubst/blob/master/Dockerfile
RUN ALPINE_GLIBC_BASE_URL="https://github.com/sgerrand/alpine-pkg-glibc/releases/download" && \
    ALPINE_GLIBC_PACKAGE_VERSION="2.29-r0" && \
    ALPINE_GLIBC_BASE_PACKAGE_FILENAME="glibc-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    ALPINE_GLIBC_BIN_PACKAGE_FILENAME="glibc-bin-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    ALPINE_GLIBC_I18N_PACKAGE_FILENAME="glibc-i18n-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    apk add --update libintl && \
    apk add --no-cache --virtual=.build-dependencies wget ca-certificates gettext && \
    echo \
        "-----BEGIN PUBLIC KEY-----\
        MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApZ2u1KJKUu/fW4A25y9m\
        y70AGEa/J3Wi5ibNVGNn1gT1r0VfgeWd0pUybS4UmcHdiNzxJPgoWQhV2SSW1JYu\
        tOqKZF5QSN6X937PTUpNBjUvLtTQ1ve1fp39uf/lEXPpFpOPL88LKnDBgbh7wkCp\
        m2KzLVGChf83MS0ShL6G9EQIAUxLm99VpgRjwqTQ/KfzGtpke1wqws4au0Ab4qPY\
        KXvMLSPLUp7cfulWvhmZSegr5AdhNw5KNizPqCJT8ZrGvgHypXyiFvvAH5YRtSsc\
        Zvo9GI2e2MaZyo9/lvb+LbLEJZKEQckqRj4P26gmASrZEPStwc+yqy1ShHLA0j6m\
        1QIDAQAB\
        -----END PUBLIC KEY-----" | sed 's/   */\n/g' > "/etc/apk/keys/sgerrand.rsa.pub" && \
    wget \
        "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
    apk add --no-cache \
        "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
    \
    rm "/etc/apk/keys/sgerrand.rsa.pub" && \
    /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 "$LANG" || true && \
    echo "export LANG=$LANG" > /etc/profile.d/locale.sh && \
    cp /usr/bin/envsubst /usr/local/bin/envsubst && \
    \
    apk del glibc-i18n && \
    \
    rm "/root/.wget-hsts" && \
    apk del .build-dependencies && \
    rm \
        "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME"

# install satis-go
RUN mkdir -p /opt/satis-go /opt/satis-go/admin-ui
COPY --from=builder /go/src/github.com/benschw/satis-go/satis-go /opt/satis-go/
RUN chmod +x /opt/satis-go/satis-go && \
    wget -qO- https://github.com/benschw/satis-admin/releases/download/0.1.1/admin-ui.tar.gz | \
        tar xzv --strip-components=1 -C /opt/satis-go/admin-ui
COPY --from=builder1 /opt/satis-go/admin-ui/bower_components /opt/satis-go/admin-ui/bower_components

ADD entrypoint.sh /entrypoint.sh
ADD config.template.yaml /opt/satis-go/config.template.yaml

EXPOSE 8080

ENTRYPOINT ["/sbin/tini", "-g", "--", "/entrypoint.sh"]

CMD ["/opt/satis-go/satis-go"]
