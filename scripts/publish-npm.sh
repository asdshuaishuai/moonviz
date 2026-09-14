#!/usr/bin/env bash
# 一键发布全部 MoonViz npm 包（需先 npm login）。
# 用法：cd moonviz && ./scripts/publish-npm.sh [--dry-run]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRY_RUN="${1:-}"
PUBLISH_ARGS=(publish --access public)
[ "$DRY_RUN" = "--dry-run" ] && PUBLISH_ARGS+=(--dry-run)

cd "$ROOT"

echo "==> 检查 npm 登录状态"
if ! npm whoami >/dev/null 2>&1; then
  echo "未登录 npm。请先执行: npm login" >&2
  exit 1
fi
echo "已登录: $(npm whoami)"

echo "==> 重建产物（wasm + native mcp/cli 二进制）"
moon build --release --target wasm-gc wasm
cp _build/wasm-gc/release/build/wasm/wasm.wasm sdk/wasm/dist/moonviz.wasm
moon build --release --target native mcp
moon build --release --target native cli
mkdir -p npm/moonviz-bin-darwin-arm64/bin
cp _build/native/release/build/mcp/mcp.exe npm/moonviz-bin-darwin-arm64/bin/moonviz-mcp
cp _build/native/release/build/cli/cli.exe npm/moonviz-bin-darwin-arm64/bin/moonviz-cli
chmod +x npm/moonviz-bin-darwin-arm64/bin/*

echo "==> 运行自检"
node sdk/node/test/selftest.mjs
NODE22="$(command -v node >/dev/null && node -e 'process.stdout.write(process.versions.node.split(".")[0] >= 22 ? "1" : "0")')"
if [ "$NODE22" = "1" ]; then
  node sdk/wasm/test/selftest.mjs
else
  echo "（跳过 wasm selftest：当前 node < 22）"
fi

echo "==> 发布顺序：平台二进制 → 主包 → SDK（依赖方向）"
npm -C npm/moonviz-bin-darwin-arm64 "${PUBLISH_ARGS[@]}"
npm -C sdk/node "${PUBLISH_ARGS[@]}"
npm -C sdk/wasm "${PUBLISH_ARGS[@]}"
npm -C npm/moonviz-mcp "${PUBLISH_ARGS[@]}"

echo ""
echo "完成。其余平台包（darwin-x64 / linux-x64 / linux-arm64）由 CI 构建："
echo "  1. 仓库 Settings → Secrets 添加 NPM_TOKEN（npm access token）"
echo "  2. 仓库 Settings → Variables 添加 NPM_PUBLISH=true"
echo "  3. 手动触发 workflows/binaries.yml（或等 main 分支下一次推送）"
