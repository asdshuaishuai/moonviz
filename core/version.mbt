///|
/// 引擎版本单一事实源：moon.mod.json 同步维护。
/// version_info（wasm）、CLI banner、MCP serverInfo、artifact meta_version
/// 全部引用本常量——发布新版本时改这一处 + moon.mod.json。
pub const ENGINE_VERSION : String = "0.1.6-fix"
