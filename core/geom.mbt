/// 基础几何类型：布局求解与“不崩”谓词共用的坐标语言。
/// 约定：SolvedLayout 中的矩形为画布绝对坐标，渲染层可直接消费（见 docs/03）。

///|
/// 尺寸有效性上限：拦截 Infinity 与异常大的数值。
/// NaN 参与任何比较均为 false，因此天然被排除。
pub const SIZE_SANITY_LIMIT : Double = 1000000.0

///|
pub(all) struct Size {
  width : Double
  height : Double
}

///|
pub(all) struct Rect {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
pub fn Rect::new(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Rect {
  { x, y, width, height }
}

///|
pub fn Rect::right(self : Rect) -> Double {
  self.x + self.width
}

///|
pub fn Rect::bottom(self : Rect) -> Double {
  self.y + self.height
}

///|
/// 各边内缩（top, right, bottom, left）
pub fn Rect::inset(
  self : Rect,
  t : Double,
  r : Double,
  b : Double,
  l : Double,
) -> Rect {
  {
    x: self.x + l,
    y: self.y + t,
    width: self.width - l - r,
    height: self.height - t - b,
  }
}

///|
/// self 是否完整包含 other（“无溢出”谓词的几何核心）
pub fn Rect::contains_rect(self : Rect, other : Rect) -> Bool {
  self.x <= other.x &&
  self.y <= other.y &&
  self.right() >= other.right() &&
  self.bottom() >= other.bottom()
}

///|
/// self 是否包含 other（带像素级容差）：浮点求解的 Fill 子节点与父内容盒
/// 理论上严丝合缝，但 IEEE754 尘埃会算出 2e-13 之类的假溢出（issue #14
/// adaptive_landing feat_bN 一类）。≤0.5px 的越界在渲染上不可见，视为包含。
pub fn Rect::contains_rect_eps(
  self : Rect,
  other : Rect,
  eps : Double,
) -> Bool {
  self.x <= other.x + eps &&
  self.y <= other.y + eps &&
  self.right() + eps >= other.right() &&
  self.bottom() + eps >= other.bottom()
}

///|
/// 两矩形是否相交（“无重叠”谓词的几何核心；仅贴边不算相交）
pub fn Rect::intersects(self : Rect, other : Rect) -> Bool {
  self.x < other.right() &&
  other.x < self.right() &&
  self.y < other.bottom() &&
  other.y < self.bottom()
}

///|
/// 尺寸是否有效：非负、有限、且小于 sanity 上限
pub fn size_is_valid(w : Double, h : Double) -> Bool {
  w >= 0.0 && w <= SIZE_SANITY_LIMIT && h >= 0.0 && h <= SIZE_SANITY_LIMIT
}
