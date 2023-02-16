    `define silence   32'd50000000


    `define ha  32'd440   // A4
    `define hb  32'd494   // B4
    `define hc  32'd524   // C4
    `define hd  32'd588   // D4
    `define he  32'd660   // E4
    `define hf  32'd698   // F4
    `define hg  32'd784   // G4
    `define c   32'd262   // C3
    `define g   32'd392   // G3
    `define b   32'd494   // B3
    `define d   32'd294   // D3
    `define e   32'd330   // E3
    `define f   32'd349
    `define sil   32'd50000000 // slience

    `define A 3'b001
    `define B 3'b010
    `define C 3'b011
    `define D 3'b100
    `define E 3'b101
    `define F 3'b110
    `define G 3'b111

    module clock_divider(clk, clk_div);
        parameter n = 26;
        input clk;
        output clk_div;

        reg [n-1:0] num;
        wire [n-1:0] next_num;

        always@(posedge clk)begin
            num<=next_num;
        end

        assign next_num = num +1;
        assign clk_div = num[n-1];

    endmodule

    module onepulse(input wire rst, input wire clk, input wire pb_debounced, output reg pb_1pulse);
        reg pb_1pulse_next;
        reg pb_debounced_delay;

        always@(*) begin
            pb_1pulse_next = pb_debounced & ~pb_debounced_delay;
        end
        always@(posedge clk,posedge rst) begin
            if(rst == 1'b1) begin
                pb_1pulse = 1'b0;
                pb_debounced_delay = 1'b0;
            end
            else begin
                pb_1pulse = pb_1pulse_next;
                pb_debounced_delay = pb_debounced;
            end
        end
    endmodule

    module debounce (pb_debounced, pb, clk);
        output pb_debounced; // output after being debounced
        input pb; // input from a pushbutton
        input clk;
        reg [3:0] shift_reg; // use shift_reg to filter the bounce
        always@(posedge clk)
            begin
                shift_reg[3:1] <= shift_reg[2:0];
                shift_reg[0] <= pb;
            end
        assign pb_debounced = ((shift_reg == 4'b1111) ? 1'b1 : 1'b0);
    endmodule

    module player_control (
        input clk,
        input reset,
        input _play,
        input _repeat,
        input music,
        output reg [11:0] ibeat,
        output reg play
    );
        parameter LEN = 128;
        parameter _LEN = 512;
        parameter INITIAL = 2'd0;
        parameter FIRST = 2'd1;
        parameter SECOND = 2'd2;
        reg [11:0] next_ibeat;
        reg [1:0] state, next_state;

        always @(posedge clk, posedge reset) begin
            if (reset) begin
                ibeat <= 0;
                state <= INITIAL;
            end
            else begin
                ibeat <= next_ibeat;
                state <= next_state;
            end
        end

        always @* begin
            next_state = state;
            next_ibeat = ibeat;
            case(state)
                INITIAL: begin
                    if(music == 1'b1) begin
                        next_state = FIRST;
                    end
                    else begin
                        next_state = SECOND;
                    end
                end
                FIRST: begin
                    if(_play == 1'b1) begin
                        if(_repeat == 1'b1) begin
                            next_ibeat = (ibeat + 1 < LEN) ? (ibeat + 1) : 12'd0;
                            play = 1'b1;
                        end
                        else begin
                            next_ibeat = (ibeat + 1 < LEN) ? (ibeat + 1) : ibeat;
                            if(ibeat + 1 == LEN) begin
                                play = 1'b0;
                            end
                            else begin
                                play = 1'b1;
                            end
                        end
                    end
                    else begin
                        next_ibeat = ibeat;
                        play = 1'b0;
                    end
                    if(music == 1'b0) begin
                        next_state = SECOND;
                        next_ibeat = 0;
                    end
                end
                SECOND: begin
                    if(_play == 1'b1) begin
                        if(_repeat == 1'b1) begin
                            next_ibeat = (ibeat + 1 < _LEN) ? (ibeat + 1) : 12'd0;
                            play = 1'b1;
                        end
                        else begin
                            next_ibeat = (ibeat + 1 < _LEN) ? (ibeat + 1) : ibeat;
                            if(ibeat + 1 == _LEN) begin
                                play = 1'b0;
                            end
                            else begin
                                play = 1'b1;
                            end
                        end
                    end
                    else begin
                        next_ibeat = ibeat;
                        play = 1'b0;
                    end
                    if(music == 1'b1) begin
                        next_state = FIRST;
                        next_ibeat = 0;
                    end
                end
            endcase
        end

    endmodule

    module note_gen(
        clk, // clock from crystal
        rst, // active high reset
        note_div_left, // div for note generation
        note_div_right,
        audio_left,
        audio_right,
        volume
    );

        // I/O declaration
        input clk; // clock from crystal
        input rst; // active low reset
        input [21:0] note_div_left, note_div_right; // div for note generation
        output [15:0] audio_left, audio_right;
        input [2:0] volume;

        // Declare internal signals
        reg [21:0] clk_cnt_next, clk_cnt;
        reg [21:0] clk_cnt_next_2, clk_cnt_2;
        reg b_clk, b_clk_next;
        reg c_clk, c_clk_next;

        // Note frequency generation
        always @(posedge clk or posedge rst)
            if (rst == 1'b1)
                begin
                    clk_cnt <= 22'd0;
                    clk_cnt_2 <= 22'd0;
                    b_clk <= 1'b0;
                    c_clk <= 1'b0;
                end
            else
                begin
                    clk_cnt <= clk_cnt_next;
                    clk_cnt_2 <= clk_cnt_next_2;
                    b_clk <= b_clk_next;
                    c_clk <= c_clk_next;
                end

        always @*
            if (clk_cnt == note_div_left)
                begin
                    clk_cnt_next = 22'd0;
                    b_clk_next = ~b_clk;
                end
            else
                begin
                    clk_cnt_next = clk_cnt + 1'b1;
                    b_clk_next = b_clk;
                end

        always @*
            if (clk_cnt_2 == note_div_right)
                begin
                    clk_cnt_next_2 = 22'd0;
                    c_clk_next = ~c_clk;
                end
            else
                begin
                    clk_cnt_next_2 = clk_cnt_2 + 1'b1;
                    c_clk_next = c_clk;
                end

        // Assign the amplitude of the note
        // Volume is controlled here
        assign audio_left = (b_clk == 1'b0 && volume == 3'd1) ? 16'hE666 : //1999
                            (b_clk == 1'b1 && volume == 3'd1) ? 16'h1999 :
                            (b_clk == 1'b0 && volume == 3'd2) ? 16'hAAAB : //3333
                            (b_clk == 1'b1 && volume == 3'd2) ? 16'h3333 :
                            (b_clk == 1'b0 && volume == 3'd3) ? 16'hB334 : //4CCC
                            (b_clk == 1'b1 && volume == 3'd3) ? 16'h4CCC :
                            (b_clk == 1'b0 && volume == 3'd4) ? 16'h999A : // 6666
                            (b_clk == 1'b1 && volume == 3'd4) ? 16'h6666 :
                            (b_clk == 1'b0 && volume == 3'd5) ? 16'h8001 : 16'h7FFF;
        assign audio_right = (c_clk == 1'b0 && volume == 3'd1) ? 16'hE666 : //1999
                             (c_clk == 1'b1 && volume == 3'd1) ? 16'h1999 :
                             (c_clk == 1'b0 && volume == 3'd2) ? 16'hAAAB : //3333
                             (c_clk == 1'b1 && volume == 3'd2) ? 16'h3333 :
                             (c_clk == 1'b0 && volume == 3'd3) ? 16'hB334 : //4CCC
                             (c_clk == 1'b1 && volume == 3'd3) ? 16'h4CCC :
                             (c_clk == 1'b0 && volume == 3'd4) ? 16'h999A : // 6666
                             (c_clk == 1'b1 && volume == 3'd4) ? 16'h6666 :
                             (c_clk == 1'b0 && volume == 3'd5) ? 16'h8001 : 16'h7FFF;
    endmodule

    module music_example (
        input [11:0] ibeatNum,
        input play,
        input reset,
        input music,
        output reg [31:0] toneL,
        output reg [31:0] toneR,
        output reg [31:0] _toneL,
        output reg [31:0] _toneR,
        output reg [2:0] note
    );

    //first song
        always @* begin
            if(play == 1 && music == 1'b1) begin
                case(ibeatNum)
                    // --- Measure 1 ---
                    12'd0: toneR = `hg;      12'd1: toneR = `hg; // HG (half-beat)
                    12'd2: toneR = `hg;      12'd3: toneR = `hg;
                    12'd4: toneR = `hg;      12'd5: toneR = `hg;
                    12'd6: toneR = `hg;      12'd7: toneR = `hg;
                    12'd8: toneR = `he;      12'd9: toneR = `he; // HE (half-beat)
                    12'd10: toneR = `he;     12'd11: toneR = `he;
                    12'd12: toneR = `he;     12'd13: toneR = `he;
                    12'd14: toneR = `he;     12'd15: toneR = `sil; // (Short break for repetitive notes: high E)

                    12'd16: toneR = `he;     12'd17: toneR = `he; // HE (one-beat)
                    12'd18: toneR = `he;     12'd19: toneR = `he;
                    12'd20: toneR = `he;     12'd21: toneR = `he;
                    12'd22: toneR = `he;     12'd23: toneR = `he;
                    12'd24: toneR = `he;     12'd25: toneR = `he;
                    12'd26: toneR = `he;     12'd27: toneR = `he;
                    12'd28: toneR = `he;     12'd29: toneR = `he;
                    12'd30: toneR = `he;     12'd31: toneR = `he;

                    12'd32: toneR = `hf;     12'd33: toneR = `hf; // HF (half-beat)
                    12'd34: toneR = `hf;     12'd35: toneR = `hf;
                    12'd36: toneR = `hf;     12'd37: toneR = `hf;
                    12'd38: toneR = `hf;     12'd39: toneR = `hf;
                    12'd40: toneR = `hd;     12'd41: toneR = `hd; // HD (half-beat)
                    12'd42: toneR = `hd;     12'd43: toneR = `hd;
                    12'd44: toneR = `hd;     12'd45: toneR = `hd;
                    12'd46: toneR = `hd;     12'd47: toneR = `sil; // (Short break for repetitive notes: high D)

                    12'd48: toneR = `hd;     12'd49: toneR = `hd; // HD (one-beat)
                    12'd50: toneR = `hd;     12'd51: toneR = `hd;
                    12'd52: toneR = `hd;     12'd53: toneR = `hd;
                    12'd54: toneR = `hd;     12'd55: toneR = `hd;
                    12'd56: toneR = `hd;     12'd57: toneR = `hd;
                    12'd58: toneR = `hd;     12'd59: toneR = `hd;
                    12'd60: toneR = `hd;     12'd61: toneR = `hd;
                    12'd62: toneR = `hd;     12'd63: toneR = `hd;

                    // --- Measure 2 ---
                    12'd64: toneR = `hc;     12'd65: toneR = `hc; // HC (half-beat)
                    12'd66: toneR = `hc;     12'd67: toneR = `hc;
                    12'd68: toneR = `hc;     12'd69: toneR = `hc;
                    12'd70: toneR = `hc;     12'd71: toneR = `hc;
                    12'd72: toneR = `hd;     12'd73: toneR = `hd; // HD (half-beat)
                    12'd74: toneR = `hd;     12'd75: toneR = `hd;
                    12'd76: toneR = `hd;     12'd77: toneR = `hd;
                    12'd78: toneR = `hd;     12'd79: toneR = `hd;

                    12'd80: toneR = `he;     12'd81: toneR = `he; // HE (half-beat)
                    12'd82: toneR = `he;     12'd83: toneR = `he;
                    12'd84: toneR = `he;     12'd85: toneR = `he;
                    12'd86: toneR = `he;     12'd87: toneR = `he;
                    12'd88: toneR = `hf;     12'd89: toneR = `hf; // HF (half-beat)
                    12'd90: toneR = `hf;     12'd91: toneR = `hf;
                    12'd92: toneR = `hf;     12'd93: toneR = `hf;
                    12'd94: toneR = `hf;     12'd95: toneR = `hf;

                    12'd96: toneR = `hg;     12'd97: toneR = `hg; // HG (half-beat)
                    12'd98: toneR = `hg;     12'd99: toneR = `hg;
                    12'd100: toneR = `hg;     12'd101: toneR = `hg;
                    12'd102: toneR = `hg;     12'd103: toneR = `sil; // (Short break for repetitive notes: high D)
                    12'd104: toneR = `hg;     12'd105: toneR = `hg; // HG (half-beat)
                    12'd106: toneR = `hg;     12'd107: toneR = `hg;
                    12'd108: toneR = `hg;     12'd109: toneR = `hg;
                    12'd110: toneR = `hg;     12'd111: toneR = `sil; // (Short break for repetitive notes: high D)

                    12'd112: toneR = `hg;     12'd113: toneR = `hg; // HG (one-beat)
                    12'd114: toneR = `hg;     12'd115: toneR = `hg;
                    12'd116: toneR = `hg;     12'd117: toneR = `hg;
                    12'd118: toneR = `hg;     12'd119: toneR = `hg;
                    12'd120: toneR = `hg;     12'd121: toneR = `hg;
                    12'd122: toneR = `hg;     12'd123: toneR = `hg;
                    12'd124: toneR = `hg;     12'd125: toneR = `hg;
                    12'd126: toneR = `hg;     12'd127: toneR = `hg;
                    default: toneR = `sil;
                endcase
            end else begin
                toneR = `sil;
            end
        end

        always @(*) begin
            if(play == 1 && music == 1'b1)begin
                case(ibeatNum)
                    12'd0: toneL = `hc;  	12'd1: toneL = `hc; // HC (two-beat)
                    12'd2: toneL = `hc;  	12'd3: toneL = `hc;
                    12'd4: toneL = `hc;	    12'd5: toneL = `hc;
                    12'd6: toneL = `hc;  	12'd7: toneL = `hc;
                    12'd8: toneL = `hc;	    12'd9: toneL = `hc;
                    12'd10: toneL = `hc;	12'd11: toneL = `hc;
                    12'd12: toneL = `hc;	12'd13: toneL = `hc;
                    12'd14: toneL = `hc;	12'd15: toneL = `hc;

                    12'd16: toneL = `hc;	12'd17: toneL = `hc;
                    12'd18: toneL = `hc;	12'd19: toneL = `hc;
                    12'd20: toneL = `hc;	12'd21: toneL = `hc;
                    12'd22: toneL = `hc;	12'd23: toneL = `hc;
                    12'd24: toneL = `hc;	12'd25: toneL = `hc;
                    12'd26: toneL = `hc;	12'd27: toneL = `hc;
                    12'd28: toneL = `hc;	12'd29: toneL = `hc;
                    12'd30: toneL = `hc;	12'd31: toneL = `hc;

                    12'd32: toneL = `g;	    12'd33: toneL = `g; // G (one-beat)
                    12'd34: toneL = `g;	    12'd35: toneL = `g;
                    12'd36: toneL = `g;	    12'd37: toneL = `g;
                    12'd38: toneL = `g;	    12'd39: toneL = `g;
                    12'd40: toneL = `g;	    12'd41: toneL = `g;
                    12'd42: toneL = `g;	    12'd43: toneL = `g;
                    12'd44: toneL = `g;	    12'd45: toneL = `g;
                    12'd46: toneL = `g;	    12'd47: toneL = `g;

                    12'd48: toneL = `b;	    12'd49: toneL = `b; // B (one-beat)
                    12'd50: toneL = `b;	    12'd51: toneL = `b;
                    12'd52: toneL = `b;	    12'd53: toneL = `b;
                    12'd54: toneL = `b;	    12'd55: toneL = `b;
                    12'd56: toneL = `b;	    12'd57: toneL = `b;
                    12'd58: toneL = `b;	    12'd59: toneL = `b;
                    12'd60: toneL = `b;	    12'd61: toneL = `b;
                    12'd62: toneL = `b;	    12'd63: toneL = `b;

                    12'd64: toneL = `hc;	    12'd65: toneL = `hc; // HC (two-beat)
                    12'd66: toneL = `hc;	    12'd67: toneL = `hc;
                    12'd68: toneL = `hc;	    12'd69: toneL = `hc;
                    12'd70: toneL = `hc;	    12'd71: toneL = `hc;
                    12'd72: toneL = `hc;	    12'd73: toneL = `hc;
                    12'd74: toneL = `hc;	    12'd75: toneL = `hc;
                    12'd76: toneL = `hc;	    12'd77: toneL = `hc;
                    12'd78: toneL = `hc;	    12'd79: toneL = `hc;

                    12'd80: toneL = `hc;	    12'd81: toneL = `hc;
                    12'd82: toneL = `hc;	    12'd83: toneL = `hc;
                    12'd84: toneL = `hc;	    12'd85: toneL = `hc;
                    12'd86: toneL = `hc;	    12'd87: toneL = `hc;
                    12'd88: toneL = `hc;	    12'd89: toneL = `hc;
                    12'd90: toneL = `hc;	    12'd91: toneL = `hc;
                    12'd92: toneL = `hc;	    12'd93: toneL = `hc;
                    12'd94: toneL = `hc;	    12'd95: toneL = `hc;

                    12'd96: toneL = `g;	    12'd97: toneL = `g; // G (one-beat)
                    12'd98: toneL = `g; 	12'd99: toneL = `g;
                    12'd100: toneL = `g;	12'd101: toneL = `g;
                    12'd102: toneL = `g;	12'd103: toneL = `g;
                    12'd104: toneL = `g;	12'd105: toneL = `g;
                    12'd106: toneL = `g;	12'd107: toneL = `g;
                    12'd108: toneL = `g;	12'd109: toneL = `g;
                    12'd110: toneL = `g;	12'd111: toneL = `g;

                    12'd112: toneL = `b;	12'd113: toneL = `b; // B (one-beat)
                    12'd114: toneL = `b;	12'd115: toneL = `b;
                    12'd116: toneL = `b;	12'd117: toneL = `b;
                    12'd118: toneL = `b;	12'd119: toneL = `b;
                    12'd120: toneL = `b;	12'd121: toneL = `b;
                    12'd122: toneL = `b;	12'd123: toneL = `b;
                    12'd124: toneL = `b;	12'd125: toneL = `b;
                    12'd126: toneL = `b;	12'd127: toneL = `b;
                    default : toneL = `sil;
                endcase
            end
            else begin
                toneL = `sil;
            end
        end


        //second song
        always @* begin
            if(play == 1 && music == 1'b0) begin
                case(ibeatNum)
                    // --- Measure 1 ---
                    12'd0: _toneR = `hc;   12'd1: _toneR = `hc;
                    12'd2: _toneR = `hc;   12'd3: _toneR = `hc;
                    12'd4: _toneR = `hc;   12'd5: _toneR = `hc;
                    12'd6: _toneR = `hc;   12'd7: _toneR = `hc;
                    12'd8: _toneR = `hc;   12'd9: _toneR = `hc;
                    12'd10: _toneR = `hc;   12'd11: _toneR = `hc;
                    12'd12: _toneR = `hc;  12'd13: _toneR = `hc;
                    12'd14: _toneR = `hc;  12'd15: _toneR = `sil; // (Short break for repetitive notes: high E)

                    12'd16: _toneR = `hd;   12'd17: _toneR = `hd;
                    12'd18: _toneR = `hd;   12'd19: _toneR = `hd;
                    12'd20: _toneR = `hd;   12'd21: _toneR = `hd;
                    12'd22: _toneR = `hd;   12'd23: _toneR = `hd;
                    12'd24: _toneR = `hd;   12'd25: _toneR = `hd;
                    12'd26: _toneR = `hd;   12'd27: _toneR = `hd;
                    12'd28: _toneR = `hd;   12'd29: _toneR = `hd;
                    12'd30: _toneR = `hd;   12'd31: _toneR = `sil;

                    12'd32: _toneR = `he;   12'd33: _toneR = `he;
                    12'd34: _toneR = `he;   12'd35: _toneR = `he;
                    12'd36: _toneR = `he;   12'd37: _toneR = `he;
                    12'd38: _toneR = `he;   12'd39: _toneR = `he;
                    12'd40: _toneR = `he;   12'd41: _toneR = `he;
                    12'd42: _toneR = `he;   12'd43: _toneR = `he;
                    12'd44: _toneR = `he;   12'd45: _toneR = `he;
                    12'd46: _toneR = `he;   12'd47: _toneR = `sil; // (Short break for repetitive notes: high D)

                    12'd48: _toneR = `hc;   12'd49: _toneR = `hc;
                    12'd50: _toneR = `hc;   12'd51: _toneR = `hc;
                    12'd52: _toneR = `hc;   12'd53: _toneR = `hc;
                    12'd54: _toneR = `hc;   12'd55: _toneR = `hc;
                    12'd56: _toneR = `hc;   12'd57: _toneR = `hc;
                    12'd58: _toneR = `hc;   12'd59: _toneR = `hc;
                    12'd60: _toneR = `hc;   12'd61: _toneR = `hc;
                    12'd62: _toneR = `hc;   12'd63: _toneR = `sil;

                    // --- Measure 2 ---
                    12'd64: _toneR = `hc;   12'd65: _toneR = `hc;
                    12'd66: _toneR = `hc;   12'd67: _toneR = `hc;
                    12'd68: _toneR = `hc;   12'd69: _toneR = `hc;
                    12'd70: _toneR = `hc;   12'd71: _toneR = `hc;
                    12'd72: _toneR = `hc;   12'd73: _toneR = `hc;
                    12'd74: _toneR = `hc;   12'd75: _toneR = `hc;
                    12'd76: _toneR = `hc;   12'd77: _toneR = `hc;
                    12'd78: _toneR = `hc;   12'd79: _toneR = `sil;

                    12'd80: _toneR = `hd;   12'd81: _toneR = `hd;
                    12'd82: _toneR = `hd;   12'd83: _toneR = `hd;
                    12'd84: _toneR = `hd;   12'd85: _toneR = `hd;
                    12'd86: _toneR = `hd;   12'd87: _toneR = `hd;
                    12'd88: _toneR = `hd;   12'd89: _toneR = `hd;
                    12'd90: _toneR = `hd;   12'd91: _toneR = `hd;
                    12'd92: _toneR = `hd;   12'd93: _toneR = `hd;
                    12'd94: _toneR = `hd;   12'd95: _toneR = `sil;

                    12'd96: _toneR = `he;   12'd97: _toneR = `he;
                    12'd98: _toneR = `he;   12'd99: _toneR = `he;
                    12'd100: _toneR = `he;   12'd101: _toneR = `he;
                    12'd102: _toneR = `he;   12'd103: _toneR = `he;
                    12'd104: _toneR = `he;   12'd105: _toneR = `he;
                    12'd106: _toneR = `he;   12'd107: _toneR = `he;
                    12'd108: _toneR = `he;   12'd109: _toneR = `he;
                    12'd110: _toneR = `he;   12'd111: _toneR = `sil; // (Short break for repetitive notes: high D)

                    12'd112: _toneR = `hc;   12'd113: _toneR = `hc;
                    12'd114: _toneR = `hc;   12'd115: _toneR = `hc;
                    12'd116: _toneR = `hc;   12'd117: _toneR = `hc;
                    12'd118: _toneR = `hc;   12'd119: _toneR = `hc;
                    12'd120: _toneR = `hc;   12'd121: _toneR = `hc;
                    12'd122: _toneR = `hc;   12'd123: _toneR = `hc;
                    12'd124: _toneR = `hc;   12'd125: _toneR = `hc;
                    12'd126: _toneR = `hc;   12'd127: _toneR = `sil;

                    // --- Measure 3 ---
                    12'd128: _toneR = `he;   12'd129: _toneR = `he;
                    12'd130: _toneR = `he;   12'd131: _toneR = `he;
                    12'd132: _toneR = `he;   12'd133: _toneR = `he;
                    12'd134: _toneR = `he;   12'd135: _toneR = `he;
                    12'd136: _toneR = `he;   12'd137: _toneR = `he;
                    12'd138: _toneR = `he;   12'd139: _toneR = `he;
                    12'd140: _toneR = `he;   12'd141: _toneR = `he;
                    12'd142: _toneR = `he;   12'd143: _toneR = `sil;

                    12'd144: _toneR = `hf;   12'd145: _toneR = `hf;
                    12'd146: _toneR = `hf;   12'd147: _toneR = `hf;
                    12'd148: _toneR = `hf;   12'd149: _toneR = `hf;
                    12'd150: _toneR = `hf;   12'd151: _toneR = `hf;
                    12'd152: _toneR = `hf;   12'd153: _toneR = `hf;
                    12'd154: _toneR = `hf;   12'd155: _toneR = `hf;
                    12'd156: _toneR = `hf;   12'd157: _toneR = `hf;
                    12'd158: _toneR = `hf;   12'd159: _toneR = `hf;

                    12'd160: _toneR = `hg;   12'd161: _toneR = `hg;
                    12'd162: _toneR = `hg;   12'd163: _toneR = `hg;
                    12'd164: _toneR = `hg;   12'd165: _toneR = `hg;
                    12'd166: _toneR = `hg;   12'd167: _toneR = `hg;
                    12'd168: _toneR = `hg;   12'd169: _toneR = `hg;
                    12'd170: _toneR = `hg;   12'd171: _toneR = `hg;
                    12'd172: _toneR = `hg;   12'd173: _toneR = `hg;
                    12'd174: _toneR = `hg;   12'd175: _toneR = `hg;

                    12'd176: _toneR = `hg;   12'd177: _toneR = `hg;
                    12'd178: _toneR = `hg;   12'd179: _toneR = `hg;
                    12'd180: _toneR = `hg;   12'd181: _toneR = `hg;
                    12'd182: _toneR = `hg;   12'd183: _toneR = `hg;
                    12'd184: _toneR = `hg;   12'd185: _toneR = `hg;
                    12'd186: _toneR = `hg;   12'd187: _toneR = `hg;
                    12'd188: _toneR = `hg;   12'd189: _toneR = `hg;
                    12'd190: _toneR = `hg;   12'd191: _toneR = `sil;

                    // --- Measure 4 ---
                    12'd192: _toneR = `he;   12'd193: _toneR = `he;
                    12'd194: _toneR = `he;   12'd195: _toneR = `he;
                    12'd196: _toneR = `he;   12'd197: _toneR = `he;
                    12'd198: _toneR = `he;   12'd199: _toneR = `he;
                    12'd200: _toneR = `he;   12'd201: _toneR = `he;
                    12'd202: _toneR = `he;   12'd203: _toneR = `he;
                    12'd204: _toneR = `he;   12'd205: _toneR = `he;
                    12'd206: _toneR = `he;   12'd207: _toneR = `sil;

                    12'd208: _toneR = `hf;   12'd209: _toneR = `hf;
                    12'd210: _toneR = `hf;   12'd211: _toneR = `hf;
                    12'd212: _toneR = `hf;   12'd213: _toneR = `hf;
                    12'd214: _toneR = `hf;   12'd215: _toneR = `hf;
                    12'd216: _toneR = `hf;   12'd217: _toneR = `hf;
                    12'd218: _toneR = `hf;   12'd219: _toneR = `hf;
                    12'd220: _toneR = `hf;   12'd221: _toneR = `hf;
                    12'd222: _toneR = `hf;   12'd223: _toneR = `sil;

                    12'd224: _toneR = `hg;   12'd225: _toneR = `hg;
                    12'd226: _toneR = `hg;   12'd227: _toneR = `hg;
                    12'd228: _toneR = `hg;   12'd229: _toneR = `hg;
                    12'd230: _toneR = `hg;   12'd231: _toneR = `hg;
                    12'd232: _toneR = `hg;   12'd233: _toneR = `hg;
                    12'd234: _toneR = `hg;   12'd235: _toneR = `hg;
                    12'd236: _toneR = `hg;   12'd237: _toneR = `hg;
                    12'd238: _toneR = `hg;   12'd239: _toneR = `hg;

                    12'd240: _toneR = `hg;   12'd241: _toneR = `hg;
                    12'd242: _toneR = `hg;   12'd243: _toneR = `hg;
                    12'd244: _toneR = `hg;   12'd245: _toneR = `hg;
                    12'd246: _toneR = `hg;   12'd247: _toneR = `hg;
                    12'd248: _toneR = `hg;   12'd249: _toneR = `hg;
                    12'd250: _toneR = `hg;   12'd251: _toneR = `hg;
                    12'd252: _toneR = `hg;   12'd253: _toneR = `hg;
                    12'd254: _toneR = `hg;   12'd255: _toneR = `sil;

                    // --- Measure 5 ---
                    12'd256: _toneR = `hg;   12'd257: _toneR = `hg;
                    12'd258: _toneR = `hg;   12'd259: _toneR = `hg;
                    12'd260: _toneR = `hg;   12'd261: _toneR = `hg;
                    12'd262: _toneR = `hg;   12'd263: _toneR = `hg;
                    12'd264: _toneR = `ha;   12'd265: _toneR = `ha;
                    12'd266: _toneR = `ha;   12'd267: _toneR = `ha;
                    12'd268: _toneR = `ha;   12'd269: _toneR = `ha;
                    12'd270: _toneR = `ha;   12'd271: _toneR = `ha;

                    12'd272: _toneR = `hg;   12'd273: _toneR = `hg;
                    12'd274: _toneR = `hg;   12'd275: _toneR = `hg;
                    12'd276: _toneR = `hg;   12'd277: _toneR = `hg;
                    12'd278: _toneR = `hg;   12'd279: _toneR = `hg;
                    12'd280: _toneR = `hf;   12'd281: _toneR = `hf;
                    12'd282: _toneR = `hf;   12'd283: _toneR = `hf;
                    12'd284: _toneR = `hf;   12'd285: _toneR = `hf;
                    12'd286: _toneR = `hf;   12'd287: _toneR = `sil;

                    12'd288: _toneR = `he;   12'd289: _toneR = `he;
                    12'd290: _toneR = `he;   12'd291: _toneR = `he;
                    12'd292: _toneR = `he;   12'd293: _toneR = `he;
                    12'd294: _toneR = `he;   12'd295: _toneR = `he;
                    12'd296: _toneR = `he;   12'd297: _toneR = `he;
                    12'd298: _toneR = `he;   12'd299: _toneR = `he;
                    12'd300: _toneR = `he;   12'd301: _toneR = `he;
                    12'd302: _toneR = `he;   12'd303: _toneR = `sil;

                    12'd304: _toneR = `hc;   12'd305: _toneR = `hc;
                    12'd306: _toneR = `hc;   12'd307: _toneR = `hc;
                    12'd308: _toneR = `hc;   12'd309: _toneR = `hc;
                    12'd310: _toneR = `hc;   12'd311: _toneR = `hc;
                    12'd312: _toneR = `hc;   12'd313: _toneR = `hc;
                    12'd314: _toneR = `hc;   12'd315: _toneR = `hc;
                    12'd316: _toneR = `hc;   12'd317: _toneR = `hc;
                    12'd318: _toneR = `hc;   12'd319: _toneR = `sil;

                    // --- Measure 6 ---
                    12'd320: _toneR = `hg;   12'd321: _toneR = `hg;
                    12'd322: _toneR = `hg;   12'd323: _toneR = `hg;
                    12'd324: _toneR = `hg;   12'd325: _toneR = `hg;
                    12'd326: _toneR = `hg;   12'd327: _toneR = `hg;
                    12'd328: _toneR = `ha;   12'd329: _toneR = `ha;
                    12'd330: _toneR = `ha;   12'd331: _toneR = `ha;
                    12'd332: _toneR = `ha;   12'd333: _toneR = `ha;
                    12'd334: _toneR = `ha;   12'd335: _toneR = `ha;

                    12'd336: _toneR = `hg;   12'd337: _toneR = `hg;
                    12'd338: _toneR = `hg;   12'd339: _toneR = `hg;
                    12'd340: _toneR = `hg;   12'd341: _toneR = `hg;
                    12'd342: _toneR = `hg;   12'd343: _toneR = `hg;
                    12'd344: _toneR = `hf;   12'd345: _toneR = `hf;
                    12'd346: _toneR = `hf;   12'd347: _toneR = `hf;
                    12'd348: _toneR = `hf;   12'd349: _toneR = `hf;
                    12'd350: _toneR = `hf;   12'd351: _toneR = `hf;

                    12'd352: _toneR = `he;   12'd353: _toneR = `he;
                    12'd354: _toneR = `he;   12'd355: _toneR = `he;
                    12'd356: _toneR = `he;   12'd357: _toneR = `he;
                    12'd358: _toneR = `he;   12'd359: _toneR = `he;
                    12'd360: _toneR = `he;   12'd361: _toneR = `he;
                    12'd362: _toneR = `he;   12'd363: _toneR = `he;
                    12'd364: _toneR = `he;   12'd365: _toneR = `he;
                    12'd366: _toneR = `he;   12'd367: _toneR = `sil;

                    12'd368: _toneR = `hc;   12'd369: _toneR = `hc;
                    12'd370: _toneR = `hc;   12'd371: _toneR = `hc;
                    12'd372: _toneR = `hc;   12'd373: _toneR = `hc;
                    12'd374: _toneR = `hc;   12'd375: _toneR = `hc;
                    12'd376: _toneR = `hc;   12'd377: _toneR = `hc;
                    12'd378: _toneR = `hc;   12'd379: _toneR = `hc;
                    12'd380: _toneR = `hc;   12'd381: _toneR = `hc;
                    12'd382: _toneR = `hc;   12'd383: _toneR = `sil;

                    // --- Measure 7 ---
                    12'd384: _toneR = `hc;   12'd385: _toneR = `hc;
                    12'd386: _toneR = `hc;   12'd387: _toneR = `hc;
                    12'd388: _toneR = `hc;   12'd389: _toneR = `hc;
                    12'd390: _toneR = `hc;   12'd391: _toneR = `hc;
                    12'd392: _toneR = `hc;   12'd393: _toneR = `hc;
                    12'd394: _toneR = `hc;   12'd395: _toneR = `hc;
                    12'd396: _toneR = `hc;   12'd397: _toneR = `hc;
                    12'd398: _toneR = `hc;   12'd399: _toneR = `sil;

                    12'd400: _toneR = `g;   12'd401: _toneR = `g;
                    12'd402: _toneR = `g;   12'd403: _toneR = `g;
                    12'd404: _toneR = `g;   12'd405: _toneR = `g;
                    12'd406: _toneR = `g;   12'd407: _toneR = `g;
                    12'd408: _toneR = `g;   12'd409: _toneR = `g;
                    12'd410: _toneR = `g;   12'd411: _toneR = `g;
                    12'd412: _toneR = `g;   12'd413: _toneR = `g;
                    12'd414: _toneR = `g;   12'd415: _toneR = `sil;

                    12'd416: _toneR = `hc;   12'd417: _toneR = `hc;
                    12'd418: _toneR = `hc;   12'd419: _toneR = `hc;
                    12'd420: _toneR = `hc;   12'd421: _toneR = `hc;
                    12'd422: _toneR = `hc;   12'd423: _toneR = `hc;
                    12'd424: _toneR = `hc;   12'd425: _toneR = `hc;
                    12'd426: _toneR = `hc;   12'd427: _toneR = `hc;
                    12'd428: _toneR = `hc;   12'd429: _toneR = `hc;
                    12'd430: _toneR = `hc;   12'd431: _toneR = `hc;

                    12'd432: _toneR = `hc;   12'd433: _toneR = `hc;
                    12'd434: _toneR = `hc;   12'd435: _toneR = `hc;
                    12'd436: _toneR = `hc;   12'd437: _toneR = `hc;
                    12'd438: _toneR = `hc;   12'd439: _toneR = `hc;
                    12'd440: _toneR = `hc;   12'd441: _toneR = `hc;
                    12'd442: _toneR = `hc;   12'd443: _toneR = `hc;
                    12'd444: _toneR = `hc;   12'd445: _toneR = `hc;
                    12'd446: _toneR = `hc;   12'd447: _toneR = `sil;

                    // --- Measure 8 ---
                    12'd448: _toneR = `hc;   12'd449: _toneR = `hc;
                    12'd450: _toneR = `hc;   12'd451: _toneR = `hc;
                    12'd452: _toneR = `hc;   12'd453: _toneR = `hc;
                    12'd454: _toneR = `hc;   12'd455: _toneR = `hc;
                    12'd456: _toneR = `hc;   12'd457: _toneR = `hc;
                    12'd458: _toneR = `hc;   12'd459: _toneR = `hc;
                    12'd460: _toneR = `hc;   12'd461: _toneR = `hc;
                    12'd462: _toneR = `hc;   12'd463: _toneR = `sil;

                    12'd464: _toneR = `g;   12'd465: _toneR = `g;
                    12'd466: _toneR = `g;   12'd467: _toneR = `g;
                    12'd468: _toneR = `g;   12'd469: _toneR = `g;
                    12'd470: _toneR = `g;   12'd471: _toneR = `g;
                    12'd472: _toneR = `g;   12'd473: _toneR = `g;
                    12'd474: _toneR = `g;   12'd475: _toneR = `g;
                    12'd476: _toneR = `g;   12'd477: _toneR = `g;
                    12'd478: _toneR = `g;   12'd479: _toneR = `sil;

                    12'd480: _toneR = `hc;   12'd481: _toneR = `hc;
                    12'd482: _toneR = `hc;   12'd483: _toneR = `hc;
                    12'd484: _toneR = `hc;   12'd485: _toneR = `hc;
                    12'd486: _toneR = `hc;   12'd487: _toneR = `hc;
                    12'd488: _toneR = `hc;   12'd489: _toneR = `hc;
                    12'd490: _toneR = `hc;   12'd491: _toneR = `hc;
                    12'd492: _toneR = `hc;   12'd493: _toneR = `hc;
                    12'd494: _toneR = `hc;   12'd495: _toneR = `hc;

                    12'd496: _toneR = `hc;   12'd497: _toneR = `hc;
                    12'd498: _toneR = `hc;   12'd499: _toneR = `hc;
                    12'd500: _toneR = `hc;   12'd501: _toneR = `hc;
                    12'd502: _toneR = `hc;   12'd503: _toneR = `hc;
                    12'd504: _toneR = `hc;   12'd505: _toneR = `hc;
                    12'd506: _toneR = `hc;   12'd507: _toneR = `hc;
                    12'd508: _toneR = `hc;   12'd509: _toneR = `hc;
                    12'd510: _toneR = `hc;   12'd511: _toneR = `sil;
                    default: _toneR = `sil;
                endcase
            end else begin
                _toneR = `sil;
            end
        end

        always @(*) begin
            if(play == 1 && music == 1'b0)begin
                case(ibeatNum)
                    // --- Measure 1 ---
                    12'd0: _toneL = `hc;   12'd1: _toneL = `hc;
                    12'd2: _toneL = `hc;   12'd3: _toneL = `hc;
                    12'd4: _toneL = `hc;   12'd5: _toneL = `hc;
                    12'd6: _toneL = `hc;   12'd7: _toneL = `hc;
                    12'd8: _toneL = `hc;   12'd9: _toneL = `hc;
                    12'd10: _toneL = `hc;   12'd11: _toneL = `hc;
                    12'd12: _toneL = `hc;   12'd13: _toneL = `hc;
                    12'd14: _toneL = `hc;   12'd15: _toneL = `hc;

                    12'd16: _toneL = `hc;   12'd17: _toneL = `hc;
                    12'd18: _toneL = `hc;   12'd19: _toneL = `hc;
                    12'd20: _toneL = `hc;   12'd21: _toneL = `hc;
                    12'd22: _toneL = `hc;   12'd23: _toneL = `hc;
                    12'd24: _toneL = `hc;   12'd25: _toneL = `hc;
                    12'd26: _toneL = `hc;   12'd27: _toneL = `hc;
                    12'd28: _toneL = `hc;   12'd29: _toneL = `hc;
                    12'd30: _toneL = `hc;   12'd31: _toneL = `sil;

                    12'd32: _toneL = `g;	12'd33: _toneL = `g; // G (one-beat)
                    12'd34: _toneL = `g;	12'd35: _toneL = `g;
                    12'd36: _toneL = `g;	12'd37: _toneL = `g;
                    12'd38: _toneL = `g;	12'd39: _toneL = `g;
                    12'd40: _toneL = `g;	12'd41: _toneL = `g;
                    12'd42: _toneL = `g;	12'd43: _toneL = `g;
                    12'd44: _toneL = `g;	12'd45: _toneL = `g;
                    12'd46: _toneL = `g;	12'd47: _toneL = `g;

                    12'd48: _toneL = `g;   12'd49: _toneL = `g;
                    12'd50: _toneL = `g;   12'd51: _toneL = `g;
                    12'd52: _toneL = `g;   12'd53: _toneL = `g;
                    12'd54: _toneL = `g;   12'd55: _toneL = `g;
                    12'd56: _toneL = `g;   12'd57: _toneL = `g;
                    12'd58: _toneL = `g;   12'd59: _toneL = `g;
                    12'd60: _toneL = `g;   12'd61: _toneL = `g;
                    12'd62: _toneL = `g;   12'd63: _toneL = `sil;

                    // --- Measure 2 ---
                    12'd64: _toneL = `hc;	    12'd65: _toneL = `hc; // HC (two-beat)
                    12'd66: _toneL = `hc;	    12'd67: _toneL = `hc;
                    12'd68: _toneL = `hc;	    12'd69: _toneL = `hc;
                    12'd70: _toneL = `hc;	    12'd71: _toneL = `hc;
                    12'd72: _toneL = `hc;	    12'd73: _toneL = `hc;
                    12'd74: _toneL = `hc;	    12'd75: _toneL = `hc;
                    12'd76: _toneL = `hc;	    12'd77: _toneL = `hc;
                    12'd78: _toneL = `hc;	    12'd79: _toneL = `hc;

                    12'd80: _toneL = `hc;	    12'd81: _toneL = `hc;
                    12'd82: _toneL = `hc;	    12'd83: _toneL = `hc;
                    12'd84: _toneL = `hc;	    12'd85: _toneL = `hc;
                    12'd86: _toneL = `hc;	    12'd87: _toneL = `hc;
                    12'd88: _toneL = `hc;	    12'd89: _toneL = `hc;
                    12'd90: _toneL = `hc;	    12'd91: _toneL = `hc;
                    12'd92: _toneL = `hc;	    12'd93: _toneL = `hc;
                    12'd94: _toneL = `hc;	    12'd95: _toneL = `sil;

                    12'd96: _toneL = `g;	12'd97: _toneL = `g; // G (one-beat)
                    12'd98: _toneL = `g; 	12'd99: _toneL = `g;
                    12'd100: _toneL = `g;	12'd101: _toneL = `g;
                    12'd102: _toneL = `g;	12'd103: _toneL = `g;
                    12'd104: _toneL = `g;	12'd105: _toneL = `g;
                    12'd106: _toneL = `g;	12'd107: _toneL = `g;
                    12'd108: _toneL = `g;	12'd109: _toneL = `g;
                    12'd110: _toneL = `g;	12'd111: _toneL = `g;

                    12'd112: _toneL = `g;   12'd113: _toneL = `g;
                    12'd114: _toneL = `g;   12'd115: _toneL = `g;
                    12'd116: _toneL = `g;   12'd117: _toneL = `g;
                    12'd118: _toneL = `g;   12'd119: _toneL = `g;
                    12'd120: _toneL = `g;   12'd121: _toneL = `g;
                    12'd122: _toneL = `g;   12'd123: _toneL = `g;
                    12'd124: _toneL = `g;   12'd125: _toneL = `g;
                    12'd126: _toneL = `g;   12'd127: _toneL = `sil;

                    // --- Measure 3 ---
                    12'd128: _toneL = `c;   12'd129: _toneL = `c;
                    12'd130: _toneL = `c;   12'd131: _toneL = `c;
                    12'd132: _toneL = `c;   12'd133: _toneL = `c;
                    12'd134: _toneL = `c;   12'd135: _toneL = `c;
                    12'd136: _toneL = `c;   12'd137: _toneL = `c;
                    12'd138: _toneL = `c;   12'd139: _toneL = `c;
                    12'd140: _toneL = `c;   12'd141: _toneL = `c;
                    12'd142: _toneL = `c;   12'd143: _toneL = `sil;

                    12'd144: _toneL = `d;   12'd145: _toneL = `d;
                    12'd146: _toneL = `d;   12'd147: _toneL = `d;
                    12'd148: _toneL = `d;   12'd149: _toneL = `d;
                    12'd150: _toneL = `d;   12'd151: _toneL = `d;
                    12'd152: _toneL = `d;   12'd153: _toneL = `d;
                    12'd154: _toneL = `d;   12'd155: _toneL = `d;
                    12'd156: _toneL = `d;   12'd157: _toneL = `d;
                    12'd158: _toneL = `d;   12'd159: _toneL = `sil;

                    12'd160: _toneL = `e;   12'd161: _toneL = `e;
                    12'd162: _toneL = `e;   12'd163: _toneL = `e;
                    12'd164: _toneL = `e;   12'd165: _toneL = `e;
                    12'd166: _toneL = `e;   12'd167: _toneL = `e;
                    12'd168: _toneL = `e;   12'd169: _toneL = `e;
                    12'd170: _toneL = `e;   12'd171: _toneL = `e;
                    12'd172: _toneL = `e;   12'd173: _toneL = `e;
                    12'd174: _toneL = `e;   12'd175: _toneL = `e;

                    12'd176: _toneL = `e;   12'd177: _toneL = `e;
                    12'd178: _toneL = `e;   12'd179: _toneL = `e;
                    12'd180: _toneL = `e;   12'd181: _toneL = `e;
                    12'd182: _toneL = `e;   12'd183: _toneL = `e;
                    12'd184: _toneL = `e;   12'd185: _toneL = `e;
                    12'd186: _toneL = `e;   12'd187: _toneL = `e;
                    12'd188: _toneL = `e;   12'd189: _toneL = `e;
                    12'd190: _toneL = `e;   12'd191: _toneL = `sil;

                    // --- Measure 4 ---
                    12'd192: _toneL = `c;   12'd193: _toneL = `c;
                    12'd194: _toneL = `c;   12'd195: _toneL = `c;
                    12'd196: _toneL = `c;   12'd197: _toneL = `c;
                    12'd198: _toneL = `c;   12'd199: _toneL = `c;
                    12'd200: _toneL = `c;   12'd201: _toneL = `c;
                    12'd202: _toneL = `c;   12'd203: _toneL = `c;
                    12'd204: _toneL = `c;   12'd205: _toneL = `c;
                    12'd206: _toneL = `c;   12'd207: _toneL = `sil;

                    12'd208: _toneL = `d;   12'd209: _toneL = `d;
                    12'd210: _toneL = `d;   12'd211: _toneL = `d;
                    12'd212: _toneL = `d;   12'd213: _toneL = `d;
                    12'd214: _toneL = `d;   12'd215: _toneL = `d;
                    12'd216: _toneL = `d;   12'd217: _toneL = `d;
                    12'd218: _toneL = `d;   12'd219: _toneL = `d;
                    12'd220: _toneL = `d;   12'd221: _toneL = `d;
                    12'd222: _toneL = `d;   12'd223: _toneL = `sil;

                    12'd224: _toneL = `e;   12'd225: _toneL = `e;
                    12'd226: _toneL = `e;   12'd227: _toneL = `e;
                    12'd228: _toneL = `e;   12'd229: _toneL = `e;
                    12'd230: _toneL = `e;   12'd231: _toneL = `e;
                    12'd232: _toneL = `e;   12'd233: _toneL = `e;
                    12'd234: _toneL = `e;   12'd235: _toneL = `e;
                    12'd236: _toneL = `e;   12'd237: _toneL = `e;
                    12'd238: _toneL = `e;   12'd239: _toneL = `e;

                    12'd240: _toneL = `e;   12'd241: _toneL = `e;
                    12'd242: _toneL = `e;   12'd243: _toneL = `e;
                    12'd244: _toneL = `e;   12'd245: _toneL = `e;
                    12'd246: _toneL = `e;   12'd247: _toneL = `e;
                    12'd248: _toneL = `e;   12'd249: _toneL = `e;
                    12'd250: _toneL = `e;   12'd251: _toneL = `e;
                    12'd252: _toneL = `e;   12'd253: _toneL = `e;
                    12'd254: _toneL = `e;   12'd255: _toneL = `sil;

                    // --- Measure 5 ---
                    12'd256: _toneL = `e;   12'd257: _toneL = `e;
                    12'd258: _toneL = `e;   12'd259: _toneL = `e;
                    12'd260: _toneL = `e;   12'd261: _toneL = `e;
                    12'd262: _toneL = `e;   12'd263: _toneL = `e;
                    12'd264: _toneL = `e;   12'd265: _toneL = `e;
                    12'd266: _toneL = `e;   12'd267: _toneL = `e;
                    12'd268: _toneL = `e;   12'd269: _toneL = `e;
                    12'd270: _toneL = `e;   12'd271: _toneL = `sil;

                    12'd272: _toneL = `f;   12'd273: _toneL = `f;
                    12'd274: _toneL = `f;   12'd275: _toneL = `f;
                    12'd276: _toneL = `f;   12'd277: _toneL = `f;
                    12'd278: _toneL = `f;   12'd279: _toneL = `f;
                    12'd280: _toneL = `f;   12'd281: _toneL = `f;
                    12'd282: _toneL = `f;   12'd283: _toneL = `f;
                    12'd284: _toneL = `f;   12'd285: _toneL = `f;
                    12'd286: _toneL = `f;   12'd287: _toneL = `sil;

                    12'd288: _toneL = `g;   12'd289: _toneL = `g;
                    12'd290: _toneL = `g;   12'd291: _toneL = `g;
                    12'd292: _toneL = `g;   12'd293: _toneL = `g;
                    12'd294: _toneL = `g;   12'd295: _toneL = `g;
                    12'd296: _toneL = `g;   12'd297: _toneL = `g;
                    12'd298: _toneL = `g;   12'd299: _toneL = `g;
                    12'd300: _toneL = `g;   12'd301: _toneL = `g;
                    12'd302: _toneL = `g;   12'd303: _toneL = `g;

                    12'd304: _toneL = `g;   12'd305: _toneL = `g;
                    12'd306: _toneL = `g;   12'd307: _toneL = `g;
                    12'd308: _toneL = `g;   12'd309: _toneL = `g;
                    12'd310: _toneL = `g;   12'd311: _toneL = `g;
                    12'd312: _toneL = `g;   12'd313: _toneL = `g;
                    12'd314: _toneL = `g;   12'd315: _toneL = `g;
                    12'd316: _toneL = `g;   12'd317: _toneL = `g;
                    12'd318: _toneL = `g;   12'd319: _toneL = `sil;

                    // --- Measure 6 ---
                    12'd320: _toneL = `e;   12'd321: _toneL = `e;
                    12'd322: _toneL = `e;   12'd323: _toneL = `e;
                    12'd324: _toneL = `e;   12'd325: _toneL = `e;
                    12'd326: _toneL = `e;   12'd327: _toneL = `e;
                    12'd328: _toneL = `e;   12'd329: _toneL = `e;
                    12'd330: _toneL = `e;   12'd331: _toneL = `e;
                    12'd332: _toneL = `e;   12'd333: _toneL = `e;
                    12'd334: _toneL = `e;   12'd335: _toneL = `sil;

                    12'd336: _toneL = `f;   12'd337: _toneL = `f;
                    12'd338: _toneL = `f;   12'd339: _toneL = `f;
                    12'd340: _toneL = `f;   12'd341: _toneL = `f;
                    12'd342: _toneL = `f;   12'd343: _toneL = `f;
                    12'd344: _toneL = `f;   12'd345: _toneL = `f;
                    12'd346: _toneL = `f;   12'd347: _toneL = `f;
                    12'd348: _toneL = `f;   12'd349: _toneL = `f;
                    12'd350: _toneL = `f;   12'd351: _toneL = `sil;

                    12'd352: _toneL = `g;   12'd353: _toneL = `g;
                    12'd354: _toneL = `g;   12'd355: _toneL = `g;
                    12'd356: _toneL = `g;   12'd357: _toneL = `g;
                    12'd358: _toneL = `g;   12'd359: _toneL = `g;
                    12'd360: _toneL = `g;   12'd361: _toneL = `g;
                    12'd362: _toneL = `g;   12'd363: _toneL = `g;
                    12'd364: _toneL = `g;   12'd365: _toneL = `g;
                    12'd366: _toneL = `g;   12'd367: _toneL = `g;

                    12'd368: _toneL = `g;   12'd369: _toneL = `g;
                    12'd370: _toneL = `g;   12'd371: _toneL = `g;
                    12'd372: _toneL = `g;   12'd373: _toneL = `g;
                    12'd374: _toneL = `g;   12'd375: _toneL = `g;
                    12'd376: _toneL = `g;   12'd377: _toneL = `g;
                    12'd378: _toneL = `g;   12'd379: _toneL = `g;
                    12'd380: _toneL = `g;   12'd381: _toneL = `g;
                    12'd382: _toneL = `g;   12'd383: _toneL = `sil;

                    // --- Measure 7 ---
                    12'd384: _toneL = `g;   12'd385: _toneL = `g;
                    12'd386: _toneL = `g;   12'd387: _toneL = `g;
                    12'd388: _toneL = `g;   12'd389: _toneL = `g;
                    12'd390: _toneL = `g;   12'd391: _toneL = `g;
                    12'd392: _toneL = `g;   12'd393: _toneL = `g;
                    12'd394: _toneL = `g;   12'd395: _toneL = `g;
                    12'd396: _toneL = `g;   12'd397: _toneL = `g;
                    12'd398: _toneL = `g;   12'd399: _toneL = `g;

                    12'd400: _toneL = `g;   12'd401: _toneL = `g;
                    12'd402: _toneL = `g;   12'd403: _toneL = `g;
                    12'd404: _toneL = `g;   12'd405: _toneL = `g;
                    12'd406: _toneL = `g;   12'd407: _toneL = `g;
                    12'd408: _toneL = `g;   12'd409: _toneL = `g;
                    12'd410: _toneL = `g;   12'd411: _toneL = `g;
                    12'd412: _toneL = `g;   12'd413: _toneL = `g;
                    12'd414: _toneL = `g;   12'd415: _toneL = `sil;

                    12'd416: _toneL = `e;   12'd417: _toneL = `e;
                    12'd418: _toneL = `e;   12'd419: _toneL = `e;
                    12'd420: _toneL = `e;   12'd421: _toneL = `e;
                    12'd422: _toneL = `e;   12'd423: _toneL = `e;
                    12'd424: _toneL = `e;   12'd425: _toneL = `e;
                    12'd426: _toneL = `e;   12'd427: _toneL = `e;
                    12'd428: _toneL = `e;   12'd429: _toneL = `e;
                    12'd430: _toneL = `e;   12'd431: _toneL = `e;

                    12'd432: _toneL = `e;   12'd433: _toneL = `e;
                    12'd434: _toneL = `e;   12'd435: _toneL = `e;
                    12'd436: _toneL = `e;   12'd437: _toneL = `e;
                    12'd438: _toneL = `e;   12'd439: _toneL = `e;
                    12'd440: _toneL = `e;   12'd441: _toneL = `e;
                    12'd442: _toneL = `e;   12'd443: _toneL = `e;
                    12'd444: _toneL = `e;   12'd445: _toneL = `e;
                    12'd446: _toneL = `e;   12'd447: _toneL = `sil;

                    // --- Measure 8 ---
                    12'd448: _toneL = `g;   12'd449: _toneL = `g;
                    12'd450: _toneL = `g;   12'd451: _toneL = `g;
                    12'd452: _toneL = `g;   12'd453: _toneL = `g;
                    12'd454: _toneL = `g;   12'd455: _toneL = `g;
                    12'd456: _toneL = `g;   12'd457: _toneL = `g;
                    12'd458: _toneL = `g;   12'd459: _toneL = `g;
                    12'd460: _toneL = `g;   12'd461: _toneL = `g;
                    12'd462: _toneL = `g;   12'd463: _toneL = `g;

                    12'd464: _toneL = `g;   12'd465: _toneL = `g;
                    12'd466: _toneL = `g;   12'd467: _toneL = `g;
                    12'd468: _toneL = `g;   12'd469: _toneL = `g;
                    12'd470: _toneL = `g;   12'd471: _toneL = `g;
                    12'd472: _toneL = `g;   12'd473: _toneL = `g;
                    12'd474: _toneL = `g;   12'd475: _toneL = `g;
                    12'd476: _toneL = `g;   12'd477: _toneL = `g;
                    12'd478: _toneL = `g;   12'd479: _toneL = `sil;

                    12'd480: _toneL = `e;   12'd481: _toneL = `e;
                    12'd482: _toneL = `e;   12'd483: _toneL = `e;
                    12'd484: _toneL = `e;   12'd485: _toneL = `e;
                    12'd486: _toneL = `e;   12'd487: _toneL = `e;
                    12'd488: _toneL = `e;   12'd489: _toneL = `e;
                    12'd490: _toneL = `e;   12'd491: _toneL = `e;
                    12'd492: _toneL = `e;   12'd493: _toneL = `e;
                    12'd494: _toneL = `e;   12'd495: _toneL = `e;

                    12'd496: _toneL = `e;   12'd497: _toneL = `e;
                    12'd498: _toneL = `e;   12'd499: _toneL = `e;
                    12'd500: _toneL = `e;   12'd501: _toneL = `e;
                    12'd502: _toneL = `e;   12'd503: _toneL = `e;
                    12'd504: _toneL = `e;   12'd505: _toneL = `e;
                    12'd506: _toneL = `e;   12'd507: _toneL = `e;
                    12'd508: _toneL = `e;   12'd509: _toneL = `e;
                    12'd510: _toneL = `e;   12'd511: _toneL = `e;

                    default : _toneL = `sil;
                endcase
            end
            else begin
                _toneL = `sil;
            end
        end

        always@(*) begin
            if(music == 1'b1) begin
                case(toneR)
                    `ha: note = `A;
                    `hb: note = `B;
                    `hc: note = `C;
                    `hd: note = `D;
                    `he: note = `E;
                    `hf: note = `F;
                    `hg: note = `G;
                    default: note = note;
                endcase
                if(reset == 1'b1) begin
                    note = 3'b0;
                end
            end
            else if(music == 1'b0) begin
                case(_toneR)
                    `ha: note = `A;
                    `hb: note = `B;
                    `hc: note = `C;
                    `hd: note = `D;
                    `he: note = `E;
                    `hf: note = `F;
                    `hg: note = `G;
                    `g: note = `G;
                    default: note = note;
                endcase
                if(reset == 1'b1) begin
                    note = 3'b0;
                end
            end
        end

    endmodule

    module speaker_control(
        clk,  // clock from the crystal
        rst,  // active high reset
        audio_in_left, // left channel audio data input
        audio_in_right, // right channel audio data input
        audio_mclk, // master clock
        audio_lrck, // left-right clock, Word Select clock, or sample rate clock
        audio_sck, // serial clock
        audio_sdin // serial audio data input
    );

        // I/O declaration
        input clk;  // clock from the crystal
        input rst;  // active high reset
        input [15:0] audio_in_left; // left channel audio data input
        input [15:0] audio_in_right; // right channel audio data input
        output audio_mclk; // master clock
        output audio_lrck; // left-right clock
        output audio_sck; // serial clock
        output audio_sdin; // serial audio data input
        reg audio_sdin;

        // Declare internal signal nodes
        wire [8:0] clk_cnt_next;
        reg [8:0] clk_cnt;
        reg [15:0] audio_left, audio_right;

        // Counter for the clock divider
        assign clk_cnt_next = clk_cnt + 1'b1;

        always @(posedge clk or posedge rst)
            if (rst == 1'b1)
                clk_cnt <= 9'd0;
            else
                clk_cnt <= clk_cnt_next;

        // Assign divided clock output
        assign audio_mclk = clk_cnt[1];
        assign audio_lrck = clk_cnt[8];
        assign audio_sck = 1'b1; // use internal serial clock mode

        // audio input data buffer
        always @(posedge clk_cnt[8] or posedge rst)
            if (rst == 1'b1)
                begin
                    audio_left <= 16'd0;
                    audio_right <= 16'd0;
                end
            else
                begin
                    audio_left <= audio_in_left;
                    audio_right <= audio_in_right;
                end

        always @*
            case (clk_cnt[8:4])
                5'b00000: audio_sdin = audio_right[0];
                5'b00001: audio_sdin = audio_left[15];
                5'b00010: audio_sdin = audio_left[14];
                5'b00011: audio_sdin = audio_left[13];
                5'b00100: audio_sdin = audio_left[12];
                5'b00101: audio_sdin = audio_left[11];
                5'b00110: audio_sdin = audio_left[10];
                5'b00111: audio_sdin = audio_left[9];
                5'b01000: audio_sdin = audio_left[8];
                5'b01001: audio_sdin = audio_left[7];
                5'b01010: audio_sdin = audio_left[6];
                5'b01011: audio_sdin = audio_left[5];
                5'b01100: audio_sdin = audio_left[4];
                5'b01101: audio_sdin = audio_left[3];
                5'b01110: audio_sdin = audio_left[2];
                5'b01111: audio_sdin = audio_left[1];
                5'b10000: audio_sdin = audio_left[0];
                5'b10001: audio_sdin = audio_right[15];
                5'b10010: audio_sdin = audio_right[14];
                5'b10011: audio_sdin = audio_right[13];
                5'b10100: audio_sdin = audio_right[12];
                5'b10101: audio_sdin = audio_right[11];
                5'b10110: audio_sdin = audio_right[10];
                5'b10111: audio_sdin = audio_right[9];
                5'b11000: audio_sdin = audio_right[8];
                5'b11001: audio_sdin = audio_right[7];
                5'b11010: audio_sdin = audio_right[6];
                5'b11011: audio_sdin = audio_right[5];
                5'b11100: audio_sdin = audio_right[4];
                5'b11101: audio_sdin = audio_right[3];
                5'b11110: audio_sdin = audio_right[2];
                5'b11111: audio_sdin = audio_right[1];
                default: audio_sdin = 1'b0;
            endcase

    endmodule

    module lab08(
        clk, // clock from crystal
        rst, // active high reset: BTNC
        _play, // SW: Play/Pause
        _mute, // SW: Mute
        _repeat, // SW: Repeat
        _music, // SW: Music
        _volUP, // BTN: Vol up
        _volDOWN, // BTN: Vol down
        _led_vol, // LED: volume
        audio_mclk, // master clock
        audio_lrck, // left-right clock
        audio_sck, // serial clock
        audio_sdin, // serial audio data input
        DISPLAY, // 7-seg
        DIGIT // 7-seg
    );

        // I/O declaration
        input clk;  // clock from the crystal
        input rst;  // active high reset
        input wire _play, _mute, _repeat, _music, _volUP, _volDOWN;
        output [4:0] _led_vol;
        output audio_mclk; // master clock
        output audio_lrck; // left-right clock
        output audio_sck; // serial clock
        output audio_sdin; // serial audio data input
        output reg [6:0] DISPLAY;
        output reg [3:0] DIGIT;

        // Modify these

        //assign DIGIT = 4'b0001;
        //assign DISPLAY = 7'b111_1111;

        // Internal Signal
        wire [15:0] audio_in_left, audio_in_right;

        wire clkDiv22, play, clkDiv13, pb_volUP, pulse_volUP, pb_volDOWN, pulse_volDOWN, _en;
        wire [11:0] ibeatNum; // Beat counter
        wire [31:0] freqL, freqR, _freqL, _freqR; // Raw frequency, produced by music module
        wire [21:0] freq_outL, freq_outR; // Processed Frequency, adapted to the clock rate of Basys3

        reg [2:0] value, vol, next_vol;
        wire [2:0] _vol, note;

        debounce de_volUP(.pb_debounced(pb_volUP), .pb(_volUP), .clk(clkDiv13));
        onepulse pul_volUP(.rst(rst), .clk(clkDiv13), .pb_debounced(pb_volUP), .pb_1pulse(pulse_volUP));

        debounce de_volDOWN(.pb_debounced(pb_volDOWN), .pb(_volDOWN), .clk(clkDiv13));
        onepulse pul_volDOWN(.rst(rst), .clk(clkDiv13), .pb_debounced(pb_volDOWN), .pb_1pulse(pulse_volDOWN));

        always@(posedge clkDiv13) begin
            if(rst) begin
                vol <= 3'd3;
            end
            else begin
                vol <= next_vol;
            end
        end

        always@(*) begin
            if(pulse_volUP == 1'b1 && vol < 3'd5) begin
                next_vol = vol + 3'd1;
            end
            else if(pulse_volDOWN == 1'b1 && vol > 3'd1) begin
                next_vol = vol - 3'd1;
            end
            else begin
                next_vol = vol;
            end
        end

        assign _vol = vol;

        assign _led_vol = (_mute == 1'b1) ? 5'b0 :
                          (_vol == 3'd1) ? 5'b00001 :
                          (_vol == 3'd2) ? 5'b00011 :
                          (_vol == 3'd3) ? 5'b00111 :
                          (_vol == 3'd4) ? 5'b01111 : 5'b11111;

        //assign _en = (_mute == 1'b1) ? 1'b1 : 1'b0;

        assign freq_outL = (_music == 1'b1) ? 50000000 / (_mute ? `silence : freqL) : 50000000 / (_mute ? `silence : _freqL); // Note gen makes no sound, if freq_out = 50000000 / `silence = 1
        assign freq_outR = (_music == 1'b1) ? 50000000 / (_mute ? `silence : freqR) : 50000000 / (_mute ? `silence : _freqR);

        clock_divider #(.n(22)) clock_22(
            .clk(clk),
            .clk_div(clkDiv22)
        );

        clock_divider #(.n(13)) clock_13(
            .clk(clk),
            .clk_div(clkDiv13)
        );

        // Player Control
        player_control playerCtrl_00 (
            .clk(clkDiv22),
            .reset(rst),
            ._play(_play),
            ._repeat(_repeat),
            .ibeat(ibeatNum),
            .music(_music),
            .play(play)
        );

        // Music module
        // [in]  beat number and en
        // [out] left & right raw frequency
        music_example music_00 (
            .ibeatNum(ibeatNum),
            .reset(rst),
            .toneL(freqL),
            .toneR(freqR),
            ._toneL(_freqL),
            ._toneR(_freqR),
            .play(play),
            .note(note),
            .music(_music)
        );

        // Note generation
        // [in]  processed frequency
        // [out] audio wave signal (using square wave here)
        note_gen noteGen_00(
            .clk(clk), // clock from crystal
            .rst(rst), // active high reset
            .note_div_left(freq_outL),
            .note_div_right(freq_outR),
            .audio_left(audio_in_left), // left sound audio
            .audio_right(audio_in_right),
            .volume(_vol) // 3 bits for 5 levels,
        );

        // Speaker controller
        speaker_control sc(
            .clk(clk),  // clock from the crystal
            .rst(rst),  // active high reset
            .audio_in_left(audio_in_left), // left channel audio data input
            .audio_in_right(audio_in_right), // right channel audio data input
            .audio_mclk(audio_mclk), // master clock
            .audio_lrck(audio_lrck), // left-right clock
            .audio_sck(audio_sck), // serial clock
            .audio_sdin(audio_sdin) // serial audio data input
        );

        always@(posedge clkDiv13) begin
            case(DIGIT)
                4'b1110: begin
                    value = 3'b0;
                    DIGIT = 4'b1101;
                end
                4'b1101: begin
                    value = 3'b0;
                    DIGIT = 4'b1011;
                end
                4'b1011: begin
                    value = 3'b0;
                    DIGIT = 4'b0111;
                end
                4'b0111: begin
                    value = note;
                    DIGIT = 4'b1110;
                end
                default: begin
                    value = note;
                    DIGIT = 4'b1110;
                end
            endcase
        end

        always@(*) begin
            case(value)
                3'd0: DISPLAY = 7'b0111111;
                `A: DISPLAY = 7'b0100000;
                `B: DISPLAY = 7'b0000011;
                `C: DISPLAY = 7'b0100111;
                `D: DISPLAY = 7'b0100001;
                `E: DISPLAY = 7'b0000110;
                `F: DISPLAY = 7'b0001110;
                `G: DISPLAY = 7'b1000010;
                default: DISPLAY = 7'b0111111;
            endcase
        end

    endmodule
