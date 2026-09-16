#!/usr/bin/env bash
# MoonViz npm 全量发布（浏览器 passkey / iCloud 钥匙串认证版）
#
# 用法：cd moonviz && ./scripts/publish-all.sh
#
# - 首次发布会弹出浏览器，用 iCloud 钥匙串完成验证；
#   认证 token 写入 ~/.npmrc，后续包不再弹窗。
# - 若提示未登录：先跑一次 `npm login`（同样走浏览器），再重跑本脚本。
# - 平台二进制 tarball 从 CI artifacts 下载（默认 run 35104131216，
#   可用 MOONVIZ_CI_RUN 覆盖）。
# - 已发布过的版本自动跳过，可安全重复执行。
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_ID="${MOONVIZ_CI_RUN:-35104131216}"
TGZ_DIR="${MOONVIZ_TGZ_DIR:-/tmp/mv-tgz}"

cd "$ROOT"

echo "==> 检查 npm 登录态"
if ! npm whoami >/dev/null 2>&1; then
  echo "未登录。请先执行: npm login   （浏览器验证后再重跑本脚本）" >&2
  exit 1
fi
echo "    已登录: $(npm whoami)"

echo "==> 准备平台二进制 tarball（CI run $RUN_ID）"
if ls "$TGZ_DIR"/*/*.tgz >/dev/null 2>&1; then
  echo "    使用已有: $TGZ_DIR"
else
  gh run download "$RUN_ID" --repo asdshuaishuai/moonviz -D "$TGZ_DIR" || {
    echo "下载失败：确认 gh 已登录，或手动设置 MOONVIZ_CI_RUN 指向成功的 run" >&2
    exit 1
  }
fi

# 自检已在发布前用 Node 24+ 跑过绿，这里 --ignore-scripts 跳过 prepublish
# 钩子（本机默认 node 可能是 20，wasm selftest 需要 24+）。
publish_one() {
  local label="$1"; shift
  echo ""
  echo "==> 发布 $label"
  local out rc
  out=$(npm publish "$@" --access public --ignore-scripts --auth-type=web 2>&1)
  rc=$?
  echo "$out" | grep -vE "^\s*$|⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏" | tail -3
  if [ $rc -eq 0 ]; then
    echo "    ✓ 成功"; return 0
  fi
  if echo "$out" | grep -qi "cannot publish over"; then
    echo "    ⊘ 版本已存在，跳过"; return 0
  fi
  echo "    ✗ 失败"; return 1
}

fails=0
done_list=()

# 1) 平台二进制（moonviz-mcp 的 optionalDependencies 依赖它们）
for tgz in "$TGZ_DIR"/*/*.tgz; do
  name="$(basename "$tgz" .tgz)"
  publish_one "$name" "$tgz" && done_list+=("$name") || fails=$((fails+1))
done

# 2) 本地包（engine-sdk / engine-wasm / skill / mcp wrapper）
for dir in sdk/node sdk/wasm npm/moonviz-skill npm/moonviz-mcp; do
  name="$(basename "$dir")"
  publish_one "$name" "$dir" && done_list+=("$name") || fails=$((fails+1))
done

echo ""
echo "================================"
if [ $fails -eq 0 ]; then
  echo "全部发布成功 ✓（${#done_list[@]} 个包）"
else
  echo "完成，但 $fails 个失败——安全重跑本脚本只会补发失败的包。"
fi
