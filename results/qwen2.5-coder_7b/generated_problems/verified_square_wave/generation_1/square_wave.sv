module square_wave (
    input wire clk,          // Clock signal that drives the module
    input wire [7:0] freq,   // Frequency control, specifying how often the square wave toggles
    output reg wave_out      // Square wave output signal
);

reg [7:0] count;  // Counter register used to track cycles between wave toggles

always @(posedge clk) begin
    if (count == freq - 1) begin
        count <= 8'b0;       // Reset counter when it reaches (freq - 1)
        wave_out <= ~wave_out; // Toggle the square wave output signal
    end else begin
        count <= count + 1;   // Increment the counter on each clock cycle
    end
end

endmodule
