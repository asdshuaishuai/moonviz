///|
/// Vendored from mizchi/zlib (Apache-2.0) — DEFLATE fixed Huffman 压缩
pub enum DeflateToken {
  Lit(Int)
  Match(len~ : Int, dist~ : Int)
}

///|
let deflate_length_base : FixedArray[Int] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let deflate_length_extra : FixedArray[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
let deflate_dist_base : FixedArray[Int] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let deflate_dist_extra : FixedArray[Int] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
let window_size : Int = 32768

///|
let max_match_len : Int = 258

///|
let min_match_len : Int = 3

///|
let hash_size : Int = 1 << 15

///|
let max_chain : Int = 64

///|
fn deflate_reverse_bits(code : Int, len : Int) -> Int {
  let mut v = code
  let mut out = 0
  let mut n = len
  while n > 0 {
    out = (out << 1) | (v & 1)
    v = v >> 1
    n -= 1
  }
  out
}

///|
fn fixed_lit_code(sym : Int) -> (Int, Int) {
  if sym <= 143 {
    let code = sym + 0x30
    (deflate_reverse_bits(code, 8), 8)
  } else if sym <= 255 {
    let code = sym - 144 + 0x190
    (deflate_reverse_bits(code, 9), 9)
  } else if sym <= 279 {
    let code = sym - 256
    (deflate_reverse_bits(code, 7), 7)
  } else {
    let code = sym - 280 + 0xC0
    (deflate_reverse_bits(code, 8), 8)
  }
}

///|
fn fixed_dist_code(sym : Int) -> (Int, Int) {
  (deflate_reverse_bits(sym, 5), 5)
}

///|
fn length_code_info(len : Int) -> (Int, Int, Int) {
  for i in 0..<deflate_length_base.length() {
    let base = deflate_length_base[i]
    let extra = deflate_length_extra[i]
    let max_len = base + ((1 << extra) - 1)
    if len <= max_len {
      return (257 + i, extra, len - base)
    }
  }
  (285, 0, 0)
}

///|
fn dist_code_info(dist : Int) -> (Int, Int, Int) {
  for i in 0..<deflate_dist_base.length() {
    let base = deflate_dist_base[i]
    let extra = deflate_dist_extra[i]
    let max_dist = base + ((1 << extra) - 1)
    if dist <= max_dist {
      return (i, extra, dist - base)
    }
  }
  (29, 13, dist - deflate_dist_base[29])
}

///|
fn hash3(data : Bytes, pos : Int) -> Int {
  let b0 = data[pos].to_int()
  let b1 = data[pos + 1].to_int()
  let b2 = data[pos + 2].to_int()
  ((b0 << 8) ^ (b1 << 4) ^ b2) & (hash_size - 1)
}

///|
fn insert_hash(
  data : Bytes,
  pos : Int,
  head : FixedArray[Int],
  prev : FixedArray[Int],
) -> Unit {
  if pos + 2 >= data.length() {
    return
  }
  let h = hash3(data, pos)
  prev[pos] = head[h]
  head[h] = pos
}

///|
fn write_literal(writer : BitWriter, sym : Int) -> Unit {
  let (code, len) = fixed_lit_code(sym)
  writer.write_bits(code, len)
}

///|
fn write_match(writer : BitWriter, length : Int, distance : Int) -> Unit {
  let (len_code, len_extra_bits, len_extra_val) = length_code_info(length)
  let (code_bits, code_len) = fixed_lit_code(len_code)
  writer.write_bits(code_bits, code_len)
  if len_extra_bits > 0 {
    writer.write_bits(len_extra_val, len_extra_bits)
  }
  let (dist_code, dist_extra_bits, dist_extra_val) = dist_code_info(distance)
  let (dist_bits, dist_len) = fixed_dist_code(dist_code)
  writer.write_bits(dist_bits, dist_len)
  if dist_extra_bits > 0 {
    writer.write_bits(dist_extra_val, dist_extra_bits)
  }
}

///|
fn write_end_block(writer : BitWriter) -> Unit {
  let (code, len) = fixed_lit_code(256)
  writer.write_bits(code, len)
}

///|
fn write_tokens_fixed(tokens : Array[DeflateToken], writer : BitWriter) -> Unit {
  for t in tokens {
    match t {
      Lit(sym) => write_literal(writer, sym)
      Match(len~, dist~) => write_match(writer, len, dist)
    }
  }
}

///|
fn build_tokens(data : Bytes) -> Array[DeflateToken] {
  let tokens : Array[DeflateToken] = []
  let len = data.length()
  let head : FixedArray[Int] = FixedArray::make(hash_size, -1)
  let prev : FixedArray[Int] = FixedArray::make(len, -1)
  let mut pos = 0
  while pos < len {
    let remaining = len - pos
    let mut best_len = 0
    let mut best_dist = 0
    if remaining >= min_match_len {
      let h = hash3(data, pos)
      let mut candidate = head[h]
      let limit = if pos > window_size { pos - window_size } else { 0 }
      let max_len = if remaining < max_match_len {
        remaining
      } else {
        max_match_len
      }
      let mut chain = 0
      while candidate >= limit && chain < max_chain {
        if data[candidate] == data[pos] &&
          data[candidate + 1] == data[pos + 1] &&
          data[candidate + 2] == data[pos + 2] {
          let mut l = min_match_len
          while l < max_len && data[candidate + l] == data[pos + l] {
            l += 1
          }
          if l > best_len {
            best_len = l
            best_dist = pos - candidate
            if l == max_len {
              break
            }
          }
        }
        candidate = prev[candidate]
        chain += 1
      }
    }
    if best_len >= min_match_len {
      tokens.push(Match(len=best_len, dist=best_dist))
      for i = 0; i < best_len; i = i + 1 {
        insert_hash(data, pos + i, head, prev)
      }
      pos = pos + best_len
    } else {
      tokens.push(Lit(data[pos].to_int()))
      insert_hash(data, pos, head, prev)
      pos = pos + 1
    }
  }
  tokens
}

///|

///|
/// DEFLATE 固定 Huffman 压缩入口
fn deflate_compress_fixed_v(data : Bytes) -> Bytes {
  let writer = BitWriter::new()
  writer.write_bits(1, 1) // BFINAL=1
  writer.write_bits(1, 2) // BTYPE=01 (fixed Huffman)
  let tokens = build_tokens(data)
  write_tokens_fixed(tokens, writer)
  write_end_block(writer)
  writer.finish()
}

// Bit writer for deflate streams (LSB-first)

//

///|
struct BitWriter {
  buf : Array[Byte]
  mut bit_buf : Int
  mut bit_count : Int
}

//

///|
fn BitWriter::new() -> BitWriter {
  { buf: [], bit_buf: 0, bit_count: 0 }
}

//

///|
fn BitWriter::write_bits(self : BitWriter, bits : Int, count : Int) -> Unit {
  let mut value = bits
  let mut remaining = count
  while remaining > 0 {
    let available = 8 - self.bit_count
    let take = if remaining < available { remaining } else { available }
    let mask = (1 << take) - 1
    self.bit_buf = self.bit_buf | ((value & mask) << self.bit_count)
    self.bit_count = self.bit_count + take
    value = value >> take
    remaining = remaining - take
    if self.bit_count == 8 {
      self.buf.push((self.bit_buf & 0xff).to_byte())
      self.bit_buf = 0
      self.bit_count = 0
    }
  }
}

//

///|
fn BitWriter::align_byte(self : BitWriter) -> Unit {
  if self.bit_count > 0 {
    self.buf.push((self.bit_buf & 0xff).to_byte())
    self.bit_buf = 0
    self.bit_count = 0
  }
}

//

///|
fn BitWriter::finish(self : BitWriter) -> Bytes {
  self.align_byte()
  Bytes::from_array(FixedArray::makei(self.buf.length(), fn(i) { self.buf[i] }))
}
