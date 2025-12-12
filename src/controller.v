`include "controller.vh"
`include "block.vh"

module pipeline_controller
	#(
		parameter n_blocks 		= 32,
		parameter n_block_registers 	= 16,
		parameter data_width 	= 16
	)
	(
		input wire clk,
		input wire reset,
		
		input wire [7:0] inp_byte,
		input wire inp_ready,
		
		output reg [$clog2(n_blocks) - 1 : 0] block_target,
		output reg [`BLOCK_REG_ADDR_WIDTH - 1 : 0] reg_target,
		output reg [`BLOCK_INSTR_WIDTH    - 1 : 0] instr_out,
		output reg [data_width - 1 : 0] data_out,
		
		output reg block_instr_write,
		output reg block_reg_write,
		output reg block_reg_update,
		
		output reg alloc_sram_delay,
		
		output reg ready,
		output reg inp_fifo_read,
		
		output reg invalid
	);

	reg [7:0] state;
	reg [7:0] ret_state;
	
	reg [7:0] command;
	reg [7:0] inp_latched;
	reg [data_width - 1 : 0] data;
	
	reg [`BLOCK_INSTR_WIDTH : 0] instr;
	
	reg [31:0] word;
	
	wire need_block_number = command[7];
	wire need_reg_number   = command[6];
	wire need_data		   = command[5];
	wire need_instr		   = command[4];
	
	wire inp_is_valid_command = 
	   (inp_byte == `COMMAND_WRITE_BLOCK_INSTR ||
		inp_byte == `COMMAND_WRITE_BLOCK_REG   ||
		inp_byte == `COMMAND_UPDATE_BLOCK_REG  ||
		inp_byte == `COMMAND_ALLOC_SRAM_DELAY);
	
	localparam [7:0] block_number_read_target 	= 8'($clog2(n_blocks) / 8);
	localparam [7:0] reg_number_read_target 	= 8'($clog2(n_block_registers) / 8);
	localparam [7:0] data_read_target 			= 8'(data_width / 8);
	localparam [7:0] instr_read_target 			= 8'(`BLOCK_INSTR_WIDTH / 8);
	
	reg [7:0] read_ctr;
	
	reg block_number_loaded = 0;
	reg reg_number_loaded 	= 0;
	reg data_loaded			= 0;
	reg instr_loaded		= 0;
	
	always @(posedge clk) begin	
		block_instr_write 	<= 0;
		block_reg_write 	<= 0;
		block_reg_update 	<= 0;
		alloc_sram_delay	<= 0;
		inp_fifo_read 		<= 0;
		invalid 			<= 0;
		
		if (reset) begin
			block_target 	<= 0;
			state 			<= `CONTROLLER_STATE_READY;
			ready 			<= 1;
			inp_fifo_read	<= 0;
			invalid 		<= 0;
		end
		else begin
			case (state)
				`CONTROLLER_STATE_READY: begin
					inp_fifo_read <= 1;
					if (inp_ready) begin
						if (inp_is_valid_command) begin
							command <= inp_byte;
							inp_fifo_read <= 0;
							
							state <= `CONTROLLER_STATE_ASSESS;
							ready <= 0;
							
							block_number_loaded <= 0;
							reg_number_loaded 	<= 0;
							instr_loaded 		<= 0;
							data_loaded 		<= 0;
							
							read_ctr <= 0;
						end
						else begin
							invalid <= 1;
						end
					end
				end
				
				`CONTROLLER_STATE_ASSESS: begin
					if (need_block_number & !block_number_loaded) begin
						state 		<= `CONTROLLER_STATE_LOAD_BLOCK_NUMBER;
						read_ctr 	<= 0;
						ret_state 	<= `CONTROLLER_STATE_ASSESS;
						
						inp_fifo_read <= 1;
					end
					else if (need_reg_number & !reg_number_loaded) begin
						state 		<= `CONTROLLER_STATE_LOAD_REG_NUMBER;
						read_ctr 	<= 0;
						ret_state 	<= `CONTROLLER_STATE_ASSESS;
						
						inp_fifo_read <= 1;
					end
					else if (need_data & !data_loaded) begin
						state 		<= `CONTROLLER_STATE_LOAD_DATA;
						read_ctr 	<= 0;
						ret_state 	<= `CONTROLLER_STATE_ASSESS;
						
						inp_fifo_read <= 1;
					end
					else if (need_instr & !instr_loaded) begin
						state 		<= `CONTROLLER_STATE_LOAD_INSTR;
						read_ctr 	<= 0;
						ret_state 	<= `CONTROLLER_STATE_ASSESS;
						
						inp_fifo_read <= 1;
					end
					else begin
						state <= `CONTROLLER_STATE_EXECUTE;
					end
				end
				
				`CONTROLLER_STATE_EXECUTE: begin
					state <= `CONTROLLER_STATE_READY;
					ready <= 1;
					
					case (command)
						`COMMAND_WRITE_BLOCK_INSTR: begin
							block_instr_write <= 1;
						end
						
						`COMMAND_WRITE_BLOCK_REG: begin
							block_reg_write <= 1;
						end
						
						`COMMAND_UPDATE_BLOCK_REG: begin
							block_reg_update <= 1;
						end
						
						`COMMAND_ALLOC_SRAM_DELAY: begin
							alloc_sram_delay <= 1;
						end
						
						default: begin
							invalid <= 1;
						end
					endcase
				end
				
				`CONTROLLER_STATE_LOAD_BLOCK_NUMBER: begin
					if (inp_ready) begin
						block_target <= {block_target, inp_byte}[$clog2(n_blocks) - 1 : 0];
						
						if (read_ctr + 1 >= block_number_read_target) begin
							state 		<= ret_state;
							read_ctr 	<= 0;
							block_number_loaded <= 1;
						end
						else begin
							read_ctr <= read_ctr + 1;
						end
					end
					else begin
						inp_fifo_read <= 1;
					end
				end
				
				`CONTROLLER_STATE_LOAD_REG_NUMBER: begin
					if (inp_ready) begin
						reg_target <= inp_byte[`BLOCK_REG_ADDR_WIDTH - 1 : 0];
						
						state 		<= ret_state;
						read_ctr 	<= 0;
						reg_number_loaded <= 1;
					end
					else begin
						inp_fifo_read <= 1;
					end
				end
				
				`CONTROLLER_STATE_LOAD_DATA: begin
					if (inp_ready) begin
						data_out <= (data_out << 8) | {{(data_width - 8){1'b0}}, inp_byte};
						
						if (read_ctr + 1 >= data_read_target) begin
							state 		<= ret_state;
							read_ctr 	<= 0;
							data_loaded <= 1;
						end
						else begin
							read_ctr <= read_ctr + 1;
						end
					end
					else begin
						inp_fifo_read <= 1;
					end
				end
				
				`CONTROLLER_STATE_LOAD_INSTR: begin
					if (inp_ready) begin
						instr_out <= (instr_out << 8) | {{(`BLOCK_INSTR_WIDTH - 8){1'b0}}, inp_byte};
						
						if (read_ctr + 1 >= instr_read_target) begin
							state 		<= ret_state;
							read_ctr 	<= 0;
							instr_loaded <= 1;
						end
						else begin
							read_ctr <= read_ctr + 1;
						end
					end
					else begin
						inp_fifo_read <= 1;
					end
				end
				
				default: begin
					invalid <= 1;
					state <= `CONTROLLER_STATE_READY;
				end
			endcase
		end
	end

endmodule
