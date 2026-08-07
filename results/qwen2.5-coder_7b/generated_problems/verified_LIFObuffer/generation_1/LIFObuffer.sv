module LIFObuffer (
    input wire [3:0] dataIn,     // 4-bit input data to be pushed onto the buffer
    input wire RW,               // Read/Write control signal (1 for read, 0 for write)
    input wire EN,               // Enable signal to activate buffer operations
    input wire Rst,              // Active high reset signal to initialize the buffer
    input wire Clk,              // Clock signal for synchronous operations

    output reg EMPTY,            // Flag indicating whether the buffer is empty
    output reg FULL,             // Flag indicating whether the buffer is full
    output reg [3:0] dataOut     // 4-bit output data retrieved from the buffer
);

    parameter DEPTH = 4;          // Depth of the buffer (number of entries)
    reg [3:0] stack_mem [0:DEPTH-1];  // Stack memory array to store the data
    reg [1:0] SP;                 // Stack pointer tracking the current position in the stack

    always @(posedge Clk or posedge Rst) begin
        if (Rst) begin
            // Reset the buffer
            SP <= DEPTH;
            EMPTY <= 1;
            FULL <= 0;
            dataOut <= 4'b0000;
            for (integer i = 0; i < DEPTH; i = i + 1)
                stack_mem[i] <= 4'b0000;
        end else if (EN) begin
            // Buffer operations are enabled
            if (!FULL && RW == 0) begin
                // Write operation and buffer is not full
                stack_mem[SP-1] <= dataIn;
                SP <= SP - 1;
                FULL <= (SP == 0);
                EMPTY <= (SP == DEPTH);
            end else if (!EMPTY && RW == 1) begin
                // Read operation and buffer is not empty
                dataOut <= stack_mem[SP];
                stack_mem[SP] <= 4'b0000;
                SP <= SP + 1;
                FULL <= (SP == DEPTH);
                EMPTY <= (SP == DEPTH);
            end else begin
                // Buffer
