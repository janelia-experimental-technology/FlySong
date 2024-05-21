//------------------------------------------------------------------------
// TMP06.v
//
// Interface to read dat from daisy-chained TMP05 temperature sensors. 
//
// Steve Sawtelle
// HHMI Janelia Research Campus
// 20161103 
//------------------------------------------------------------------------

//`default_nettype none

module TMP06
(
    input wire         clk,
    output wire [7:0]  led,
	input wire         tmpPin,
	output wire        cnvPin,
	output wire        tenPin,
	input wire         start, 
	output wire [15:0] temperature,  // temperature data
	output wire [15:0] tempvalid,    // temperature channel
	inout wire         tempread,
	output wire [191:0] testdata,
    output wire [15:0]  tp
	
);


// tmp06
reg  [3:0]  state;
reg  [23:0] hicnts;
reg  [23:0] locnts;
reg  [23:0] savehicnts;
reg   [9:0] cnvrtcnts;

reg startcnv;
reg cnvrtsig;
wire tensig;
reg tempdata;

 // divider                 
 wire  dvsrdy;
 reg   dvsvalid;        // dividend is ready
 reg   [15:0] divisor;
 wire   dvdrdy;         // out - dividend ready
 reg   dvdvalid;
 reg [31:0] dividend;
 reg [15:0] tempch;
 wire doutvalid;
 wire [47:0] dout;
 reg  [47:0] d_dout;
 wire [15:0] tempout;
 reg [191:0] testdatad;
 
 // multiplier
 reg[15:0]  multiplicand;
 wire[32:0] product;
 
 reg first;
 
 reg[5:0] div_wait_cnt;
 
 reg overflow;
 reg thrshld;
 reg lowover;
 reg glitch;
 
 reg tmpState;


assign temperature = d_dout[31:16]; //testdatad[31:16]; // !!!!  savehicnts[22:78];
assign tempvalid   = tempch; // { 1'b0, testdatad[15:1] }; // !!! 
 
assign cnvPin  = cnvrtsig; 
assign tenPin  = 1'b1;  //tensig;

assign testdata = testdatad;

//assign tp[7:4] = state[3:0];
//assign tp[8] = overflow;
//assign tp[9] = thrshld;
////assign tp[10] = lowover;
//assign led[7] = tmpPin;
//assign led[6] = start;
//assign tp[15:12] = tempch[3:0];
//assign tp[11] = glitch;


// Temperature measurement
// - take temperatures of 96 TMP05 devices in daisy-chain mode.
//    measure high and low times with 48Mhz clock
//    at 25 deg C:
//       high time ~= 34msec ~= 1,632,000 counts
//       low time  ~= 65msec ~= 3,120,000 counts
//   so need at least 22 bit numbers - we use 24 bits
//   deg C = 421- (751 * (th/tl))
//    - or - to get deg C * 100
//   deg C*100 = 421*100 - ((751*100) * th)/tl
//     we divide high time by 2^7 and drop MSB to get 16 bits ~= 12,750
//     same with low time ~= 24,375
//     first multiply th x 751 * 100 to get ~= 957,525,000
// 



localparam[3:0]
    idle     = 4'd0,
    cnvbeg   = 4'd1,
    waitcnv  = 4'd2,
    timehi   = 4'd3,
    higlitch = 4'd4,
    timelo   = 4'd5,
    loglitch = 4'd6,   
    endhi    = 4'd7,
    save     = 4'd8,
    delay    = 4'd9,
       
    multiply = 4'd10,
    divbeg   = 4'd11,
    divwait  = 4'd12,
    endhi_old = 4'd13;
  
 
