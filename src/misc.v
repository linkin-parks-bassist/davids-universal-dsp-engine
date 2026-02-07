`include "instr_dec.vh"

module misc_branch #(parameter data_width = 16, parameter n_blocks = 256)
	(
		input wire clk,
		input wire reset,
		
		input wire enable,
				
		input  wire in_valid,
		output wire in_ready,
		
		output reg out_valid,
		input wire out_ready,
		
		input wire [$clog2(n_blocks) - 1 : 0] block_in,
		output reg [$clog2(n_blocks) - 1 : 0] block_out,
		
		input wire signed [data_width - 1 : 0] arg_a_in,
		input wire signed [data_width - 1 : 0] arg_b_in,
		input wire signed [data_width - 1 : 0] arg_c_in,
		
		input wire signed [2 * data_width - 1 : 0] accumulator_in,
		
		input wire [4 : 0] operation_in,
		
		input wire saturate_disable_in,
		input wire [4 : 0] shift_in,
		
		input wire [3 : 0] dest_in,
		output reg [3 : 0] dest_out,
		
		output reg signed [2 * data_width - 1 : 0] result_out,
		
		input wire [8 : 0] commit_id_in,
		output reg [8 : 0] commit_id_out,
		
		input wire commit_flag_in,
		output reg commit_flag_out
	);
	
	localparam signed sat_max = {{(data_width + 1){1'b0}}, {(data_width - 1){1'b1}}};
	localparam signed sat_min = {{(data_width + 1){1'b1}}, {(data_width - 1){1'b0}}};

	assign in_ready = ~out_valid | out_ready;
	
	wire take_in  = in_ready & in_valid;
	wire take_out = out_valid & out_ready;
	
	logic signed [2 * data_width - 1 : 0] result;
	
	wire signed [2 * data_width - 1 : 0] upper_acc = {{(data_width){1'b0}}, accumulator_in[2 * data_width - 1 : data_width]};
	wire signed [2 * data_width - 1 : 0] lower_acc = {{(data_width){1'b0}}, accumulator_in[    data_width - 1 :          0]};
	
	wire signed [2 * data_width - 1 : 0] abs 	= (arg_a_in < 0) 		? -arg_a_in : arg_a_in;
	
	wire clamp_flipped = (arg_b_in < arg_c_in);
	
	wire signed [2 * data_width - 1 : 0] min = (arg_a_in < arg_b_in) ? arg_a_in : arg_b_in;
	wire signed [2 * data_width - 1 : 0] max = (arg_a_in > arg_b_in) ? arg_a_in : arg_b_in;
	
	wire signed [2 * data_width - 1 : 0] lsh = arg_a_in << shift_in;
	wire signed [2 * data_width - 1 : 0] rsh = arg_a_in >> shift_in;
	
	always_comb begin
		case (operation_in)
			`BLOCK_INSTR_MOV_ACC: 	result = accumulator_in >>> shift_in;
			`BLOCK_INSTR_ABS: 		result = abs;
			`BLOCK_INSTR_MIN: 	    result = min;
			`BLOCK_INSTR_MAX: 	    result = max;
			`BLOCK_INSTR_LSH: 		result = lsh;
			`BLOCK_INSTR_RSH: 		result = rsh;
			`BLOCK_INSTR_MOV_UACC: 	result = upper_acc;
			`BLOCK_INSTR_MOV_LACC: 	result = lower_acc;
		endcase
	end

	//wire signed [2 * data_width - 1 : 0] result_sat = (result < sat_min) ? sat_min : ((result > sat_max) ? sat_max : result);

	always @(posedge clk) begin
		if (reset) begin
			out_valid 	<= 0;
		end else if (enable) begin
			if (take_in) begin
				out_valid <= 1;
				
				block_out <= block_in;
				
				result_out <= result;
				
				dest_out 			 <= dest_in;
				
				commit_id_out		 <= commit_id_in;
				commit_flag_out 	 <= commit_flag_in;
			end else if (take_out) begin
				out_valid <= 0;
			end
		end
	end

endmodule