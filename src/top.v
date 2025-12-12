module top
	#(
		parameter n_blocks 			= 2,
		parameter n_block_registers = 16,
		parameter data_width 		= 16,
		parameter n_channels 		= 16,
		parameter n_sram_banks 		= 8,
		parameter sram_bank_size 	= 1024,
		parameter spi_fifo_length	= 32
	)
    (
        input wire clk,
        input wire reset,

        input  wire cs,
        input  wire mosi,
        output wire miso,
        input  wire sck,

        output wire led0,
        output wire led1,
        output wire led2,
        output wire led3,
        output wire led4,
        output wire led5,

        output wire mclk,
        output wire bclk,
        output wire lrclk,
        
        input  wire i2s_din,
        output wire i2s_dout
    );
    
    reg signed [data_width - 1 : 0]  in_sample   = 0;
    reg signed [data_width - 1 : 0] out_sample_a = 0;
    reg signed [data_width - 1 : 0] out_sample_b = 0;
    
    wire in_valid;
    
    wire pipeline_a_ready;
    wire pipeline_b_ready;
    
    wire pipeline_a_error;
    
    reg current_pipeline;
    reg pipelines_swapping;
    
    pipeline
		#(
			.n_blocks(n_blocks),
			.n_block_registers(n_block_registers),
			.data_width(data_width),
			.n_channels(n_channels),
			.n_sram_banks(n_sram_banks)
			.sram_bank_size(sram_bank_size)
		)
		pipeline_a
		(
			.clk(clk),
			.reset(reset),
			
			.in_sample(in_sample),
			.in_valid(in_valid),
			
			.ready(pipeline_a_ready),
			.error(pipeline_a_error),
			
			.inp_byte(spi_fifo_out_latched),
			.inp_ready(spi_fifo_out_ready),
			.inp_read(pipeline_a_spi_fifo_read),
		);
    
    pipeline
		#(
			.n_blocks(n_blocks),
			.n_block_registers(n_block_registers),
			.data_width(data_width),
			.n_channels(n_channels),
			.n_sram_banks(n_sram_banks)
			.sram_bank_size(sram_bank_size)
		)
		pipeline_b
		(
			.clk(clk),
			.reset(reset),
			
			.in_sample(in_sample),
			.in_valid(in_valid),
			
			.ready(pipeline_b_ready),
			.error(pipeline_b_error),
			
			.inp_byte(spi_fifo_out_latched),
			.inp_ready(spi_fifo_out_ready),
			.inp_read(pipeline_b_spi_fifo_read),
		);
	
	wire pipeline_a_spi_fifo_read;
	wire pipeline_b_spi_fifo_read;
	
	wire [7:0] spi_fifo_out;
	reg  [7:0] spi_fifo_out_latched;
	reg  	   spi_fifo_out_ready = 0;
	
	wire spi_fifo_nonempty;
	wire spi_fifo_full;
	
	reg spi_fifo_read;
	
	fifo_buffer #(.data_width(8), .n(spi_fifo_length)) spi_fifo
		(
			.clk(clk),
			.reset(reset),
			
			.data_in(spi_in),
			.data_out(spi_fifo_out),
			
			.write(spi_in_valid),
			.read(spi_fifo_read),
			
			.nonempty(spi_fifo_ready),
			.full(spi_fifo_full)
		);

    wire [7:0] spi_in;
    wire spi_in_valid;

    sync_spi_slave spi
        (
            .clk(master_clk),
            .reset(reset),

            .sck(sck),
            .cs(cs),
            .mosi(mosi),
            .miso(miso),
            .miso_byte(data_out),

            .enable(1),

            .mosi_byte(spi_in),
            .data_ready(spi_in_valid)
        );
endmodule
