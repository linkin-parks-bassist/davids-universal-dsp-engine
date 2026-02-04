`include "instr_dec.vh"
`include "block.vh"
`include "lut.vh"
`include "seq.vh"
`include "alu.vh"

module multiply_stage #(parameter data_width = 16)
	(
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		input  wire in_valid,
		output wire in_ready,
		
		input wire [7 : 0] operation_in,
		
		input wire [4:0] shift_in,
		input wire no_shift_in,
		input wire saturate_in,
		input wire signedness_in,
		input wire use_accumulator_in,
		input wire subtract_in,
		
		input wire signed [data_width - 1 : 0] arg_a_in,
		input wire signed [data_width - 1 : 0] arg_b_in,
		input wire signed [data_width - 1 : 0] arg_c_in,
		
		input wire signed [2 * data_width - 1 : 0] accumulator_in,
		
		input wire [3:0] dest_in,
		input wire dest_acc_in,
		
		output reg [7 : 0] operation_out,
		
		output reg [4:0] shift_out,
		output reg no_shift_out,
		output reg saturate_out,
		output reg signedness_out,
		output reg use_accumulator_out,
		output reg subtract_out,
		
		output reg signed [data_width - 1 : 0] arg_a_out,
		output reg signed [data_width - 1 : 0] arg_b_out,
		output reg signed [data_width - 1 : 0] arg_c_out,
		
		output reg signed [2 * data_width - 1 : 0] product_out,
		
		output reg signed [2 * data_width - 1 : 0] accumulator_out,
		
		output reg [3:0] dest_out,
		output reg dest_acc_out,
		
		output reg out_valid,
		input wire out_ready,
		
		input wire [8:0] commit_id_in,
		output reg [8:0] commit_id_out
	);
	
	assign in_ready = ~out_valid | out_ready;
	
	wire take_in  = in_ready & in_valid;
	wire take_out = out_valid & out_ready;

	always @(posedge clk) begin
		if (reset) begin
			out_valid 	<= 0;
		end else if (enable) begin
			if (take_in) begin
				out_valid <= 1;
				
				operation_out 		<= operation_in;
				shift_out 			<= shift_in;
				no_shift_out 		<= no_shift_in;
				saturate_out 		<= saturate_in;
				signedness_out 		<= signedness_in;
				use_accumulator_out <= use_accumulator_in;
				subtract_out		<= subtract_in;
				
				product_out 		<= signedness_in ? $signed(arg_a_in) * $signed(arg_b_in) : arg_a_in * arg_b_in;
				arg_a_out 			<= arg_a_in;
				arg_b_out 			<= arg_b_in;
				arg_c_out 			<= arg_c_in;
				
				accumulator_out 	<= accumulator_in;
				dest_out 			<= dest_in;
				dest_acc_out 		<= dest_acc_in;
				
				commit_id_out		<= commit_id_in;
			end else if (take_out) begin
				out_valid <= 0;
			end
		end
	end
endmodule

module shift_stage #(parameter data_width = 16)
	(
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		input  wire in_valid,
		output wire in_ready,
		
		input wire [7 : 0] operation_in,
		
		input wire [4:0] shift_in,
		input wire no_shift_in,
		input wire saturate_in,
		input wire signedness_in,
		input wire use_accumulator_in,
		input wire subtract_in,
		
		input wire signed [2 * data_width - 1 : 0] product_in,
		
		input wire signed [data_width - 1 : 0] arg_a_in,
		input wire signed [data_width - 1 : 0] arg_b_in,
		input wire signed [data_width - 1 : 0] arg_c_in,
		
		input wire signed [2 * data_width - 1 : 0] accumulator_in,
		
		input wire [3:0] dest_in,
		input wire dest_acc_in,
		
		output reg [7 : 0] operation_out,
		
		output reg saturate_out,
		output reg signedness_out,
		output reg use_accumulator_out,
		output reg subtract_out,
		
		output reg signed [data_width - 1 : 0] arg_a_out,
		output reg signed [data_width - 1 : 0] arg_b_out,
		output reg signed [data_width - 1 : 0] arg_c_out,
		
		output reg signed [2 * data_width - 1 : 0] product_out,
		output reg signed [2 * data_width - 1 : 0] accumulator_out,
		
		output reg [3:0] dest_out,
		output reg dest_acc_out,
		
		output reg out_valid,
		input wire out_ready,
		
		input wire [8:0] commit_id_in,
		output reg [8:0] commit_id_out
	);
	
	assign in_ready = ~out_valid | out_ready;
	
	wire take_in  = in_ready & in_valid;
	wire take_out = out_valid & out_ready;
	
	wire shift_arg_a = (operation_in == `BLOCK_INSTR_LSH
					 || operation_in == `BLOCK_INSTR_RSH
					 || operation_in == `BLOCK_INSTR_ARSH);
	
	wire [1:0] arg_a_shift_type =
		(operation_in == `BLOCK_INSTR_ARSH) ? 2'b11 :
			((operation_in == `BLOCK_INSTR_RSH) ? 2'b10 :
				((operation_in == `BLOCK_INSTR_LSH) ? 2'b01
					: 2'b00));
	
	wire [data_width - 1 : 0] arg_a_shifts [3:0];
	
	assign arg_a_shifts[2'b00] = arg_a_in;
	assign arg_a_shifts[2'b01] = arg_a_in  << shift_in;
	assign arg_a_shifts[2'b10] = arg_a_in  >> shift_in;
	assign arg_a_shifts[2'b11] = arg_a_in >>> shift_in;
	
	wire [data_width - 1 : 0] arg_a_shift = arg_a_shifts[arg_a_shift_type];

	wire [4 : 0] product_shift = (no_shift_in) ? 0 : (data_width - shift_in - 1);

	always @(posedge clk) begin
		if (reset) begin
			out_valid 	<= 0;
		end else if (enable) begin
			if (take_in) begin
				out_valid <= 1;
				
				operation_out 		<= operation_in;
				saturate_out 		<= saturate_in;
				signedness_out 		<= signedness_in;
				use_accumulator_out <= use_accumulator_in;
				subtract_out		<= subtract_in;
				
				product_out 		<= product_in >>> product_shift;
				arg_a_out 			<= arg_a_shift;
				arg_b_out 			<= arg_b_in;
				arg_c_out 			<= arg_c_in;
				
				accumulator_out 	<= accumulator_in;
				dest_out 			<= dest_in;
				dest_acc_out 		<= dest_acc_in;
				
				commit_id_out		<= commit_id_in;
			end else if (take_out) begin
				out_valid <= 0;
			end
		end
	end
endmodule

module arithmetic_stage #(parameter data_width = 16)
	(
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		input  wire in_valid,
		output wire in_ready,
		
		input wire [7 : 0] operation_in,
		
		input wire saturate_in,
		input wire signedness_in,
		input wire use_accumulator_in,
		input wire subtract_in,
		
		input wire signed [2 * data_width - 1 : 0] product_in,
		
		input wire signed [data_width - 1 : 0] arg_a_in,
		input wire signed [data_width - 1 : 0] arg_b_in,
		input wire signed [data_width - 1 : 0] arg_c_in,
		
		input wire signed [2 * data_width - 1 : 0] accumulator_in,
		
		input wire [3:0] dest_in,
		input wire dest_acc_in,
		
		output reg saturate_out,
		output reg use_accumulator_out,
		
		output reg signed [2 * data_width - 1 : 0] result_out,
		
		output reg [3:0] dest_out,
		output reg dest_acc_out,
		
		output reg out_valid,
		input wire out_ready,
		
		input wire [8:0] commit_id_in,
		output reg [8:0] commit_id_out
	);
	
	assign in_ready = ~out_valid | out_ready;
	
	wire take_in  =  in_ready & in_valid;
	wire take_out = out_valid & out_ready;
	
	wire signed [2 * data_width - 1 : 0] arg_a_ext = {{(data_width){signedness_in & arg_a_in[data_width-1]}}, arg_a_in};
	wire signed [2 * data_width - 1 : 0] arg_b_ext = {{(data_width){signedness_in & arg_b_in[data_width-1]}}, arg_b_in};
	wire signed [2 * data_width - 1 : 0] arg_c_ext = {{(data_width){signedness_in & arg_c_in[data_width-1]}}, arg_c_in};
	
	wire signed [2 * data_width - 1 : 0] r_summand = use_accumulator_in ? accumulator_in : arg_c_ext;
	
	wire signed [2 * data_width - 1 : 0] sum = product_in + ((subtract_in) ? -r_summand : r_summand);
	
	wire signed [2 * data_width - 1 : 0] clamp = (arg_a_ext < arg_b_in) ? arg_b_ext : ((arg_a_in > arg_c_in) ? arg_c_ext : arg_a_ext);
	wire signed [2 * data_width - 1 : 0] abs   = (arg_a_in < 0) ? -arg_a_ext : arg_a_ext;
	
	wire signed [2 * data_width - 1 : 0] result = (operation_in == `BLOCK_INSTR_ABS) ? abs : ((operation_in == `BLOCK_INSTR_CLAMP) ? clamp : sum);

	always @(posedge clk) begin
		if (reset) begin
			out_valid 	<= 0;
		end else if (enable) begin
			if (take_in) begin
				out_valid <= 1;
				
				saturate_out 		<= saturate_in;
				use_accumulator_out <= use_accumulator_in;
				
				result_out			<= result;
				
				dest_out 			<= dest_in;
				dest_acc_out 		<= dest_acc_in;
				
				commit_id_out		<= commit_id_in;
			end else if (take_out) begin
				out_valid <= 0;
			end
		end
	end
endmodule

module saturate_stage #(parameter data_width = 16)
	(
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		input  wire in_valid,
		output wire in_ready,
		
		input wire saturate_in,
		
		input wire [3:0] dest_in,
		input wire dest_acc_in,
		
		input wire signed [2 * data_width - 1 : 0] result_in,
		output reg signed [2 * data_width - 1 : 0] result_out,
		
		output reg [3:0] dest_out,
		output reg dest_acc_out,
		
		output reg out_valid,
		input wire out_ready,
		
		input wire [8:0] commit_id_in,
		output reg [8:0] commit_id_out
	);
	
	assign in_ready = ~out_valid | out_ready;
	
	wire take_in  =  in_ready & in_valid;
	wire take_out = out_valid & out_ready;
	
	localparam signed sat_max = {{(data_width + 1){1'b0}}, {(data_width - 1){1'b1}}};
	localparam signed sat_min = {{(data_width + 1){1'b1}}, {(data_width - 1){1'b0}}};
	
	wire signed [2 * data_width - 1 : 0] result_in_sat = (result_in > sat_max) ? sat_max : ((result_in < sat_min) ? sat_min : result_in);

	always @(posedge clk) begin
		if (reset) begin
			out_valid 		<= 0;
		end else if (enable) begin
			if (take_in) begin
				out_valid <= 1;
				
				result_out <= (saturate_in) ? result_in_sat : result_in;
				
				dest_out     <= dest_in;
				dest_acc_out <= dest_acc_in;
				
				commit_id_out <= commit_id_in;
			end else if (take_out) begin
				out_valid <= 0;
			end
		end
	end
endmodule
