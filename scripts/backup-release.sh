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

# 包家族清单：与 npm 发布面保持一致（新增包在这里追加一行）
PACKAGES=(
  "moonviz-mcp"
  "moonviz-engine-sdk"
  "moonviz-engine-wasm"
  "moonviz-skill"
  "moonviz-bin-darwin-arm64"
  "moonviz-bin-darwin-x64"
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
  ver=$(printf '%s' "$meta" | python3 -c "import sys,json;d=json.load(sys.stdin);vs=sorted(d.get('versions',{}).keys());print(vs[-1] if vs else '')")
  [ -z "$ver" ] && { echo "  ⊘ $pkg 无版本（跳过）"; continue; }
  tgz="$WORK/$pkg-$ver.tgz"
  curl -fsSL -o "$tgz" "https://registry.npmjs.org/$pkg/-/$pkg-$ver.tgz"
  # 已有同名资产则 --clobber 刷新，否则新增
  gh release upload "$TAG" "$tgz" --repo "$REPO" --clobber
  echo "  ✓ $pkg-$ver"
  uploaded=$((uploaded+1))
done
echo "==> 完成：$uploaded 个包已备份到 $TAG"
