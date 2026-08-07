module sequence_detector (
    input wire clk,          // Clock signal
    input wire rst_n,        // Active-low reset signal
    input wire data_in,      // 1-bit binary input signal
    output reg sequence_detected  // 1-bit output signal indicating sequence detection
);

// Define states
typedef enum reg [2:0] {
    IDLE,
    S1,
    S2,
    S3,
    S4
} state_t;

state_t current_state, next_state;  // Current and next state of the FSM

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
        sequence_detected <= 0;
    end else begin
        current_state <= next_state;
        if (current_state == S4)
            sequence_detected <= 1;
        else
            sequence_detected <= 0;
    end
end

always @(*) begin
    // Default state transition and output assignment
    next_state = IDLE;
    case (current_state)
        IDLE:
            if (data_in == 1'b1) begin
                next_state = S1;
            end
        S1:
            if (data_in == 1'b0) begin
                next_state = S2;
            end else begin
                next_state = IDLE;
            end
        S2:
            if (data_in == 1'b0) begin
                next_state = S3;
            end else begin
                next_state = IDLE;
            end
        S3:
            if (data_in == 1'b1) begin
                next_state = S4;
            end else begin
                next_state = IDLE;
            end
        S4:
            // Stay in S4 until reset
            ;
    endcase
end

endmodule
