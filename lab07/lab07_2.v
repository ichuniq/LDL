`define INITIAL 3'd1
`define SHIFT_LEFT   3'd2
`define SHIFT_DOWN  3'd3
`define SPLIT   3'd4

module lab07_2 (
    input wire clk,
    input wire rst,
    input wire shift,
    input wire split,
    output reg [3:0] vgaRed,
    output reg [3:0] vgaGreen,
    output reg [3:0] vgaBlue,
    output wire hsync,
    output wire vsync,
    output reg [4:0] led
    );

    wire [11:0] data;
    wire [16:0] pixel_addr;
    wire [11:0] pixel;
    wire valid;
    wire [2:0] state;
    wire [9:0] h_cnt; // 640
    wire [9:0] v_cnt; // 480

    wire clk_25MHz, clk_div_22;
    clock_divider #(.n(2)) c1 (.clk(clk), .clk_div(clk_25MHz)); //clk/2^2 = 25MHz
    clock_divider #(.n(22)) c3 (.clk(clk), .clk_div(clk_div_22));

    wire db_rst, db_shift, db_split;
    debounce d1 (db_rst, rst, clk_div_22);
    debounce d2 (db_shift, shift, clk_div_22);
    debounce d3 (db_split, split, clk_div_22);

    wire op_shift, op_split;
    one_pulse o1 (db_rst, clk_div_22, db_shift, op_shift);
    one_pulse o2 (db_rst, clk_div_22, db_split, op_split);

    wire [9:0] count;
    wire [9:0] count_h;

    always @ ( * ) begin
        led = 5'b0;
        if (!valid)
            {vgaRed, vgaGreen, vgaBlue} = 12'h0;
        else if (state == `INITIAL) begin
            led = 5'b11111;
            {vgaRed, vgaGreen, vgaBlue} = pixel;
        end else if (state==`SHIFT_LEFT) begin
            led = 5'b00010;
            if ((h_cnt>>1) < 320 - count)
                {vgaRed, vgaGreen, vgaBlue} = pixel;
            else
                {vgaRed, vgaGreen, vgaBlue} = 12'h0;
        end else if (state==`SHIFT_DOWN) begin
            led = 5'b00100;
            if ((v_cnt>>1) < count)
                {vgaRed, vgaGreen, vgaBlue} = pixel;
            else
                {vgaRed, vgaGreen, vgaBlue} = 12'h0;
        end else if (state==`SPLIT) begin
            led = 5'b01000;
            if ((v_cnt>>1 < 120 - count) && (h_cnt>>1  < 160))
                {vgaRed, vgaGreen, vgaBlue} = pixel;
            else if ((v_cnt>>1  < 120) && (h_cnt>>1 > 160 + count_h))
                {vgaRed, vgaGreen, vgaBlue} = pixel;
            else if ((v_cnt>>1  >= 120) && (h_cnt>>1  <= 160 - count_h))
                {vgaRed, vgaGreen, vgaBlue} = pixel;
            else if ((v_cnt>>1  > 120 + count) && (h_cnt>>1  >= 160))
                {vgaRed, vgaGreen, vgaBlue} = pixel;
            else
                {vgaRed, vgaGreen, vgaBlue} = 12'h0;
        end else
            {vgaRed, vgaGreen, vgaBlue} = 12'h0;
    end

    mem_addr_gen mem_addr_gen_inst(
     .clk(clk_div_22),
     .rst(db_rst),
     .shift(op_shift),
     .split(op_split),
     .h_cnt(h_cnt),
     .v_cnt(v_cnt),
     .count(count),
     .count_h(count_h),
     .state(state),
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


module mem_addr_gen(
    input clk,
    input rst,
    input shift,
    input split,
    input [9:0] h_cnt,
    input [9:0] v_cnt,
    output reg [9:0] count,
    output reg [9:0] count_h,
    output reg [2:0] state,
    output reg [16:0] pixel_addr
   );

   reg [2:0] next_state;
   reg [16:0] pixel_addr_temp;
   reg [9:0] count, count_h;
   reg [9:0] next_count, next_count_h;

   always @ (posedge clk or posedge rst) begin
       if (rst) begin
           state <= `INITIAL;
           count <= 10'b0;
           count_h <= 10'b0;
       end else begin
           state = next_state;
           count <= next_count;
           count_h <= next_count_h;
       end
    end

    always @ ( * ) begin
        next_state = state;
        next_count = count;
        next_count_h = count_h;
        case (state)
            `INITIAL: begin
                if (shift) begin
                    next_state = `SHIFT_LEFT;
                end else if (split) begin
                    next_state = `SPLIT;
                end
            end
            `SHIFT_LEFT: begin
                if (count == 10'd320) begin
                    next_count = 0;
                    next_state = `SHIFT_DOWN;
                end else begin
                    next_count = count + 1;
                end
            end
            `SHIFT_DOWN: begin
                if (count == 10'd240) begin
                    next_count = 0;
                    next_state = `INITIAL;
                end else begin
                    next_count = count + 1;
                end
            end
            `SPLIT: begin
                if (count_h == 10'd160) begin
                    {next_count, next_count_h} = 0;
                    next_state = `INITIAL;
                end else begin
                    next_count_h= count_h + 1;
                    next_count = (count < 120)? count + 1:count;
                end
            end
       endcase
    end

    always @(*) begin
        if (state == `SPLIT) begin
            if (h_cnt < 320 && v_cnt < 240) begin   // upper left: shift up
                pixel_addr = ((h_cnt>>1)+ 320*(v_cnt>>1) + 320*count)% 76800;
            end else if (h_cnt >= 320 && v_cnt < 240) begin // upper right: shift right
                pixel_addr = (((h_cnt>>1) + (320-count_h))%320 + 320*(v_cnt>>1))% 76800;
            end else if (h_cnt < 320 && v_cnt >= 240) begin // lower left: shift left
                pixel_addr = (((h_cnt>>1) + count_h)%320 + 320*(v_cnt>>1))% 76800;
            end else if (h_cnt >= 320 && v_cnt >= 240) begin    // lower right: shift down
                pixel_addr = ((h_cnt>>1)+ 320*(v_cnt>>1) + 320*(240-count))% 76800;
            end else begin
                pixel_addr = ((h_cnt>>1)%320 + 320*(v_cnt>>1))% 76800;
            end
        end else    // 640x480->320x240
            pixel_addr = (((h_cnt>>1))%320 + 320*(v_cnt>>1))% 76800;
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
