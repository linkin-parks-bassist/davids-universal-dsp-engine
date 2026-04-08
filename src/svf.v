module svf_master #(parameter data_width, parameter math_width, parameter block_addr_width, parameter n_slots)
	(
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		input wire signed [data_width - 1 : 0] data_in,
		input wire [data_width - 1 : 0] cutoff_in,
		input wire [data_width - 1 : 0] q_in,
		
		output reg signed [data_width - 1 : 0] low_out,
		output reg signed [data_width - 1 : 0] band_out,
		output reg signed [data_width - 1 : 0] high_out,
		
		output reg data_valid,
		
		input wire req,
		input wire [block_addr_width - 1 : 0] block_in,
		
		output reg ack,
		
		output reg slot_alloc_fail
	);
	
	localparam handle_addr_width = $clog2(n_slots);
	
	reg signed [2 * math_width - 1 : 0] state_mem [n_slots - 1 : 0];
	reg signed [2 * math_width - 1 : 0] state_mem_write_val;
	reg signed [2 * math_width - 1 : 0] state_mem_read_val;
	reg [handle_addr_width  - 1 : 0] state_mem_write_addr;
	reg [handle_addr_width  - 1 : 0] state_mem_read_addr;
	
	reg state_mem_write_enable;
	
	always @(posedge clk) begin
		if (state_mem_write_enable)
			state_mem[state_mem_write_addr] <= state_mem_write_val;
		
		state_mem_read_val <= state_mem[state_mem_read_addr];
	end
	
	reg [handle_addr_width - 1 : 0] n_slots_used;
	
	reg  req_prev;
	wire req_posedge = req & ~req_prev;
	reg  req_posedge_latched;
	wire req_pending = req | req_posedge_latched;
	
	
	reg signed [data_width - 1 : 0] data_in_r;
	reg signed [data_width - 1 : 0] cutoff_in_r;
	reg signed [data_width - 1 : 0] q_in_r;
	
	reg signed [math_width - 1 : 0] low;
	reg signed [math_width - 1 : 0] band;
	reg signed [math_width - 1 : 0] high;
	
	reg [handle_addr_width - 1 : 0] prev_slot;
	reg [handle_addr_width - 1 : 0] current_slot;
	reg [block_addr_width  - 1 : 0] prev_block;
	
	reg signed [math_width - 1 : 0] factor_a;
	reg signed [math_width - 1 : 0] factor_b;
	
	wire signed [2 * math_width - 1 : 0] product = factor_a * factor_b;
	reg  signed [2 * math_width - 1 : 0] product_r;
	
	wire signed [math_width - 1 : 0] product_r_plus_low  = low  + (product_r >>> (math_width - 1));
	wire signed [math_width - 1 : 0] band_plus_product_r = band + (product_r >>> (math_width - 1));
	
	wire signed [math_width - 1 : 0] x_minus_low_minus_product_r = data_in_r - low - (product_r >>> (math_width - 2));
	
	wire blocks_wrapped = (block_in <= prev_block);
	wire new_slot_needed = ~|n_slots_used | ((prev_slot == (n_slots_used - 1)) & ~blocks_wrapped);
	wire req_valid = !(new_slot_needed && (n_slots_used == n_slots));
	
	localparam IDLE 			= 4'd0;
	localparam STATE_LOAD_WAIT 	= 4'd1;
	localparam STATE_LOAD 		= 4'd2;
	localparam CALC_1 			= 4'd3;
	localparam CALC_2 			= 4'd4;
	localparam CALC_3 			= 4'd5;
	localparam CALC_4 			= 4'd6;
	localparam CALC_5 			= 4'd7;
	localparam CALC_6 			= 4'd8;
	
	reg [3:0] state;
	
	always @(posedge clk) begin
		if (reset) begin
			state <= IDLE;
			n_slots_used <= 0;
			
			req_prev <= 0;
			req_posedge_latched <= 0;
		end else if (enable) begin
			ack <= 0;
			req_prev <= req;
			product_r <= product;
			slot_alloc_fail <= 0;
			state_mem_write_enable <= 0;
			req_posedge_latched <= req | req_posedge_latched;
			
			case (state)
				IDLE: begin
					if (req_pending) begin
						if (new_slot_needed) begin // need to allocate a new slot
							if (n_slots_used == n_slots) begin
								slot_alloc_fail <= 1;
								low_out  <= 0;
								band_out <= 0;
								high_out <= 0;
								data_valid <= 1; // so that the consumer doesn't get locked up
							end else begin
								current_slot <= n_slots_used;
								n_slots_used <= n_slots_used + 1;
								
								state_mem_write_val <= 0;
								state_mem_write_addr <= n_slots_used;
								state_mem_write_enable <= 1;
								
								low <= 0;
								band <= 0;
								
								state <= CALC_1;
							end
						end else if (blocks_wrapped) begin
							current_slot <= 0;
							state_mem_read_addr <= 0;
							state <= STATE_LOAD_WAIT;
						end else if (req_valid) begin
							current_slot <= current_slot + 1;
							state_mem_read_addr <= current_slot + 1;
							state <= STATE_LOAD_WAIT;
						end
						
						if (req_valid) begin
							data_in_r 	<= data_in;
							cutoff_in_r <= cutoff_in;
							q_in_r 		<= q_in;
							data_valid  <= 0;
						end
						
						prev_block <= block_in;
						
						req_posedge_latched <= 0;
						ack <= 1;
					end
				end
				
				STATE_LOAD_WAIT: begin
					state <= STATE_LOAD;
				end
				
				STATE_LOAD: begin
					{low, band} <= state_mem_read_val;
					state <= CALC_1;
				end
				
				CALC_1: begin
					factor_a <= cutoff_in_r;
					factor_b <= band;
					
					state <= CALC_2;
				end
				
				CALC_2: begin
					// product_r <= product (automatic)
					factor_a <= q_in_r;
					factor_b <= band;
					
					state <= CALC_3;
				end
				
				CALC_3: begin
					low <= product_r_plus_low;
					state <= CALC_4;
				end
				
				CALC_4: begin
					high <= x_minus_low_minus_product_r;
					factor_a <= cutoff_in_r;
					factor_b <= x_minus_low_minus_product_r;
					
					state <= CALC_5;
				end
				
				CALC_5: begin
					state <= CALC_6;
				end
				
				CALC_6: begin
					band <= band_plus_product_r;
					high_out <= high >>> (math_width - data_width);
					low_out  <= low  >>> (math_width - data_width);
					band_out <= band_plus_product_r >>> (math_width - data_width);
					
					state_mem_write_val <= {low, band_plus_product_r};
					state_mem_write_addr <= current_slot;
					state_mem_write_enable <= 1;
					
					data_valid <= 1;
					prev_slot <= current_slot;
					
					state <= IDLE;
				end
			endcase
		end
	end
	
endmodule
