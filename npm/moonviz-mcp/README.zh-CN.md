# moonviz-mcp

> 🇬🇧 English: [README.md](./README.md)

[MoonViz](https://github.com/asdshuaishuai/moonviz) 引擎的 MCP（Model Context Protocol）服务器启动器。

MoonViz 是纯 MoonBit 实现的原型设计引擎：`.mbt.md` 单一事实源、human/Agent 双路线编辑、每次预览从源重建。本包把引擎的 MCP server 以**平台预编译二进制**分发——`npx` 即起，零编译、零工具链。

## 使用

任意 MCP 客户端（Claude Desktop / ZCode / Cursor / 5ire …）配置：

```json
{
  "mcpServers": {
    "moonviz": {
      "command": "npx",
      "args": ["-y", "moonviz-mcp"]
    }
  }
}
```

需要引擎目录的工具（`read_mbt` / `render_mbt` / `apply_*` 等）通过 `MOONVIZ_DIR` 指向你的 moonviz 仓库 clone：

```json
{
  "mcpServers": {
    "moonviz": {
      "command": "npx",
      "args": ["-y", "moonviz-mcp"],
      "env": { "MOONVIZ_DIR": "/path/to/moonviz" }
    }
  }
}
```

## 工作方式

1. 按 `os-arch` 解析可选依赖平台包（`moonviz-bin-darwin-arm64` / `-darwin-x64` / `-linux-x64` / `-linux-arm64`，npm 自动只装匹配当前平台的那一个），直接以 stdio 运行内嵌二进制——启动为毫秒级。
2. 当前平台无预编译包时回退：`moon run --target native mcp`（需要 [MoonBit 工具链](https://docs.moonbitlang.com/) + `MOONVIZ_DIR` 指向引擎仓库）。

## 工具一览（节选）

| 工具 | 说明 |
|---|---|
| `initialize` | 初始化项目会话 |
| `read_mbt` / `render_mbt` | 源侧读写入口：读取 canonical 源码 / 从源渲染全部画板 |
| `list_templates` / `list_components` / `list_themes` / `list_tokens` / `list_artboards` | 枚举模板（8 页面）/ 组件（8×22 变体）/ 主题 / token / 画板 |
| `apply_template` / `apply_theme` | 实例化模板 / 切换主题 |
| `lint_design` / `auto_fix` | 设计 Lint 与自动修复 |
| `critique` / `infer_page_type` / `infer_missing` | 设计批评与推断 |
| `extract_design_system` / `generate_spec` / `generate_responsive` | 设计系统反提取 / 移交标注 / 响应式变体 |
| `export_svg` / `export_artifact` / `benchmark` | 导出与性能基准 |
| `ddp_view` | DDP 容器只读元数据 |

## 从源码构建二进制

```bash
git clone https://github.com/asdshuaishuai/moonviz && cd moonviz
moon build --release --target native mcp
# → _build/native/release/build/mcp/mcp.exe（自包含，仅依赖 libc）
```

平台包由仓库 `.github/workflows/binaries.yml` CI 矩阵构建。

## License

MIT © MoonViz contributors
