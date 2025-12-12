module sram_bank
	#(
		parameter data_width 	= 16,
		parameter size 			= 1024,
		parameter addr_width 	= $clog2(size)
	)
	(
		input wire clk,
		input wire reset,
		
		input wire read,
		input wire write,
		
		input wire [addr_width - 1 : 0] write_addr,
		input wire [addr_width - 1 : 0] read_addr,
		input wire [data_width - 1 : 0] data_in,
		output reg [data_width - 1 : 0] data_out,
		
		output reg invalid_read,
		output reg invalid_write
	);
	
	localparam _IS_POW2 = ((size & (size-1)) == 0);
	
	reg [data_width - 1 : 0] memory [size - 1 : 0];
	
	always @(posedge clk) begin
		invalid_read 	<= 0;
		invalid_write 	<= 0;
		
		if (reset) begin
			// hmm...
		end
		else begin
			if (read) begin
				if (_IS_POW2 || read_addr < size[addr_width - 1 : 0]) begin
					data_out 	<= memory[read_addr];
				end
				else begin
					invalid_read <= 1;
				end
			end
			
			if (write) begin
				if (_IS_POW2 || write_addr < size[addr_width - 1 : 0]) begin
					memory[write_addr] <= data_in;
				end
				else begin
					invalid_write <= 1;
				end
			end
		end
	end
endmodule


