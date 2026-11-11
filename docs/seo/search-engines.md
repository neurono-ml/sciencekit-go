# Search Engine Registration Guide

This runbook documents how to verify ownership of **`https://neurono-ml.github.io/sciencekit-go/`** and submit its generated `sitemap.xml` in **Google Search Console** and **Bing Webmaster Tools**, either through each console's web UI or programmatically via `docs/scripts/submit-sitemaps.sh`.

## Why DNS Verification Is Not Available

`neurono-ml.github.io` is a shared `*.github.io` subdomain managed by GitHub. Organization and repository administrators cannot add `TXT` or `CNAME` records to GitHub's `github.io` DNS zone. Consequently:

- **Do not** choose the **Domain** property type in Google Search Console (it requires DNS `TXT` verification).
- **Always** choose the **URL prefix** property type with the trailing slash:
  ```text
  https://neurono-ml.github.io/sciencekit-go/
  ```
- Verify ownership using **HTML file upload** served from the site root (`docs/src/<token>.html`) or an HTML `<meta>` tag in `docs/theme/head.hbs`.

---

## 1. Google Search Console

1. Open [Google Search Console](https://search.google.com/search-console).
2. Click the property selector (top-left) → **Add property**.
3. Select **URL prefix** (right card) and enter:
   ```text
   https://neurono-ml.github.io/sciencekit-go/
   ```
4. Under **Other verification methods → HTML file**, download the generated verification file named `google<token>.html` (for example `google8f4a1c2d3e5b6789.html`). Its single-line body looks like:
   ```text
   google-site-verification: google<token>.html
   ```
5. Save that exact file inside `docs/src/` on branch `docs/documentations`:
   ```text
   docs/src/google<token>.html
   ```
   Because mdBook copies every non-Markdown file under `docs/src/` verbatim into `docs/book/`, deploying `docs/documentations` serves the file from the site root at:
   ```text
   https://neurono-ml.github.io/sciencekit-go/google<token>.html
   ```
   (`docs/scripts/postbuild.mjs` automatically skips `google*.html` files so their contents remain byte-for-byte identical and are excluded from `sitemap.xml`.)
   - *Alternative:* Under **HTML tag**, copy the `content` token and add `<meta name="google-site-verification" content="<token>">` inside `docs/theme/head.hbs`.
6. Push to `docs/documentations`, wait for `.github/workflows/deploy-documentation.yml` to succeed, confirm `curl -fsSL https://neurono-ml.github.io/sciencekit-go/google<token>.html` returns `200`, and click **Verify** in Google Search Console.

### Submitting the Sitemap in Google Search Console

1. Select the verified `https://neurono-ml.github.io/sciencekit-go/` property.
2. In the left sidebar, open **Indexing → Sitemaps**.
3. In the **Add a new sitemap** field (already prefixed with `https://neurono-ml.github.io/sciencekit-go/`), enter:
   ```text
   sitemap.xml
   ```
4. Click **Submit** and confirm the status updates to **Success**.

---

## 2. Bing Webmaster Tools

1. Open [Bing Webmaster Tools](https://www.bing.com/webmasters).
2. Choose one of the two onboarding paths:
   - **Option A — Import from Google Search Console (fastest once Google is verified):** Click **Import** under *Import your sites from Google Search Console*, authorize read access to the verified property `https://neurono-ml.github.io/sciencekit-go/`, and import it directly (sitemaps carry over automatically).
   - **Option B — Add manually:** Enter `https://neurono-ml.github.io/sciencekit-go/` under *Add your site manually* and verify using one of Bing's non-DNS methods:
     - **File at site root:** Download `BingSiteAuth.xml` (or any HTML verification file `<token>.html` issued by Bing) and place it under `docs/src/` (`docs/src/BingSiteAuth.xml` or `docs/src/<token>.html`) on branch `docs/documentations` so GitHub Pages serves it at `https://neurono-ml.github.io/sciencekit-go/BingSiteAuth.xml` (or `https://neurono-ml.github.io/sciencekit-go/<token>.html`).
     - **HTML Meta Tag:** Copy the `msvalidate.01` token and add `<meta name="msvalidate.01" content="<token>">` to `docs/theme/head.hbs`.
3. Push to `docs/documentations`, wait for the Pages deployment to finish, and click **Verify**.

### Submitting the Sitemap in Bing Webmaster Tools

1. Open the `https://neurono-ml.github.io/sciencekit-go/` property in Bing Webmaster Tools.
2. In the left sidebar, select **Sitemaps** → click **Submit sitemap** (top-right).
3. Enter the full sitemap URL:
   ```text
   https://neurono-ml.github.io/sciencekit-go/sitemap.xml
   ```
4. Click **Submit**.

---

## 3. Automated API Submission (`docs/scripts/submit-sitemaps.sh`)

Once the property is verified in both consoles, you can submit (or re-submit) `https://neurono-ml.github.io/sciencekit-go/sitemap.xml` programmatically using `docs/scripts/submit-sitemaps.sh`.

### Required Credentials

1. **Google Search Console API** (enable *Google Search Console API* in Google Cloud Console and grant the service account `Owner` or `Full` permission on the Search Console property):
   - Either export a short-lived OAuth 2.0 Bearer token with scope `https://www.googleapis.com/auth/webmasters`:
     ```sh
     export GOOGLE_ACCESS_TOKEN="ya29...."
     ```
   - Or point `GOOGLE_SERVICE_ACCOUNT_JSON` (or `GOOGLE_APPLICATION_CREDENTIALS`) at a service-account JSON key file (or inline JSON string); the script signs an RS256 JWT with Node.js and exchanges it at `https://oauth2.googleapis.com/token`:
     ```sh
     export GOOGLE_SERVICE_ACCOUNT_JSON="/path/to/service-account.json"
     ```
2. **Bing Webmaster API** (generate under Bing Webmaster Tools → *Settings (gear icon) → API Access → API Key*):
   ```sh
   export BING_API_KEY="your-bing-api-key"
   ```

### Running the Script

```sh
docs/scripts/submit-sitemaps.sh
```

If either credential is missing, expired, or rejected by Google or Bing, the script prints the exact error to `stderr` and exits with a non-zero status code.
