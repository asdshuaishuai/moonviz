# DDP 容器格式规范（FORMAT.md）

> 状态：**宿主契约草案 v2**（v1 已随 0.1.x 发布）。实现单一事实源：`ddp/src/lib.rs`。
> 变更须走显式 PR 并同步本文件；CI 校验随实现补齐。
> 本规范由「规范先行」工作流驱动：先定格式，再按格式实现，最后对齐修复。

## 1. 设计原则（不可回退）

1. **单一事实源语义不变**：DDP 的主负载永远是一份完整 `.mbt.md`——它是项目唯一真相。
   附加段（本规范 v2 引入）只能是 `.mbt.md` 的**指导/派生材料**，绝不是第二个真相源。
2. **向后兼容**：v1 读取器遇到 v2 容器必须能解出主负载（见 §4 兼容规则），或给出明确
   的 `ddp_version_unsupported`——绝不允许静默解出损坏数据。
3. **防篡改等级不低于主负载**：附加段与主负载同受认证加密/完整性校验保护。
4. **上限约束**：全容器解压后总字节数 ≤ 16 MiB；单段 ≤ 8 MiB（与 v1 一致）。

## 2. v1 现状（已发布，保持不变）

| 模式 | 布局 |
|---|---|
| DDP1（带密码） | `"DDP1"`(4B) + version(1B=1) + salt(16B) + nonce(24B) + XChaCha20-Poly1305 密文（内为 zstd 压缩的一份 `.mbt.md`；明文头整段作为 AAD） |
| DDP2（免密） | `"DDP2"`(4B) + version(1B=1) + CRC32(LE 4B) + zstd 压缩的一份 `.mbt.md` |

v1 语义：容器 = 一份 UTF-8 `.mbt.md`，**不是归档、没有 manifest**。

## 3. v2 设计：多段容器（本规范新增）

### 3.1 原则：外层分段表 + 命名段

v2 在**压缩层之外**引入明文分段表，使容器可携带命名段；每段独立压缩、独立校验：

```
"DDP2"(4B) | version=2(1B) | section_count(2B LE) |
section_table[ section_count ]：每项
    name_len(1B) | name(UTF-8, ≤31B) | flags(1B) |
    raw_len(4B LE) | stored_len(4B LE) | crc32(4B LE) | data(stored_len B)
```

- `name`：段名，保留名见 §3.2；未知段读取器必须可跳过（向前兼容）。
- `flags`：bit0 = zstd 压缩（1=压缩，0=原样）。
- DDP1 + v2：分段表与全部段数据一并进入 AEAD 密文（AAD 仍覆盖明文头），
  即加密形态为 `"DDP1" + version=2 + salt + nonce + AEAD(分段表+段数据)`。
- DDP2 + v2：分段表明文可读（段名/长度可见，内容仍可压缩），CRC32 逐段 +
  整表一次总校验。

### 3.2 段名注册表

| 段名 | 必带 | 内容 | 写入方 |
|---|---|---|---|
| `mbt.md` | ✅ 唯一真相源 | 完整 `.mbt.md` 源码（UTF-8） | codec |
| `design-spec/components.json` | 可选 | 组件设计规范目录：65 组件 × `{id,kind,category,variants,default_size,description,norm}`——客户端「规范先行」的指导文件 | 客户端/codec |
| `design-spec/engine-manifest.json` | 可选 | 引擎能力锚定清单：version / wasm_sha512 / exports / session / templates / components | 客户端/codec |
| `meta.json` | 可选 | 预留：来源、生成时间、作者标签（v1 曾明确的「不含 manifest」仅指**真相源语义**；v2 的 meta 只描述容器自身，不描述项目内容） | codec |

规则：
- **读取器以 `mbt.md` 段为项目真相**；规范段只作指导/校验输入，不参与场景重建。
- 写入方不得把派生物（SVG/RenderPlan）写入任何段（与 v1 纪律一致，docs/02:109）。
- 规范段与主负载的一致性由**使用方**校验：`engine-manifest.wasm_sha512` 应对得上
  解码方所用引擎的 wasm；不符时按「规范先行 → 对齐修复」流程提示，不阻断解包。

### 3.3 兼容规则

- v1 读取器 读 v2 DDP2：`version=2` → 返回 `ddp_version_unsupported`（明确失败，OK）。
- **v1 读取器 读 v2 DDP1：AEAD 解密仍成功**（version 字节在 AAD 内会改变密文，
  实际上 version=2 的 DDP1 对 v1 读取器表现为 `ddp_version_unsupported`）。
- v2 读取器 读 v1：version=1 → 单段隐式 `mbt.md`，行为与今天完全一致。
- 因此升级顺序：先升读取面（codec/SDK/查看器），再开始发 v2 容器。

### 3.4 校验与安全

- 解压后每段独立上限 8 MiB，容器总计 16 MiB；段名重复 → `ddp_container_invalid`。
- DDP1 下段数据与 v1 同强度：XChaCha20-Poly1305 + Argon2id（19 MiB, t=2, p=1）。
- CRC32 仅用于 DDP2 意外损坏检测，不是安全边界。

## 4. 「规范先行」工作流（本规范服务的流程）

1. **设计规范**：客户端/设计师产出或更新 `design-spec/*` 段内容（组件 norm、引擎锚定）。
2. **按规范实现**：Agent/人以规范段为指导生成/修改 `mbt.md` 主负载。
3. **对齐修复**：解码方比对规范段与主负载（组件是否存在、norm 是否满足、
   引擎版本是否匹配），偏差进入修复循环。

## 5. 实现面清单（按本规范落地时）

- [ ] `ddp/src/lib.rs`：v2 编解码 + 段 API（`encrypt_sections` / `decrypt_sections`）+ 单元测试
- [ ] `ddp/src/bin/ddp_codec.rs`：CLI 参数（`--spec components.json --spec engine-manifest.json`）
- [ ] `sdk/node/src/ddp.js`：sections 透传 + DDP2 v2 解包
- [ ] `ddpView`：v2 段浏览（未知段显示跳过提示）
- [ ] CI：v1↔v2 往返、跨版本兼容矩阵测试
