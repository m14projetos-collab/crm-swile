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

## Relatórios (aba Relatórios)

- **Indicadores:** contas, clientes, leads quentes, pipeline aberto (TPV mensal), forecast ponderado, taxa de conversão (ganhos ÷ ganhos + perdas no período), atividades concluídas e follow-ups atrasados.
- **Gráficos:** funil por etapa (quantidade e TPV), prospecção por status, atividades concluídas por semana e temperatura da carteira.
- **Filtro de período** (7, 30, 90 dias ou tudo) para ganhos, perdas e atividades.
- **PDF:** botão "PDF" abre a impressão do navegador já formatada (fundo branco, só o relatório). Escolha "Salvar como PDF".
- **Excel:** botão "Excel" gera um `.xlsx` com as abas Resumo, Contas, Oportunidades e Follow-ups (SheetJS, carregado só na hora do clique). Sem internet, cai para CSV.
- **Enviar resumo:** texto pronto com os números, por WhatsApp ou e-mail.

## Produtividade

- **Pipeline:** arraste o card para outra coluna (os botões Voltar/Avançar continuam). Etapa, probabilidade, status da conta e forecast se atualizam juntos.
- **Contas:** clique no cabeçalho (Empresa, Polo, Vidas, TPV/mês, Cartão atual, Score) para ordenar; clique de novo para inverter. Filtros de polo, cartão e prioridade combinam com a busca.
- **Ficha da conta:** campo "Registrar nota ou interação" (Nota, WhatsApp, Ligação, Reunião, E-mail, Visita) com data e hora. WhatsApp, Ligar e E-mail feitos pelo CRM entram no histórico sozinhos. As notas ficam no navegador e vão no backup JSON (ainda não há tabela no Supabase para elas).
- **Celular e telas menores que 1024px:** botão ☰ abre o menu lateral completo.
- **Exclusões** pedem confirmação numa janela do próprio app. Excluir a conta apaga junto oportunidades, follow-ups e notas.
- **Banco sem login:** o topo mostra "Local · entre para sincronizar" em âmbar, sem acusar erro.

## Fase 3: pipeline automático, copiloto de call e home office

- **Pipeline automático** (`autoAdvancePipelineFromAccount`): o card anda sozinho quando você muda o status da conta (cria a oportunidade se faltar), marca interesse Quente (1 → Discovery), registra ligação/WhatsApp/e-mail numa conta já qualificada (1 → Discovery), registra reunião (→ Demo), salva a simulação PAT (→ Proposta) ou aplica uma transcrição. Fora a mudança manual de status, ele só avança, nunca recua. Perdido: oportunidade a 0% e recontato em 90 dias. Fechado: ganho e follow-up de onboarding.
- **Copiloto de call** (ficha da conta): transcrição por voz em pt-BR (Chrome/Edge) e análise local por palavras-sinal: temperatura, score, 3 destaques, contorno de objeção e WhatsApp pós-call. "Aplicar no lead" grava transcrição e resumo no histórico, atualiza o interesse e move o card. **A gravação só capta o seu microfone**: em call do Meet, cole a transcrição do Meet/Gemini/Tactiq.
- **Gemini opcional** (Integrações): com chave do Google AI Studio, a análise vai para o Gemini e volta em JSON; se falhar, usa a análise local. A chave fica no `localStorage` deste navegador, fora do backup e do Supabase, e fica exposta a quem usar o computador.
- **Home office**: na ficha, Ligar, chamada WhatsApp, Google Meet (abre a sala e copia o convite) e convite no Google Agenda com o decisor. Resultados de 1 clique: Atendeu, Pediu proposta, Caixa postal, Sem interesse. A Agenda tem os modos Home Office (fila remota do dia) e Campo (rotas).
- **Playbook em sub-abas**: CHAVE & Objeções, Battlecards & Matriz (nota da Swile com fonte Benway; demais informadas pelo usuário), Gatilhos Regulatórios 2026 (com fonte e "Copiar gancho") e Raio-X Swile Brasil.
- **Dados da Fattu e da Future**: informados pelo usuário (Fattu cita fattu.com.br/filiais e Econodata). Só substituem os valores provisórios antigos; não sobrescrevem algo editado.

