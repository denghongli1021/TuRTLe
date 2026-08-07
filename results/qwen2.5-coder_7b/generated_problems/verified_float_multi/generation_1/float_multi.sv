module float_multi (
    input wire clk,
    input wire rst,
    input wire [31:0] a,
    input wire [31:0] b,
    output reg [31:0] z
);

// Internal signals
reg [2:0] counter;
reg [23:0] a_mantissa, b_mantissa, z_mantissa;
reg [9:0] a_exponent, b_exponent, z_exponent;
reg a_sign, b_sign, z_sign;
reg [49:0] product;
reg guard_bit, round_bit, sticky;

// Function to extract sign, exponent, and mantissa from a floating-point number
function [31:0] extract_parts;
    input [31:0] float_num;
    begin
        extract_parts[31] = float_num[31]; // Sign bit
        extract_parts[30:23] = float_num[30:23]; // Exponent bits
        extract_parts[22:0] = float_num[22:0]; // Mantissa bits
    end
endfunction

// Function to normalize the mantissa and adjust the exponent
function [49:0] normalize;
    input reg [23:0] mantissa;
    input reg [9:0] exponent;
    begin
        if (mantissa[22]) begin // If the most significant bit is 1, no normalization needed
            normalize = {mantissa, 26'b0};
        end else begin // Normalize by shifting left until the most significant bit becomes 1
            integer shift_count;
            for (shift_count = 0; shift_count < 23; shift_count = shift_count + 1) begin
                if (mantissa[22 - shift_count]) begin
                    normalize = {1'b0, mantissa << shift_count};
                    exponent = exponent - shift_count;
                    break;
                end
            end
        end
    end
endfunction

// Function to handle special cases like NaN and infinity
function [31:0] handle_special_cases;
    input reg [23:0] a_mantissa, b_mantissa;
    input reg [9:0] a
