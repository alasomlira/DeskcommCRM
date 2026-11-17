# DeskcommCRM on Coolify with an existing Cloudflare Tunnel

This template is for a Cloudflare Tunnel that already runs as a Docker container
in Coolify and for Supabase Cloud. It deliberately does not create a `cloudflared`
container, expose host ports, or install Supabase locally.

## Before deploying

1. Fork `melgarafael/DeskcommCRM` and copy this folder into its root. The fork is
   required because `bootstrap` mounts `supabase/baseline.sql` from the project.
2. Connect the existing tunnel container to the Docker network named by
   `TUNNEL_NETWORK` (usually `coolify`). In Cloudflare Zero Trust, set the public
   hostname service to `http://deskcommcrm-app:3000`.
3. In Supabase Auth URL Configuration, add `https://crm.example.com/auth/confirm`
   and set the Site URL to `https://crm.example.com`.
4. Connect the existing Redis container and this stack to `REDIS_NETWORK`. Set
   `EXTERNAL_REDIS_URL` with the Redis container hostname and a dedicated logical
   database, such as `/2`. Do not share n8n's Redis database index: the CRM will
   write rate-limit and debounce keys there.

## Coolify

Create a Git-based **Docker Compose Application** from the fork. Set the Compose
file path to `deskcomm-coolify-template/docker-compose.yml`, then paste the
values from `.env.coolify.example` in Environment Variables. Also copy every
required application secret from `.env.hostgator.example`; never commit them.

The template does not create a Redis container. It keeps the small `srh` bridge
because DeskcommCRM uses the Upstash-compatible REST protocol; `srh` connects to
your existing Redis through `EXTERNAL_REDIS_URL`.

Set `UPSTASH_REDIS_REST_URL=http://srh:80` and make
`UPSTASH_REDIS_REST_TOKEN` exactly equal to `SRH_TOKEN`. The WAHA URLs are also
internal: `WAHA_API_BASE_URL=http://waha:3000` and
`WAHA_WEBHOOK_BASE_URL=http://app:3000`.

Generate `WAHA_API_KEY` as a random secret and put its SHA-512 hex digest in
`WAHA_API_KEY_SHA512`. The CRM uses the plain key internally; WAHA stores only
its hash.

On the first deploy, `bootstrap` enables the required database extensions,
applies `supabase/baseline.sql`, creates the owner in Supabase Auth, and promotes
that account to platform administrator. Its persistent marker prevents repeated
schema provisioning on normal redeploys.

## Important

This is an initial-install template. Before upgrading DeskcommCRM, apply the
upstream release's documented database update procedure; do not delete the
`bootstrap-state` volume to force a migration on a populated database.

