module multi_16bit (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] ain,
    input wire [15:0] bin,
    output reg [31:0] yout,
    output reg done
);

reg [4:0] i;  // Shift count register
reg [15:0] areg;  // Multiplicand register
reg [15:0] breg;  // Multiplier register
reg [31:0] yout_r;  // Product register
reg done_r;  // Internal completion flag

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset conditions
        i <= 5'b0;
        areg <= 16'b0;
        breg <= 16'b0;
        yout_r <= 32'b0;
        done_r <= 1'b0;
        yout <= 32'b0;
    end else begin
        if (start) begin
            // Start of multiplication operation
            if (i == 5'b0) begin
                areg <= ain;
                breg <= bin;
            end
            if (i < 5'b17) begin
                if (areg[i-1] == 1'b1) begin
                    yout_r <= yout_r + (breg << i);
                end
                i <= i + 1;
            end else begin
                // Multiplication complete
                done_r <= 1'b1;
            end
        end else begin
            // Reset shift count and completion flag when start is inactive
            i <= 5'b0;
            done_r <= 1'b0;
        end
    end
end

assign yout = yout_r;  // Assign product register to output
assign done = done_r;  // Assign internal completion flag to output

endmodule
