# Swile OS CRM — Middle Market RJ (Supabase + GitHub Pages)

Sistema operacional comercial B2B para a operação de **Sales Executive Middle Market (Rio de Janeiro)**,
evoluído do *Fields OS CRM (Takeat)*: sai do Notion e passa para **Supabase (PostgreSQL + RLS + View 360°)**
com uma SPA estática publicada no **GitHub Pages**.

- **App publicado (após o primeiro deploy):** https://m14projetos-collab.github.io/crm-swile/
- **Projeto Supabase:** `yjomvwnxqinbmoqyeyre` — [SQL Editor](https://supabase.com/dashboard/project/yjomvwnxqinbmoqyeyre/sql/new)

> ⚠️ **Sobre os dados:** as 15 empresas, contatos, operadoras atuais, vidas, tickets e a "inteligência 2026"
> (compra da Caju pelo iFood, interoperabilidade do PAT etc.) vieram do material de especificação e **não foram
> verificados** de forma independente. Trate como hipóteses de prospecção e valide antes de usar com clientes.

---

## Estrutura

```text
crm-swile/
├── index.html                                         # SPA completa (Tailwind + Chart.js + supabase-js)
├── .github/workflows/deploy.yml                       # CI (validação) + deploy no GitHub Pages
├── scripts/
│   ├── embed_sql.py                                   # Embute migration + seed no botão "Copiar SQL" do app
│   └── check_js.mjs                                   # Valida a sintaxe do JS do index.html
└── supabase/
    ├── migrations/20261029000000_swile_os_crm_schema.sql   # Schema + view 360° + triggers + RLS (modo demo)
    ├── seed.sql                                            # 15 contas + 7 oportunidades + 6 follow-ups
    └── security/secure_rls_authenticated.sql               # Modo seguro: só usuário logado acessa
```

## Colocar no ar

### 1. Banco (Supabase) — uma vez
1. Abra o [SQL Editor do projeto](https://supabase.com/dashboard/project/yjomvwnxqinbmoqyeyre/sql/new).
2. Cole o SQL completo e clique em **Run**. O jeito mais fácil: no app, aba **⚡ Supabase & GitHub** → **📋 Copiar SQL Completo**
   (é a migration + o seed juntos). Ou rode os arquivos `supabase/migrations/...sql` e depois `supabase/seed.sql`.
3. Os scripts são idempotentes: rodar de novo não duplica nem apaga dados.

Se as tabelas existirem mas estiverem vazias, o app envia as 15 contas sozinho na primeira conexão.

### 2. Site (GitHub Pages)
1. No GitHub: **Settings → Pages → Build and deployment → Source: GitHub Actions**.
2. Todo push na branch `main` roda a validação e publica o site. Pull requests só rodam a validação.

### 3. Usar
Abra o site. A URL e a chave pública já vêm preenchidas e o app conecta sozinho. O status aparece no topo e na aba
**Banco e login** (conectado / tabelas pendentes / erro). Sem banco, tudo funciona no cache local do navegador.

## Segurança — leia antes de cadastrar dados reais

A chave `sb_publishable_...` é pública por design (fica visível no código do site). Quem protege os dados é o RLS.
A migration principal cria policies **`using (true)`** para o papel `anon` — isso é um **modo demo**: qualquer pessoa
com a URL do site consegue ler, editar e apagar as contas.

Para uso real, ative o **modo seguro** (só e-mails liberados acessam):
1. No app, aba **⚡ Supabase & GitHub**: digite e-mail e senha e clique em **Criar login**.
   Por padrão o Supabase pede confirmação por e-mail: clique no link recebido.
   Em **Authentication → URL Configuration**, coloque `https://m14projetos-collab.github.io/crm-swile/` como *Site URL*
   para o link voltar ao site.
2. Em `supabase/security/secure_rls_authenticated.sql`, troque `SEU_EMAIL_AQUI` pelo e-mail do passo 1 e rode no SQL Editor.
   Nenhum dado é apagado; só muda quem pode ver.
3. No app, clique em **Entrar**. Sem login (ou com um e-mail fora da lista), o banco não devolve nada.

Mesmo com o botão "Criar login" aberto, quem se cadastrar sem estar na lista `crm_allowed_users` não vê dados.
Para liberar outra pessoa: `insert into public.crm_allowed_users (email) values ('email@exemplo.com');`

> Observação: as 15 contas iniciais também estão embutidas no `index.html` (modo offline) e o repositório é público,
> então esses dados de seed são visíveis para qualquer pessoa. O modo seguro protege o que é gravado no banco.

Para voltar ao modo demo, rode a migration principal de novo.

## Regras de negócio implementadas

| Regra | Onde |
|---|---|
| Fonte única de verdade (geografia, operadora, vidas, ticket só em `crm_accounts`) | schema + app |
| TPV mensal = vidas × ticket; anual = mensal × 12 | colunas geradas no banco + app |
| Próxima ação vem só de `crm_follow_ups` (pendente mais próximo) | view `v_crm_accounts_360` + app |
| Funil 1–5 (prob. 30/50/65/80/100%); avançar no Kanban atualiza oportunidade e status da conta | app → Supabase |
| Score ICP 0–100: prioridade (22/14), vidas (≥450: 22, ≥250: 16, senão 10), interesse (22/14/6), operadora vulnerável Caju/Pluxee/Alelo (16, senão 10), estágio × 4 | view + app (mesma fórmula) |
| Rotas Field RJ agrupam contas por polo lendo `crm_accounts` (sem duplicar endereço); "Abrir rota" monta o trajeto no Google Maps | app |
| Conta nova já nasce com oportunidade (estágio 1) e primeiro contato agendado (opcional, marcado por padrão) | app → Supabase |
| Oportunidade aberta sem follow-up pendente aparece em "Negócios sem próximo passo" e no card do Kanban | app |
| "Feito" em 1 clique: conclui e agenda o próximo contato (+1/+2/+5/+7 dias úteis, sem resposta, outro) | app → Supabase |
| Perda exige motivo (`loss_category`/`loss_details`) e pode agendar recontato em 90 dias; perdidas podem ser reabertas | app → Supabase |
| Modelos de WhatsApp/e-mail com "avança para": ao enviar, a conta e a oportunidade aberta sobem de etapa (nunca descem) | app → Supabase |

## Integrações gratuitas (aba Integrações)

Tudo por link, sem OAuth e sem custo: usa o WhatsApp, o e-mail e a agenda já logados no aparelho.

- **WhatsApp** (`wa.me`) e **ligação** (`tel:`) em cada conta, follow-up, card e na busca rápida. Modelos editáveis com
  `{nome}`, `{empresa}`, `{operadora}`, `{vidas}`, `{bairro}`, `{vendedor}`, `{link_agenda}`, `{link_proposta}`.
  Número fixo avisa que só abre se tiver WhatsApp Business.
- **E-mail**: abre rascunho no Gmail, Outlook.com, Outlook 365 ou no app do aparelho, com destinatário extraído do campo de e-mail.
- **Agenda**: Google Agenda, Outlook ou arquivo `.ics` (iPhone/Android) por follow-up, ou a semana inteira de uma vez.
- **Mapas**: Google Maps ou Waze; pesquisa rápida (Google, LinkedIn, vagas na Gupy, notícias, Reclame Aqui da operadora atual, Meet).
- **Webhook** para Make, n8n, Zapier ou Pipedream: `account.created`, `followup.completed`, `deal.won`, `deal.lost`
  (POST `text/plain` com JSON, enviado em modo `no-cors`; só aceita https público).
- **Planilhas**: importar CSV (vírgula ou ponto e vírgula; ignora empresas que já existem), exportar CSV e backup JSON.
- Busca rápida com **Ctrl+K** (ou `/`), **N** nova conta, **F** agendar ação, **Esc** fecha.

As preferências e os modelos ficam no `localStorage` deste navegador (não vão para o banco).

## Sincronização com o Supabase

- **Leitura:** ao conectar, contas, oportunidades e follow-ups são carregados do banco. O banco é a fonte da verdade.
- **Escrita:** criar/editar conta, criar oportunidade, avançar/voltar no Kanban, criar e concluir follow-up gravam no banco.
  Se a gravação falhar, a mudança fica no cache local e o app avisa.
- **Botão ⬆️ Enviar 15 Contas RJ p/ o Banco:** faz upsert por `code`. Em modo local, contas que já existem no banco não são sobrescritas.
- **SDK + fallback REST:** usa `@supabase/supabase-js`; se o SDK não carregar, usa `fetch` direto em `/rest/v1/`.
  A URL é normalizada (remove `/rest/v1/` do fim) para não duplicar a rota.

## Desenvolvimento

```bash
python3 scripts/embed_sql.py         # depois de editar os .sql, atualiza o SQL embutido no index.html
python3 scripts/embed_sql.py --check # o CI falha se o index.html estiver desatualizado
node scripts/check_js.mjs            # valida a sintaxe do JS
```

Para testar localmente, abra `index.html` no navegador (ou `python3 -m http.server`).

Total da base inicial (calculado dos dados): **15 contas, 6.820 vidas, TPV de R$ 5.907.900/mês** (R$ 70,9 mi/ano).
