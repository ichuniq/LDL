module lab07_1 (
    input wire clk,
    input wire rst,
    input wire en,
    input wire dir,
    output wire [3:0] vgaRed,
    output wire [3:0] vgaGreen,
    output wire [3:0] vgaBlue,
    output wire hsync,
    output wire vsync
    );

    wire [11:0] data;
    wire [16:0] pixel_addr;
    wire [11:0] pixel;
    wire valid;
    wire [9:0] h_cnt; // 640
    wire [9:0] v_cnt; // 480

    assign {vgaRed, vgaGreen, vgaBlue} = (valid==1'b1) ? pixel:12'h0;

    wire clk_25MHz, clk_div_16, clk_div_22;
    clock_divider #(.n(2)) c1 (.clk(clk), .clk_div(clk_25MHz)); //clk/2^2 = 25MHz
    clock_divider #(.n(16)) c2 (.clk(clk), .clk_div(clk_div_16));
    clock_divider #(.n(22)) c3 (.clk(clk), .clk_div(clk_div_22));

    wire db_rst;
    debounce d1 (db_rst, rst, clk_div_16);

    mem_addr_gen mem_addr_gen_inst(
     .clk(clk_div_22),
     .rst(db_rst),
     .en(en),
     .dir(dir),
     .h_cnt(h_cnt),
     .v_cnt(v_cnt),
     .pixel_addr(pixel_addr)
    );

    blk_mem_gen_0 blk_mem_gen_0_inst(
     .clka(clk_25MHz),
     .wea(0),
     .addra(pixel_addr),
     .dina(data[11:0]),
     .douta(pixel)
   );

    vga_controller  vga_inst(
      .pclk(clk_25MHz),
      .reset(db_rst),
      .hsync(hsync),
      .vsync(vsync),
      .valid(valid),
      .h_cnt(h_cnt),
      .v_cnt(v_cnt)
    );

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

module mem_addr_gen(
   input clk,
   input rst,
   input en,
   input dir,
   input [9:0] h_cnt,
   input [9:0] v_cnt,
   output [16:0] pixel_addr
   );

   reg [8:0] position;

   // input image is 320x240, but display is 640x480
   assign pixel_addr = ( ((h_cnt>>1) + position)%320 + 320*(v_cnt>>1)) % 76800;  //640*480 --> 320*240

   always @ (posedge clk or posedge rst) begin
       if (rst)
           position <= 0;
       else if (en == 1'b1) begin
           if (dir == 0) begin
               if (position < 9'd319)  // scroll the image to left
                   position <= position + 1;
               else
                   position <= 0;
           end else begin
               if (position > 0)
                   position <= position - 1;
               else
                   position <= 9'd319;
           end
       end else begin  // en==0, pause
           position <= position;
       end
   end

endmodule


module vga_controller (
    input wire pclk, reset,
    output wire hsync, vsync, valid,
    output wire [9:0] h_cnt,
    output wire [9:0] v_cnt
    );

    reg [9:0] pixel_cnt;
    reg [9:0] line_cnt;
    reg hsync_i, vsync_i;

    parameter HD = 640;
    parameter HF = 16;
    parameter HS = 96;
    parameter HB = 48;
    parameter HT = 800;
    parameter VD = 480;
    parameter VF = 10;
    parameter VS = 2;
    parameter VB = 33;
    parameter VT = 525;
    parameter hsync_default = 1'b1;
    parameter vsync_default = 1'b1;

    always @(posedge pclk)
        if (reset)
            pixel_cnt <= 0;
        else
            if (pixel_cnt < (HT - 1))
                pixel_cnt <= pixel_cnt + 1;
            else
                pixel_cnt <= 0;

    always @(posedge pclk)
        if (reset)
            hsync_i <= hsync_default;
        else
            if ((pixel_cnt >= (HD + HF - 1)) && (pixel_cnt < (HD + HF + HS - 1)))
                hsync_i <= ~hsync_default;
            else
                hsync_i <= hsync_default;

    always @(posedge pclk)
        if (reset)
            line_cnt <= 0;
        else
            if (pixel_cnt == (HT -1))
                if (line_cnt < (VT - 1))
                    line_cnt <= line_cnt + 1;
                else
                    line_cnt <= 0;

    always @(posedge pclk)
        if (reset)
            vsync_i <= vsync_default;
        else if ((line_cnt >= (VD + VF - 1)) && (line_cnt < (VD + VF + VS - 1)))
            vsync_i <= ~vsync_default;
        else
            vsync_i <= vsync_default;

    assign hsync = hsync_i;
    assign vsync = vsync_i;
    assign valid = ((pixel_cnt < HD) && (line_cnt < VD));

    assign h_cnt = (pixel_cnt < HD) ? pixel_cnt : 10'd0;
    assign v_cnt = (line_cnt < VD) ? line_cnt : 10'd0;

endmodule
