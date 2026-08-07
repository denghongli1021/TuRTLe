module signal_generator (
    input wire clk,          // Clock signal used for synchronous operation
    input wire rst_n,        // Active-low reset signal (0 for reset, 1 for active)
    output reg [4:0] wave   // 5-bit output waveform signal representing the generated waveform
);

// Internal state register to control the state of the waveform generation
reg [1:0] state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset condition
        state <= 2'b00;
        wave <= 5'd0;
    end else begin
        // Normal operation
        case (state)
            2'b00: begin
                // Increment the waveform and transition to state 1 when it reaches 31
                if (wave == 5'd31) begin
                    state <= 2'b01;
                end else begin
                    wave <= wave + 1;
                end
            end
            2'b01: begin
                // Decrement the waveform and transition back to state 0 when it reaches 0
                if (wave == 5'd0) begin
                    state <= 2'b00;
                end else begin
                    wave <= wave - 1;
                end
            end
        endcase
    end
end

endmodule
