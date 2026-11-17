#!/bin/sh
set -eu

# This service is deliberately idempotent. It only provisions an empty Supabase
# project, then records completion in its own persistent volume.
if [ -f /state/complete ]; then
  exit 0
fi

: "${SUPABASE_DB_URL:?SUPABASE_DB_URL is required}"
: "${NEXT_PUBLIC_SUPABASE_URL:?NEXT_PUBLIC_SUPABASE_URL is required}"
: "${SUPABASE_SERVICE_ROLE_KEY:?SUPABASE_SERVICE_ROLE_KEY is required}"
: "${OWNER_EMAIL:?OWNER_EMAIL is required}"
: "${OWNER_PASSWORD:?OWNER_PASSWORD is required}"

apk add --no-cache curl jq >/dev/null

existing="$(psql "$SUPABASE_DB_URL" -tAc "select 1 from information_schema.tables where table_schema='public' and table_name='organizations' limit 1" | tr -d '[:space:]')"

if [ "$existing" != "1" ]; then
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -c "create extension if not exists vector with schema public; create extension if not exists citext with schema public; create extension if not exists pg_trgm with schema public;"
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f /schema/baseline.sql
fi

payload="$(jq -nc --arg email "$OWNER_EMAIL" --arg password "$OWNER_PASSWORD" --arg locale "${APP_LOCALE:-pt-BR}" '{email:$email,password:$password,email_confirm:true,user_metadata:{locale:$locale}}')"
curl -fsS -X POST "$NEXT_PUBLIC_SUPABASE_URL/auth/v1/admin/users" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d "$payload" >/dev/null || true

psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -v owner_email="$OWNER_EMAIL" -v app_locale="${APP_LOCALE:-pt-BR}" <<'SQL'
select set_config('deskcomm.owner_email', :'owner_email', false);
select set_config('deskcomm.app_locale', :'app_locale', false);
do $$
declare
  v_uid uuid;
  v_org uuid;
begin
  select id into v_uid from auth.users where email = current_setting('deskcomm.owner_email');
  if v_uid is null then
    raise exception 'owner was not created in Supabase Auth';
  end if;
  select id into v_org from public.organizations where slug = 'minha-empresa';
  if v_org is null then
    insert into public.organizations (slug, display_name, legal_name, locale, created_by)
    values ('minha-empresa', 'Minha Empresa', 'Minha Empresa', current_setting('deskcomm.app_locale'), v_uid)
    returning id into v_org;
  end if;
  insert into public.user_organizations (user_id, organization_id, role, accepted_at)
  values (v_uid, v_org, 'admin', now())
  on conflict (user_id, organization_id) do update set role = 'admin', revoked_at = null;
  insert into public.platform_admins (user_id, granted_by, scope, mfa_required, reason)
  values (v_uid, v_uid, 'full', false, 'Bootstrap Coolify')
  on conflict do nothing;
end $$;
SQL

touch /state/complete

