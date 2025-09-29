# FPGA-DES-Module
Rust FPGA project implementing DES encryption/decryption over UART. Messages and keys are framed with a 7+1 scheme in Rust, sent to an FPGA FSM in Verilog, and processed by a DES core. Supports both encryption and decryption with register clearing for reliable round trip recovery.
