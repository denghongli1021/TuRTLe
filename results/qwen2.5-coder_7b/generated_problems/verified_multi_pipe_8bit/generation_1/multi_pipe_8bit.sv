module multi_pipe_8bit (
    input wire clk,          // Clock signal used for synchronous operation.
    input wire rst_n,        // Active-low reset signal. Defined as 0 for chip reset and 1 for reset signal inactive.
    input wire mul_en_in,    // Input enable signal that controls the multiplication operation.
    input wire [7:0] mul_a,   // Input signal representing the multiplicand with a data width of 8 bits.
    input wire [7:0] mul_b,   // Input signal representing the multiplier with a data width of 8 bits.

    output reg mul_en_out,   // Output enable signal indicating if the multiplication operation is enabled.
    output reg [15:0] mul_out // Product output signal with a data width of 16 bits
);

// Internal registers for input values
reg [7:0] mul_a_reg;
reg [7:0] mul_b_reg;

// Internal registers for partial products and sums
wire [15:0] temp [0:7];
reg [15:0] sum [0:3];

// Internal register to store the final product
reg [15:0] mul_out_reg;

// Pipeline stages

// Stage 1: Input Control and Register Update
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mul_en_out_reg <= 8'b0;
        mul_a_reg <= 8'b0;
        mul_b_reg <= 8'b0;
    end else begin
        mul_en_out_reg <= mul_en_in;
        if (mul_en_in) begin
            mul_a_reg <= mul_a;
            mul_b_reg <= mul_b;
        end
    end
end

// Stage 2: Partial Product Generation
assign temp[0] = mul_a_reg * mul_b_reg[0];
assign temp[1] = mul_a_reg * mul_b_reg[1];
assign temp[2] = mul_a_reg * mul_b_reg[2];
assign temp[3] = mul_a_reg * mul_b_reg[3];
assign temp[4] = mul_a_reg * mul_b_reg[4];
assign temp[5] = mul_a_reg * mul_b_reg[5];
assign temp[6] = mul_a_reg * mul_b_reg[6
