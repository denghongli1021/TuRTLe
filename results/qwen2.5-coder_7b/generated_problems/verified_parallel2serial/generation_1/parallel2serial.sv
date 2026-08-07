module parallel2serial (
    input wire clk,
    input wire rst_n,
    input wire [3:0] d,
    output reg valid_out,
    output reg dout
);

// Internal registers and signals
reg [1:0] cnt;  // Counter to track the bit position
reg [3:0] data; // Register to hold the parallel data

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset case
        valid_out <= 0;
        dout <= 0;
        cnt <= 2'b00;
        data <= 4'b0000;
    end else begin
        // Normal operation
        if (cnt == 2'b11) begin
            // Last bit processed, update data and reset counter
            data <= d;
            cnt <= 2'b00;
            valid_out <= 1;
        end else begin
            // Shift data left and increment counter
            dout <= data[3];
            data <= {data[2:0], 1'b0};
            cnt <= cnt + 1;
            valid_out <= 0;
        end
    end
end

endmodule
