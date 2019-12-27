module player_control (
	input clk,
	input reset,
	input _play,
	input _repeat,
	input _music,
    output reg in_pause,
	output reg [11:0] ibeat,
	output reg [1:0] state
);
	  parameter LEN = 4095;

    parameter INIT = 2'd0;
    parameter PLAY = 2'd1;
    parameter PAUSE = 2'd2;
    parameter STOP = 2'd3;

    reg [11:0] next_ibeat;
    reg [1:0] next_state;
    wire [11:0] beatLen;
    wire switched;
    reg last_music;

    assign beatLen = (_music == 1)? 512:544;
    assign switched = (last_music != _music) ? 1'b1: 1'b0;

    always @(posedge clk or posedge reset) begin
        last_music <= _music;
        if (reset || switched)
            ibeat <= 0;
        else
            ibeat <= next_ibeat;
    end

    always @ (posedge clk or posedge reset) begin
        if(reset) begin
            state <= INIT;
        end else begin
            state <= next_state;
        end
    end

    always @ (*) begin
        next_state = state;
        next_ibeat = ibeat;
        case(state)
            INIT: begin
                in_pause = 1;
                if (_play == 1) begin
                    next_state = PLAY;
                end
            end
            PLAY: begin
                in_pause = 0;
                if (_play == 0) begin
                   next_state = PAUSE;
                end else if (ibeat == beatLen) begin
                    next_state = (_repeat)? PLAY:STOP;
                    next_ibeat = 12'd0;
                end else if (ibeat < beatLen) begin
                    next_ibeat = ibeat + 1;
                end
            end
            PAUSE: begin
                in_pause = 1;
                if (_play == 1) begin
                    next_state = PLAY;
                end
            end
            STOP: begin
                in_pause = 1;
                if (_repeat)
                    next_state = PLAY;
                else if (_play == 0) begin
                    next_state = INIT;
                end
            end
        endcase
    end

//	always @(posedge clk, posedge reset) begin
//		if (reset)
//			ibeat <= 0;
//		else begin
//            ibeat <= next_ibeat;
//		end
//	end

//    always @* begin
//        if (_music == 0)
//            next_ibeat = (ibeat + 1 < LEN) ? (ibeat + 1) : 12'd0;
//        else
//            next_ibeat = (ibeat + 1 < LEN_2) ? (ibeat + 1) : 12'd0;
//    end

endmodule
