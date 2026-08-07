module calendar (
    input CLK,
    input RST,
    output reg [5:0] Hours,
    output reg [5:0] Mins,
    output reg [5:0] Secs
);

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        // Reset all values to 0 when reset is active
        Secs <= 6'd0;
        Mins <= 6'd0;
        Hours <= 6'd0;
    end else begin
        // Update seconds
        if (Secs == 6'd59) begin
            Secs <= 6'd0;
        end else begin
            Secs <= Secs + 1;
        end

        // Update minutes based on seconds
        if (Secs == 6'd59) begin
            if (Mins == 6'd59) begin
                Mins <= 6'd0;
            end else begin
                Mins <= Mins + 1;
            end
        end

        // Update hours based on minutes and seconds
        if (Secs == 6'd59 && Mins == 6'd59) begin
            if (Hours == 6'd23) begin
                Hours <= 6'd0;
            end else begin
                Hours <= Hours + 1;
            end
        end
    end
end

endmodule
