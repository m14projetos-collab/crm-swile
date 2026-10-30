// Valida a sintaxe do JavaScript embutido no index.html (usado no CI).
import { readFileSync, writeFileSync, mkdtempSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";

const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
if (scripts.length === 0) {
  console.error("Nenhum <script> inline encontrado no index.html");
  process.exit(1);
}
const dir = mkdtempSync(join(tmpdir(), "swile-js-"));
scripts.forEach((code, i) => {
  const file = join(dir, `inline-${i}.js`);
  writeFileSync(file, code);
  execFileSync(process.execPath, ["--check", file], { stdio: "inherit" });
});
console.log(`OK: ${scripts.length} bloco(s) <script> com sintaxe válida.`);
