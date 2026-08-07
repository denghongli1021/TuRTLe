module adder_pipe_64bit (
    input wire clk,
    input wire rst_n,
    input wire i_en,
    input wire [63:0] adda,
    input wire [63:0] addb,
    output reg [65:0] result,
    output reg o_en
);

// Internal signals for pipeline stages
reg [63:0] sum_a;
reg [63:0] sum_b;
reg [64:0] carry_out;

// Pipeline registers
reg [63:0] adda_reg;
reg [63:0] addb_reg;
reg [64:0] carry_out_reg;
reg o_en_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers to zero
        sum_a <= 64'b0;
        sum_b <= 64'b0;
        carry_out <= 65'b0;
        adda_reg <= 64'b0;
        addb_reg <= 64'b0;
        carry_out_reg <= 65'b0;
        o_en_reg <= 1'b0;
    end else begin
        if (i_en) begin
            // Stage 1: Load inputs into registers
            adda_reg <= adda;
            addb_reg <= addb;

            // Stage 2: Perform addition and calculate carry
            sum_a <= adda_reg + addb_reg[63:0];
            sum_b <= adda_reg + addb_reg[64:1] + (sum_a[63] ? 1'b1 : 1'b0);
            carry_out <= sum_b[64] ? 1'b1 : 1'b0;

            // Stage 3: Output the result and enable signal
            result <= {carry_out, sum_b};
            o_en_reg <= 1'b1;
        end else begin
            // If i_en is not asserted, hold the output and disable it
            result <= {carry_out_reg, sum_b_reg};
            o_en_reg
