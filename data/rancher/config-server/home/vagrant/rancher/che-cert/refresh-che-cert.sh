#!/usr/bin/env bash

if [[ "$1" = "force" || ! ( -f che-cert.pem && -f che-cert.key ) ]]; then
	openssl req -new -nodes -x509 -config che-cert.cfg -days 10000 -out che-cert.pem -keyout che-cert.key
fi

yq -y \
	--arg tls.cert.base64 "$(base64 -w0 < che-cert.pem)" \
	--arg tls.key.base64 "$(base64 -w0 < che-cert.key)" \
	--argjson tls.cert.raw "\"$(cat che-cert.pem | sed ':a;N;$!ba;s/\n/\\n/g')\\n\"" \
	'walk(if type == "string" then $ARGS.named[match("^<([^>]+)>$").captures[0].string] // . else . end)' \
	che-cert.yaml.template > che-cert.yaml

