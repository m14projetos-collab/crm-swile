-- =============================================================================
-- SWILE OS CRM — MODO SEGURO (RECOMENDADO PARA DADOS REAIS)
-- Rode DEPOIS da migration principal, no SQL Editor do Supabase.
--
-- O que muda:
--   * Remove o acesso público (anon) às tabelas do CRM.
--   * Só usuários logados (Supabase Auth) leem e gravam.
--
-- Passos no painel do Supabase antes de rodar:
--   1. Authentication > Users > "Add user" > crie seu usuário (e-mail + senha).
--   2. Authentication > Sign In / Providers > desative "Allow new users to sign up"
--      (assim ninguém além de você consegue criar conta).
--   3. Rode este arquivo.
--   4. No app, aba "⚡ Supabase & GitHub", faça login com o e-mail e a senha.
--
-- Para voltar ao modo demo: rode de novo a migration principal.
-- =============================================================================

do $$
declare
  t text;
begin
  foreach t in array array['crm_accounts', 'crm_opportunities', 'crm_meetings', 'crm_follow_ups', 'crm_routes_rj']
  loop
    execute format('drop policy if exists "Public access %1$s" on public.%1$I', t);
    execute format('drop policy if exists "Authenticated access %1$s" on public.%1$I', t);
    execute format(
      'create policy "Authenticated access %1$s" on public.%1$I for all to authenticated using (true) with check (true)',
      t
    );
    execute format('revoke all on public.%I from anon', t);
  end loop;
end
$$;

revoke all on public.v_crm_accounts_360 from anon;

notify pgrst, 'reload schema';
