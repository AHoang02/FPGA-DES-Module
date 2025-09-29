use serialport;
use std::io::{Read, Write};
use std::thread::sleep;
use std::time::Duration;

const PORT_NAME: &str = "COM4"; // Adjust as needed.
const BAUD_RATE: u32 = 15200;    // Must match the FPGA's UART settings.
const TIMEOUT_MS: u64 = 1000;    // 1-second timeout.

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Open the serial port.
    let mut port = serialport::new(PORT_NAME, BAUD_RATE)
        .timeout(Duration::from_millis(TIMEOUT_MS))
        .open()?;

    // Define the 64-bit message and the 64-bit key.
    let message: u64 = 0x4BBD010363A955C0;
    let key: u64 = 0xA1B2C3D4E5F61234;

    //--- Send the 64-bit message ---
    let msg_transfers = prepare_transfers(message);
    println!("Sending 10 transfers for the message...");
    for (i, &byte) in msg_transfers.iter().enumerate() {
        println!("Sending message transfer {}: 0x{:02X}", i, byte);
        port.write_all(&[byte])?;
        port.flush()?;
        sleep(Duration::from_millis(10)); // Give FPGA time to process
    }

    //--- Send the 64-bit key ---
    let key_transfers = prepare_transfers(key);
    println!("Sending 10 transfers for the key...");
    for (i, &byte) in key_transfers.iter().enumerate() {
        println!("Sending key transfer {}: 0x{:02X}", i, byte);
        port.write_all(&[byte])?;
        port.flush()?;
        sleep(Duration::from_millis(10)); // Give FPGA time to process
    }

    println!("Message and key sent. Waiting for ciphertext from FPGA...");

    //--- Read the 64-bit ciphertext (8 bytes) ---
    let mut ciphertext = [0u8; 8];
    port.read_exact(&mut ciphertext)?;

    //--- Print the received ciphertext ---
    print!("Received ciphertext: ");
    for byte in &ciphertext {
        print!("0x{:02X} ", byte);
    }
    println!();

    // Optionally, reconstruct the 64-bit ciphertext as a u64 for processing.
    let recovered_ciphertext = ciphertext.iter().fold(0u64, |acc, &b| (acc << 8) | b as u64);
    println!("Ciphertext as u64: 0x{:016X}", recovered_ciphertext);

    Ok(())
}

/// Splits a 64-bit value into 10 8-bit transfers using the 7+1 scheme.
/// - Transfers 0–8: Extract 7 bits from the value (command bit = 0).
/// - Transfer 9: Extract the last bit and set the command bit (MSB = 1).
fn prepare_transfers(value: u64) -> [u8; 10] {
    let mut transfers = [0u8; 10];
    for i in 0..9 {
        // For transfer 0, we want bits [63:57], transfer 1 gets [56:50], etc.
        let shift = 64 - 7 * (i + 1);
        transfers[i] = ((value >> shift) & 0x7F) as u8;
    }
    // For transfer 9, use the least significant bit and set the command bit (MSB = 1).
    transfers[9] = 0x80 | ((value & 0x1) as u8);
    transfers
}