module freq_div (
    input CLK_in,
    input RST,
    output reg CLK_50,
    output reg CLK_10,
    output reg CLK_1
);

reg [2:0] cnt_50;
reg [3:0] cnt_10;
reg [6:0] cnt_100;

always @(posedge CLK_in or posedge RST) begin
    if (RST) begin
        CLK_50 <= 0;
        CLK_10 <= 0;
        CLK_1 <= 0;
        cnt_50 <= 3'b000;
        cnt_10 <= 4'b0000;
        cnt_100 <= 7'b0000000;
    end else begin
        // CLK_50 generation
        if (cnt_50 == 3'b000) begin
            CLK_50 <= ~CLK_50;
        end
        cnt_50 <= cnt_50 + 1;

        // CLK_10 generation
        if (cnt_10 == 4'b0000) begin
            CLK_10 <= ~CLK_10;
        end
        cnt_10 <= cnt_10 + 1;

        // CLK_1 generation
        if (cnt_100 == 7'b0000000) begin
            CLK_1 <= ~CLK_1;
        end
        cnt_100 <= cnt_100 + 1;
    end
end

endmodule
