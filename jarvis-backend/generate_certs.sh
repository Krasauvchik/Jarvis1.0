#!/bin/bash
# Generate self-signed TLS certificate for local HTTPS development.
# Run once; certs stored in ./certs/ directory.

set -e
CERT_DIR="$(dirname "$0")/certs"
mkdir -p "$CERT_DIR"

if [ -f "$CERT_DIR/server.crt" ] && [ -f "$CERT_DIR/server.key" ]; then
    echo "Certificates already exist in $CERT_DIR"
    exit 0
fi

echo "Generating self-signed TLS certificate..."
openssl req -x509 -newkey rsa:2048 \
    -keyout "$CERT_DIR/server.key" \
    -out "$CERT_DIR/server.crt" \
    -days 365 \
    -nodes \
    -subj "/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

echo "Certificate generated:"
echo "  Key:  $CERT_DIR/server.key"
echo "  Cert: $CERT_DIR/server.crt"
echo ""
echo "To trust on macOS (optional, avoids browser warnings):"
echo "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $CERT_DIR/server.crt"
