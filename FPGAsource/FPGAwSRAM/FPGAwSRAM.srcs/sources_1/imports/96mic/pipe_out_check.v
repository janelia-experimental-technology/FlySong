//------------------------------------------------------------------------
// pipe_out_check.v
//
// Generates pseudorandom data for Pipe Out verifications.
//
// Copyright (c) 2005-2010  Opal Kelly Incorporated
// $Rev$ $Date$
//------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module pipe_out_check(
	input  wire            clk,
	input  wire            reset,
	input  wire            pipe_out_read,
	output wire [15:0]     pipe_out_data,
	output reg             pipe_out_ready,
	input  wire            throttle_set,
	input  wire [31:0]     throttle_val,
	input  wire            mode,                // 0=Count, 1=LFSR
	input wire             tmpPin,
    output wire            cnvPin,
    output wire [7:0]      led
	);


reg  [63:0]  lfsr;
reg  [15:0]  lfsr_p1;
reg  [31:0]  throttle;
reg  [15:0]  level;

// tmp06
reg  [2:0]  state;
reg  [23:0] hicnts;
reg  [23:0] locnts;
reg  [23:0] savehicnts;

reg startcnv;
reg cnvrtsig;
reg tempdata;

localparam[2:0]
    idle     = 3'd0,
    cnvbeg   = 3'd1,
    cnvend   = 3'd2,
    waitcnv  = 3'd3,
    timehi   = 3'd4,
    timelo   = 3'd5,
    endhi    = 3'd6,
    endlo    = 3'd7;

//assign pipe_out_data = lfsr_p1;
assign cnvPin  = cnvrtsig;
//assign led[2:0] = state;

//------------------------------------------------------------------------
// LFSR mode signals
//
// 32-bit: x^32 + x^22 + x^2 + 1
// lfsr_out_reg[0] <= r[31] ^ r[21] ^ r[1]
//------------------------------------------------------------------------
// reg [31:0] temp;
always @(posedge clk) begin
	if (reset == 1'b1) begin
		throttle <= throttle_val;
///		pipe_out_ready <= 1'b0;
		level <= 16'd0;
//		state <= idle;
        cnvrtsig <= 1'b0;
//		if (mode == 1'b1) begin
//			lfsr  <= 64'h0D0C0B0A04030201;
//		end else begin
//			lfsr  <= 64'h0000000100000001;
//		end
	end 
	  else 
	begin
	
	  case (state)
          idle:
            begin
               if( reset == 1'b0 )   //start conversion
               begin
                    state <= cnvbeg;  // next state waits out conversion pin high 
                    hicnts <= 24'd0;  // reset temperature counters 
                    cnvrtsig <= 1'b1; // set conversion pin high
               end               
               else
               begin
                  cnvrtsig <= 1'b0;
              end   
            end    
          cnvbeg:    // convert pin output
             begin
               if( hicnts == 24'd500 )   // need convrt pin high >10 nsec && < 25 uS, 
               begin                        //  - use 500 * 1/48e6 = 10 uS
                  cnvrtsig <= 1'b0;      // when done, set cnvrt pin low 
                  state <=  cnvend;      
                  hicnts <= 24'd0;       // start counter over for high part
               end
               else
               begin   
                  hicnts <= hicnts + 1;   // else count up time on convert high
               end   
            end
          cnvend:    // wait for high out for  temperature counting
            begin
               if( tmpPin == 1'b1 )  // got it - start counting  
               begin
                  state <= timehi;  
               end
            end              
          timehi:   // count high time
             begin
                if( tmpPin == 1'b1 )  // while temp in pin hi, count
                begin
                  hicnts <= hicnts + 1;
                end  
                else  // tmp pin went low, we are done with this one
                begin
                   if( hicnts <= 24'd2000 )  // if hi counts was short, then that is end of daisy chain
                   begin
                       state <= endhi;   
                   end
                   else
                   begin
                       savehicnts <= hicnts;
                       lfsr_p1 <= hicnts[21:6];  // just 16 bits for now
                       locnts <= 24'd0;  // was a temp reading, so set up and run lo time 
                       state <= timelo;
                   end      
                end                
             end   
          timelo:  // count lo time
             begin 
                if( tmpPin == 1'b0 )  // while lo, count
                begin
                   locnts = locnts + 1;
    //               count1 <= hicnts[23:16];
    //               count2 <= hicnts[15:8]; 
                   
                end
                else 
                begin
                   hicnts <= 24'd0;   // reset high counter
                   state <= timehi;   // when hi, start hi time again
                end                    
             end      
          endhi:      
             begin
    //           count1 = 24'd421 - ((24'd751 * savehicnts)/ locnts);
//                count1 <= locnts[23:16];
//                count2 <= locnts[15:8]; 
                lfsr_p1 <= locnts[21:6];
 ///               pipe_out_ready <= 1'b1;
                state <= endlo;
//                if( reset == 1'b0 ) 
//                begin
//                   state <= idle;
//                end    
             end  
          endlo:
             begin
               lfsr_p1 <= savehicnts[21:6];
               state <= endhi;
             end           
          
        endcase

	
//		lfsr_p1 <= 16'h55aa; // lfsr[15:0];
		
//		if (level >= 16'd1024) begin
//			pipe_out_ready <= 1'b1;
//		end
	
		// Update our virtual FIFO level.
		case ({pipe_out_read, throttle[0]})
			2'b00: begin
			end
			
			// Write : Increase the FIFO level
			2'b01: begin
				if (level < 16'd65535) begin
					level <= level + 1'b1;					
				end
			end
			
			// Read : Decrease the FIFO level
			2'b10: begin
				if (level > 16'd0) begin
					level <= level - 1'b1;
				end
			end
			
			// Read/Write : No net change
			2'b11: begin
			    throttle[0] <= 1'b0;  // assume no data
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
		
//		// Cycle the LFSR
//		if (pipe_out_read == 1'b1) begin
//			if (mode == 1'b1) begin
//				temp = lfsr[31:0];
//				lfsr[31:0]  <= 32'd222;  //{temp[30:0], temp[31] ^ temp[21] ^ temp[1]};
//				temp = lfsr[63:32];
//				lfsr[63:32] <= 32'd333; //{temp[30:0], temp[31] ^ temp[21] ^ temp[1]};
//			end else begin
//				lfsr[31:0]  <= 32'd444;  //lfsr[31:0]  + 1'b1;
//				lfsr[63:32] <= 32'd555;  // lfsr[63:32] + 1'b1;
//			end
//		end
	end
end

endmodule
