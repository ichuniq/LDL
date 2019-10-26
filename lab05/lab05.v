`timescale 1ns/100ps

module lab05(clk, rst, money_5, money_10, cancel, drink_A, drink_B, drop_money, enough_A, enough_B, DIGIT, DISPLAY);
    input clk;
    input rst;
    input money_5;
    input money_10;
    input cancel;
    input drink_A;
    input drink_B;
    output reg[9:0] drop_money;
    output reg enough_A;
    output reg enough_B;
    output [3:0] DIGIT;
    output [6:0] DISPLAY;

    wire clk_div_13, clk_div_16, clk_div_26;
    clock_divider #(.n(13)) c1 (.clk(clk), .clk_div(clk_div_13));
    clock_divider #(.n(16)) c2 (.clk(clk), .clk_div(clk_div_16));
    clock_divider #(.n(26)) c3 (.clk(clk), .clk_div(clk_div_26));

    wire db_reset, db_5, db_10, db_cancel, db_drinkA, db_drinkB;
    debounce d_rst (db_reset, reset, clk_div_16);
    debounce d_5 (db_5, money_5, clk_div_16);
    debounce d_10 (db_10, money_10, clk_div_16);
    debounce d_cnl (db_cancel, cancel, clk_div_16);
    debounce d_A (db_drink_A, drink_A, clk_div_16);
    debounce d_B (db_drink_B, drink_B, clk_div_16);

    wire op_5, op_10;
    one_pulse o_5 (db_reset, clk_div_16, db_5, op_5);
    one_pulse o_10 (db_reset, clk_div_16, db_10, op_10);


endmodule

module clock_divider(clk, clk_div);
    parameter n = 26;
    input clk;
    output clk_div;

    reg [n-1:0] num;
    wire [n-1:0] next_num;

    always @(posedge clk) begin
        num <= next_num;
    end

    assign next_num = num + 1'b1;
    assign clk_div = num[n-1];

endmodule

module debounce (pb_debounced, pb, clk);
    output pb_debounced; // output after being debounced
    input pb; // input from a pushbutton
    input clk;
    reg [3:0] shift_reg; // use shift_reg to filter the bounce

    always @(posedge clk) begin
        shift_reg[3:1] <= shift_reg[2:0];
      	shift_reg[0] <= pb;
    end

    assign pb_debounced = ((shift_reg == 4'b1111) ? 1'b1 : 1'b0);

endmodule

module one_pulse (
    input wire rst,
    input wire clk,
    input wire pb_debounced,
    output reg pb_1pulse
);
    // internal registers
    reg pb_1pulse_next;
    reg pb_debounced_delay;

    always @* begin
        pb_1pulse_next = pb_debounced & ~pb_debounced_delay;
    end

    always @(posedge clk, posedge rst) begin
        if (rst == 1'b1) begin
            pb_1pulse = 1'b0;
            pb_debounced_delay = 1'b0;
        end else begin
            pb_1pulse = pb_1pulse_next;
            pb_debounced_delay = pb_debounced;
        end
    end

endmodule
