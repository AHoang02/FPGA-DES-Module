// UART Receiver Module
module uart_rx #(
    parameter CLK_FREQ = 100_000_000,   // 100 MHz clock
    parameter BAUD_RATE = 15200         // 15,200 baud
)(
    input  clk,
    input  reset,
    input  rx,                        // Serial RX input
    output reg [7:0] data,            // Received byte
    output reg valid                // Asserted for one clock cycle when data is valid
);

    // Calculate clock ticks per bit period.
    localparam integer BIT_TICK = CLK_FREQ / BAUD_RATE;

    // Define state machine states.
    localparam STATE_IDLE  = 0,
               STATE_START = 1,
               STATE_DATA  = 2,
               STATE_STOP  = 3;

    reg [1:0] state;
    reg [31:0] tick_count;
    reg [3:0] bit_index;
    reg [7:0] rx_shift;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state      <= STATE_IDLE;
            tick_count <= 0;
            bit_index  <= 0;
            valid      <= 0;
            rx_shift   <= 0;
            data       <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    valid <= 0;
                    tick_count <= 0;
                    bit_index <= 0;
                    if (rx == 0) begin // Detect start bit.
                        state <= STATE_START;
                    end
                end

                STATE_START: begin
                    // Wait half a bit period to sample the start bit in its middle.
                    if (tick_count < (BIT_TICK >> 1) - 1)
                        tick_count <= tick_count + 1;
                    else begin
                        tick_count <= 0;
                        if (rx == 0)
                            state <= STATE_DATA;
                        else
                            state <= STATE_IDLE; // False start.
                    end
                end

                STATE_DATA: begin
                    if (tick_count < BIT_TICK - 1)
                        tick_count <= tick_count + 1;
                    else begin
                        tick_count <= 0;
                        rx_shift[bit_index] <= rx; // Sample data bit.
                        if (bit_index < 7)
                            bit_index <= bit_index + 1;
                        else begin
                            bit_index <= 0;
                            state <= STATE_STOP;
                        end
                    end
                end

                STATE_STOP: begin
                    if (tick_count < BIT_TICK - 1)
                        tick_count <= tick_count + 1;
                    else begin
                        tick_count <= 0;
                        // Optionally, verify rx is high for a valid stop bit.
                        data  <= rx_shift;
                        valid <= 1;
                        state <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
