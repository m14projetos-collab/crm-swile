-- =============================================================================
-- SWILE OS CRM — FASE 5: RLS POR USUÁRIO (cada login só vê as próprias linhas)
-- Rode no SQL Editor do Supabase. O script é idempotente: pode rodar de novo.
--
-- O que faz, nesta ordem (tudo numa transação: se algo falhar, nada muda):
--   1. Garante a lista de e-mails liberados (crm_allowed_users) e a função
--      crm_is_allowed(), iguais às do Modo Seguro. Se você já rodou o Modo Seguro,
--      nada se perde.
--   2. Procura o seu usuário em auth.users pelo e-mail abaixo. Se não achar, PARA
--      com erro, antes de mexer em qualquer tabela.
--   3. Cria a coluna user_id (default auth.uid()) nas 5 tabelas do CRM e PREENCHE
--      as linhas que já existem com o seu id. Sem isso, as contas atuais sumiriam
--      depois das policies novas.
--   4. Troca as policies: só usuário logado, liberado na lista E dono da linha
--      (user_id = auth.uid()) lê e grava. O acesso anônimo sai.
--   5. Recria a view 360° (respeita o RLS de quem consulta) e mostra a conferência.
--
-- Antes de rodar:
--   a. No app, aba "Banco e login": crie o login (Criar login) e confirme o e-mail.
--   b. Troque SEU_EMAIL_AQUI (linha do v_email, no passo 2) pelo e-mail desse login.
--
-- Depois de rodar:
--   c. No app, clique em "Entrar". As contas aparecem como antes.
--   d. Linhas novas recebem o seu user_id sozinhas (o app também envia).
--
-- Cuidados:
--   * Não rode de novo a migration principal depois deste script: ela recria as
--     policies abertas ("Public access") e o banco volta a ficar público.
--   * Linhas inseridas pelo SQL Editor (usuário postgres) ficam com user_id nulo e
--     não aparecem no app. Rode este script de novo para atribuí-las a você.
--   * crm_accounts.code continua único no banco todo (não por usuário). Para mais
--     de um vendedor com códigos próprios, a constraint precisa mudar depois.
--   * Para liberar outra pessoa: insira o e-mail em crm_allowed_users. Ela verá só
--     as linhas que ela mesma criar.
-- =============================================================================

begin;

-- 1. Lista de e-mails liberados e função de checagem (mesma definição do Modo Seguro)
create table if not exists public.crm_allowed_users (
  email text primary key,
  created_at timestamptz not null default now()
);
alter table public.crm_allowed_users enable row level security;
revoke all on public.crm_allowed_users from anon, authenticated;

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

-- 2 e 3. Dono das linhas atuais + coluna user_id
do $$
declare
  v_email text := lower(trim('SEU_EMAIL_AQUI'));
  v_uid uuid;
  t text;
begin
  select id into v_uid from auth.users where lower(email) = v_email limit 1;
  if v_uid is null then
    raise exception 'Usuário % não encontrado em auth.users. Crie o login no app (Banco e login > Criar login), confirme o e-mail e troque SEU_EMAIL_AQUI antes de rodar.', v_email;
  end if;

  insert into public.crm_allowed_users (email) values (v_email) on conflict (email) do nothing;

  foreach t in array array['crm_accounts', 'crm_opportunities', 'crm_meetings', 'crm_follow_ups', 'crm_routes_rj']
  loop
    if to_regclass('public.' || t) is null then
      raise notice 'Tabela public.% não existe: pulada.', t;
      continue;
    end if;
    execute format('alter table public.%I add column if not exists user_id uuid', t);
    execute format('alter table public.%I alter column user_id set default auth.uid()', t);
    execute format('update public.%I set user_id = %L where user_id is null', t, v_uid);
    execute format('create index if not exists %I on public.%I (user_id)', t || '_user_id_idx', t);
  end loop;
end
$$;

-- 4. Policies: logado + liberado + dono da linha
do $$
declare
  t text;
begin
  foreach t in array array['crm_accounts', 'crm_opportunities', 'crm_meetings', 'crm_follow_ups', 'crm_routes_rj']
  loop
    continue when to_regclass('public.' || t) is null;
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "Public access %1$s" on public.%1$I', t);
    execute format('drop policy if exists "Authenticated access %1$s" on public.%1$I', t);
    execute format('drop policy if exists "Allowed users %1$s" on public.%1$I', t);
    execute format('drop policy if exists "Owner only %1$s" on public.%1$I', t);
    execute format(
      'create policy "Owner only %1$s" on public.%1$I for all to authenticated '
      'using (user_id = (select auth.uid()) and public.crm_is_allowed()) '
      'with check (user_id = (select auth.uid()) and public.crm_is_allowed())',
      t
    );
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end
$$;

