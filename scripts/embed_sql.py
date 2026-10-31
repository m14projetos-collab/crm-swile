#!/usr/bin/env python3
"""Embute a migration + seed e o script de RLS por usuário no index.html (botões de copiar SQL).

Uso:
  python3 scripts/embed_sql.py          # atualiza o index.html
  python3 scripts/embed_sql.py --check  # falha se o index.html estiver desatualizado (usado no CI)
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
INDEX = ROOT / "index.html"
MIGRATION = ROOT / "supabase" / "migrations" / "20261029000000_swile_os_crm_schema.sql"
SEED = ROOT / "supabase" / "seed.sql"
SECURITY = ROOT / "supabase" / "security" / "rls_por_usuario.sql"

BEGIN = "/* SQL:BEGIN (gerado por scripts/embed_sql.py — não edite à mão) */"
END = "/* SQL:END */"


def build_block() -> str:
    sql = (
        MIGRATION.read_text(encoding="utf-8").rstrip()
        + "\n\n-- =============================================================================\n"
        + "-- SEED (supabase/seed.sql)\n"
        + SEED.read_text(encoding="utf-8").rstrip()
        + "\n"
    )
    literal = json.dumps(sql, ensure_ascii=False).replace("</", "<\\/")
    sec = json.dumps(SECURITY.read_text(encoding="utf-8"), ensure_ascii=False).replace("</", "<\\/")
    return f"{BEGIN}\n    const SQL_SCHEMA_TEXT = {literal};\n    const SQL_SECURITY_TEXT = {sec};\n    {END}"


def main() -> int:
    html = INDEX.read_text(encoding="utf-8")
    pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)
    if not pattern.search(html):
        print("Marcadores SQL:BEGIN/SQL:END não encontrados no index.html", file=sys.stderr)
        return 1
    new_html = pattern.sub(lambda _m: build_block(), html, count=1)
    if "--check" in sys.argv:
        if new_html != html:
            print("index.html desatualizado: rode python3 scripts/embed_sql.py", file=sys.stderr)
            return 1
        print("SQL embutido no index.html está atualizado.")
        return 0
    INDEX.write_text(new_html, encoding="utf-8")
    print("index.html atualizado com a migration + seed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