always @(posedge clk) begin

   if( start == 1'b0 )
   begin
      state <= idle;
   end   
   
   tmpState <= tmpPin;  // latch current state of temperature output pin
   
   case (state)
   
      idle:
        begin
//           testdatad <= 192'h0;   
           dvdvalid <= 1'b0;
           dvsvalid <= 1'b0;    
           overflow <= 1'b0;
           thrshld <= 1'b0;
           lowover = 1'b0;
           glitch = 1'b0;

           if( start == 1'b1 )   //start conversion
           begin
              state <= delay;    // we will delay a bit when starting new round 
              hicnts <= 24'd0;    // reset temperature counters   
              cnvrtcnts <= 10'd0; // counter to set conversion time              
              first <= 1'b1;                          
           end               
           else
           begin
              cnvrtsig <= 1'b0;
              tempch <= 16'd0;  // 0 is no data yet  
              testdatad <= 192'd0;  // no data yet (ch = 0)             
           end   
        end   
        
      delay: // wait 100 usecs before starting a round, to be sure last round is done 
         begin
           cnvrtcnts <= cnvrtcnts + 1;   // count up conversion start timer
           if( cnvrtcnts >= 10'd4800 )   // 100 usces
           begin
              cnvrtcnts <= 10'd0;        // reuse counter to time start pulse 
              cnvrtsig <= 1'b1;   // set conversion pin high               
              state <=  cnvbeg;                    
           end
         end     
        
      cnvbeg:    // convert pin output
         begin
           cnvrtcnts <= cnvrtcnts + 1;     // count up conversion start timer
           if( cnvrtcnts >= 10'd480 )   // need convrt pin high >10 nsec && < 25 uS  - use ~10 usecs
           begin
              cnvrtsig <= 1'b0;      // when done, set cnvrt pin low 
              state <=  timehi;      
           end
           if( tmpState == 1'b1 )  // if conversion started, then count up  
           begin
              hicnts <= hicnts + 24'd1;
           end
        end
                       
      timehi:   // count high time
         begin
            if( tmpState == 1'b1 )  // while temp in pin hi, count
            begin
               hicnts <= hicnts + 24'd1;
               if( hicnts > 24'd2000000)
               begin
                    overflow <= 1'b1;
               end
               if( hicnts > 24'd500000 )
               begin
                    thrshld <= 1'b1;
               end
            end  
            else  // tmp pin went low, we are done with this one
            begin
                state <= higlitch;
            end
         end       
            
      higlitch:
         begin
            if( tmpState == 1'b0 )  // still low? -say its ok
            begin
               if( hicnts <= 24'd2000 )  // if hi counts was short, then that is end of daisy chain
               begin
                   state <= idle; //stwait; //  idle; // one set done  // endhi;   
               end
               else
               begin
                   savehicnts <= hicnts;
                   locnts <= 24'd0;  // was a temp reading, so set up and run lo time 
                   state <= timelo;                                 
               end      
            end  
            else
            begin
                state <= timehi; // glitch - keep going
                glitch = 1'b1;
            end              
         end   
         
      timelo:  // count lo time
         begin                  
            if( tmpState == 1'b0 )  // while lo, count
            begin
               locnts = locnts + 24'd1; 
               if( locnts > 24'd4500000 )
               begin
                  lowover <= 1'b1;
               end                           
            end
            else //  went hi, be sure it's not a glitch
            begin
               state <= loglitch;
            end
         end
         
      loglitch:         
         begin
            if( tmpState == 1'b1 ) // yup, still hi, ok legit
            begin   
               hicnts <= 24'd0;   // reset high counte
               thrshld <= 1'b0;
               overflow <= 1'b0;
               lowover = 1'b0;
               state <= endhi; // done with one, calculate....  timehi;   // when hi, start hi time again
            //   tempch <= tempch + 16'd1;  // count up channels
            end                    
            else  //glitch - not done
            begin
                state <= timelo;
                glitch = 1'b1;
            end    
         end    
         
      endhi:     
         begin            
            state <= save;
            if( first == 1'b1 )  // is this our first reading?
            begin
               tempch <= 16'd1;       // then set to chan 1
               first <= 1'b0;
            end  
            else
            begin   
               tempch <= tempch + 16'd1;  // else count up channels
            end                                                              
         end    
      
      save:
         begin
         // format of temp data:
         //  - top 4 bits of each 16 bit section is an ID - 0000 = adr, 0001 = num hi 12bits, 0010 = num lo 12bits, 0100 = den hi 12bits, 1000 = den lo 12bits 
            testdatad[95:0] <= { 16'd0, tempch[15:0], 4'd1, savehicnts[23:12], 4'd2, savehicnts[11:0], 4'd4, locnts[23:12], 4'd8, locnts[11:0] }; //[22:7]; //dout[31:16];
            state <= timehi;
            glitch = 1'b0;
         end   
         
      endhi_old:      
         begin            
            dvsvalid <= 1'b0;  
            dvdvalid <= 1'b0;
            multiplicand <= savehicnts[22:7]; //hicnts[22:7]
            testdatad[31:16] <= savehicnts[22:7]; //dout[31:16];
            state <= multiply;         
            hicnts <= hicnts + 24'd1;  // continue to count hi time while we calculate                                    
         end  
         
      multiply:
         begin
             divisor <=  locnts[22:7];  // lose lower 7 bits and top bit 16'd23215; //    
             testdatad[15:0]  <= locnts[22:7];       
             state <= divbeg; 
             hicnts <= hicnts + 24'd1;  // continue to count hi time while we calculate                         
         end    
              
      divbeg:   // start divide of product/locnts
         begin   // we use 32 bit dividend and 16 bit remainder
 //           if( dvdrdy == 1'b1 )
            begin
               dividend <= product[31:0];  // multiplican * 75100;  32'd922678600; //345678; //    
               dvdvalid <= 1'b1;
               dvsvalid <= 1'b1;
               div_wait_cnt <= 6'd0;
               state <= divwait;
              // testdatad[63:32] <= product[31:0];
 
            end         
            hicnts <= hicnts + 24'd1;  // continue to count hi time while we calculate            
         end
         
      divwait:   // wait for division to complete 
         begin
            hicnts <= hicnts + 24'd1;  // continue to count hi time while we calculate  
            div_wait_cnt <= div_wait_cnt + 6'd1;
            if( dvsrdy == 1'b1)  dvsvalid <= 1'b0;  // once these are latched stop the pipeline
            if( dvdrdy == 1'b1)  dvdvalid <= 1'b0;  
            if( doutvalid == 1'b1 )  // final temperature data is ready!
       //     if( (div_wait_cnt >= 6'd50) && ( doutvalid == 1'b1 ) )  // wait 1usec
            begin
               state <= timehi;
               glitch = 1'b0;
               if( first == 1'b1 )  // is this our first reading?
                begin
                  tempch <= 1;       // then set to chan 1
                  first <= 1'b0;
                end  
                else
                begin   
                  tempch <= tempch + 16'd1;  // else count up channels
                end                  
                          
                d_dout <= 48'd2759065600 - dout;   // 421 * 100 * 2^16 - (751 *100) * Th/Tl
               //  d_dout[31:16] will hold the temperature in C * 100 
// tempch <= 16'h0303; //              tempch <= tempch + 16'd1;  // count up channels               
               
            end
         end 
         
      default:
         begin
            state <= idle;
         end   
          
    endcase


end


 

 // ===========================
 // === M U L T I P L I E R ===
 // multiply high time (/2^7) by 751 * 100 
 mult_gen_0 mul
 (
    .CLK      (clk),
    .A        (multiplicand),
    .P        (product)
 );
 
 
// ======================
// === D I V I D E R  ===
// ======================
                     
 div_gen_0 div
 (
    .aclk                    (clk),
    .s_axis_divisor_tvalid   (dvsvalid), // divisor is valid
    .s_axis_divisor_tready   (dvsrdy),   // optional
    .s_axis_divisor_tdata    (divisor),  // divisor
    .s_axis_dividend_tvalid  (dvdvalid),   // 
    .s_axis_dividend_tready  (dvdrdy),    // optional
    .s_axis_dividend_tdata   (dividend),
    .m_axis_dout_tvalid      (doutvalid),  // answer ready
    .m_axis_dout_tdata       (dout)        // answer
 );                                    

endmodule
