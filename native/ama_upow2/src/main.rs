mod upow2;
use blake3;
use blake3::Hash;
use std::fs;
use std::str::FromStr;

fn main() {
    let mut hasher = blake3::Hasher::new();
    let entry = vec![0u8; 240];
    hasher.update(&entry);
    let mut xof = hasher.finalize_xof();
    let file_bytes = fs::read("./all_zero").expect("test vector ./all_zero");
    let mut xof_bytes = vec![0u8; file_bytes.len()];
    xof.fill(&mut xof_bytes);
    if file_bytes == xof_bytes {
        println!("✅  File contents match the BLAKE3 XOF output.");
    } else {
        println!("❌  File contents differ from the BLAKE3 XOF output.");
    }

    let epoch = 0;
    let seg_hash = [0u8; 32];
    let trainer = vec![0u8; 48];
    let pop = vec![0u8; 96];
    let computor = vec![0u8; 48];

    let (hash, solution) = upow2::tensormath(epoch, &seg_hash, &trainer, &pop, &computor);

    let expected = "b98d2d8c79fcdb79e272d35b226e00235ec5fc17e00fb6e8bc59faa60c2e9783";
    let expected_hash = Hash::from_str(expected).expect("hex string is not a valid BLAKE3 hash");

    if hash == expected_hash {
        println!("✅  hash match tensor output.");
    } else {
        println!("❌  hash doesn't match tensor output.");
    }

    println!("hash  = {}", hash);
    println!("bytes = {}", solution.len());
}
