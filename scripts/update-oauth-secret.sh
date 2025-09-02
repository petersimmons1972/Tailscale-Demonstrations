#!/bin/bash

# Script to update Tailscale OAuth secret
# Usage: ./update-oauth-secret.sh [oauth|authkey]

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 [oauth|authkey]"
    echo "  oauth   - Use OAuth client credentials"
    echo "  authkey - Use auth key (simpler)"
    exit 1
fi

METHOD=$1

case $METHOD in
    oauth)
        echo "Enter your Tailscale OAuth credentials:"
        read -p "Client ID: " CLIENT_ID
        read -s -p "Client Secret: " CLIENT_SECRET
        echo
        
        if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
            echo "Error: Both Client ID and Client Secret are required"
            exit 1
        fi
        
        kubectl patch secret operator-oauth -n tailscale --type='merge' -p="{\"stringData\":{\"client_id\":\"$CLIENT_ID\",\"client_secret\":\"$CLIENT_SECRET\"}}"
        echo "OAuth secret updated successfully!"
        ;;
        
    authkey)
        read -s -p "Enter your Tailscale auth key: " AUTH_KEY
        echo
        
        if [ -z "$AUTH_KEY" ]; then
            echo "Error: Auth key is required"
            exit 1
        fi
        
        kubectl patch secret operator-oauth -n tailscale --type='merge' -p="{\"stringData\":{\"authkey\":\"$AUTH_KEY\"}}"
        echo "Auth key secret updated successfully!"
        ;;
        
    *)
        echo "Error: Invalid method. Use 'oauth' or 'authkey'"
        exit 1
        ;;
esac

echo "Restarting Tailscale operator..."
kubectl rollout restart deployment/operator -n tailscale

echo "Waiting for operator to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/operator -n tailscale

echo "Checking operator status..."
kubectl get pods -n tailscale
