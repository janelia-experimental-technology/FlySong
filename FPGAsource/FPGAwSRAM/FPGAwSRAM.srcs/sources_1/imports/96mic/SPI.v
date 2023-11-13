//------------------------------------------------------------------------
// SPI.v
//
// 'Special' SPI interface to talk with LTC1867 ADCs; 12 at a time, suing common MOSI 
// for commands
//
// Steve Sawtelle
// HHMI Janelia Research Campus
// 20161029 sws - ADC basically working
//------------------------------------------------------------------------

module SPI
(
	input  wire        clk,
	input  wire [7:0]  command,
	input  wire        start,
	input  wire [11:0] miso,
//    input  wire        miso,
	output wire        mosi,
	output wire        sclk,
    output wire        adccs,
    output wire[191:0] adcdata, 
    output wire        adcdone,
    output wire [15:0]  tp

);


//reg  [23:0]  div1;
reg          clk1div;

reg  [2:0]   state;
reg          sclk_d;
reg          adcdone_d;
reg          mosi_d;
reg          cs_d;
reg  [7:0]   cnvrtclk_d;
reg  [7:0]   cmd_d;
reg  [3:0]   datacnt_d;
reg  [191:0] datain;   // reg  [15:0] datain [12:0];   // 12 words of data
reg  [191:0] lastdata;
    
localparam[2:0]
    idle    = 3'd0,
    starthi = 3'd1,
    startlo = 3'd2,
    waitcnv = 3'd3,
    data    = 3'd4,
    stop    = 3'd5,
    holdclk = 3'd6, // need 2 clock cycles to be under max sclk freq
    extra_1  = 3'd7;  
    
//always @(posedge clk) begin
//	div1 <= div1 - 1;
//	if (div1 == 24'h000000) begin
//		div1 <= 24'h400000;
//		clk1div <= ~clk1div;
////	state_next <= starthi;
//	end
// end
 
 assign mosi = mosi_d;
 assign sclk = sclk_d;
 assign adccs = cs_d; 
// assign led[3] = datain[0];
// assign led[4] = mosi_d;
// assign led[5]  = sclk_d;
// assign led[6] = cs_d;
// assign led[6:4] = state;
// assign tp[5] = datain[0];
// assign tp[4] = mosi_d;
// assign tp[3]  = sclk_d;
// assign tp[2:0] = state[2:0];

//assign tp[15:12] = {datain[15], miso[0], datain[47], datain[63] };
 
 assign adcdata[191:0] = datain;
 assign adcdone = adcdone_d;
  
always @(posedge clk) begin
   
   case (state)
      idle:
        begin
            if (start == 1'b1 )
            begin
                state <= starthi;
                cmd_d <= command;
            end    
            adcdone_d <= 1'b0;  
      
        end    
      starthi: // start conversion 
         begin
           cs_d <= 1'b1;   // cs high starts conversion
           sclk_d <= 1'b0;
           cnvrtclk_d <= 8'd0;
           datacnt_d <= 4'd15;      
           state <= startlo;     // then go wait cs high time and set cs low
           datain <= 16'h0000;
         end  
      startlo:    // then set cs low - this is 'stay awake' mode
         begin
            if( cnvrtclk_d == 8'd5 )   // after 8 counts or 125 nsec (need at least 100)
            begin
              cs_d <= 1'b0;
              state <= waitcnv;      // then go to conversion wait time 
            end  
            else
            begin
               cnvrtclk_d <= cnvrtclk_d + 1;
            end                
         end   
      waitcnv:    // now we wait for max conversion time (3.7usec) 
         begin 		  
            if( cnvrtclk_d == 8'd190 )   // we wait 3.8usec  (was 4)
            begin
                mosi_d <= cmd_d[7];
                state <= data;         // time to get data
                cnvrtclk_d <=  8'd0;   // zero convert clock
                datacnt_d <= 4'd0;
            end
            else
            begin
               cnvrtclk_d <= cnvrtclk_d + 1;
            end                    
         end      
      data:      // pull in the data from 12 channels
         begin
            state <= holdclk;  // assume we loop  - need to slow sclk down for ADC 
            if( sclk_d == 1'b0 )
            begin
                sclk_d <= 1'b1;        // data latched
                datain <= datain << 1; // shift data over to add in in new
                cmd_d <= cmd_d << 1;   // shift to next command bit            
            end
            else
            begin
                 datain[0] <=  miso[0];   // get next data bit
                 datain[16] <= miso[1];
                 datain[32] <= miso[2];
                 datain[48] <= miso[3];
                 datain[64] <= miso[4];
                 datain[80] <= miso[5];
                 datain[96] <= miso[6];
                 datain[112] <= miso[7];
                 datain[128] <= miso[8];
                 datain[144] <= miso[9];
                 datain[160] <= miso[10];  
                 datain[176] <= miso[11];  
                 
                 sclk_d <= 1'b0;         // clock low 
                 mosi_d <= cmd_d[7];     // show next command bit
				 datacnt_d <= datacnt_d + 1;  // count another data point
                 if( datacnt_d == 4'd15 )   // after 16 we are done
                 begin
                    state <= stop; // // or go to extra_1 to fix occasional spikes - but we shouldn't need this
                 end
            end    
         end  
      holdclk: // slow down SCLK (max 20MHz) 
         begin
           state <= data;
         end     
      stop:    // all done, clean up, get ready for next and go home
         begin  // we will stay quiet here for 2usec as we are in acquistion mode  		  
            if( cnvrtclk_d == 8'd100 )  // 8'd100  // we wait 2usec (8'd100)  - actually, was 4us
            begin
               cnvrtclk_d <=  8'd0;   // zero convert clock
               lastdata <= datain;  // keep previous data in case we have a bad data point next time  
               adcdone_d <= 1'b1;  // signal we have data
               state <= idle;      
            end
            else
            begin
              cnvrtclk_d <= cnvrtclk_d + 1;  // keep counting up
            end                          
         end 
      extra_1:   // we were getting occasional low rail spikes - this removes single odd spikes
         begin
         // temporary (?!) fix for occasional bad data  
             if ( datain[15:0]  < 16'h0010 )  datain[15:0] <= lastdata[15:0];
             if ( datain[31:16] < 16'h0010 )  datain[31:16] <= lastdata[31:16]; 
             if ( datain[47:32] < 16'h0010 )  datain[47:32] <= lastdata[47:32]; 
             if ( datain[63:48] < 16'h0010 )  datain[63:48] <= lastdata[63:48];         
             if ( datain[79:64] < 16'h0010 )  datain[79:64] <= lastdata[79:64];       
             if ( datain[95:80] < 16'h0010 )  datain[95:80] <= lastdata[95:80];    
             if ( datain[111:96] < 16'h0010 )  datain[111:96] <= lastdata[111:96];
             if ( datain[127:112] < 16'h0010 )  datain[127:112] <= lastdata[127:112];
             if ( datain[143:128] < 16'h0010 )  datain[143:128] <= lastdata[143:128];
             if ( datain[159:144] < 16'h0010 )  datain[159:144] <= lastdata[159:144];
             if ( datain[191:176] < 16'h0010 )  datain[191:176] <= lastdata[191:176];                
              
            state <= stop;
         end                   
    endcase
end

endmodule