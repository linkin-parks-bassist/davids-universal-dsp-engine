module commit_stage #(parameter data_width = 16, parameter n_blocks = 256)
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
		
		input wire signed [2 * data_width - 1 : 0] result_in,
		output reg signed [2 * data_width - 1 : 0] result_out,
		
		input wire [3:0] dest_in,
		output reg [3:0] dest_out,
		
		input wire [8:0] commit_id_in,
		output reg [8:0] commit_id_out,

		input wire commit_flag_in,
		output reg commit_flag_out
	);
	
	assign in_ready = ~buf_valid | (out_valid & out_ready);
	
	wire take_in  = in_ready & in_valid;
	wire take_out = out_valid & out_ready;
	
	reg buf_valid;
	
	reg commit_flag_buf;
	reg [3 : 0] dest_buf;
	reg [8 : 0] commit_id_buf;
	reg [2 * data_width - 1 : 0] result_buf;
	reg [$clog2(n_blocks) - 1 : 0] block_buf;
	
	always @(posedge clk) begin
		if (reset) begin
			buf_valid <= 0;
			out_valid <= 0;
		end else begin
			out_valid <= out_valid;
			buf_valid <= buf_valid;
			
			case ({take_in, take_out})
				2'b10: begin
					if (out_valid) begin
						dest_buf <= dest_in;
						result_buf <= result_in;
						commit_id_buf <= commit_id_in;
						commit_flag_buf <= commit_flag_in;
						block_buf <= block_in;
						buf_valid <= 1;
					end else begin
						dest_out <= dest_in;
						result_out <= result_in;
						commit_id_out <= commit_id_in;
						commit_flag_out <= commit_flag_in;
						block_out <= block_in;
						out_valid <= 1;
					end
				end
				
				2'b01: begin
					if (buf_valid) begin
						dest_out <= dest_buf;
						result_out <= result_buf;
						commit_id_out <= commit_id_buf;
						commit_flag_out <= commit_flag_buf;
						block_out <= block_buf;
						buf_valid <= 0;
					end else begin
						out_valid <= 0;
					end
				end
				
				2'b11: begin
					if (buf_valid) begin
						dest_buf <= dest_in;
						result_buf <= result_in;
						commit_id_buf <= commit_id_in;
						commit_flag_buf <= commit_flag_in;
						block_buf <= block_in;
						dest_out <= dest_buf;
						result_out <= result_buf;
						commit_id_out <= commit_id_buf;
						commit_flag_out <= commit_flag_buf;
						block_out <= block_buf;
						
						out_valid <= 1;
						buf_valid <= 1;
					end else begin
						dest_out <= dest_in;
						result_out <= result_in;
						commit_id_out <= commit_id_in;
						commit_flag_out <= commit_flag_in;
						block_out <= block_in;
						
						out_valid <= 1;
						buf_valid <= 0;
					end
				end
				
				default: begin end
			endcase
		end
	end
endmodule
