module width_8to16 (
    input wire clk,          // Clock signal
    input wire rst_n,        // Active-low reset signal
    input wire valid_in,     // Input signal indicating the validity of the input data
    input wire [7:0] data_in,// 8-bit input data to be converted

    output reg valid_out,    // Output signal indicating the validity of the output data
    output reg [15:0] data_out// 16-bit output data resulting from the width conversion
);

reg [7:0] data_lock;       // Register to store the first input data
reg flag;                  // Flag to indicate if the first valid data has been received

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_out <= 0;
        data_out <= 16'b0;
        data_lock <= 8'b0;
        flag <= 0;
    end else begin
        if (valid_in && !flag) begin
            // Store the first valid input data
            data_lock <= data_in;
            flag <= 1;
        end else if (valid_in && flag) begin
            // Concatenate the two inputs and output the result
            data_out <= {data_lock, data_in};
            valid_out <= 1;
            flag <= 0; // Reset the flag for next input
        end else begin
            // If no new data is received, keep outputs as they are
            valid_out <= 0;
        end
    end
end

endmodule
