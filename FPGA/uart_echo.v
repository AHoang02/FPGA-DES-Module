`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/23/2025 11:14:15 PM
// Design Name: UART_DES_Interface
// Module Name: uart_des
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//   This module receives a 64-bit plaintext and a 64-bit key (each received as 10 transfers 
//   using the 7+1 scheme) via UART, passes them to the DES module (from the GitHub repository,
//   whose top-level file is main.v), and then transmits the 64-bit ciphertext as 8 bytes via UART.
// 
// Dependencies: 
//   uart_rx, uart_tx, DES (from main.v)
// 
// Revision:
// Revision 0.1 - Integrated DES from main.v into UART interface.
//////////////////////////////////////////////////////////////////////////////////

module uart_des(
    input clk,
    input reset,
    input rx,// UART RX input.
    input select,      
    output tx      // UART TX output.
);

    // UART interface signals.
    wire [7:0] rx_data;
    wire       rx_valid;
    reg        tx_start;
    reg [7:0]  tx_data;
    wire       tx_busy;
    
    // Instantiate the UART Receiver.
    uart_rx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(15200)
    ) uart_rx_inst (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .data(rx_data),
        .valid(rx_valid)
    );
    
    // Instantiate the UART Transmitter.
    uart_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(15200)
    ) uart_tx_inst (
        .clk(clk),
        .reset(reset),
        .start(tx_start),
        .data(tx_data),
        .tx(tx),
        .busy(tx_busy)
    );
    
    // State machine states.
    localparam RECV_MSG = 2'b00;
    localparam RECV_KEY = 2'b01;
    localparam ENCRYPT  = 2'b10;
    localparam SEND     = 2'b11;
    
    reg [1:0] state;
    reg [3:0] recv_count;   // Counts transfers (0 to 9).
    reg [2:0] send_count;   // Counts 8 bytes to send (0 to 7).

    // 64-bit registers for message and key using 1-indexed vectors (as expected by DES)
    reg [64:1] message_reg;
    reg [64:1] key_reg;
    wire [64:1] ciphertext_wire;
    
    // Instantiate the DES module from the repository (from main.v).
    // The DES module has the following port signature:
    //   DES(input [64:1] in, input [64:1] key, output [64:1] out);
    DES des_inst (
        .in(message_reg),
        .key(key_reg),
        .decrypt_select(select),
        .out(ciphertext_wire)
    );
    
    // Main state machine:
    // 1. RECV_MSG: Assemble the 64-bit plaintext from 10 transfers.
    // 2. RECV_KEY: Assemble the 64-bit key from 10 transfers.
    // 3. ENCRYPT: (Assumes the DES module is combinational; if sequential, add handshake logic.)
    // 4. SEND: Transmit the 64-bit ciphertext as 8 bytes via UART.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= RECV_MSG;
            recv_count  <= 0;
            send_count  <= 0;
            tx_start    <= 0;
            tx_data     <= 8'd0;
            message_reg <= 64'd0;
            key_reg     <= 64'd0;
        end else begin
            case (state)
                //----------------------------------------------
                // RECV_MSG: Assemble 64-bit plaintext.
                RECV_MSG: begin
                    if (rx_valid) begin
                        if (recv_count < 9) begin
                            case (recv_count)
                                0: message_reg[64:58] <= rx_data[6:0];
                                1: message_reg[57:51] <= rx_data[6:0];
                                2: message_reg[50:44] <= rx_data[6:0];
                                3: message_reg[43:37] <= rx_data[6:0];
                                4: message_reg[36:30] <= rx_data[6:0];
                                5: message_reg[29:23] <= rx_data[6:0];
                                6: message_reg[22:16] <= rx_data[6:0];
                                7: message_reg[15:9]  <= rx_data[6:0];
                                8: message_reg[8:2]   <= rx_data[6:0];
                                default: ;
                            endcase
                            recv_count <= recv_count + 1;
                        end else begin
                            // Transfer 9: Use the LSB only (bit 1)
                            message_reg[1] <= rx_data[0];
                            recv_count <= 0;
                            state <= RECV_KEY;
                        end
                    end
                end

                //----------------------------------------------
                // RECV_KEY: Assemble 64-bit key.
                RECV_KEY: begin
                    if (rx_valid) begin
                        if (recv_count < 9) begin
                            case (recv_count)
                                0: key_reg[64:58] <= rx_data[6:0];
                                1: key_reg[57:51] <= rx_data[6:0];
                                2: key_reg[50:44] <= rx_data[6:0];
                                3: key_reg[43:37] <= rx_data[6:0];
                                4: key_reg[36:30] <= rx_data[6:0];
                                5: key_reg[29:23] <= rx_data[6:0];
                                6: key_reg[22:16] <= rx_data[6:0];
                                7: key_reg[15:9]  <= rx_data[6:0];
                                8: key_reg[8:2]   <= rx_data[6:0];
                                default: ;
                            endcase
                            recv_count <= recv_count + 1;
                        end else begin
                            // Transfer 9: Use the LSB only (bit 1)
                            key_reg[1] <= rx_data[0];
                            recv_count <= 0;
                            state <= ENCRYPT;
                        end
                    end
                end

                //----------------------------------------------
                // ENCRYPT: Wait for DES encryption to complete.
                // If the DES module is purely combinational, its output is immediately valid.
                ENCRYPT: begin
                    state <= SEND;
                    send_count <= 0;
                end

                //----------------------------------------------
                // SEND: Transmit the 64-bit ciphertext as 8 bytes (MSB first).
                SEND: begin
                    if (!tx_busy && !tx_start) begin
                        case (send_count)
                            0: tx_data <= ciphertext_wire[64:57];
                            1: tx_data <= ciphertext_wire[56:49];
                            2: tx_data <= ciphertext_wire[48:41];
                            3: tx_data <= ciphertext_wire[40:33];
                            4: tx_data <= ciphertext_wire[32:25];
                            5: tx_data <= ciphertext_wire[24:17];
                            6: tx_data <= ciphertext_wire[16:9];
                            7: tx_data <= ciphertext_wire[8:1];
                            default: tx_data <= 8'd0;
                        endcase
                        tx_start <= 1;
                        send_count <= send_count + 1;
                        if (send_count == 7)
                            state <= RECV_MSG;  // Ready for next message.
                    end else begin
                        tx_start <= 0; // Generate a one-cycle pulse.
                    end
                end

                default: state <= RECV_MSG;
            endcase
        end
    end

endmodule