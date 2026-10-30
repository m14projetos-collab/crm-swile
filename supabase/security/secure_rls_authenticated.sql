-- =============================================================================
-- SWILE OS CRM — MODO SEGURO (RLS RESTRITO A E-MAILS LIBERADOS)
-- Rode DEPOIS da migration principal, no SQL Editor do Supabase.
--
-- O que muda:
--   * Remove o acesso público (anon) às tabelas do CRM.
--   * Só usuários LOGADOS e com e-mail na lista crm_allowed_users leem e gravam.
--     Assim, mesmo que alguém crie um login pelo botão "Criar login", não vê nada.
--   * Nenhum dado é apagado: contas, oportunidades e follow-ups continuam no banco.
--
-- Ordem recomendada:
--   1. No app, aba "⚡ Supabase & GitHub": digite e-mail + senha e clique em "Criar login".
--      Confirme pelo link que chega no e-mail (se a confirmação estiver ligada).
--   2. Troque SEU_EMAIL_AQUI abaixo pelo e-mail usado no passo 1 e rode este arquivo.
--   3. No app, clique em "Entrar".
--
-- Para liberar outra pessoa depois:
--   insert into public.crm_allowed_users (email) values ('outra@pessoa.com') on conflict do nothing;
-- Para voltar ao modo demo (aberto): rode de novo a migration principal.
-- =============================================================================

-- 1. Lista de e-mails liberados (não é exposta pela API)
create table if not exists public.crm_allowed_users (
  email text primary key,
  created_at timestamptz not null default now()
);
alter table public.crm_allowed_users enable row level security;
revoke all on public.crm_allowed_users from anon, authenticated;

insert into public.crm_allowed_users (email)
values (lower('SEU_EMAIL_AQUI'))
on conflict (email) do nothing;

-- 2. Função que diz se o usuário logado está liberado (lê o e-mail do token do Supabase Auth)
create or replace function public.crm_is_allowed()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.crm_allowed_users u
    where u.email = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

revoke all on function public.crm_is_allowed() from public, anon;
grant execute on function public.crm_is_allowed() to authenticated;

-- 3. Troca as policies: sai o acesso público, entra o acesso restrito
do $$
declare
  t text;
begin
  foreach t in array array['crm_accounts', 'crm_opportunities', 'crm_meetings', 'crm_follow_ups', 'crm_routes_rj']
  loop
    execute format('drop policy if exists "Public access %1$s" on public.%1$I', t);
    execute format('drop policy if exists "Authenticated access %1$s" on public.%1$I', t);
    execute format('drop policy if exists "Allowed users %1$s" on public.%1$I', t);
    execute format(
      'create policy "Allowed users %1$s" on public.%1$I for all to authenticated using (public.crm_is_allowed()) with check (public.crm_is_allowed())',
      t
    );
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end
$$;

revoke all on public.v_crm_accounts_360 from anon;
grant select on public.v_crm_accounts_360 to authenticated;

-- 4. Conferência: deve listar o seu e-mail
select email as emails_liberados from public.crm_allowed_users order by email;

notify pgrst, 'reload schema';
