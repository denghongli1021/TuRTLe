module serial2parallel (
    input wire clk,          // Clock signal
    input wire rst_n,        // Reset signal (active low)
    input wire din_serial,   // Serial input data
    input wire din_valid,    // Validity signal for input data

    output reg [7:0] dout_parallel,  // Parallel output data (8 bits wide)
    output reg dout_valid          // Validity signal for the output data
);

reg [2:0] cnt;  // Counter to keep track of received serial bits

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all outputs and counter
        dout_parallel <= 8'b0;
        dout_valid <= 1'b0;
        cnt <= 3'b0;
    end else begin
        if (din_valid && din_serial) begin
            // Shift the received bit into dout_parallel
            dout_parallel <= {dout_parallel[6:0], din_serial};
            
            // Increment the counter
            cnt <= cnt + 1;
            
            // Check if all 8 bits have been received
            if (cnt == 3'b111) begin
                dout_valid <= 1'b1;  // Set dout_valid to indicate valid output
            end else begin
                dout_valid <= 1'b0;  // Reset dout_valid for invalid output
            end
        end else begin
            // If no new data is received, keep dout_parallel and dout_valid unchanged
            dout_valid <= dout_valid;
        end
    end
end

endmodule