## Fase 4: Business Case RJ

- **Regra do case:** foco em empresas com 200 vidas ou mais no RJ. Conta nova abre com 200 vidas e mostra um aviso abaixo disso. Faturamento = vidas × benefício. Metas: R$ 600 mil/mês e R$ 1,5 mi/trimestre.
- **Pipeline em 6 fases do Salesforce + Perdida:** Não contactado (10%), Qualificando (20%), Em contato (40%), Negociando (65%), Contrato enviado (85%), Contrato assinado (100%).
  - Sem mudança de schema: o banco aceita `stage_weight` de 0 a 5, então o app grava o peso limitado a 5 e usa o rótulo `stage` como fonte da verdade ("5. Contrato enviado" e "6. Contrato assinado ✅" gravam peso 5 e são diferenciados pelo rótulo).
  - Oportunidades antigas (fases de 5 colunas) são convertidas na carga, no navegador e no Supabase (uma gravação por oportunidade convertida).
  - A view SQL `crm_account_overview` ainda trata peso 5 como cliente ativo; ela não é usada pelo app.
- **Contas › Abastecer Funil Semanal:** calculadora de gap e cobertura, catálogo de 10 empresas do RJ (cada campo mostra a origem: conferido com fonte, informado pelo usuário ou estimativa), busca pronta em Google/Gupy, LinkedIn e Econodata.
- **Relatórios:** 3 sub-abas: Metas, Tendência & Simulador; Funil Salesforce & KPIs (Questões 3 e 5); Carteira & Operadoras. O PDF imprime as três.
- **Playbook › Case RJ (7 Questões):** respostas Q1 a Q7, plano 30-60-90 e atalhos "Demonstrar na prática".
- **Integrações › Conector Salesforce:** gera no navegador (sem conexão com o Salesforce):
  - CSV Accounts & Contacts (Import Wizard) e CSV Opportunities nas colunas `External_ID__c,Opportunity_Name,Account_Name,NumberOfEmployees,Swile_Avg_Benefit__c,Amount,StageName,Probability,CloseDate,NextStep,Current_Competitor__c,Cluster_RJ__c,LeadSource`, em UTF-8 com BOM, decimal `0.00` e datas ISO;
  - importação de CSV do Salesforce com prévia das 5 primeiras linhas e trava de 200 vidas;
  - inspetor de payload REST v60.0 (PATCH Opportunity por External_ID__c, composite/tree Account, Task), com cópia e envio opcional pelo webhook.
  - Pré-requisito na org: campo `External_ID__c` (ID externo) em Account e Opportunity e os campos personalizados citados.

### Briefing executivo e copiloto (Fase 4 completa)

- **Briefing por tela** (Hoje, Contas, Pipeline, Agenda, Relatórios): 1 a 2 linhas calculadas na hora pelo motor local, com "Detalhar" e "Atualizar com Gemini 2.5". A resposta do Gemini fica em cache na sessão do navegador até os dados mudarem.
- **Relatórios:** o briefing faz o diagnóstico de ganhos e perdas com o motivo registrado ao marcar Perdida e a fase em que o negócio morreu (`lost_stage`, só no navegador).
- **Ficha da conta:** card "Diagnóstico do lead & próximo passo" com nível de interesse, dor/gatilho, como trabalhar e uma ação em 1 clique.
- **Copiloto de call:**
  - ditado rápido (SpeechRecognition);
  - gravação da call completa: microfone e, opcionalmente, áudio da aba, em arquivos separados, com aviso de consentimento (LGPD) antes de gravar;
  - transcrição pelo Gemini em `inlineData`, separando Executivo Swile e Cliente;
  - análise em JSON, "Aplicar no lead" e "Pergunte ao copiloto".
