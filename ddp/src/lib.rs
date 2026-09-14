use argon2::{Algorithm, Argon2, Params, Version};
use chacha20poly1305::{
    aead::{Aead, KeyInit, Payload},
    XChaCha20Poly1305, XNonce,
};
use rand_core::{OsRng, RngCore};
use std::io::{Cursor, Read};
use zeroize::Zeroizing;
const DDP_MAGIC: &[u8; 4] = b"DDP1";
const DDP_MAGIC_OPEN: &[u8; 4] = b"DDP2"; // 无密码模式：仅 zstd + CRC32 完整性校验
const DDP_VERSION: u8 = 1;
const DDP_SALT_BYTES: usize = 16;
const DDP_NONCE_BYTES: usize = 24;
const DDP_HEADER_BYTES: usize = DDP_MAGIC.len() + 1 + DDP_SALT_BYTES + DDP_NONCE_BYTES;
const DDP_MAX_PLAINTEXT_BYTES: usize = 8 * 1024 * 1024;
const DDP_MAX_CIPHERTEXT_BYTES: usize = 16 * 1024 * 1024;

type DdpResult<T> = Result<T, String>;

/// IEEE CRC32（无查表实现，DDP2 完整性校验用）。
fn crc32_ieee(data: &[u8]) -> u32 {
    let mut crc: u32 = 0xFFFF_FFFF;
    for &byte in data {
        crc ^= byte as u32;
        for _ in 0..8 {
            let mask = (crc & 1).wrapping_neg();
            crc = (crc >> 1) ^ (0xEDB8_8320 & mask);
        }
    }
    !crc
}

/// DDP is one authenticated encrypted MBT source, never an archive or manifest.
/// The clear header is only the codec discriminator and KDF/nonce material. Every
/// semantic byte belongs to the encrypted UTF-8 `.mbt.md` payload.
fn derive_ddp_key(password: &str, salt: &[u8]) -> DdpResult<Zeroizing<[u8; 32]>> {
    let params = Params::new(19 * 1024, 2, 1, Some(32))
        .map_err(|_| "ddp_kdf_parameters_invalid".to_string())?;
    let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);
    let mut key = Zeroizing::new([0u8; 32]);
    argon2
        .hash_password_into(password.as_bytes(), salt, &mut *key)
        .map_err(|_| "ddp_key_derivation_failed".to_string())?;
    Ok(key)
}

pub fn encrypt_ddp(mbt: &str, password: &str) -> DdpResult<Vec<u8>> {
    if mbt.is_empty() {
        return Err("ddp_mbt_empty".into());
    }
    if mbt.as_bytes().len() > DDP_MAX_PLAINTEXT_BYTES {
        return Err("ddp_mbt_too_large".into());
    }
    // 空密码 → DDP2 未加密模式：仍是单一 .mbt.md 的容器（zstd 压缩 + CRC32），
    // 供无需保密、查看器免密直开的场景；带密码则走 DDP1 认证加密。
    if password.is_empty() {
        let compressed = Zeroizing::new(
            zstd::stream::encode_all(Cursor::new(mbt.as_bytes()), 8)
                .map_err(|_| "ddp_compression_failed".to_string())?,
        );
        let mut header = Vec::with_capacity(5 + 4 + compressed.len());
        header.extend_from_slice(DDP_MAGIC_OPEN);
        header.push(DDP_VERSION);
        let crc = crc32_ieee(&compressed);
        header.extend_from_slice(&crc.to_le_bytes());
        header.extend_from_slice(&*compressed);
        return Ok(header);
    }

    let compressed = Zeroizing::new(
        zstd::stream::encode_all(Cursor::new(mbt.as_bytes()), 8)
            .map_err(|_| "ddp_compression_failed".to_string())?,
    );
    let mut salt = [0u8; DDP_SALT_BYTES];
    let mut nonce = [0u8; DDP_NONCE_BYTES];
    OsRng
        .try_fill_bytes(&mut salt)
        .map_err(|_| "ddp_random_failed".to_string())?;
    OsRng
        .try_fill_bytes(&mut nonce)
        .map_err(|_| "ddp_random_failed".to_string())?;
    let key = derive_ddp_key(password, &salt)?;
    let cipher = XChaCha20Poly1305::new((&*key).into());

    let mut header = Vec::with_capacity(DDP_HEADER_BYTES);
    header.extend_from_slice(DDP_MAGIC);
    header.push(DDP_VERSION);
    header.extend_from_slice(&salt);
    header.extend_from_slice(&nonce);
    let ciphertext = cipher
        .encrypt(
            XNonce::from_slice(&nonce),
            Payload {
                msg: &compressed,
                aad: &header,
            },
        )
        .map_err(|_| "ddp_encryption_failed".to_string())?;

    if ciphertext.len() > DDP_MAX_CIPHERTEXT_BYTES {
        return Err("ddp_ciphertext_too_large".into());
    }
    header.extend_from_slice(&ciphertext);
    Ok(header)
}

