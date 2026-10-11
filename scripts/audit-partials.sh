#!/usr/bin/env bash
#
# audit-partials.sh — partial 调用关系审计（alpha.pre 工具之一）
#
# 用法：
#   scripts/audit-partials.sh [layouts_dir]     # 默认 ./layouts
#   例： scripts/audit-partials.sh layouts
#
# 输出四类发现，全部为「问题才打印」，干净时只输出一行 OK：
#   MISSING  —— 字面量调用指向不存在的 partial（fatal，退出码 1）
#   ORPHAN   —— 无任何字面量调用方的 partial（alpha.0a 门槛：必须为空）
#   DYNAMIC  —— `partial $var` 动态分发，静态不可解析，需人工确认
#   HOOK     —— templates.Exists 站点层钩子，主题不提供是设计使然（提示，非问题）

set -euo pipefail

LAYOUTS="${1:-layouts}"
PARTIALS_DIR="$LAYOUTS/partials"

if [ ! -d "$PARTIALS_DIR" ]; then
  echo "ERROR: 找不到 partials 目录：$PARTIALS_DIR" >&2
  exit 2
fi

# 站点层钩子：由 templates.Exists 保护，站点提供即启用，主题不提供不算缺失
SITE_HOOKS="extend-head.html extend-head-uncached.html favicons.html extend-article-link.html cookie-consent.html"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---- 1) inventory：partials 目录下的全部文件 --------------------------------
find "$PARTIALS_DIR" -type f | sed "s|^$PARTIALS_DIR/||" | sort >"$TMP/inv"
grep '\.html$' "$TMP/inv" >"$TMP/inv_html" || true
grep -v '\.html$' "$TMP/inv" >"$TMP/inv_other" || true

# ---- 2) 字面量调用：partial "x" / partialCached "x" ------------------------
# grep -o 输出形如 `file:line:partial "x"`，用引号切字段取 x
# 只扫 layouts/ 全域（含 baseof/index 等非 partial 模板）
grep -rnoE 'partial(Cached)?[[:space:]]+"[^"]+"' "$LAYOUTS" 2>/dev/null \
  | awk -F'"' '{print $2}' >"$TMP/calls" || true

# 归一化：去可能的 "partials/" 前缀；补 .html 后缀（Hugo 允许省略）
awk '{
  t = $0
  sub(/^partials\//, "", t)
  if (t !~ /\./) t = t ".html"
  print t
}' "$TMP/calls" >"$TMP/calls_norm"

sort "$TMP/calls_norm" | uniq -c | sort -rn >"$TMP/targets"
sort -u "$TMP/calls_norm" >"$TMP/targets_list"

# ---- 3) MISSING：字面量目标不存在，且不是站点钩子 ---------------------------
: >"$TMP/missing"
while IFS= read -r t; do
  [ -z "$t" ] && continue
  case " $SITE_HOOKS " in
    *" $t "*) continue ;;
  esac
  [ -f "$PARTIALS_DIR/$t" ] || echo "$t" >>"$TMP/missing"
done <"$TMP/targets_list"
sort -u "$TMP/missing" >"$TMP/missing_u" || true

# ---- 4) 动态分发模式：从 `print "prefix" ... ".html"` 提取 glob ------------
# 例： print "header/" site.Params.header.layout ".html"  →  header/*.html
grep -rhoE 'print "[^"]+"[^}]{0,120}"[^"]*\.html"' "$LAYOUTS" 2>/dev/null \
  | awk -F'"' '$2 !~ /%/ && $4 ~ /\.html$/ {print $2 "*" $4}' \
  | sort -u >"$TMP/dyn_patterns" || true

# ---- 5) ORPHAN vs DYNAMIC-REACHABLE ---------------------------------------
: >"$TMP/orphan"
: >"$TMP/dyn_reach"
while IFS= read -r f; do
  hit=0
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    # shellcheck disable=SC2254
    case "$f" in $p) hit=1; break ;; esac
  done <"$TMP/dyn_patterns"
  if [ "$hit" -eq 1 ]; then echo "$f" >>"$TMP/dyn_reach"; else echo "$f" >>"$TMP/orphan"; fi
done < <(comm -23 "$TMP/inv_html" <(sort -u "$TMP/targets_list"))

# ---- 6) DYNAMIC + HOOK：动态分发调用点与站点钩子 ---------------------------
grep -rnE 'partial[[:space:]]+\$' "$LAYOUTS" 2>/dev/null | sed "s|^$LAYOUTS/||" | sed 's/^/  /' >"$TMP/dynamic" || true
grep -rnE 'templates\.Exists' "$LAYOUTS" 2>/dev/null | sed "s|^$LAYOUTS/||" | sed 's/^/  /' >"$TMP/hooks" || true

# ---- report ----------------------------------------------------------------
FOUND=0

if [ -s "$TMP/missing_u" ]; then
  FOUND=1
  echo "MISSING（字面量调用指向不存在的 partial）:"
  while IFS= read -r t; do
    echo "  $t"
    grep -rn "partial\(Cached\)\? \"$t\"" "$LAYOUTS" 2>/dev/null | sed "s|^$LAYOUTS/||" | sed 's/^/    /'
  done <"$TMP/missing_u"
  echo
fi

if [ -s "$TMP/orphan" ]; then
  FOUND=1
  echo "ORPHAN（无字面量调用方，需人工确认是否死代码）:"
  sed 's/^/  /' "$TMP/orphan"
  echo
fi

if [ -s "$TMP/dynamic" ]; then
  echo "DYNAMIC（partial \$var 动态分发，静态不可解析，人工确认覆盖范围）:"
  echo "  模式（由 print 拼接推得）:"
  sed 's/^/    /' "$TMP/dyn_patterns"
  echo "  调用点:"
  cat "$TMP/dynamic"
  echo "  仅经动态分发可达（不算 orphan，但要确认该分发点是否还该保留）:"
  sed 's/^/    /' "$TMP/dyn_reach"
  echo
fi

if [ -s "$TMP/hooks" ]; then
  echo "HOOK（templates.Exists 站点层钩子，主题不提供属设计使然）:"
  cat "$TMP/hooks"
  echo
fi

if [ -s "$TMP/inv_other" ]; then
  echo "NON-HTML 资源（不参与 partial 调用检查）:"
  sed 's/^/  /' "$TMP/inv_other"
  echo
fi

TOTAL_HTML=$(wc -l <"$TMP/inv_html" | tr -d ' ')
ORPHANS=$(grep -c . "$TMP/orphan" || true)
DYN_REACH=$(grep -c . "$TMP/dyn_reach" || true)
MISSING=$(grep -c . "$TMP/missing_u" || true)
DYN=$(grep -c . "$TMP/dynamic" || true)
REFERENCED=$((TOTAL_HTML - ORPHANS - DYN_REACH))

echo "汇总: partial(.html)=$TOTAL_HTML  字面量引用=$REFERENCED  动态可达=$DYN_REACH  orphan=$ORPHANS  missing=$MISSING  动态分发点=$DYN"

if [ "$FOUND" -eq 1 ]; then
  exit 1
fi
echo "OK: 无 MISSING / 无 ORPHAN"
