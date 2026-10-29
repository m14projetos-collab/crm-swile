-- =============================================================================
-- SWILE OS CRM — MIDDLE MARKET RJ (SUPABASE POSTGRESQL SCHEMA)
-- Evolução do Fields OS CRM (Takeat) -> Arquitetura Relacional Limpa (Seção 9 Corrigida)
-- =============================================================================

create extension if not exists "pgcrypto";

-- 1. TABELA CENTRAL: CONTAS & CLIENTES (crm_accounts)
-- Fonte Única de Verdade para geografia, decisores, vidas, cartão atual e TPV
create table if not exists public.crm_accounts (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  company_name text not null,
  cnpj text,
  website text,
  careers_url text,
  sector text not null,
  polo_rj text not null,
  neighborhood text,
  address text,
  phone text,
  email_rh text,
  decision_maker_name text,
  decision_maker_role text,
  persona_chave text not null default 'RH Estratégico / Employer Branding',
  employees_count integer not null default 100,
  active_card_users integer not null default 100,
  avg_monthly_ticket numeric(12,2) not null default 800.00,
  -- TPV Mensal e Anual calculados diretamente pelo banco (Generated Columns)
  estimated_monthly_tpv numeric(14,2) generated always as (active_card_users * avg_monthly_ticket) stored,
  estimated_annual_tpv numeric(14,2) generated always as (active_card_users * avg_monthly_ticket * 12) stored,
  current_provider text not null default 'A Validar',
  current_model text not null default 'Tradicional',
  status text not null default 'Lead Mapeado',
  priority_icp text not null default 'Alta',
  interest_level text not null default 'Morno',
  preferred_channel text not null default 'LinkedIn',
  rh_pains text,
  user_complaints text,
  provider_pros_cons text,
  swile_trigger_2026 text,
  contract_expiration_date date,
  loss_reason text,
  post_sales_phase text,
  last_interaction_at timestamptz default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. PIPELINE COMERCIAL: OPORTUNIDADES (crm_opportunities)
create table if not exists public.crm_opportunities (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.crm_accounts(id) on delete cascade,
  title text not null,
  stage text not null default '1. Qualificado (SQL)',
  stage_weight integer not null default 1, -- 1=SQL, 2=Discovery, 3=Demo, 4=Proposta/Negociação, 5=Fechado, 0=Perdido
  negotiated_lives integer not null default 100,
  proposed_monthly_tpv numeric(14,2) not null default 0,
  probability integer not null default 30 check (probability >= 0 and probability <= 100),
  weighted_forecast_tpv numeric(14,2) generated always as (proposed_monthly_tpv * (probability::numeric / 100.0)) stored,
  wallets_included text[] default array['Refeição', 'Alimentação', 'Mobilidade', 'Saúde', 'Home Office', 'Educação', 'Premiação'],
  origin_channel text default 'Outbound Prospecção',
  expected_close_date date,
  proposal_sent_date date,
  closed_date date,
  loss_category text,
  loss_details text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. AGENDA DE REUNIÕES & VISITAS (crm_meetings)
create table if not exists public.crm_meetings (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.crm_accounts(id) on delete cascade,
  route_id uuid,
  title text not null,
  meeting_date timestamptz not null,
  modality text not null default 'Videoconferência (Meet/Teams)',
  meeting_type text not null default 'Discovery RH/DP',
  status text not null default 'Agendada',
  outcome text,
  duration_minutes integer default 45,
  notes text,
  created_at timestamptz not null default now()
);

-- 4. FONTE ÚNICA DE PRÓXIMA AÇÃO: FOLLOW-UPS (crm_follow_ups)
create table if not exists public.crm_follow_ups (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.crm_accounts(id) on delete cascade,
  opportunity_id uuid references public.crm_opportunities(id) on delete set null,
  action_title text not null,
  due_date date not null,
  completed_date date,
  status text not null default 'Pendente',
  channel text not null default 'WhatsApp',
  priority text not null default 'Alta',
  trigger_used text,
  notes text,
  created_at timestamptz not null default now()
);

-- 5. PLANEJAMENTO DE ROTAS FIELD RJ (crm_routes_rj)
-- Enxuta (Correção #3 da Seção 9): sem duplicar endereço/sistema do CRM
create table if not exists public.crm_routes_rj (
  id uuid primary key default gen_random_uuid(),
  route_date date not null,
  shift text not null default 'Manhã + Tarde',
  polo_rj text not null,
  work_mode text not null default 'Campo (Field RJ)',
  status text not null default 'Planejada',
  estimated_km numeric(6,1) default 25.0,
  logistics_notes text,
  created_at timestamptz not null default now()
);

-- 6. VIEW CONSOLIDADA (SUBSTITUI ROLLUPS E FÓRMULAS DO NOTION)
create or replace view public.v_crm_accounts_360 as
select
  a.*,
  coalesce(o.max_stage_weight, 0) as max_pipeline_weight,
  coalesce(o.open_opportunities_count, 0) as open_opportunities_count,
  coalesce(m.meetings_count, 0) as meetings_count,
  f.next_action_date,
  f.next_action_title,
  f.next_action_channel,
  -- Etapa do Funil Calculada Automaticamente
  case
    when a.status = 'Perdido ❌' then 'Perdido'
    when a.status = 'Fechado ✅' or coalesce(o.max_stage_weight, 0) = 5 then 'Cliente Ativo'
    when coalesce(o.max_stage_weight, 0) >= 3 then 'Oportunidade'
    when coalesce(o.max_stage_weight, 0) >= 1 then 'SQL'
    when a.interest_level in ('Quente', 'Morno') then 'MQL'
    else 'Lead'
  end as funnel_stage,
  -- Score Comercial ICP Swile (0 a 100)
  least(100, greatest(0,
    (case when a.priority_icp = 'Alta' then 20 when a.priority_icp = 'Média' then 12 else 5 end) +
    (case when a.active_card_users >= 400 then 20 when a.active_card_users >= 150 then 12 else 5 end) +
    (case when a.interest_level = 'Quente' then 20 when a.interest_level = 'Morno' then 12 else 4 end) +
    (case when a.current_provider in ('Caju', 'Pluxee (ex-Sodexo)', 'Alelo') then 15 else 8 end) +
    (coalesce(o.max_stage_weight, 0) * 5)
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

-- 7. ROW LEVEL SECURITY (RLS) — PRONTO PARA SUPABASE FRONTEND
alter table public.crm_accounts enable row level security;
alter table public.crm_opportunities enable row level security;
alter table public.crm_meetings enable row level security;
alter table public.crm_follow_ups enable row level security;
alter table public.crm_routes_rj enable row level security;

create policy "Permitir leitura e escrita autenticada ou anon demo em crm_accounts"
  on public.crm_accounts for all using (true) with check (true);
create policy "Permitir leitura e escrita autenticada ou anon demo em crm_opportunities"
  on public.crm_opportunities for all using (true) with check (true);
create policy "Permitir leitura e escrita autenticada ou anon demo em crm_meetings"
  on public.crm_meetings for all using (true) with check (true);
create policy "Permitir leitura e escrita autenticada ou anon demo em crm_follow_ups"
  on public.crm_follow_ups for all using (true) with check (true);
create policy "Permitir leitura e escrita autenticada ou anon demo em crm_routes_rj"
  on public.crm_routes_rj for all using (true) with check (true);
