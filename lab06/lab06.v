`define INITIAL 4'b0001
`define READ 4'b0010
`define END  4'b0100
`define CHEAT  4'b1000

module lab06(
    output wire [6:0] DISPLAY,
    output wire [3:0] DIGIT,
    output reg [15:0] LED,
    inout wire PS2_DATA,
    inout wire PS2_CLK,
    input wire rst,
    input wire clk,
    input wire start,
    input wire cheat
);
    parameter [8:0] ENTER = 9'b0_0101_1010; // right enter => E05A
    parameter [8:0] KEY_CODES [0:9] = {
        9'b0_0111_0000, // right_0 => 70
        9'b0_0110_1001, // right_1 => 69
        9'b0_0111_0010, // right_2 => 72
        9'b0_0111_1010, // right_3 => 7A
        9'b0_0110_1011, // right_4 => 6B
        9'b0_0111_0011, // right_5 => 73
        9'b0_0111_0100, // right_6 => 74
        9'b0_0110_1100, // right_7 => 6C
        9'b0_0111_0101, // right_8 => 75
        9'b0_0111_1101  // right_9 => 7D
    };

	reg [3:0] key_num;
	reg [9:0] last_key;

	wire enter_down, enter;
	wire [511:0] key_down;
	wire [8:0] last_change;
	wire been_ready;

    assign enter_down = (key_down[ENTER] == 1'b1)? 1'b1 : 1'b0;
    //assign enter = been_ready & key_down[last_change] & last_change == ENTER;

	KeyboardDecoder key_de (
		.key_down(key_down),
		.last_change(last_change),
		.key_valid(been_ready),
		.PS2_DATA(PS2_DATA),
		.PS2_CLK(PS2_CLK),
		.rst(rst),
		.clk(clk)
	);

    always @ (*) begin
		case (last_change)
			KEY_CODES[0] : key_num = 4'b0000;
			KEY_CODES[1] : key_num = 4'b0001;
			KEY_CODES[2] : key_num = 4'b0010;
			KEY_CODES[3] : key_num = 4'b0011;
			KEY_CODES[4] : key_num = 4'b0100;
			KEY_CODES[5] : key_num = 4'b0101;
			KEY_CODES[6] : key_num = 4'b0110;
			KEY_CODES[7] : key_num = 4'b0111;
			KEY_CODES[8] : key_num = 4'b1000;
			KEY_CODES[9] : key_num = 4'b1001;
			default		  : key_num = 4'b1111;
		endcase
	end

    wire clk_div_13, clk_div_16, clk_div_25;
    clock_divider #(.n(13)) c1 (.clk(clk), .clk_div(clk_div_13));
    clock_divider #(.n(16)) c2 (.clk(clk), .clk_div(clk_div_16));
    clock_divider #(.n(25)) c3 (.clk(clk), .clk_div(clk_div_25));

    wire db_rst, db_start, db_cheat, db_enter;
    debounce d1 (db_rst, rst, clk_div_16);
    debounce d2 (db_start, start, clk_div_16);
    debounce d3 (db_cheat, cheat, clk_div_16);

    wire op_start, op_enter;
    one_pulse o1 (db_rst, clk_div_16, db_start, op_start);

    // use counter in clock divider to get a random number
    reg [8-1:0] num;
    wire [8-1:0] next_num;
    always @ (posedge clk) begin
        if (db_rst)
            num <= 8'd0;
        else
            num <= next_num;
    end
    assign next_num = (num + 1) % 8'd99;

    reg [3:0] state, next_state;
    reg [7:0] right, next_right;
    reg [7:0] left, next_left;
    reg [7:0] upper, next_upper;
    reg [7:0] lower, next_lower;
    reg [25-1:0] count, next_count;
    reg [7:0] goal, next_goal;

    reg press_count, next_press_count;

    // FSM
    always @ (posedge clk or posedge db_rst) begin
        if (db_rst) begin
            state <= `INITIAL;
            left <= 8'b10101010;    // '- -'
            right <= 8'b10101010;
            upper <= 8'b10011001;   // '9 9'
            lower <= 8'b0;  // '0 0'
            count <= 25'b0;
            goal <= 8'd0;
            press_count <= 0;
        end else begin
            state <= next_state;
            left <= next_left;
            right <= next_right;
            upper <= next_upper;
            lower <= next_lower;
            count <= next_count;
            goal <= next_goal;
            press_count <= next_press_count;
        end
    end

    always @ ( * ) begin
        LED = 16'b0;
        next_state = state;
        {next_left, next_right} = {left, right};
        {next_lower, next_upper} = {lower, upper};
        next_count = count;
        next_goal = goal;
        next_press_count = press_count;
        case (state)
            `INITIAL: begin
                {next_lower, next_upper} = {8'b0, 8'b1001_1001};
                {next_left, next_right} = {8'b1010_1010, 8'b1010_1010}; // '-- --'
                next_goal = 8'd0;
                if (op_start) begin
                    {next_left, next_right} = {8'b0, 8'b1001_1001}; // '00 99'
                    next_goal[7:4] = num / 10;
                    next_goal[3:0] = num % 10;
                    next_state = `READ;
                end
            end
            `READ: begin
                if ( /*been_ready &&*/ key_down[last_change] == 1'b1) begin
                    if (key_num != 4'b1111) begin;
                        LED = 16'b0000_1111_0000_0000;
                        next_left = 8'b1111_1111; // blank
                        if (been_ready) begin
                            if (press_count == 0) begin
                                next_right = {4'b1111, key_num};
                                next_press_count = 1;
                            end else begin
                                next_right = {right[3:0], key_num};
                            end
                        end
                    end else if (enter_down) begin
                        LED = 16'b1111_0000_0000_0000;
                        next_press_count = 0;
                        if (been_ready) begin
                            if (right[7:4] == 4'd10||right <= lower||right >= upper) begin // If guess is invalid
                                {next_left, next_right} = {lower, upper};
                            end else begin
                                if (right > goal) begin
                                    {next_left, next_right} = {lower, right};
                                    next_upper = right;
                                end else if (right < goal) begin
                                    {next_left, next_right} = {right, upper};
                                    next_lower = right;
                                end else begin  // correct
                                    {next_left, next_right} = {goal, goal};
                                    next_state = `END;
                                end
                            end
                        end
                    end
                end else begin
                    LED = 16'd15;
                    if (cheat) begin
                        next_state = `CHEAT;
                        {next_left, next_right} = {goal, 8'b1111_1111}; //goal, blank
                    end
                end
            end
            `CHEAT: begin
                if (cheat == 0) begin
                    {next_left, next_right} = {lower, upper};
                    next_state = `READ;
                end
            end
            `END: begin
                LED = 16'b1111_1111_1111_1111;
                // use a count to stay in this state for longer
                next_count = count + 1;
                if (count == 25'd33554431) begin
                    next_count = 25'b0;
                    {next_left, next_right} = {8'b1010_1010, 8'b1010_1010}; // '-- --'
                    next_state = `INITIAL;
                end
            end
        endcase
    end

    seven_segment s1 (clk_div_13, db_rst, right[3:0], right[7:4], left[3:0], left[7:4], DIGIT, DISPLAY);

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
            4'd10: DISPLAY = 7'b1111110; // '-'
            default: DISPLAY = 7'b1111111;
        endcase
   end
endmodule

module KeyboardDecoder(
	output reg [511:0] key_down,
	output wire [8:0] last_change,
	output reg key_valid,
	inout wire PS2_DATA,
	inout wire PS2_CLK,
	input wire rst,
	input wire clk
    );

    parameter [1:0] INIT			= 2'b00;
    parameter [1:0] WAIT_FOR_SIGNAL = 2'b01;
    parameter [1:0] GET_SIGNAL_DOWN = 2'b10;
    parameter [1:0] WAIT_RELEASE    = 2'b11;

	parameter [7:0] IS_INIT			= 8'hAA;
    parameter [7:0] IS_EXTEND		= 8'hE0;
    parameter [7:0] IS_BREAK		= 8'hF0;

    reg [9:0] key;		// key = {been_extend, been_break, key_in}
    reg [1:0] state;
    reg been_ready, been_extend, been_break;

    wire [7:0] key_in;
    wire is_extend;
    wire is_break;
    wire valid;
    wire err;

    wire [511:0] key_decode = 1 << last_change;
    assign last_change = {key[9], key[7:0]};

    KeyboardCtrl_0 inst (
		.key_in(key_in),
		.is_extend(is_extend),
		.is_break(is_break),
		.valid(valid),
		.err(err),
		.PS2_DATA(PS2_DATA),
		.PS2_CLK(PS2_CLK),
		.rst(rst),
		.clk(clk)
	);

    wire pulse_been_ready;
	OnePulse op (
		.signal_single_pulse(pulse_been_ready),
		.signal(been_ready),
		.clock(clk)
	);

    always @ (posedge clk, posedge rst) begin
    	if (rst) begin
    		state <= INIT;
    		been_ready  <= 1'b0;
    		been_extend <= 1'b0;
    		been_break  <= 1'b0;
    		key <= 10'b0_0_0000_0000;
    	end else begin
    		state <= state;
			been_ready  <= been_ready;
			been_extend <= (is_extend) ? 1'b1 : been_extend;
			been_break  <= (is_break ) ? 1'b1 : been_break;
			key <= key;
    		case (state)
    			INIT : begin
    					if (key_in == IS_INIT) begin
    						state <= WAIT_FOR_SIGNAL;
    						been_ready  <= 1'b0;
							been_extend <= 1'b0;
							been_break  <= 1'b0;
							key <= 10'b0_0_0000_0000;
    					end else begin
    						state <= INIT;
    					end
    				end
    			WAIT_FOR_SIGNAL : begin
    					if (valid == 0) begin
    						state <= WAIT_FOR_SIGNAL;
    						been_ready <= 1'b0;
    					end else begin
    						state <= GET_SIGNAL_DOWN;
    					end
    				end
    			GET_SIGNAL_DOWN : begin
						state <= WAIT_RELEASE;
						key <= {been_extend, been_break, key_in};
						been_ready  <= 1'b1;
    				end
    			WAIT_RELEASE : begin
    					if (valid == 1) begin
    						state <= WAIT_RELEASE;
    					end else begin
    						state <= WAIT_FOR_SIGNAL;
    						been_extend <= 1'b0;
    						been_break  <= 1'b0;
    					end
    				end
    			default : begin
    					state <= INIT;
						been_ready  <= 1'b0;
						been_extend <= 1'b0;
						been_break  <= 1'b0;
						key <= 10'b0_0_0000_0000;
    				end
    		endcase
    	end
    end

    always @ (posedge clk, posedge rst) begin
    	if (rst) begin
    		key_valid <= 1'b0;
    		key_down <= 511'b0;
    	end else if (key_decode[last_change] && pulse_been_ready) begin
    		key_valid <= 1'b1;
    		if (key[8] == 0) begin
    			key_down <= key_down | key_decode;
    		end else begin
    			key_down <= key_down & (~key_decode);
    		end
    	end else begin
    		key_valid <= 1'b0;
			key_down <= key_down;
    	end
    end

endmodule

module OnePulse (
	output reg signal_single_pulse,
	input wire signal,
	input wire clock
	);

	reg signal_delay;

	always @(posedge clock) begin
		if (signal == 1'b1 & signal_delay == 1'b0)
		  signal_single_pulse <= 1'b1;
		else
		  signal_single_pulse <= 1'b0;

		signal_delay <= signal;
	end
endmodule