- **Limites:** a requisição inline do Gemini é de 20 MB, então a gravação para perto de 14 MB de áudio. O modelo padrão é `gemini-2.5-flash`; se a chave não tiver acesso (404), o CRM tenta `gemini-3.8-flash`.
- **Sugerir empresas RJ via Gemini:** entram como "sugestão não verificada" e só viram conta depois de conferidas.
- **Sem chave:** tudo funciona pelo motor local.

### Nome na interface: Agente Swile (antes M14 IA)

- Na tela, a camada de IA se chama **M14 IA** (rótulos, botões, toasts, chip de status). O campo Modelo mostra `M14 IA · Motor Comercial RJ` por padrão.
- `resolveInternalModelId()` traduz o nome exibido para o modelo real: um nome que comece com `gemini-` passa direto; qualquer outro vira `gemini-2.5-flash`, com a troca automática para `gemini-3.8-flash` mantida. Mensagens de erro passam por `aiErr()`.
- A transparência fica numa linha recolhível em Integrações ("Processamento por modelo de IA de terceiros (Google Gemini). A chave fica neste navegador.") e no aviso de consentimento antes de gravar, porque o áudio e os dados das contas saem do navegador para o Google (LGPD).

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

### Segurança (Fase 5)

- **RLS por usuário:** `supabase/security/rls_por_usuario.sql` (também em Banco e login › "Segurança: RLS por usuário", com o e-mail do login já preenchido ao copiar). Em uma transação: garante `crm_allowed_users`/`crm_is_allowed()` do Modo Seguro, acha o seu usuário em `auth.users` (para com erro se não achar), cria `user_id uuid default auth.uid()` nas 5 tabelas, **preenche as linhas existentes com o seu id** e só então troca as policies para `user_id = auth.uid() and crm_is_allowed()`. Idempotente. Não rode a migration principal depois: ela recria as policies abertas. O app envia `user_id` quando a coluna existe e há sessão.
- **XSS e links:** todo texto vindo de usuário, CSV, banco ou IA passa por `esc()` (alias `escapeHtml`); sites de contas passam por `safeExternalUrl()` (só http/https) e `openExternal()` recusa outros protocolos.
- **CSV injection:** `sanitizeCsvCell()` põe apóstrofo em texto que começa com `= + - @ TAB CR`, exceto números, telefones (`+55 …`) e negativos, para não estragar a importação no Salesforce. O importador tira o apóstrofo. O Excel (.xlsx) grava as células como texto, sem fórmulas.
- **Vazamentos:** `<meta name="referrer" content="no-referrer">`, `rel="noopener noreferrer"` em todo link externo, backup JSON passa por `stripSensitiveCredentials()` (sem chaves, tokens ou URL de webhook). A chamada da M14 IA manda só a origem no Referer, para chaves restritas por site.
- **Chave da M14 IA:** opção "Guardar chave apenas nesta sessão" (sessionStorage).
- **Console limpo:** chave do Supabase em formato inválido não dispara requisição; depois que o banco pediu login uma vez, a abertura automática sem sessão não chama a API (o botão Conectar sempre tenta).
- **Busca:** debounce de 150 ms na busca de Contas e no Ctrl+K.
- **Agente Swile:** desde 31/10/2026 a IA aparece como "Agente Swile" (subtítulo "Powered by M14 IA"); padrões antigos salvos ("M14 IA · Motor Comercial RJ", "Swile IA…") passam a mostrar "Agente Swile · Comercial RJ". O fallback continua `gemini-3.8-flash`: o `gemini-2.0-flash` foi desligado pelo Google (junho/2026).
- **Ingestão Python:** `scripts/ingest_prospects.py` + `docs/ingestao_python.md` (login do usuário + chave pública; sem service_role key). O script de RLS pula tabelas que não existem (ex.: `crm_routes_rj`).

