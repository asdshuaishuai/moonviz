#!/usr/bin/env bash
# 把 npm 上当前发布的全部 MoonViz 包 tarball 备份到 GitHub Releases，
# 作为 npm 之外的分发归档（tag 版本一致性：统一挂 engine-v<MOONVIZ_VERSION>）。
#
# 用法：cd moonviz && MOONVIZ_VERSION=0.1.1 ./scripts/backup-release.sh
#   MOONVIZ_VERSION 缺省读 binaries.yml 的 env 声明。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${MOONVIZ_VERSION:-$(grep -o 'MOONVIZ_VERSION: "[^"]*"' .github/workflows/binaries.yml | head -1 | cut -d'"' -f2)}"
TAG="engine-v${VERSION}"
REPO="$(git -C "$ROOT" remote get-url origin | sed -E 's#.*github.com[:/]##; s#\.git$##')"

# 包家族清单：与 npm 发布面保持一致（新增包在这里追加一行）。
# 不含 moonviz-bin-darwin-x64：该平台已停建（binaries.yml matrix 注释），
# 备份面与构建面保持一致。
PACKAGES=(
  "moonviz-mcp"
  "moonviz-engine-sdk"
  "moonviz-engine-wasm"
  "moonviz-skill"
  "moonviz-bin-darwin-arm64"
  "moonviz-bin-linux-x64"
  "moonviz-bin-linux-arm64"
  "moonviz-bin-win32-x64"
)

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> 备份目标：$REPO @ $TAG"
gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1 || {
  echo "Release $TAG 不存在：先由 CI（binaries.yml gh-release job）或 gh release create 创建" >&2
  exit 1
}

uploaded=0
for pkg in "${PACKAGES[@]}"; do
  meta=$(curl -fsSL "https://registry.npmjs.org/$pkg" 2>/dev/null) || { echo "  ⊘ $pkg 不在 npm（跳过）"; continue; }
  # tag 版本一致性：只备份与 MOONVIZ_VERSION 基线相等的版本，
  # npm 最新版落后/超前基线（含打包后缀号）一律告警跳过
  ver=$(printf '%s' "$meta" | python3 -c "
import sys, json
d = json.load(sys.stdin)
vs = sorted(d.get('versions', {}).keys())
base = sys.argv[1]
matches = [v for v in vs if v == base]
print(matches[-1] if matches else '')" "$VERSION")
  if [ -z "$ver" ]; then
    latest=$(printf '%s' "$meta" | python3 -c "import sys,json;d=json.load(sys.stdin);vs=sorted(d.get('versions',{}).keys());print(vs[-1] if vs else '')")
    echo "  ⚠ $pkg npm 无 ${VERSION} 基线版本（最新 ${latest:-无}），与 tag 基线不一致，跳过" >&2
    continue
  fi
  tgz="$WORK/$pkg-$ver.tgz"
  curl -fsSL -o "$tgz" "https://registry.npmjs.org/$pkg/-/$pkg-$ver.tgz"
  # 已有同名资产则 --clobber 刷新，否则新增
  gh release upload "$TAG" "$tgz" --repo "$REPO" --clobber
  echo "  ✓ $pkg-$ver"
  uploaded=$((uploaded+1))
done
echo "==> 完成：$uploaded 个包已备份到 $TAG"
