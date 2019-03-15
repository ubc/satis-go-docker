#!/bin/sh

envsubst < /opt/satis-go/config.template.yaml > /opt/satis-go/config.yaml

if [[ $GITHUB_TOKEN ]]; then
    /satis/vendor/bin/composer config -g github-oauth.github.com $GITHUB_TOKEN
fi

exec "$@"
