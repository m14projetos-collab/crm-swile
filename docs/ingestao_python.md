# Ingestão semanal de prospects (script Python)

O script `scripts/ingest_prospects.py` envia empresas novas (≥ 200 vidas) para a tabela `crm_accounts` pela API REST do Supabase. Ele não tem dependências além do Python 3.

## Endpoint

| Passo | Requisição |
|---|---|
| Login | `POST {SUPABASE_URL}/auth/v1/token?grant_type=password` com `{"email", "password"}` e header `apikey: <chave pública>` |
| Envio | `POST {SUPABASE_URL}/rest/v1/crm_accounts?on_conflict=code` |
| Headers do envio | `apikey: <chave pública>`, `Authorization: Bearer <access_token do login>`, `Content-Type: application/json`, `Prefer: resolution=ignore-duplicates,return=minimal` |
| Corpo | Lista JSON de contas: `code`, `company_name`, `sector`, `polo_rj`, `active_card_users` e campos opcionais |

Contas com o mesmo `code` não são sobrescritas. Sem `code` no CSV, o script gera `PY-` + hash do nome, estável entre semanas.

## Credenciais

- Use a **chave pública** (a mesma do site) e o **seu login** do CRM, em variáveis de ambiente (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `CRM_EMAIL`, `CRM_PASSWORD`).
- Com o RLS por usuário (`supabase/security/rls_por_usuario.sql`), o banco preenche `user_id` com o seu id e só aceita contas suas.
- **Não use a `service_role` key.** Ela ignora o RLS: se vazar (repositório, site, print), qualquer pessoa lê e apaga o banco inteiro. Ela nunca vai para o repositório nem para o `index.html`.

## Rodar

```bash
export SUPABASE_URL="https://<projeto>.supabase.co"
export SUPABASE_ANON_KEY="sb_publishable_..."
export CRM_EMAIL="seu@email.com"
read -s CRM_PASSWORD && export CRM_PASSWORD
python3 scripts/ingest_prospects.py prospects.csv --dry-run   # confere sem enviar
python3 scripts/ingest_prospects.py prospects.csv
```

Para rodar toda semana, agende no seu computador (cron, Agendador de Tarefas do Windows) ou num GitHub Actions com as variáveis em *Secrets*.
