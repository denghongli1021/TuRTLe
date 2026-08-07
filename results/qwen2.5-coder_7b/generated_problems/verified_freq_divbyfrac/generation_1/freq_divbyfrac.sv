module freq_divbyfrac (
    input wire clk,          // Input clock signal
    input wire rst_n,        // Active low reset signal to initialize the module
    output reg clk_div       // Fractionally divided clock output
);

    parameter MUL2_DIV_CLK = 7;  // Number of cycles for fractional division (3.5x)
    reg [2:0] counter;          // Counter to count clock cycles
    reg [1:0] phase_shift;      // Phase shift register

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 3'b000;
            phase_shift <= 2'b00;
            clk_div <= 1'b0;
        end else begin
            case (counter)
                3'b000: begin
                    // First cycle with 4 source clock cycles
                    clk_div <= 1'b1;
                    counter <= 3'b001;
                end
                3'b001, 3'b010, 3'b011: begin
                    // Second cycle with 3 source clock cycles
                    clk_div <= 1'b0;
                    counter <= counter + 1;
                end
                3'b100: begin
                    // Phase shift for the next cycle
                    phase_shift <= phase_shift + 1;
                    counter <= 3'b000;
                end
                default: begin
                    counter <= 3'b000;
                end
            endcase

            if (phase_shift == 2'b00) begin
                // No phase shift
                clk_div <= ~clk_div;
            end else if (phase_shift == 2'b01) begin
                // Delayed by half a clock period
                clk_div <= #5 ~clk_div;  // Adjust the delay as needed
            end else if (phase_shift == 2'b10) begin
                // Advanced by half a clock period
                clk_div <= #5 clk_div;   // Adjust the delay as needed
            end
        end
    end

endmodule
