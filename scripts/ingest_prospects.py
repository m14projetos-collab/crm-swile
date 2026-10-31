#!/usr/bin/env python3
"""Ingestão semanal de prospects no Swile OS CRM (Supabase REST), sem dependências.

Uso:
  export SUPABASE_URL="https://<projeto>.supabase.co"
  export SUPABASE_ANON_KEY="sb_publishable_..."   # chave PÚBLICA (a mesma do site)
  export CRM_EMAIL="seu@email.com"                # login do CRM (Banco e login)
  export CRM_PASSWORD="..."                       # nunca grave no repositório
  python3 scripts/ingest_prospects.py prospects.csv [--dry-run]

CSV (UTF-8, separador , ou ;) com cabeçalho. Colunas aceitas:
  company_name (obrigatória), sector, polo_rj, neighborhood, address, phone,
  email_rh, website, decision_maker_name, decision_maker_role,
  active_card_users, current_provider, swile_trigger_2026, code

Regras:
  * Entra só empresa com active_card_users >= 200 (regra do Case RJ).
  * code ausente vira "PY-" + 8 caracteres do hash do nome (estável entre semanas).
  * Conta que já existe (mesmo code) não é alterada: on_conflict=code + ignore-duplicates.
  * O script entra com o SEU login, então o RLS por usuário vale e o banco
    preenche user_id sozinho. Não use a service_role key aqui.
"""
import csv
import hashlib
import json
import os
import sys
import unicodedata
import urllib.error
import urllib.request

MIN_LIVES = 200
FIELDS = [
    "company_name", "sector", "polo_rj", "neighborhood", "address", "phone", "email_rh", "website",
    "decision_maker_name", "decision_maker_role", "active_card_users", "current_provider",
    "swile_trigger_2026", "code",
]


def env(name):
    v = os.environ.get(name, "").strip()
    if not v:
        sys.exit(f"Defina a variável de ambiente {name}.")
    return v


def http(method, url, headers, body=None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            txt = r.read().decode("utf-8")
            return r.status, (json.loads(txt) if txt else None)
    except urllib.error.HTTPError as e:
        txt = e.read().decode("utf-8", "replace")
        return e.code, txt


def login(base, key, email, password):
    status, data = http("POST", f"{base}/auth/v1/token?grant_type=password",
                        {"apikey": key, "Content-Type": "application/json"},
                        {"email": email, "password": password})
    if status != 200 or not isinstance(data, dict) or "access_token" not in data:
        sys.exit(f"Login falhou ({status}). Confira e-mail/senha e se o e-mail foi confirmado.")
    return data["access_token"]


def norm(s):
    s = unicodedata.normalize("NFD", str(s or "")).encode("ascii", "ignore").decode()
    return " ".join(s.lower().split())


def read_rows(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        sample = f.read(4096)
        f.seek(0)
        sep = ";" if sample.count(";") > sample.count(",") else ","
        return list(csv.DictReader(f, delimiter=sep))


def to_account(raw):
    row = {k: (raw.get(k) or "").strip() for k in FIELDS}
    name = row["company_name"].lstrip("'")
    if not name:
        return None, "sem company_name"
    try:
        lives = int(float(row["active_card_users"].replace(".", "").replace(",", "."))) if row["active_card_users"] else 0
    except ValueError:
        lives = 0
    if lives < MIN_LIVES:
        return None, f"{name}: {lives} vidas (< {MIN_LIVES})"
    acc = {
        "code": row["code"] or "PY-" + hashlib.sha1(norm(name).encode()).hexdigest()[:8].upper(),
        "company_name": name,
        "sector": row["sector"] or "A Validar",
        "polo_rj": row["polo_rj"] or "A Validar",
        "active_card_users": lives,
        "employees_count": lives,
        "status": "Lead Mapeado",
    }
    for k in ("neighborhood", "address", "phone", "email_rh", "website", "decision_maker_name",
              "decision_maker_role", "current_provider", "swile_trigger_2026"):
        if row[k]:
            acc[k] = row[k]
    return acc, None


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry-run" in sys.argv
    if not args:
        sys.exit(__doc__)
    accounts, skipped = [], []
    for raw in read_rows(args[0]):
        acc, why = to_account(raw)
        (accounts.append(acc) if acc else skipped.append(why))
    print(f"{len(accounts)} conta(s) prontas, {len(skipped)} pulada(s).")
    for why in skipped:
        print("  pulada:", why)
    if dry or not accounts:
        print(json.dumps(accounts, ensure_ascii=False, indent=2) if dry else "Nada a enviar.")
        return 0
    base = env("SUPABASE_URL").rstrip("/")
    key = env("SUPABASE_ANON_KEY")
    token = login(base, key, env("CRM_EMAIL"), env("CRM_PASSWORD"))
    status, data = http("POST", f"{base}/rest/v1/crm_accounts?on_conflict=code", {
        "apikey": key,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Prefer": "resolution=ignore-duplicates,return=minimal",
    }, accounts)
    if status not in (200, 201, 204):
        sys.exit(f"Envio recusado ({status}): {str(data)[:300]}")
    print(f"Enviado. Contas novas entram no CRM; códigos repetidos foram ignorados.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
