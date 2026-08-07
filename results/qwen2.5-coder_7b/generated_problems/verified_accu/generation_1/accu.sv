module accu (
    input wire clk,
    input wire rst_n,
    input wire [7:0] data_in,
    input wire valid_in,
    output reg valid_out,
    output reg [9:0] data_out
);

reg [3:0] count;  // Counter to track the number of valid inputs received
reg [9:0] sum;   // Register to store the accumulated sum

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        count <= 4'b0;
        sum <= 10'b0;
        valid_out <= 1'b0;
        data_out <= 10'b0;
    end else begin
        if (valid_in) begin
            sum <= sum + data_in;  // Add the new data to the sum
            count <= count + 1;     // Increment the counter

            if (count == 4'b100) begin  // If 4 valid inputs have been received
                valid_out <= 1'b1;      // Set valid_out to 1
                data_out <= sum;         // Output the accumulated sum
                count <= 4'b0;           // Reset the counter
            end else begin
                valid_out <= 1'b0;      // Keep valid_out at 0
                data_out <= 10'b0;     // No output until 4 inputs are received
            end
        end else begin
            if (count == 4'b100) begin  // If 4 valid inputs have been received but no new input
                valid_out <= 1'b1;      // Set valid_out to 1 for one cycle
                data_out <= sum;         // Output the accumulated sum
                count <= 4'b0;           // Reset the counter
            end else begin
                valid_out <= 1'b0;      // Keep valid_out at 0
                data_out <= 10'b0;     // No output until 4 inputs are received
            end
        end
    end
end

endmodule
