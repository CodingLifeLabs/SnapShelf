#!/usr/bin/env node
/*
 * Gate 1 — Layer dependency direction linter (Swift-aware)
 *
 * SnapShelf enforces a one-way dependency chain:
 *
 *     Types -> Config -> Repo -> Service -> Runtime -> UI
 *
 * Each layer is its own static framework (see Project.yml), so a reverse
 * `import SnapShelfXxx` is ALSO a compile error. This linter is a fast,
 * human-readable pre-check that reports the violation with a FIX hint
 * before you ever hit xcodebuild.
 *
 * Usage:  node .harness/linters/dependency-direction.js src/ App/Sources
 */

const fs = require("fs");
const path = require("path");

// Layer order index (lower may be imported by higher, never the reverse).
const LAYER_ORDER = [
  "SnapShelfTypes",
  "SnapShelfConfig",
  "SnapShelfRepo",
  "SnapShelfService",
  "SnapShelfRuntime",
  "SnapShelfUI", // virtual name for the app/UI layer (App/Sources)
];

// Path prefix -> owning module.
const PATH_TO_MODULE = [
  [["src", "Types"], "SnapShelfTypes"],
  [["src", "Config"], "SnapShelfConfig"],
  [["src", "Repo"], "SnapShelfRepo"],
  [["src", "Service"], "SnapShelfService"],
  [["src", "Runtime"], "SnapShelfRuntime"],
  [["App", "Sources"], "SnapShelfUI"],
];

function moduleForFile(filePath) {
  const parts = filePath.split(path.sep);
  for (const [prefix, module] of PATH_TO_MODULE) {
    // find the prefix segment sequence anywhere the project-relative path starts
    const idx = parts.indexOf(prefix[0]);
    if (idx === -1) continue;
    const slice = parts.slice(idx, idx + prefix.length);
    if (slice.join(path.sep) === prefix.join(path.sep)) {
      return module;
    }
  }
  return null;
}

function allowedImportsFor(module) {
  if (!module) return new Set();
  const idx = LAYER_ORDER.indexOf(module);
  // A layer may import strictly-lower layers (everything before it).
  return new Set(LAYER_ORDER.slice(0, idx));
}

const IMPORT_RE = /^\s*import\s+(SnapShelf[A-Za-z0-9_]*)\b/gm;

function* walk(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      // skip noise
      if (entry.name === "DerivedData" || entry.name === "build" || entry.name === ".build") continue;
      yield* walk(full);
    } else if (entry.isFile() && full.endsWith(".swift")) {
      yield full;
    }
  }
}

const roots = process.argv.slice(2);
const scanRoots = roots.length ? roots : ["src", "App/Sources"];

let scanned = 0;
const violations = [];

for (const root of scanRoots) {
  const absRoot = path.resolve(root);
  for (const file of walk(absRoot)) {
    scanned++;
    const module = moduleForFile(path.relative(process.cwd(), file));
    if (!module) continue; // file outside the layer system (e.g. scripts) — skip
    const allowed = allowedImportsFor(module);
    const src = fs.readFileSync(file, "utf8");
    let match;
    while ((match = IMPORT_RE.exec(src)) !== null) {
      const imported = match[1];
      if (imported === module) continue; // self-import is nonsensical, skip
      if (!allowed.has(imported)) {
        violations.push({ file: path.relative(process.cwd(), file), module, imported });
      }
    }
  }
}

if (scanned === 0) {
  console.error(`⚠️  No .swift files found under: ${scanRoots.join(", ")}`);
  console.error(`    (Bootstrap skeleton may not have any sources yet. Re-run after Sprint 1.)`);
}

if (violations.length === 0) {
  console.log(`✅ 레이어 의존성 검사 통과 (위반: 0건, 검사 파일: ${scanned})`);
  process.exit(0);
}

console.error(`❌ 레이어 의존성 위반 발견 (${violations.length}건, 검사 파일: ${scanned})\n`);
for (const v of violations) {
  const order = LAYER_ORDER.indexOf(v.imported);
  const moduleOrder = LAYER_ORDER.indexOf(v.module);
  const direction =
    order < moduleOrder ? "정방향(허용됨)" : "역방향(금지) 또는 동일 계층";
  console.error(`  • ${v.file}`);
  console.error(`    모듈: ${v.module}  →  import ${v.imported}`);
  console.error(`    판정: ${direction}`);
  console.error(`    FIX: ${v.module}는 상위 레이어(${v.imported})에 의존할 수 없습니다.`);
  console.error(`         의존성을 역전하세요 (protocol을 하위에 정의하고 상위에서 주입, 또는 로직을 하위 레이어로 이동).\n`);
}
process.exit(1);