module contiguous_sram
	#(
		parameter data_width = 16,
		parameter addr_width = $clog2(bank_size * n_banks + 1),
		parameter bank_size = 1024, // must be a power of 2
		parameter n_banks = 8
	)
	(
		input wire clk,
		input wire reset,
		
		input wire read,
		input wire write,
		
		input  wire [addr_width - 1 : 0] write_addr,
		input  wire [addr_width - 1 : 0] read_addr,
		input  wire [data_width - 1 : 0] data_in,
		output reg  [data_width - 1 : 0] data_out,
		
		output reg read_ready,
		output reg write_ready,
		
		output reg invalid_read,
		output reg invalid_write
	);

	// Force the bank size to be a power of 2; induces division
	// by 0 error at compile time if this is not the case.
	localparam int unsigned _IS_POW2 = 32'((bank_size & (bank_size-1)) == 0);
	localparam int _FORCE_POW2 = 1 / _IS_POW2;

	localparam bank_addr_width	 = $clog2(n_banks);
	localparam bank_offset_width = $clog2(bank_size);
	
	reg read_latched	= 0;
	reg read_wait		= 0;
	reg write_latched	= 0;
	reg write_wait		= 0;
	
	wire [bank_offset_width 	- 1 : 0]  read_addr_to_bank =  read_latched ? read_bank_offset  :  read_bank_offset_latched;
	wire [bank_offset_width 	- 1 : 0] write_addr_to_bank = write_latched ? write_bank_offset : write_bank_offset_latched;

	wire [addr_width - bank_offset_width - 1 : 0] read_bank_addr	= read_addr[addr_width - 1 : bank_offset_width];
	wire [bank_offset_width 			 - 1 : 0] read_bank_offset 	= read_addr[bank_offset_width - 1 : 0];

	wire [addr_width - bank_offset_width - 1 : 0] write_bank_addr	= write_addr[addr_width - 1 : bank_offset_width];
	wire [bank_offset_width 			 - 1 : 0] write_bank_offset = write_addr[bank_offset_width - 1 : 0];
	
	reg  [data_width - 1 : 0] data_in_latched = 0;
	wire [data_width - 1 : 0] data_bus [n_banks - 1 : 0];
	
	reg [n_banks - 1 : 0] read_enables  = 0;
	reg [n_banks - 1 : 0] write_enables = 0;
	
	reg [addr_width - 1 : 0]  read_addr_latched;
	reg [addr_width - 1 : 0] write_addr_latched;
	
	reg [bank_addr_width - 1 : 0]  read_bank_addr_latched;
	reg [bank_addr_width - 1 : 0] write_bank_addr_latched;
	
	reg [bank_offset_width - 1 : 0]  read_bank_offset_latched;
	reg [bank_offset_width - 1 : 0] write_bank_offset_latched;
	
	wire [n_banks - 1 : 0]  invalid_reads;
	wire [n_banks - 1 : 0] invalid_writes;
	
	genvar i;
	generate
		for (i = 0; i < n_banks; i = i + 1) begin : BANKS
			sram_bank #(.data_width(data_width), .addr_width(bank_offset_width), .size(bank_size)) bank_inst
				(
					.clk(clk),
					.reset(reset),
					
					.read(read_enables[i]),
					.write(write_enables[i]),
					
					.read_addr(read_addr_to_bank),
					.write_addr(write_addr_to_bank),
					.data_in(data_in_latched),
					.data_out(data_bus[i]),
					
					.invalid_read(invalid_reads[i]),
					.invalid_write(invalid_writes[i])
				);
		end
	endgenerate

	reg [1:0] state = 0;
	
	wire invalid_read_addr = |read_addr[addr_width - 1 : bank_offset_width + bank_addr_width];

	always @(posedge clk) begin
		read_enables 	<= 0;
		write_enables 	<= 0;
		invalid_read 	<= 0;
		invalid_write 	<= 0;
		read_wait 		<= 0;
		write_wait 		<= 0;
		
		if (reset) begin
			state 		<= 0;
			read_ready 	<= 1;
			write_ready <= 1;
			
			read_latched <= 0;
			read_addr_latched <= 0;
			read_bank_addr_latched <= 0;
			read_bank_offset_latched <= 0;
			
			write_latched <= 0;
			write_addr_latched <= 0;
			write_bank_addr_latched <= 0;
			write_bank_offset_latched <= 0;
		end
		else begin
			if (state[0]) begin
				if (!read_wait)  begin
					if (invalid_reads[read_bank_addr_latched]) begin
						invalid_read <= 1;
					end
					
					data_out <= data_bus[read_bank_addr_latched];
					
					read_ready 	<= 1;
					read_wait 	<= 1;
					
					read_latched <= 0;
					read_addr_latched <= 0;
					read_bank_addr_latched <= 0;
					read_bank_offset_latched <= 0;
					
					state[0] <= 0;
				end
			end
			else if (read && !read_wait) begin
				if (invalid_read_addr) begin
					invalid_read <= 1;
				end
				else begin
					read_enables[read_bank_addr[bank_addr_width - 1 : 0]] <= 1;
					
					read_addr_latched <= read_addr;
					read_bank_addr_latched <= read_bank_addr[bank_addr_width - 1 : 0];
					read_bank_offset_latched <= read_bank_offset;
					
					read_latched 	<= 1;
					read_ready 		<= 0;
					read_wait 		<= 1;
					
					state[0] <= 1;
				end
			end
			
			if (state[1]) begin
				if (!write_wait) begin
					if (invalid_writes[write_bank_addr_latched]) begin
						invalid_write <= 1;
					end
					
					write_ready 	<= 1;
					write_latched 	<= 0;
					write_addr_latched <= 0;
					write_bank_addr_latched <= 0;
					write_bank_offset_latched <= 0;
					
					write_wait <= 1;
					
					state[1] <= 0;
				end
			end
			else if (write && !write_wait) begin
				if (|write_addr[addr_width - 1 : bank_offset_width + bank_addr_width]) begin
					invalid_write <= 1;
				end
				else begin
					write_enables[write_bank_addr[bank_addr_width - 1 : 0]] <= 1;
					
					data_in_latched <= data_in;
					write_addr_latched <= write_addr;
					write_bank_addr_latched <= write_bank_addr[bank_addr_width - 1 : 0];
					write_bank_offset_latched <= write_bank_offset;
					
					write_latched	<= 1;
					write_ready 	<= 0;
					write_wait 		<= 1;
					
					state[1] <= 1;
				end
			end
		end
	end
endmodule
