use aes_gcm::AeadCore;
use aes_gcm::{
    Aes256Gcm, Key,
    aead::{Aead, KeyInit, OsRng},
};
use base64::{Engine as _, engine::general_purpose};
use std::env;
use x25519_dalek::{EphemeralSecret, PublicKey, StaticSecret};
use zeroize::Zeroize;

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 3 {
        // Generate a new long-lived X25519 keypair
        let mut secret = StaticSecret::random_from_rng(&mut OsRng);
        let public = PublicKey::from(&secret);

        let pub_b64 = general_purpose::STANDARD.encode(public.as_bytes());
        let priv_b64 = general_purpose::STANDARD.encode(secret.to_bytes());

        let keypair_json = serde_json::json!({
            "public_key": pub_b64,
            "private_key": priv_b64
        });

        println!("{}", serde_json::to_string_pretty(&keypair_json).unwrap());
        secret.zeroize(); //get rid of the server key in ram
        return;
    }

    let b64_key = args[1].as_str();
    let invitation: &[u8] = args[2].as_bytes();

    let server_secret = EphemeralSecret::random_from_rng(&mut OsRng);
    let server_pub = PublicKey::from(&server_secret); //get secrets

    let decoded = general_purpose::STANDARD
        .decode(b64_key)
        .expect("Invalid base64 key");
    let key_bytes: [u8; 32] = decoded.try_into().expect("Invalid key length");
    let user_pub = PublicKey::from(key_bytes);

    let shared = server_secret.diffie_hellman(&user_pub);
    let key: &Key<Aes256Gcm> = shared.as_bytes().into();

    let cipher = Aes256Gcm::new(key);
    let nonce = Aes256Gcm::generate_nonce(&mut OsRng); // 12-byte nonce
    let ciphertext = cipher
        .encrypt(&nonce, invitation)
        .expect("Encryption failed");

    let encoded_pub = general_purpose::STANDARD.encode(server_pub.as_bytes());
    let encoded_nonce = general_purpose::STANDARD.encode(&nonce);
    let encoded_cipher = general_purpose::STANDARD.encode(&ciphertext);
    let json_output = serde_json::json!({
        "server_pubkey": encoded_pub,
        "nonce": encoded_nonce,
        "ciphertext": encoded_cipher
    });

    println!("{}", serde_json::to_string_pretty(&json_output).unwrap());
}
