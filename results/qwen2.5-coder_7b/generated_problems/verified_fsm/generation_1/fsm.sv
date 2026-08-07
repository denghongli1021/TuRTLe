module fsm (
    input wire IN,
    input wire CLK,
    input wire RST,
    output reg MATCH
);

// Define states
localparam IDLE = 3'b000;
localparam S1   = 3'b001;
localparam S2   = 3'b010;
localparam S3   = 3'b011;
localparam S4   = 3'b100;

// Current state
reg [2:0] currentState, nextState;

// Internal signals to track the sequence detection
reg [1:0] seqCounter;

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        currentState <= IDLE;
        MATCH <= 0;
        seqCounter <= 2'b00;
    end else begin
        currentState <= nextState;
        case (currentState)
            IDLE: begin
                if (IN == 1'b1) begin
                    nextState <= S1;
                    seqCounter <= 2'b00;
                end else begin
                    nextState <= IDLE;
                    MATCH <= 0;
                end
            end
            S1: begin
                if (IN == 1'b0) begin
                    nextState <= S2;
                    seqCounter <= 2'b01;
                end else begin
                    nextState <= IDLE;
                    MATCH <= 0;
                end
            end
            S2: begin
                if (IN == 1'b0) begin
                    nextState <= S3;
                    seqCounter <= 2'b10;
                end else begin
                    nextState <= IDLE;
                    MATCH <= 0;
                end
            end
            S3: begin
                if (IN == 1'b1) begin
                    nextState <= S4;
                    seqCounter <= 2'b11;
                end else begin
                    nextState <= IDLE;
                    MATCH <= 0;
                end
            end
            S4: begin
                if (IN == 1'b1) begin
                    nextState <= IDLE;
                    MATCH <= 1;
                end else begin
