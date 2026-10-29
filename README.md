# Swile OS CRM — Middle Market RJ (Supabase + GitHub)

Sistema Operacional Comercial B2B construído para a operação de **Sales Executive Middle Market (Rio de Janeiro)** da **Swile Brasil**.
Evolução arquitetural do *Fields OS CRM (Takeat)*, migrando do Notion para uma stack web moderna com **Supabase (PostgreSQL + RLS + Views Automáticas)** e **GitHub (GitHub Pages / Vercel)**.

---

## Arquitetura do Repositório

```text
swile-os-crm/
├── index.html                                           # Aplicação Web Completa (SPA c/ Supabase JS Client)
├── .env.example                                         # Exemplo de variáveis de ambiente do Supabase
├── .github/
│   └── workflows/
│       └── deploy.yml                                   # CI/CD automático para GitHub Pages
└── supabase/
    ├── migrations/
    │   └── 20261029000000_swile_os_crm_schema.sql       # Schema PostgreSQL + Views + Triggers + RLS
    └── seed.sql                                         # Seed inicial com 15 empresas Middle Market do RJ
```

---

## Como Colocar no Ar em 3 Minutos (Supabase + GitHub)

### Passo 1: Criar o Banco no Supabase (Gratuito)
1. Acesse [supabase.com](https://supabase.com/) e clique em **New Project** (ex: `swile-os-crm-rj`).
2. No menu lateral esquerdo do Supabase, abra **SQL Editor** -> **New Query**.
3. Cole o conteúdo do arquivo `supabase/migrations/20261029000000_swile_os_crm_schema.sql` e clique em **Run** (isso criará as tabelas `crm_accounts`, `crm_opportunities`, `crm_meetings`, `crm_follow_ups`, `crm_routes_rj` e a view `v_crm_accounts_360` que substitui todos os antigos rollups do Notion).
4. Em seguida, cole o conteúdo de `supabase/seed.sql` e clique em **Run** para popular as **15 empresas reais de Middle Market do Rio de Janeiro** já mapeadas.
5. Vá em **Project Settings** -> **API** e copie:
   - **Project URL** (`https://xxxx.supabase.co`)
   - **Project API Key (`anon` / `public`)**

### Passo 2: Subir para o seu GitHub
1. Crie um novo repositório no seu [GitHub](https://github.com/new) chamado `swile-os-crm-rj`.
2. Extraia o arquivo `swile_os_crm_supabase_github.zip` no seu computador e rode no terminal:
   ```bash
   git init
   git add .
   git commit -m "feat: initial commit Swile OS CRM Middle Market RJ + Supabase schema"
   git branch -M main
   git remote add origin https://github.com/SEU-USUARIO/swile-os-crm-rj.git
   git push -u origin main
   ```
3. No GitHub, vá em **Settings** -> **Pages** -> em *Build and deployment (Source)* selecione **GitHub Actions**. O workflow `.github/workflows/deploy.yml` publicará seu CRM automaticamente em `https://seu-usuario.github.io/swile-os-crm-rj/`.

### Passo 3: Conectar o App ao Supabase
1. Abra o seu CRM no navegador (ou use diretamente no Canvas) e clique no botão **"⚡ Supabase & GitHub"** no topo direito.
2. Cole sua **Supabase URL** e **Supabase Anon Key** e clique em **"Conectar e Sincronizar Banco"**.
3. Pronto! O CRM passará a ler e gravar todas as contas, movimentações de Kanban, reuniões e follow-ups diretamente no seu banco PostgreSQL do Supabase (e também funciona offline usando cache local).
