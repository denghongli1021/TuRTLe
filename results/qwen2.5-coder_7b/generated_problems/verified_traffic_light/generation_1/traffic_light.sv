module traffic_light (
    input wire rst_n,          // Reset signal (active low)
    input wire clk,            // Clock signal
    input wire pass_request,   // Request signal for allowing vehicles to pass

    output reg [7:0] clock,     // 8-bit output representing the count value of the internal counter
    output reg red,            // Output signal representing the state of the traffic light (red)
    output reg yellow,         // Output signal representing the state of the traffic light (yellow)
    output reg green           // Output signal representing the state of the traffic light (green)
);

// State definitions
parameter idle = 2'b00,
          s1_red = 2'b01,
          s2_yellow = 2'b10,
          s3_green = 2'b11;

// Registers and Wires
reg [7:0] cnt;               // Internal counter for timing purposes
reg [1:0] state;             // Current state of the traffic light controller
reg p_red, p_yellow, p_green; // Previous values for the red, yellow, and green signals

// State transition logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= idle;
        cnt <= 8'd10;
        red <= 1'b0;
        yellow <= 1'b0;
        green <= 1'b0;
    end else begin
        case (state)
            idle: begin
                state <= s1_red;
                cnt <= 8'd3;
            end
            s1_red: begin
                if (cnt == 0) begin
                    state <= s3_green;
                    cnt <= 8'd60;
                end else begin
                    cnt <= cnt - 1;
                end
            end
            s2_yellow: begin
                if (cnt == 0) begin
                    state <= s1_red;
                    cnt <= 8'd3;
                end else begin
                    cnt <= cnt - 1;
                end
            end
            s3_green: begin
                if (pass_request && green) begin
                    cnt <= 8'd10;
                end else if (!green && p_green) begin
                    cnt <= 8'd60;
                end else if (!yellow && p_yellow
