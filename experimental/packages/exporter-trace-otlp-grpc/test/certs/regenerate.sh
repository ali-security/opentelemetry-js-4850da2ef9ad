#!/usr/bin/env sh
#
# Usage: regenerate.sh
#
# regenerate.sh regenerates certificates that are used to test gRPC with TLS
# Make sure you run it in test/certs directory.
# It also serves as a documentation on how existing certificates were generated.
#
# Notes on how the committed certificates differ from a plain "openssl 365 days"
# setup:
#   * They are valid for 36500 days (~100 years). The previous fixtures were
#     generated with -days 365 and expired on Jun 8 2023, which broke the TLS
#     tests with "No connection established" long after they were written.
#   * The keys are generated unencrypted (no -des3 passphrase). OpenSSL 3.x
#     prompts interactively for a passphrase otherwise, and these keys have to
#     be readable non-interactively in CI.
#   * The server certificate carries an explicit
#     subjectAltName=DNS:localhost,IP:127.0.0.1 rather than relying on Node's
#     deprecated fallback from CN=localhost for hostname verification.

set -e

rm -f ca.crt ca.key client.crt client.csr client.key server.crt server.csr server.key

DAYS=36500

# Certificate authority.
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days "$DAYS" -key ca.key -out ca.crt -subj "/C=CL/ST=RM/L=OpenTelemetryTest/O=Root/OU=Test/CN=ca"

# Server certificate. The subjectAltName has to be supplied at signing time,
# via -extfile, because "openssl x509 -req" does not copy extensions from the CSR.
SAN_FILE=$(mktemp)
echo "subjectAltName=DNS:localhost,IP:127.0.0.1" > "$SAN_FILE"

openssl genrsa -out server.key 4096
openssl req -new -key server.key -out server.csr -subj "/C=CL/ST=RM/L=OpenTelemetryTest/O=Test/OU=Server/CN=localhost"
openssl x509 -req -days "$DAYS" -in server.csr -CA ca.crt -CAkey ca.key -set_serial 01 -extfile "$SAN_FILE" -out server.crt

rm -f "$SAN_FILE"

# Client certificate.
openssl genrsa -out client.key 4096
openssl req -new -key client.key -out client.csr -subj "/C=CL/ST=RM/L=OpenTelemetryTest/O=Test/OU=Client/CN=localhost"
openssl x509 -req -days "$DAYS" -in client.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out client.crt
