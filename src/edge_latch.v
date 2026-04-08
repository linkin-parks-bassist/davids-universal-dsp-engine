module pulse_latch (
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		input  wire in,
		output wire out,
		output wire out_d,
		
		input wire ack
	);
	
	reg  in_prev;
	wire in_posedge = in & ~in_prev;
	reg  in_posedge_latched;
	
	assign out_d = in_posedge_latched;
	assign out = in | in_posedge_latched;
	
	always @(posedge clk) begin
		if (reset) begin
			in_prev <= 0;
			in_posedge <= 0;
		end else if (enable) begin
			in_prev <= in;
			
			if (ack) in_posedge_latched <= in_posedge;
			else 	 in_posedge_latched <= in_posedge | in_posedge_latched;
		end
	end
	
endmodule
