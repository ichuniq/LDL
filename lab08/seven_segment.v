`timescale 1ns / 1ps


module seven_segment(clk, reset, BCD3, BCD2, BCD1, BCD0, DIGIT, DISPLAY);
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
            4'd10: DISPLAY = 7'b1111110; // '-'
            default: DISPLAY = 7'b0000100;
        endcase
   end
endmodule
