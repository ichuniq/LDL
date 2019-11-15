`timescale 1ns/100ps
`define INITIAL 5'b00001
`define DEPOSIT 5'b00010
`define BUY     5'b00100
`define CHANGE  5'b01000

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

    wire db_5, db_10, db_cancel, db_drink_A, db_drink_B;
    debounce d_5 (db_5, money_5, clk_div_16);
    debounce d_10 (db_10, money_10, clk_div_16);
    debounce d_cnl (db_cancel, cancel, clk_div_16);
    debounce d_A (db_drink_A, drink_A, clk_div_16);
    debounce d_B (db_drink_B, drink_B, clk_div_16);

    wire op_money_5, op_money_10, op_cancel, op_drink_A, op_drink_B;
    one_pulse o_5 (rst, clk_div_16, db_5, op_money_5);
    one_pulse o_10 (rst, clk_div_16, db_10, op_money_10);
    one_pulse o_cnl (rst, clk_div_16, db_cancel, op_cancel);
    one_pulse o_A (rst, clk_div_16, db_drink_A, op_drink_A);
    one_pulse o_B (rst, clk_div_16, db_drink_B, op_drink_B);

    wire [3:0] BCD0, BCD1, BCD2, BCD3;
    reg [4:0] state, next_state;
    // max value = 95, use 8-bit reg
    reg [7:0] cost, balance;  // balance: money that has been deposited so far
    reg [7:0] next_cost, next_balance;
    reg flag_A, flag_B, next_flag_A, next_flag_B;
    wire idle;
    reg start_idle;

    wire clk_select;
    assign clk_select = (state > `DEPOSIT)? clk_div_26 : clk_div_16;
    // FSM
    always @ (posedge clk_select or posedge rst) begin
        if (rst) begin
            state <= `INITIAL;
            cost <= 8'd0;
            balance <= 8'd0;
            flag_A <= 1'b0;
            flag_B <= 1'b0;
        end else begin
            state <= next_state;
            cost <= next_cost;
            balance <= next_balance;
            flag_A <= next_flag_A;
            flag_B <= next_flag_B;
        end
    end

    always @ ( * ) begin
        next_state = state;
        next_cost = cost;
        next_balance = balance;
        next_flag_A = flag_A;
        next_flag_B = flag_B;
        enough_A = 1'b0;
        enough_B = 1'b0;
        drop_money = 10'b0;
        start_idle = 1'b0;
        case (state)
            `INITIAL: begin
                next_cost = 8'd0;
                next_balance = 8'd0;
                next_flag_A = 1'b0;
                next_flag_B = 1'b0;
                next_state = `DEPOSIT;
            end
            `DEPOSIT: begin
                if (op_cancel || idle) begin
                    next_state = `CHANGE;
                    next_cost = 8'd0;
                end else begin
                    next_state = `DEPOSIT;
                    enough_A = (balance >= 8'd20)? 1:0;
                    enough_B = (balance >= 8'd25)? 1:0;
                    if (op_money_5) begin
                        next_balance = (balance + 8'd5 >= 8'd95)? 8'd95 : balance + 8'd5;
                    end else if (op_money_10) begin
                        next_balance = (balance + 8'd10 >= 8'd95)? 8'd95 : balance + 8'd10;
                    end else if (op_drink_A) begin
                        // if push the same drink second time, go to BUY state
                        if ((cost==8'd20) && (balance >= cost)) begin
                            next_cost = 8'd0;
                            next_balance = balance - cost;
                            next_flag_A = 1'b1;
                            next_state = `BUY;
                        end else begin
                            next_cost = 8'd20;
                        end
                    end else if (op_drink_B) begin
                        if ((cost==8'd25) && (balance >= cost)) begin
                            next_cost = 8'd0;
                            next_balance = balance - cost;
                            next_flag_B = 1'b1;
                            next_state = `BUY;
                        end else begin
                            next_cost = 8'd25;
                        end
                    end else begin
                        start_idle = 1'b1;
                    end
                end
            end
            `BUY: begin
                // show drink's name for one cycle
                enough_A = 1'b0;
                enough_B = 1'b0;
                next_state = `CHANGE;
            end
            `CHANGE: begin
                if (balance == 8'd0) begin
                    drop_money = 10'b0;
                    next_state = `INITIAL;
                end else begin
                    next_state = `CHANGE;
                    if (balance == 8'd5) begin
                        next_balance = 8'd0;
                        drop_money = 10'b0000011111;
                    end else  begin
                        next_balance = balance - 8'd10;
                        drop_money = 10'b1111111111;
                    end
                end
            end

        endcase
    end

    assign BCD3 = (state==`BUY && flag_A)? 4'd10: (state==`BUY && flag_B)? 4'd11 : cost/10;
    assign BCD2 = (state==`BUY && flag_A)? 4'd10: (state==`BUY && flag_B)? 4'd11 : cost%10;
    assign BCD1 = (state==`BUY && flag_A)? 4'd10: (state==`BUY && flag_B)? 4'd11 : balance/10;
    assign BCD0 = (state==`BUY && flag_A)? 4'd10: (state==`BUY && flag_B)? 4'd11 : balance%10;

    seven_segment s1 (clk_div_13, rst, BCD0, BCD1, BCD2, BCD3, DIGIT, DISPLAY);

    // Trigger idle when no action for 5-10s
    reg [14-1:0] num;
    wire [14-1:0] next_num;
    always @ (posedge clk_div_16 or posedge rst) begin
        if (rst)
            num <= 14'd0;
        else
            num <= next_num;
    end
    assign next_num = (start_idle)? num + 1 : 14'd0;
    assign idle = num[14-1];

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

module seven_segment(clk, reset, BCD0, BCD1, BCD2, BCD3, DIGIT, DISPLAY);
    input clk, reset;
    input [3:0] BCD0, BCD1, BCD2, BCD3;
    output reg [3:0] DIGIT;
    output reg [6:0] DISPLAY;
    reg [3:0] value;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            value = 4'd0;
            DIGIT = 4'b0;
        end
        else begin
            case (DIGIT)
                4'b1110: begin
                    value = BCD1;
                    DIGIT = 4'b1101;
                end
                4'b1101: begin
                    value = BCD2;
                    DIGIT = 4'b1011;
                end
                4'b1011: begin
                    value = BCD3;
                    DIGIT = 4'b0111;
                end
                4'b0111: begin
                    value = BCD0;
                    DIGIT = 4'b1110;
                end
                default: begin
                    value = BCD0;
                    DIGIT = 4'b1110;
                end
          endcase
        end
    end

    always @(* )begin
        case (value)
            4'd0: DISPLAY = 7'b0000001;
            4'd1: DISPLAY = 7'b1001111;
            4'd2: DISPLAY = 7'b0010010;
            4'd3: DISPLAY = 7'b0000110;
            4'd4: DISPLAY = 7'b1001100;
            4'd5: DISPLAY = 7'b0100100;
            4'd6: DISPLAY = 7'b0100000;
            4'd7: DISPLAY = 7'b0001111;
            4'd8: DISPLAY = 7'b0000000;
            4'd9: DISPLAY = 7'b0000100;
            4'd10: DISPLAY = 7'b0000010; //a
            4'd11: DISPLAY = 7'b1100000; //b
            default: DISPLAY = 7'b0000100;
        endcase
   end
endmodule