-- 5. View 360°: recriada para incluir user_id em a.* e continuar com security_invoker
drop view if exists public.v_crm_accounts_360;
create view public.v_crm_accounts_360
with (security_invoker = true) as
select
  a.*,
  coalesce(o.max_stage_weight, 0) as max_pipeline_weight,
  coalesce(o.open_opportunities_count, 0) as open_opportunities_count,
  coalesce(m.meetings_count, 0) as meetings_count,
  f.next_action_date,
  f.next_action_title,
  f.next_action_channel,
  case
    when a.status = 'Perdido ❌' then 'Perdido'
    when a.status = 'Fechado ✅' or coalesce(o.max_stage_weight, 0) = 5 then 'Cliente Ativo'
    when coalesce(o.max_stage_weight, 0) >= 3 then 'Oportunidade'
    when coalesce(o.max_stage_weight, 0) >= 1 then 'SQL'
    when a.interest_level in ('Quente', 'Morno') then 'MQL'
    else 'Lead'
  end as funnel_stage,
  least(100, greatest(0,
    (case when a.priority_icp = 'Alta' then 22 when a.priority_icp = 'Média' then 14 else 6 end) +
    (case when a.active_card_users >= 450 then 22 when a.active_card_users >= 250 then 16 else 10 end) +
    (case when a.interest_level = 'Quente' then 22 when a.interest_level = 'Morno' then 14 else 6 end) +
    (case when a.current_provider in ('Caju', 'Pluxee (ex-Sodexo)', 'Alelo') then 16 else 10 end) +
    (coalesce(o.max_stage_weight, 0) * 4)
  )) as commercial_score
from public.crm_accounts a
left join (
  select
    account_id,
    max(stage_weight) as max_stage_weight,
    count(*) filter (where stage_weight between 1 and 4) as open_opportunities_count
  from public.crm_opportunities
  group by account_id
) o on o.account_id = a.id
left join (
  select account_id, count(*) as meetings_count
  from public.crm_meetings
  group by account_id
) m on m.account_id = a.id
left join lateral (
  select
    fu.due_date as next_action_date,
    fu.action_title as next_action_title,
    fu.channel as next_action_channel
  from public.crm_follow_ups fu
  where fu.account_id = a.id and fu.status = 'Pendente'
  order by fu.due_date asc
  limit 1
) f on true;

revoke all on public.v_crm_accounts_360 from anon;
grant select on public.v_crm_accounts_360 to authenticated;

commit;

-- 6. Conferência: "sem_dono" deve ser 0 em todas as tabelas
drop table if exists pg_temp.crm_rls_check;
create temp table crm_rls_check (tabela text, total bigint, sem_dono bigint);
do $$
declare t text; v_total bigint; v_null bigint;
begin
  foreach t in array array['crm_accounts', 'crm_opportunities', 'crm_meetings', 'crm_follow_ups', 'crm_routes_rj']
  loop
    if to_regclass('public.' || t) is null then
      insert into crm_rls_check values (t || ' (não existe)', null, null);
    else
      execute format('select count(*), count(*) filter (where user_id is null) from public.%I', t) into v_total, v_null;
      insert into crm_rls_check values (t, v_total, v_null);
    end if;
  end loop;
end
$$;
select * from crm_rls_check;

-- 7. Ingestão pelo script Python semanal (scripts/ingest_prospects.py, docs/ingestao_python.md)
--   Endpoint: POST https://<projeto>.supabase.co/rest/v1/crm_accounts?on_conflict=code
--   Headers:  apikey: <chave pública>, Authorization: Bearer <access_token do SEU login>,
--             Prefer: resolution=ignore-duplicates,return=minimal
--   O token vem de POST /auth/v1/token?grant_type=password com o seu e-mail e senha
--   (variáveis de ambiente). Assim o RLS vale também para o script e o user_id é
--   preenchido sozinho. NÃO use a service_role key: ela ignora o RLS e não pode ir
--   para o repositório nem para o site.

notify pgrst, 'reload schema';
