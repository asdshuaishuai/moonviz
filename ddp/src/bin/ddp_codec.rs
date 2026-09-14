use base64::{engine::general_purpose::STANDARD as BASE64, Engine as _};
use moonviz_ddp::{decrypt_ddp, encrypt_ddp};
use serde::Deserialize;
use serde_json::json;
use std::io::{self, Read};
use zeroize::{Zeroize, Zeroizing};

#[derive(Deserialize)]
struct Request {
    operation: String,
    password: String,
    #[serde(default)]
    mbt_b64: String,
    #[serde(default)]
    ddp_b64: String,
}
impl Drop for Request {
    fn drop(&mut self) {
        self.password.zeroize();
        self.mbt_b64.zeroize();
    }
}

fn run() -> Result<(), String> {
    let mut input = Zeroizing::new(String::new());
    io::stdin()
        .take(24 * 1024 * 1024 + 1)
        .read_to_string(&mut input)
        .map_err(|_| "ddp_codec_stdin_failed")?;
    if input.len() > 24 * 1024 * 1024 {
        return Err("ddp_request_too_large".into());
    }
    let request: Request = serde_json::from_str(&input).map_err(|_| "ddp_codec_request_invalid")?;
    match request.operation.as_str() {
        "encrypt" => {
            let bytes = Zeroizing::new(
                BASE64
                    .decode(&request.mbt_b64)
                    .map_err(|_| "ddp_transport_invalid_base64")?,
            );
            let mbt = std::str::from_utf8(&bytes).map_err(|_| "ddp_mbt_not_utf8")?;
            let ddp = encrypt_ddp(mbt, &request.password)?;
            print!("{}", json!({"ok":true,"ddp_b64":BASE64.encode(ddp)}));
        }
        "decrypt" => {
            let bytes = BASE64
                .decode(&request.ddp_b64)
                .map_err(|_| "ddp_transport_invalid_base64")?;
            let mbt = decrypt_ddp(&bytes, &request.password)?;
            let encoded = Zeroizing::new(BASE64.encode(mbt.as_bytes()));
            // Base64 only contains JSON-safe characters; avoid extra plaintext Value copies.
            print!("{{\"ok\":true,\"mbt_b64\":\"{}\"}}", encoded.as_str());
        }
        _ => return Err("ddp_codec_operation_invalid".into()),
    }
    Ok(())
}
fn main() {
    if let Err(error) = run() {
        print!("{}", json!({"ok":false,"error":error}));
    }
}