pub fn decrypt_ddp(bytes: &[u8], password: &str) -> DdpResult<Zeroizing<String>> {
    if bytes.len() < 10 || bytes.len() > DDP_MAX_CIPHERTEXT_BYTES + 16 {
        return Err("ddp_container_invalid".into());
    }
    // DDP2 未加密模式：zstd + CRC32 校验，免密直开
    if &bytes[0..4] == DDP_MAGIC_OPEN {
        if bytes[4] != DDP_VERSION {
            return Err("ddp_version_unsupported".into());
        }
        let stored_crc = u32::from_le_bytes(
            bytes[5..9]
                .try_into()
                .map_err(|_| "ddp_container_invalid".to_string())?,
        );
        let payload = &bytes[9..];
        if crc32_ieee(payload) != stored_crc {
            return Err("ddp_checksum_failed".into());
        }
        let mut decoder = zstd::stream::read::Decoder::new(Cursor::new(payload))
            .map_err(|_| "ddp_decompression_failed".to_string())?;
        decoder
            .window_log_max(23)
            .map_err(|_| "ddp_decompression_failed".to_string())?;
        let mut plaintext = Zeroizing::new(Vec::new());
        let mut chunk = Zeroizing::new([0u8; 8192]);
        loop {
            let count = decoder
                .read(&mut *chunk)
                .map_err(|_| "ddp_decompression_failed".to_string())?;
            if count == 0 {
                break;
            }
            if plaintext.len() + count > DDP_MAX_PLAINTEXT_BYTES {
                return Err("ddp_plaintext_invalid".into());
            }
            plaintext.extend_from_slice(&chunk[..count]);
        }
        if plaintext.is_empty() {
            return Err("ddp_plaintext_invalid".into());
        }
        let text = std::str::from_utf8(&plaintext).map_err(|_| "ddp_mbt_not_utf8".to_string())?;
        return Ok(Zeroizing::new(text.to_owned()));
    }

    if password.is_empty() {
        return Err("ddp_password_required".into());
    }
    if bytes.len() < DDP_HEADER_BYTES + 16
        || bytes.len() > DDP_MAX_CIPHERTEXT_BYTES + DDP_HEADER_BYTES
    {
        return Err("ddp_container_invalid".into());
    }
    if &bytes[0..4] != DDP_MAGIC {
        return Err("ddp_magic_invalid".into());
    }
    if bytes[4] != DDP_VERSION {
        return Err("ddp_version_unsupported".into());
    }

    let salt_start = 5;
    let nonce_start = salt_start + DDP_SALT_BYTES;
    let payload_start = nonce_start + DDP_NONCE_BYTES;
    let salt = &bytes[salt_start..nonce_start];
    let nonce = &bytes[nonce_start..payload_start];
    let key = derive_ddp_key(password, salt)?;
    let cipher = XChaCha20Poly1305::new((&*key).into());
    let compressed = Zeroizing::new(
        cipher
            .decrypt(
                XNonce::from_slice(nonce),
                Payload {
                    msg: &bytes[payload_start..],
                    aad: &bytes[..payload_start],
                },
            )
            .map_err(|_| "ddp_authentication_failed".to_string())?,
    );

    let mut decoder = zstd::stream::read::Decoder::new(Cursor::new(&*compressed))
        .map_err(|_| "ddp_decompression_failed".to_string())?;
    // Cap zstd's window and stream into a fixed-size buffer: neither a frame's
    // advertised content size nor compressed expansion can allocate unbounded memory.
    decoder
        .window_log_max(23)
        .map_err(|_| "ddp_decompression_failed".to_string())?;
    let mut plaintext = Zeroizing::new(Vec::new());
    let mut chunk = Zeroizing::new([0u8; 8192]);
    loop {
        let count = decoder
            .read(&mut *chunk)
            .map_err(|_| "ddp_decompression_failed".to_string())?;
        if count == 0 {
            break;
        }
        if plaintext.len() + count > DDP_MAX_PLAINTEXT_BYTES {
            return Err("ddp_plaintext_invalid".into());
        }
        plaintext.extend_from_slice(&chunk[..count]);
    }
    if plaintext.is_empty() {
        return Err("ddp_plaintext_invalid".into());
    }
    let text = std::str::from_utf8(&plaintext).map_err(|_| "ddp_mbt_not_utf8".to_string())?;
    Ok(Zeroizing::new(text.to_owned()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ddp_round_trips_one_complete_mbt_source() {
        let mbt = "---\nmoonbit:\n  backend: native\n---\n\n# 视觉文档\n\n```mbt\nfn visual() -> Int { 42 }\n```\n";
        let ddp = encrypt_ddp(mbt, "correct horse battery staple").expect("encrypt");
        assert_eq!(&ddp[0..4], DDP_MAGIC);
        let marker = "视觉文档".as_bytes();
        assert!(!ddp.windows(marker.len()).any(|window| window == marker));
        assert_eq!(
            decrypt_ddp(&ddp, "correct horse battery staple")
                .expect("decrypt")
                .as_str(),
            mbt
        );
    }

    #[test]
    fn ddp_rejects_wrong_password_and_tampering() {
        let mut ddp = encrypt_ddp("# source", "correct password").expect("encrypt");
        assert_eq!(
            decrypt_ddp(&ddp, "wrong password").expect_err("wrong password must fail"),
            "ddp_authentication_failed"
        );
        let last = ddp.len() - 1;
        ddp[last] ^= 0x80;
        assert_eq!(
            decrypt_ddp(&ddp, "correct password").expect_err("tamper must fail"),
            "ddp_authentication_failed"
        );
    }
    #[test]
    fn rejects_sizes_and_authenticated_expansion() {
        assert!(encrypt_ddp(&"x".repeat(DDP_MAX_PLAINTEXT_BYTES + 1), "pw").is_err());
        assert!(decrypt_ddp(
            &vec![0; DDP_MAX_CIPHERTEXT_BYTES + DDP_HEADER_BYTES + 1],
            "pw"
        )
        .is_err());
        let mut header = vec![0u8; DDP_HEADER_BYTES];
        header[..4].copy_from_slice(DDP_MAGIC);
        header[4] = DDP_VERSION;
        let key = derive_ddp_key("pw", &header[5..21]).unwrap();
        let cipher = XChaCha20Poly1305::new((&*key).into());
        let compressed =
            zstd::stream::encode_all(Cursor::new(vec![b'x'; DDP_MAX_PLAINTEXT_BYTES + 1]), 1)
                .unwrap();
        let encrypted = cipher
            .encrypt(
                XNonce::from_slice(&header[21..]),
                Payload {
                    msg: &compressed,
                    aad: &header,
                },
            )
            .unwrap();
        header.extend(encrypted);
        assert!(decrypt_ddp(&header, "pw").is_err());
    }
}

#[cfg(test)]
mod open_tests {
    use super::*;

    #[test]
    fn ddp2_open_mode_round_trips_without_password() {
        let mbt = "---\nmoonviz:\n  entry: a\n---\n\n# 无密码文档\n\n<!-- moonviz:artboard a -->\n```mbt\nfn visual_a() -> @decl.Prototype { let page = @decl.prototype(name=\"a\", width=100, height=100) page }\n```\n";
        let ddp = encrypt_ddp(mbt, "").expect("encrypt open");
        assert_eq!(&ddp[0..4], DDP_MAGIC_OPEN);
        // 明文不应出现
        for marker in ["无密码文档", "moonviz:"] {
            assert!(!ddp
                .windows(marker.len())
                .any(|w| w == marker.as_bytes()));
        }
        let back = decrypt_ddp(&ddp, "").expect("decrypt open");
        assert_eq!(&*back, mbt);
        // 篡改必须失败
        let mut tampered = ddp.clone();
        let last = tampered.len() - 1;
        tampered[last] ^= 0xFF;
        assert!(decrypt_ddp(&tampered, "").is_err());
    }

    #[test]
    fn ddp2_ignores_password_and_ddp1_still_requires_one() {
        let mbt = "# x";
        let open_ddp = encrypt_ddp(mbt, "").expect("open");
        assert!(decrypt_ddp(&open_ddp, "any-password").is_ok());
        let encrypted = encrypt_ddp(mbt, "secret").expect("encrypted");
        assert!(decrypt_ddp(&encrypted, "").is_err());
        assert!(decrypt_ddp(&encrypted, "wrong").is_err());
        assert!(decrypt_ddp(&encrypted, "secret").is_ok());
    }
}
