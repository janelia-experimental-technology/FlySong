//------------------------------------------------------------------------
// pipe_in_check.v
//
// Received data and checks against pseudorandom sequence for Pipe In.
//
// Even though we're able to produce data in sequence every clock cycle,
// a virtual FIFO is used to provide a way to throttle transfers on a 
// block basis.
//
// Copyright (c) 2005-2010  Opal Kelly Incorporated
// $Rev$ $Date$
//------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module pipe_in_check(
	input  wire            clk,
	input  wire            reset,
	input  wire            pipe_in_write,
	input  wire [15:0]     pipe_in_data,
	output reg             pipe_in_ready,
	input  wire            throttle_set,
	input  wire [31:0]     throttle_val,
	input  wire            mode,               // 0=Count, 1=LFSR
	output reg  [15:0]     error_count  // !!! was 31:0
	);

reg  [63:0]  lfsr;
reg  [31:0]  throttle;
reg  [16:0]  level;


//------------------------------------------------------------------------
// LFSR mode signals
//
// 32-bit: x^32 + x^22 + x^2 + 1
// lfsr_out_reg[0] <= r[31] ^ r[21] ^ r[1]
//------------------------------------------------------------------------
always @(posedge clk) begin
	if (reset == 1'b1) begin
		error_count <= 0;
		throttle <= throttle_val;
		level <= 16'd0;
		
		if (mode == 1'b1) begin
			lfsr  <= 64'h0D0C0B0A04030201;
		end else begin
			lfsr  <= 64'h0000000100000001;
		end
	end else begin
		if (level < 16'd64512) begin
			pipe_in_ready <= 1'b1;
		end else begin
			pipe_in_ready <= 1'b0;
		end
	
		// Update our virtual FIFO level.
		case ({pipe_in_write, throttle[0]})
			2'b00: begin
			end
			
			// Read : Decrease the FIFO level
			2'b01: begin
				if (level > 16'd0) begin
					level <= level - 1'b1;
				end
			end
			
			// Write : Increase the FIFO level
			2'b10: begin
				if (level < 16'd65535) begin
					level <= level + 1'b1;
				end
			end
			
			// Read/Write : No net change
			2'b11: begin
			end
		endcase
	
		// The throttle is a circular register.
		// 1 enabled read or write this cycle.
		// 0 disables read or write this cycle.
		// So a single bit (0x00000001) would lead to 1/32 data rate.
		// Similarly 0xAAAAAAAA would lead to 1/2 data rate.
		if (throttle_set == 1'b1) begin
			throttle <= throttle_val;
		end else begin
			throttle <= {throttle[0], throttle[31:1]};
		end
		
		
		// Check incoming data for validity
		if (pipe_in_write == 1'b1) begin
			if (pipe_in_data[15:0] != lfsr[15:0]) begin
				error_count <= error_count + 1'b1;
			end
		end

		// Cycle the LFSR
		if (pipe_in_write == 1'b1) begin
			if (mode == 1'b1) begin
				lfsr[31:0]  <= {lfsr[30:0],  lfsr[31] ^ lfsr[21] ^ lfsr[1] };
				lfsr[63:32] <= {lfsr[62:32], lfsr[63] ^ lfsr[53] ^ lfsr[33]};
			end else begin
				lfsr[31:0]  <= lfsr[31:0]  + 1'b1;
				lfsr[63:32] <= lfsr[63:32] + 1'b1;
			end
		end
	end
end

endmodule
