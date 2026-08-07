module synchronizer (
    input wire clk_a,          // Clock signal A
    input wire clk_b,          // Clock signal B
    input wire arstn,        // Active-low reset signal A
    input wire brstn,        // Active-low reset signal B
    input wire [3:0] data_in,  // Input data signal of size 4 bits
    input wire data_en,      // Input enable signal that controls the selection operation
    output reg [3:0] dataout   // Output data signal of size 4 bits
);

// Data Register
reg [3:0] data_reg;

always @(posedge clk_a or negedge arstn) begin
    if (!arstn) begin
        data_reg <= 4'b0;
    end else begin
        data_reg <= data_in;
    end
end

// Enable Data Register
reg en_data_reg;

always @(posedge clk_a or negedge arstn) begin
    if (!arstn) begin
        en_data_reg <= 1'b0;
    end else begin
        en_data_reg <= data_en;
    end
end

// Enable Control Registers
reg en_clap_one, en_clap_two;

always @(posedge clk_b or negedge brstn) begin
    if (!brstn) begin
        en_clap_one <= 1'b0;
        en_clap_two <= 1'b0;
    end else begin
        en_clap_one <= en_data_reg;
        en_clap_two <= en_clap_one;
    end
end

// Output Assignment
always @(posedge clk_b or negedge brstn) begin
    if (!brstn) begin
        dataout <= 4'b0;
    end else begin
        if (en_clap_two) begin
            dataout <= data_reg;
        end else begin
            // Retain previous value if en_clap_two is inactive
        end
    end
end

endmodule
