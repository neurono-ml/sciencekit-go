#!/usr/bin/env bash
# Submit https://neurono-ml.github.io/sciencekit-go/sitemap.xml to both the
# Google Search Console API and the Bing Webmaster API.
#
# Required environment variables:
#   - GOOGLE_ACCESS_TOKEN  (OAuth2 Bearer token with scope https://www.googleapis.com/auth/webmasters)
#     OR GOOGLE_SERVICE_ACCOUNT_JSON / GOOGLE_APPLICATION_CREDENTIALS
#        (path to a Google service-account JSON key file, or inline JSON)
#   - BING_API_KEY         (Bing Webmaster Tools API key)
#
# Optional overrides:
#   - SITE_URL     (default: https://neurono-ml.github.io/sciencekit-go/)
#   - SITEMAP_URL  (default: ${SITE_URL}sitemap.xml)
#
# Fails with a non-zero exit code when credentials are absent or when either API
# returns a non-2xx HTTP status.
set -euo pipefail

SITE_URL="${SITE_URL:-https://neurono-ml.github.io/sciencekit-go/}"
SITEMAP_URL="${SITEMAP_URL:-${SITE_URL}sitemap.xml}"

GOOGLE_TOKEN="${GOOGLE_ACCESS_TOKEN:-}"
GOOGLE_SA="${GOOGLE_SERVICE_ACCOUNT_JSON:-${GOOGLE_APPLICATION_CREDENTIALS:-}}"
BING_KEY="${BING_API_KEY:-}"

missing=()
if [[ -z "$GOOGLE_TOKEN" && -z "$GOOGLE_SA" ]]; then
  missing+=("GOOGLE_ACCESS_TOKEN (or GOOGLE_SERVICE_ACCOUNT_JSON / GOOGLE_APPLICATION_CREDENTIALS)")
fi
if [[ -z "$BING_KEY" ]]; then
  missing+=("BING_API_KEY")
fi

if (( ${#missing[@]} > 0 )); then
  {
    echo "error: cannot submit sitemaps because required credentials are missing:"
    for item in "${missing[@]}"; do
      echo "  - $item"
    done
    echo
    echo "See docs/seo/search-engines.md for instructions on obtaining and exporting these credentials."
  } >&2
  exit 1
fi

mint_google_token_from_service_account() {
  local sa_input="$1"
  if ! command -v node >/dev/null 2>&1; then
    echo "error: node is required to mint an OAuth2 token from a service-account JSON key" >&2
    return 1
  fi
  SA_INPUT="$sa_input" node --input-type=module <<'EOF'
import { createSign } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';

const input = process.env.SA_INPUT;
const raw = existsSync(input) ? readFileSync(input, 'utf8') : input;
const key = JSON.parse(raw);
if (!key.client_email || !key.private_key) {
  throw new Error('service-account JSON must contain client_email and private_key');
}

const now = Math.floor(Date.now() / 1000);
const tokenUri = key.token_uri || 'https://oauth2.googleapis.com/token';
const b64url = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
const header = b64url({ alg: 'RS256', typ: 'JWT' });
const payload = b64url({
  iss: key.client_email,
  scope: 'https://www.googleapis.com/auth/webmasters',
  aud: tokenUri,
  iat: now,
  exp: now + 3600,
});
const unsigned = `${header}.${payload}`;
const signer = createSign('RSA-SHA256');
signer.update(unsigned);
const assertion = `${unsigned}.${signer.sign(key.private_key, 'base64url')}`;

const response = await fetch(tokenUri, {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  }),
});
const bodyText = await response.text();
if (!response.ok) {
  throw new Error(`OAuth2 token exchange failed (${response.status}): ${bodyText}`);
}
const parsed = JSON.parse(bodyText);
if (!parsed.access_token) {
  throw new Error('OAuth2 token response did not include access_token');
}
process.stdout.write(parsed.access_token);
EOF
}

urlencode() {
  local value="$1"
  local encoded=""
  local index char hex
  for (( index = 0; index < ${#value}; index++ )); do
    char="${value:index:1}"
    case "$char" in
      [a-zA-Z0-9.~_-]) encoded+="$char" ;;
      *)
        printf -v hex '%%%02X' "'$char"
        encoded+="$hex"
        ;;
    esac
  done
  printf '%s' "$encoded"
}

if [[ -z "$GOOGLE_TOKEN" ]]; then
  echo "Minting Google OAuth2 access token from service-account credentials..."
  GOOGLE_TOKEN="$(mint_google_token_from_service_account "$GOOGLE_SA")"
fi

encoded_site="$(urlencode "$SITE_URL")"
encoded_sitemap="$(urlencode "$SITEMAP_URL")"
google_endpoint="https://www.googleapis.com/webmasters/v3/sites/${encoded_site}/sitemaps/${encoded_sitemap}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

echo "Submitting $SITEMAP_URL to Google Search Console ($SITE_URL)..."
google_status="$(
  curl -sS -o "$tmp_dir/google.body" -w '%{http_code}' \
    -X PUT \
    -H "Authorization: Bearer ${GOOGLE_TOKEN}" \
    -H "Content-Length: 0" \
    "$google_endpoint"
)"
if [[ ! "$google_status" =~ ^2[0-9][0-9]$ ]]; then
  echo "error: Google Search Console API returned HTTP $google_status:" >&2
  cat "$tmp_dir/google.body" >&2
  echo >&2
  exit 1
fi
echo "Google Search Console: accepted (HTTP $google_status)"

bing_endpoint="https://ssl.bing.com/webmaster/api.svc/json/SubmitFeed?apikey=$(urlencode "$BING_KEY")"
bing_payload="$(printf '{"siteUrl":"%s","feedUrl":"%s"}' "$SITE_URL" "$SITEMAP_URL")"

echo "Submitting $SITEMAP_URL to Bing Webmaster Tools ($SITE_URL)..."
bing_status="$(
  curl -sS -o "$tmp_dir/bing.body" -w '%{http_code}' \
    -X POST \
    -H "Content-Type: application/json; charset=utf-8" \
    --data "$bing_payload" \
    "$bing_endpoint"
)"
if [[ ! "$bing_status" =~ ^2[0-9][0-9]$ ]]; then
  echo "error: Bing Webmaster API returned HTTP $bing_status:" >&2
  cat "$tmp_dir/bing.body" >&2
  echo >&2
  exit 1
fi
echo "Bing Webmaster Tools: accepted (HTTP $bing_status)"
