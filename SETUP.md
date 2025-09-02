# Tailscale Setup Guide

## Creating Your Tailnet and OAuth Credentials

### 1. Create a Tailscale Account
1. Go to [https://tailscale.com](https://tailscale.com)
2. Sign up with your email address
3. Complete the account verification

### 2. Create OAuth Credentials
1. Visit [Tailscale OAuth settings](https://login.tailscale.com/admin/settings/oauth)
2. Click "Generate OAuth client"
3. Configure the OAuth client:
   - **Name:** `k8s-operator`
   - **Scopes:** Select these permissions:
     - `device:create`
     - `device:read` 
     - `device:write`
4. Click "Generate client"
5. **Important:** Copy the Client ID and Client Secret immediately (you won't see the secret again)

### 3. Configure the Secret
```bash
# Copy the template
cp k8s-manifests/oauth-secret-template.yaml k8s-manifests/oauth-secret.yaml

# Edit with your credentials
# Replace YOUR_OAUTH_CLIENT_ID_HERE and YOUR_OAUTH_CLIENT_SECRET_HERE
```

### 4. Your Tailnet Address
Your tailnet address will be your email address (e.g., `john.doe@gmail.com`).

## Alternative: Using Auth Keys (Simpler but less secure)

If you prefer to use auth keys instead of OAuth:

1. Go to [https://login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)
2. Click "Generate auth key"
3. Configure:
   - **Reusable:** Yes
   - **Ephemeral:** No (unless you want devices to disappear when disconnected)
   - **Preauthorized:** Yes
   - **Tags:** `tag:k8s` (optional but recommended)
4. Copy the auth key

Then create a simpler secret:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: operator-oauth
  namespace: tailscale
stringData:
  authkey: "tskey-auth-YOUR_AUTH_KEY_HERE"
```

## Verification
After deployment, check your devices at:
[https://login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines)

You should see:
- `k8s-api-proxy`
- `k8s-egress` 
- `k8s-subnet-router`
- `k8s-test-app`
