module pulse_detect (
    input wire clk,          // Clock signal
    input wire rst_n,        // Active low reset signal
    input wire data_in,      // 1-bit input signal
    output reg data_out      // Output signal indicating the presence of pulses
);

// State definition for pulse detection
typedef enum reg [2:0] {
    IDLE,
    RISING,
    FALLING,
    PULSE_END
} state_t;

state_t current_state, next_state;  // Current and next state registers

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
        data_out <= 0;
    end else begin
        current_state <= next_state;
        case (current_state)
            IDLE: begin
                if (data_in == 1'b1) begin
                    next_state <= RISING;
                end else begin
                    next_state <= IDLE;
                end
                data_out <= 0;
            end

            RISING: begin
                if (data_in == 1'b0) begin
                    next_state <= FALLING;
                end else begin
                    next_state <= RISING;
                end
                data_out <= 0;
            end

            FALLING: begin
                if (data_in == 1'b0) begin
                    next_state <= FALLING;
                end else begin
                    next_state <= PULSE_END;
                end
                data_out <= 0;
            end

            PULSE_END: begin
                if (data_in == 1'b0) begin
                    next_state <= IDLE;
                end else begin
                    next_state <= PULSE_END;
                end
                data_out <= 1;
            end

            default: begin
                current_state <= IDLE;
                data_out <= 0;
            end
        endcase
    end
end

endmodule
