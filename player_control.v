module player_control (
	input clk,
	input reset,
	input _play,
	input _repeat,
	output reg [11:0] ibeat
);
	parameter LEN = 4095;
    reg [11:0] next_ibeat;

	always @(posedge clk, posedge reset) begin
		if (reset)
			ibeat <= 0;
		else begin
            ibeat <= next_ibeat;
		end
	end

    always @* begin
        next_ibeat = (ibeat + 1 < LEN) ? (ibeat + 1) : 12'd0;
    end

endmodule