#!/usr/bin/env bash
#
# diff-build.sh — 产物语义比对（alpha.pre 工具之一，alpha.0a 验收门槛）
#
# 用法：
#   scripts/diff-build.sh <before_public> <after_public> [--allow <path_regex>]...
#   scripts/diff-build.sh --make-baseline <before_public> <after_public>
#
#   --allow           允许出现差异的产物路径（awk 正则，可重复）。
#                     alpha.0a 不带任何 --allow（必须零差异）；
#                     alpha.0b 起用它声明本次预期改动范围，范围外差异即失败。
#   --make-baseline   比对后把报告留档到 scripts/baseline/diff-build.baseline.txt。
#
# 三张比对表：
#   1. 页面集合   public/**/*.html 相对路径，必须完全一致
#   2. 渲染结构   去哈希后的 DOM 骨架：标签序列 + class + id + href/src + 文本
#   3. CSS 规则   深度 0 规则块集合（选择器 + 声明），忽略注释/空白/哈希/文件内顺序
#
# 无外部依赖：只用 bash + awk + sort/comm/diff。awk 程序内联在本文件里，不落盘到项目。
#
# 退出码：0 = 零差异（或差异全在 --allow 内）；1 = 超范围差异；2 = 用法错误

set -uo pipefail

if [ $# -lt 2 ]; then
  awk 'NR==1{next}
       /^[[:space:]]*$/{if(p)print ""; next}
       /^#/{sub(/^# ?/,""); print; p=1; next}
       {exit}' "$0"
  exit 2
fi

MAKE_BASELINE=0
if [ "$1" = "--make-baseline" ]; then MAKE_BASELINE=1; shift; fi

if [ $# -lt 2 ]; then
  echo "用法错误: 需要 <before_public> <after_public>" >&2
  exit 2
fi

BEFORE="$1"; AFTER="$2"; shift 2

ALLOW=()
while [ $# -gt 0 ]; do
  case "$1" in
    --allow)
      [ $# -lt 2 ] && { echo "用法错误: --allow 需要参数" >&2; exit 2; }
      ALLOW+=("$2"); shift 2 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

for d in "$BEFORE" "$AFTER"; do
  [ -d "$d" ] || { echo "ERROR: 目录不存在: $d" >&2; exit 2; }
done

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
TAB="$(printf '\t')"

# 9 位以上小写 hex，且至少含一个 [a-f]：纯数字 9 位+ 是时间戳、电话号码、
# 毫秒数这类真值，不许归一（真哈希漏判字母的概率 (10/16)^16 ≈ 0.02%，
# 最坏只是 diff 多一行噪音）。awk 不支持 {8,} 区间量词，重复写开。
HEXRE='[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*'

# ---------------------------------------------------------------------------
# 内联 awk 程序
# ---------------------------------------------------------------------------

# CSS：去注释 → 按深度 0 切分规则块 → 压空白 + 哈希归一，输出 "key<TAB>语句"
cat >"$STAGE/canon_css.awk" <<'AWKEOF'
BEGIN {
  FS = "\t"
  H = "[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*"
}
function unhex(s,    out, m) {
  out = ""
  while (match(s, H)) {
    m = substr(s, RSTART, RLENGTH)
    if (m ~ /[a-f]/) out = out substr(s, 1, RSTART - 1) "<hash>"
    else out = out substr(s, 1, RSTART - 1) m
    s = substr(s, RSTART + RLENGTH)
  }
  return out s
}
function emit(s) {
  gsub(/[\r\n\t ]+/, " ", s)
  gsub(/^ +| +$/, "", s)
  if (length(s) > 0) printf "%s\t%s\n", KEY, unhex(s)
}
# 去 /* ... */ 注释。不能用正则字面量：类里含 '/' 会截断 awk 的正则常量，
# 所以改成逐标记扫描。
function strip_comments(s,    out, i, st, p) {
  out = ""; i = 1; st = 0
  while (i <= length(s)) {
    if (st == 0) {
      p = index(substr(s, i), "/*")
      if (p == 0) { out = out substr(s, i); break }
      out = out substr(s, i, p - 1)
      i = i + p + 1
      st = 1
    } else {
      p = index(substr(s, i), "*/")
      if (p == 0) break
      i = i + p + 1
      st = 0
    }
  }
  return out
}
{ buf = buf $0 "\n" }
END {
  gsub(/\r/, " ", buf)
  buf = strip_comments(buf)
  np = split(buf, P, /\}/)
  depth = 0; pos = 1; start = 1
  for (i = 1; i <= np; i++) {
    piece = P[i]
    t = piece
    depth += gsub(/\{/, "", t)
    if (i < np) {
      delpos = pos + length(piece)
      depth -= 1
      if (depth == 0) { emit(substr(buf, start, delpos - start + 1)); start = delpos + 1 }
      pos = delpos + 1
    } else {
      pos = pos + length(piece) + 1
    }
  }
  emit(substr(buf, start))
}
AWKEOF

# HTML：去注释、去 script/style 整块 → 输出骨架流 "txt:..." / "t:name c=.. i=.. u=.."
cat >"$STAGE/canon_html.awk" <<'AWKEOF'
BEGIN { H = "[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*" }
function unhex(s,    out, m) {
  out = ""
  while (match(s, H)) {
    m = substr(s, RSTART, RLENGTH)
    if (m ~ /[a-f]/) out = out substr(s, 1, RSTART - 1) "<hash>"
    else out = out substr(s, 1, RSTART - 1) m
    s = substr(s, RSTART + RLENGTH)
  }
  return out s
}
function norm(s) {
  gsub(/[\r\n\t ]+/, " ", s)
  gsub(/^ +| +$/, "", s)
  return unhex(s)
}
function emit_tag(tag,    inner, isend, out, name, a, eq, k, v, n, i, rs, rl) {
  inner = substr(tag, 2)
  isend = 0
  if (substr(inner, 1, 1) == "/") { isend = 1; inner = substr(inner, 2) }
  sub(/>$/, "", inner)
  sub(/\/$/, "", inner)
  name = inner
  match(name, /^[^ \t\n]+/)
  name = substr(name, 1, RLENGTH)
  out = tolower(name)
  if (isend) { print "t:" out; return }
  n = 0
  while (match(inner, /[A-Za-z_:][A-Za-z0-9_.-]*[ ]*=[ ]*"([^"]*)"/)) {
    # RSTART/RLENGTH 是全局量，norm() 内部的 match() 会改写它们，必须先存局部
    rs = RSTART; rl = RLENGTH
    a = substr(inner, rs, rl)
    eq = index(a, "=")
    k = substr(a, 1, eq - 1)
    v = substr(a, eq + 1)
    sub(/^"/, "", v); sub(/"$/, "", v)
    n++; AK[n] = tolower(k); AV[n] = norm(v)
    inner = substr(inner, rs + rl)
    if (n > 200) break
  }
  for (i = 1; i <= n; i++) {
    if (AK[i] == "class")      out = out " c=" AV[i]
    else if (AK[i] == "id")    out = out " i=" AV[i]
    else if (AK[i] == "href")  out = out " u=" AV[i]
    else if (AK[i] == "src")   out = out " u=" AV[i]
  }
  for (i = 1; i <= n; i++) { delete AK[i]; delete AV[i] }
  print "t:" out
}
{ buf = buf $0 "\n" }
END {
  s = buf; skip = ""; it = 0
  while (length(s) > 0) {
    it++
    if (it > 2000000) break                      # 防御：解析异常时不要挂死 CI
    if (skip != "") {
      p = index(tolower(s), skip)
      if (p > 0) { s = substr(s, p + length(skip)); skip = ""; continue }
      break
    }
    p = index(s, "<")
    if (p <= 0) { txt = norm(s); if (length(txt) > 0) print "txt:" txt; break }
    if (p > 1) {
      txt = norm(substr(s, 1, p - 1))
      if (length(txt) > 0) print "txt:" txt
    }
    q = index(s, ">")
    if (q < p) break
    tag = substr(s, p, q - p + 1)
    s = substr(s, q + 1)
    tl = tolower(tag)
    if (substr(tag, 1, 4) == "<!--") {
      r = index(s, "-->")
      if (r > 0) s = substr(s, r + 3)
      else break                                  # 未闭合注释：丢弃剩余
      continue
    }
    if (tl ~ /^<script/ && tl !~ /^<\/script/ && substr(tl, length(tl), 2) != "/>") { skip = "</script>"; continue }
    if (tl ~ /^<style/ && tl !~ /^<\/style/ && substr(tl, length(tl), 2) != "/>") { skip = "</style>"; continue }
    if (tl ~ /^<\/script/ || tl ~ /^<\/style/) continue
    emit_tag(tag)
  }
}
AWKEOF

# --allow 过滤前缀：正则列表从 ALLOWFILE 逐行读入
{
  cat <<'AWKEOF'
BEGIN {
  FS = "\t"
  n = 0
  while ((getline p < ALLOWFILE) > 0) P[++n] = p
  close(ALLOWFILE)
}
function allowed(s,    i) { for (i = 1; i <= n; i++) if (s ~ P[i]) return 1; return 0 }
function trunc(s) { return length(s) <= 200 ? s : substr(s, 1, 200) " …" }
AWKEOF
  printf 'NF >= 5 {\n'
  printf '  if (allowed($1)) next\n'
  printf '  printf "结构差异: %%s  (before %%s 节点 / after %%s 节点, 首分歧 @%%s)\\n    before: %%s\\n    after:  %%s\\n", $1, $2, $3, $4, $5, $6\n'
  printf '}\n'
} >"$STAGE/struct_filter.awk"

{
  cat <<'AWKEOF'
BEGIN {
  FS = "\t"
  n = 0
  while ((getline p < ALLOWFILE) > 0) P[++n] = p
  close(ALLOWFILE)
}
function allowed(s,    i) { for (i = 1; i <= n; i++) if (s ~ P[i]) return 1; return 0 }
function trunc(s) { return length(s) <= 200 ? s : substr(s, 1, 200) " …" }
NR == FNR {
  if (allowed($1)) next
  k = $1; cl[k]++; if (cl[k] <= 5) body[k] = body[k] "\n    - " trunc($2)
  next
}
{
  if (allowed($1)) next
  k = $1; cg[k]++; if (cg[k] <= 5) body[k] = body[k] "\n    + " trunc($2)
}
END {
  while ((getline k < KEYFILE) > 0) {
    if (!(k in cl) && !(k in cg)) continue
    printf "CSS 差异: %s  (-%d 语句 / +%d 语句)\n%s\n", k, cl[k] + 0, cg[k] + 0, body[k]
  }
}
AWKEOF
} >"$STAGE/css_filter.awk"

# ---------------------------------------------------------------------------
# 1) 页面集合
# ---------------------------------------------------------------------------
( cd "$BEFORE" && find . -type f -name '*.html' | sed 's|^\./||' ) | LC_ALL=C sort >"$STAGE/pages-b.txt"
( cd "$AFTER" && find . -type f -name '*.html' | sed 's|^\./||' ) | LC_ALL=C sort >"$STAGE/pages-a.txt"
comm -23 "$STAGE/pages-a.txt" "$STAGE/pages-b.txt" >"$STAGE/added.txt"
comm -13 "$STAGE/pages-a.txt" "$STAGE/pages-b.txt" >"$STAGE/removed.txt"
comm -12 "$STAGE/pages-b.txt" "$STAGE/pages-a.txt" >"$STAGE/common.txt"

# ---------------------------------------------------------------------------
# 2) DOM 骨架（struct.raw：path TAB nb TAB na TAB idx TAB before TAB after）
# ---------------------------------------------------------------------------
: >"$STAGE/struct.raw"
while IFS= read -r p; do
  awk -f "$STAGE/canon_html.awk" "$BEFORE/$p" >"$STAGE/sk-b"
  awk -f "$STAGE/canon_html.awk" "$AFTER/$p" >"$STAGE/sk-a"
  cmp -s "$STAGE/sk-b" "$STAGE/sk-a" && continue
  idx=$(awk 'NR==FNR{a[FNR]=$0; n=FNR; next}
             {if ($0 != a[FNR]) {print FNR; found=1; exit}}
             END{if (!found) print n}' \
    "$STAGE/sk-b" "$STAGE/sk-a")
  nb=$(wc -l <"$STAGE/sk-b" | tr -d ' ')
  na=$(wc -l <"$STAGE/sk-a" | tr -d ' ')
  sb=$(sed -n "${idx}p" "$STAGE/sk-b")
  sa=$(sed -n "${idx}p" "$STAGE/sk-a")
  [ -n "$sb" ] || sb="<EOF>"
  [ -n "$sa" ] || sa="<EOF>"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$p" "$nb" "$na" "$idx" "$sb" "$sa" >>"$STAGE/struct.raw"
done <"$STAGE/common.txt"

# ---------------------------------------------------------------------------
# 3) CSS 规则集（按去哈希后的路径 key 聚合）
# ---------------------------------------------------------------------------
for side in b a; do
  root="$BEFORE"; [ "$side" = a ] && root="$AFTER"
  ( cd "$root" && find . -type f -name '*.css' | sed 's|^\./||' ) | LC_ALL=C sort >"$STAGE/csslist-$side.txt"
  : >"$STAGE/css-rows-$side.tsv"
  while IFS= read -r raw; do
    key=$(printf '%s' "$raw" | awk -v H="$HEXRE" \
      'BEGIN{out=""} {
        while (match($0, H)) {
          m = substr($0, RSTART, RLENGTH)
          if (m ~ /[a-f]/) out = out substr($0, 1, RSTART-1) "<hash>"
          else out = out substr($0, 1, RSTART-1) m
          $0 = substr($0, RSTART+RLENGTH)
        }
        print out $0
      }')
    awk -f "$STAGE/canon_css.awk" -v KEY="$key" "$root/$raw" >>"$STAGE/css-rows-$side.tsv"
  done <"$STAGE/csslist-$side.txt"
  LC_ALL=C sort -u "$STAGE/css-rows-$side.tsv" >"$STAGE/css-set-$side.tsv"
done
comm -23 "$STAGE/css-set-b.tsv" "$STAGE/css-set-a.tsv" >"$STAGE/css-lost.tsv"
comm -13 "$STAGE/css-set-b.tsv" "$STAGE/css-set-a.tsv" >"$STAGE/css-gain.tsv"
awk -F'\t' '{ print $1 }' "$STAGE/css-lost.tsv" "$STAGE/css-gain.tsv" | LC_ALL=C sort -u >"$STAGE/css-keys.txt"

# ---------------------------------------------------------------------------
# 汇总（apply --allow）
# ---------------------------------------------------------------------------
: >"$STAGE/allow.txt"
for pat in "${ALLOW[@]+"${ALLOW[@]}"}"; do printf '%s\n' "$pat" >>"$STAGE/allow.txt"; done

: >"$STAGE/viol.txt"
while IFS= read -r p; do printf '页面新增: %s\n' "$p" >>"$STAGE/viol.txt"; done <"$STAGE/added.txt"
while IFS= read -r p; do printf '页面丢失: %s\n' "$p" >>"$STAGE/viol.txt"; done <"$STAGE/removed.txt"

if [ -s "$STAGE/struct.raw" ]; then
  awk -v ALLOWFILE="$STAGE/allow.txt" -f "$STAGE/struct_filter.awk" \
    "$STAGE/struct.raw" >>"$STAGE/viol.txt"
fi

if [ -s "$STAGE/css-keys.txt" ]; then
  awk -v ALLOWFILE="$STAGE/allow.txt" -v KEYFILE="$STAGE/css-keys.txt" \
    -f "$STAGE/css_filter.awk" \
    "$STAGE/css-lost.tsv" "$STAGE/css-gain.tsv" >>"$STAGE/viol.txt"
fi

N_STRUCT=$(awk '/^结构差异:/ { c++ } END { print c + 0 }' "$STAGE/viol.txt")
N_CSS=$(awk '/^CSS 差异:/ { c++ } END { print c + 0 }' "$STAGE/viol.txt")
N_VIOL=$(awk '/^(页面新增|页面丢失|结构差异|CSS 差异):/ { c++ } END { print c + 0 }' "$STAGE/viol.txt")

{
  printf '页面集合: before=%s after=%s 新增=%s 丢失=%s\n' \
    "$(wc -l <"$STAGE/pages-b.txt" | tr -d ' ')" \
    "$(wc -l <"$STAGE/pages-a.txt" | tr -d ' ')" \
    "$(wc -l <"$STAGE/added.txt" | tr -d ' ')" \
    "$(wc -l <"$STAGE/removed.txt" | tr -d ' ')"
  printf '结构差异: %s 页\n' "$N_STRUCT"
  printf 'CSS 差异: %s 文件\n' "$N_CSS"
  if [ ${#ALLOW[@]} -gt 0 ]; then printf 'allow 规则: %s\n' "${ALLOW[*]}"; fi
  if [ -s "$STAGE/viol.txt" ]; then
    printf '\n== 超范围差异 ==\n'
    cat "$STAGE/viol.txt"
  else
    printf '\nOK: 零差异（或全部落在 --allow 内）\n'
  fi
} | tee "$STAGE/report.txt"

if [ "$MAKE_BASELINE" = 1 ]; then
  OUT="$(cd "$(dirname "$0")" && pwd)/baseline/diff-build.baseline.txt"
  {
    printf '# alpha.pre 基线 — diff-build.sh\n'
    printf '# 生成: scripts/diff-build.sh --make-baseline %s %s\n' "$BEFORE" "$AFTER"
    cat "$STAGE/report.txt"
  } >"$OUT"
fi

[ "$N_VIOL" -eq 0 ] || exit 1
exit 0
