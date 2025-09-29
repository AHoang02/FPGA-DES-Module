// UART Transmitter Module
module uart_tx #(
    parameter CLK_FREQ = 100_000_000,   // 100 MHz clock
    parameter BAUD_RATE = 15200         // 15,200 baud
)(
    input  clk,
    input  reset,
    input  start,             // Pulse high to start transmitting a byte.
    input  [7:0] data,        // Byte to transmit.
    output reg tx,            // Serial TX output.
    output reg busy           // Indicates transmitter is busy.
);

    localparam integer BIT_TICK = CLK_FREQ / BAUD_RATE;

    // State machine states.
    localparam STATE_IDLE  = 0,
               STATE_START = 1,
               STATE_DATA  = 2,
               STATE_STOP  = 3;

    reg [1:0] state;
    reg [31:0] tick_count;
    reg [3:0] bit_index;
    reg [7:0] tx_shift;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state      <= STATE_IDLE;
            tick_count <= 0;
            bit_index  <= 0;
            tx         <= 1;  // Idle state for TX is high.
            busy       <= 0;
            tx_shift   <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    tx   <= 1;
                    busy <= 0;
                    if (start) begin
                        busy     <= 1;
                        tx_shift <= data;
                        state    <= STATE_START;
                        tick_count <= 0;
                    end
                end

                STATE_START: begin
                    tx <= 0; // Send start bit.
                    if (tick_count < BIT_TICK - 1)
                        tick_count <= tick_count + 1;
                    else begin
                        tick_count <= 0;
                        state <= STATE_DATA;
                        bit_index <= 0;
                    end
                end

                STATE_DATA: begin
                    tx <= tx_shift[bit_index];
                    if (tick_count < BIT_TICK - 1)
                        tick_count <= tick_count + 1;
                    else begin
                        tick_count <= 0;
                        if (bit_index < 7)
                            bit_index <= bit_index + 1;
                        else begin
                            bit_index <= 0;
                            state <= STATE_STOP;
                        end
                    end
                end

                STATE_STOP: begin
                    tx <= 1; // Send stop bit.
                    if (tick_count < BIT_TICK - 1)
                        tick_count <= tick_count + 1;
                    else begin
                        tick_count <= 0;
                        state <= STATE_IDLE;
                        busy <= 0;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
