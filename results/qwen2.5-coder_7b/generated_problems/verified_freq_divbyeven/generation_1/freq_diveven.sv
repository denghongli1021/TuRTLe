module freq_diveven #(
    parameter NUM_DIV = 4 // Default division factor
)(
    input wire clk,        // Input clock signal
    input wire rst_n,      // Active-low reset signal
    output reg clk_div     // Divided clock output signal
);

// Counter to track the number of clock cycles
reg [1:0] cnt;          // 2-bit counter for even division

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset condition: initialize counter and divided clock signal
        cnt <= 2'b00;
        clk_div <= 1'b0;
    end else begin
        if (cnt < (NUM_DIV / 2 - 1)) begin
            // Increment counter without toggling output
            cnt <= cnt + 1;
        end else begin
            // Reset counter and toggle divided clock signal
            cnt <= 2'b00;
            clk_div <= ~clk_div;
        end
    end
end

endmodule
