`define COMMAND_WRITE_BLOCK_INSTR 	8'b10010000
`define COMMAND_WRITE_BLOCK_REG 	8'b11100000
`define COMMAND_UPDATE_BLOCK_REG 	8'b11101000
`define COMMAND_WRITE_BLOCK_REG_0 	8'b11100000
`define COMMAND_UPDATE_BLOCK_REG_0 	8'b11101000
`define COMMAND_WRITE_BLOCK_REG_1 	8'b11100001
`define COMMAND_UPDATE_BLOCK_REG_1 	8'b11101001
`define COMMAND_ALLOC_DELAY 		8'b00100000
`define COMMAND_SWAP_PIPELINES 		8'b00000001
`define COMMAND_RESET_PIPELINE 		8'b00001001
`define COMMAND_SET_INPUT_GAIN 		8'b00000010
`define COMMAND_SET_OUTPUT_GAIN 	8'b00000011
`define COMMAND_COMMIT_REG_UPDATES 	8'b00001010

// If we're in a 'waiting' state, but no new data has
// appeared for a whole 100ms, then it's likely
// there was an alignment mistake, possibly
// in software, or a transfer corruption.
// In this case, reset the controller, so that
// the machine doesn't get permanently locked up!
`define CONTROLLER_TIMEOUT_CYCLES	32'd11250000
