module clkgenerator #(parameter PERIOD = 10) (
    output reg clk
);

reg [31:0] counter;

always @(posedge clk or posedge rst_n) begin
    if (!rst_n) begin
        clk <= 0;
        counter <= 0;
    end else begin
        if (counter == PERIOD - 1) begin
            clk <= ~clk; // Toggle the clock signal
            counter <= 0; // Reset the counter
        end else begin
            counter <= counter + 1; // Increment the counter
        end
    end
end

endmodule
