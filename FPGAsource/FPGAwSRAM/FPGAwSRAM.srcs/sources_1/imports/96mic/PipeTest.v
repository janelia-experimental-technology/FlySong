//------------------------------------------------------------------------
// PipeTest.v
//
// === Interface to 96-Microphone boards; audio and temperature; also LED control ===  


// === VERSIONS === 
// NOTE!! be sure to update VERSIONYEAR and VERSIONDATE to match version number

// 20200625 sws
// - in TMP06 delay each new temp reading round by 100 usecs as we are supposed to wait for last round to be done
//    before I was not waiting at all after finish, maybe that caused some problems? 

// 20200518 sws
// - temperature readings debugged; now sending raw data over and calculating temperature on host

// 20200422 sws
//  addding temperature back in

// 2020104 sws
// - make adc aq delay 3.8 not 4 usec
// - change wait time back to 2usec 

// 20200103 sws 
// - add SRAM

// 20190103 sws
// - fix wrong channel code for channel 1

// 20181210 sws
// - change wait time in SPI.V ADC routine from 2us to 4

// 20181113 sws
// - code changes for doing channel 0-6 against 7 - pseudo differential
//   we would lose channel 7 (shows up as channel 1 on board) - the channel closest to the motherboard on each mic board
// - add 2us wait time after clocking data from ADC to give a clean time for data acquisition (SPI.v)
// - do not use spike fix state in SPI state machine (SPI.v)
//   

// 20180518 sws
// - if syncRate is '0' then no sync clock - allows us to start capture at start of data taking 
// - move temperature channel to lower 8 bits when saving 

// 20180419 sws
// - add in sync output, syncCounter section and add wirein 0x0c 

// 20170711 sws
// - reenable temperature saving 

// 20170611 sws
// - recompile to new date for deployment

// 20170519 sws
// - move battery status to bit 15 (from 0)
// - use lower 12 bits of status to return the max FIFO length

// 20170503 sws
// - adc_start and tmp_start where off a bit position?
// - add in LEDEnable to allow diasble of LED logic when running real time
// - add in download of LED time and brightness before experiment runs  
// - increase data FIFO size from 2^12 to 2^14 

// 20170214 sws
// - swap battery enable and monitor pins to reflect PCB design

// 20170206 sws
// - change LED0 data out to just dutycycle (was dutycycle << 8), which overran 16 bits

// 20170125 sws
// - hi time in first temperature channel was wrong due to how counting was done (or not) during convert signal
//  - saving record count in LED 1 channel for now

// 20170123 sws
// - use divider and divisor ready to halt pipeline  

// 20170120 sws
// - wait a bit before grabbing divider data (Was getting previous value)
//   might need to look closer at this; the divider is pipelined - I'd rather put in values and get a singel ouput when it's ready   

//20170119 sws
// - don't count up temperature channel until data is valid 

//20170118 sws
// - fixed temperature output 

//20161221 sws
 // - make LED brightness to 0.1% (x10 when sending), change PC code to match

//20161219 sws
// - channel select ready to test 

//20161217 sws
// - allow selecting exactly which channels to save. USes saveCHs, smplOnwire, and CheckCh

//20161212 sws
// - getting rearanged data to work 

// 20161211 sws
// - rearrange data save so that wav chs 1-4 are LED bright 0 and 1, tenp ch, and temp
// - also allow for a variable number of mic boards to be saved (we still sample all of them)      

// 20161207 sws 
//  - change sense of LED drive so at startup LEDs are off (requires a high drive)
//    added inverters to PCB and reverse drive levels in code

// 20161205 sws
// - start adding temperature values into extra channels
//
//
// 20161202 sws
//  - got 16 bit wide FIFO workinhg
//  - added 3 words for LED brightness and temperature, stored as: 
//     ch 97 = LED0 bright * 0x10000 + LED1 bright (working)
//     ch 98 = temperature channel being saved (hard coded right now) 
//     ch 99 = temperature data as deg C times 100 (heard coded right now) 
//
// 20161201 sws
//  - add temperature and LED control to pipeout data
//  - change from wide fifo to 16 bit fifo to facilitate power of 2 block transfers  
//
//
// 20161130 sws
//  - ADC working, board 9 (0-11) low bit value wrong in dataout
//  - LED basic code in place
//  - Temperature code needs work        
//
// 20161029 sws - ADC basically working
//------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module PipeTest(
	input  wire [7:0]  hi_in,
	output wire [1:0]  hi_out,
	inout  wire [15:0] hi_inout,
	inout  wire        hi_aa,

	output wire        hi_muxsel,

	output wire [7:0]  led,
	output wire [15:0]  tp,
	
	input wire         tmpPin,
    output wire        cnvPin,
    output wire        tenPin,
    
    input wire [11:0]  misoPins,
    output wire        mosiPin,
    output wire        sclkPin,
    output wire        adccsPin, 
    
    output wire        LED0Pin,
    output wire        LED1Pin,
    
    output wire        auxioPin,         // auxilliary I/O BNC
         
    output wire        batEnablePin,    // enable battery to system, high is on
    input wire         batStatePin,     // check staus of battery voltage, high is good
    
    inout wire [15:0]  RAMdata,         // SRAM data lines 
    output wire [21:0] RAMadr,          // SRAM address lines
    output wire        RAMoe,           // SRAM output enable
    output wire        RAMwr            // SRAM write line

	);
	

parameter YEAR = 16'd2020;    
parameter DATE = 16'd0625;    	
parameter FIFOLEN = 16'h8000;
parameter LEDFIFOLEN = 16'd511;

// Endpoint connections:
wire [15:0]  ep00wire, clksPerSmp, numChs, LED0, LED1, status, syncRate, maxAdrLOW, maxAdrHOW;
//wire [15:0]  tmpdata;
wire [15:0]  VERSIONDATE;
wire [15:0]  VERSIONYEAR;	
wire [95:0]  smplOnwire;
wire [15:0]  LEDindex;  

assign VERSIONYEAR = YEAR; //16'd2017;	
assign VERSIONDATE = DATE; //16'd0123;

// Target interface bus:
wire         ti_clk;
wire [30:0]  ok1;
wire [16:0]  ok2;

assign hi_muxsel = 1'b0;


function [7:0] xem7001_led;
input [7:0] a;
integer i;
begin
	for(i=0; i<8; i=i+1) begin: u
		xem7001_led[i] = (a[i]==1'b1) ? (1'b0) : (1'bz);
	end
end
endfunction

// assign led = xem7001_led(rcv_errors[7:0]);
//assign led[7] = tmpPin;
//assign tp[7:5] = cmdcnt[2:0];
//assign tp[3:2] = po_state;
////assign tp[6:0]  = po_rd_cnt[5:0];
/// tp[7] = pipe_out_read;
//assign tp[7] = adc_start;

//assign led[4:0] = po_rd_cnt[4:0];
//assign tp[7] = LED0drive;  //start;
//assign tp[6:0] = clockcnt[6:0]; //adcfifoin[2:0];
//assign tp[3:0] = adctest[3:0];

// Pipe Out
wire        pipe_out_read;
wire        pipe_out_strobe;
wire        pipe_out_ready;
wire [15:0] pipe_out_data;

    

reg         start;                       
wire        do_reset;
wire        adc_start;
wire        LEDEnable;
reg         po_ready; 
reg [7:0]   command;
reg [2:0]   cmdcnt;
reg [3:0]   datacnt;
wire [191:0] adcdata;
wire [191:0] tempinfo;
reg [96:0]  tempvalues;

// 512 (1024 bytes) should yield 38MB/sec thoughput
reg  [15:0]  datafifo [511:0]; // [32767:0]; //[FIFOLEN-1:0]; //[16383:0]; //[8191:0]; //[4095:0];  // word wide by 4096 
reg  [8:0]  fifoin;
//reg  [207:0] fifodata;
//reg  [191:0] adctest;
//reg  [7:0]  adcfifoin;        // keep tabs on where we are
reg [95:0]  saveChs;   // a '1' bit in every place we should save save data
reg [95:0]  checkCh;   // walks through the save bits 

//reg  [7:0]   fifowr;
//reg  [7:0]   fiford;
wire        adcdone;
reg         senddata;


reg [15:0]  sampleclk;  // count up time between samples
reg [15:0]  samplecnt;  // sets sample rate count = 48e6/sample rate 
reg [15:0]  numrounds;     // number of rounds of 96 channels to do 


wire[15:0] tmpdata;
wire[15:0]  tmpvalid;
wire       tmp_start;
reg [15:0] lastvalid;
wire        tempread;
reg [31:0]  maxBuffer; 

reg batEnableDrive;


reg  syncadc;  // 0 = 'throw away' round of ADC, 1 = first round, 2 = remaining rounds

assign status[15] = batStatePin;
assign status[11:0] = LEDFIFOLEN;

assign maxAdrLOW = maxBuffer[15:0];
assign maxAdrHOW = maxBuffer[31:16]; 

assign batEnablePin = ep00wire[0];
assign do_reset = ep00wire[2];
assign adc_start = ep00wire[4];
assign tmp_start = ep00wire[5];
assign LEDEnable = ep00wire[6];
assign pipe_out_ready = po_ready;

reg syncOut;
assign auxioPin = syncOut;

reg [15:0]  fifoword;
reg [25:0]  syncClocks;
assign pipe_out_data = fifoword; 

// ===== SYNC OUT =======
//    host sends value as 48e6/(1000 * rate) so we calculate half cycle
//    by taking this value and multiplying by 500 using shift and subtract (512x - 8x - 4x) 

reg [25:0] syncCounter;
reg [15:0] frameCount;

always @(posedge ti_clk)
begin
 // syncClocks <= (syncRate << 9)  - (syncRate << 3) - (syncRate << 2);
  if (do_reset == 1'b1) 
  begin
    syncCounter <= 26'd00; //(syncRate << 9)  - (syncRate << 3) - (syncRate << 2);  //syncClocks; //syncRate;  //26'd30; //
    syncOut <= 1'b0;
    frameCount <= 16'd0;
  end
  else // not reset 
  begin
    if( syncRate > 26'd00 )  // if the rate is set to 0 then no clock
    begin
 	    syncCounter <= syncCounter + 1;
        if (syncCounter == (syncRate << 9)  - (syncRate << 3) - (syncRate << 2) )  //26'd00)
        begin
            if( syncOut == 1'b1)
            begin             
               frameCount <= frameCount + 16'd01;
            end
            syncCounter <= 26'd00; //(syncRate << 9)  - (syncRate << 3) - (syncRate << 2);  //  syncClocks; //26'd24000000 / syncRate;  // 26'd30; // 48Mhz/synrate
            syncOut <= ~syncOut;
        end 
     end      
     else  // syncCounter is > 0 
     begin
        syncOut <= 1'b0;
     end   // end check syncCounter
 //       ledtimer <= ledtimer + 24'd1;            // always inc the timer
  end  // reset check      
end   


// ========  Run the LED driver ==================
// if we use 10Khz rep rate 
//   and want 0.1% changes:
// 48e6/10000 = 4800 counts per rep and 1000 steps 
// 4800 / 1000 = 4.8, two halves / clock = 2.4
// must be integer.. 8Khz rep rate: 
// 48e6/2000 = 24000/8000 = 3

// if we use 10Khz rep rate 
//   and want 1% changes:
// 48e6/10000 = 4800 counts per rep and 100 steps 
// 4800 / 100 = 48, two halves / clock = 24

// dutycycle is 0 - 1000 (0.0% to 100.0% x10)  

reg  [8:0]  div1;
reg         clk1div;
reg  [15:0]  dutycycle0;
reg  [15:0]  dutycycle1;
reg  [15:0]  clockcnt;
reg         LED0drive;
reg         LED1drive;
reg  [23:0] ledcounter;
reg  [15:0] LEDBrightFIFO [LEDFIFOLEN:0];  // word wide by 256 for LEDs
reg  [15:0] LEDTimeFIFO [LEDFIFOLEN:0];
//reg         LEDclk;
reg  [23:0] ledtimer;
reg  [7:0] LEDptr;
reg  [15:0] maxLEDindex;
reg tpreg;
reg tpreg2;
reg [15:0] LEDbright;


assign LED0Pin = LED0drive;
assign LED1Pin = LED1drive;

always @(posedge ti_clk) 
begin
//    if( do_reset == 1'b1 )
//    begin
//       maxLEDindex <= 16'd0;
//    end
//    else
    begin
 	  if( LEDindex != 16'd0 )  // the sent index start at 1, as 0 means no data
 	  begin
     	LEDBrightFIFO[LEDindex-1] <= LED0;  // brightness, compensate for index starting at 1  
     	LEDTimeFIFO[LEDindex-1]  <= LED1;   // time
// 	    if( LEDindex > maxLEDindex )
 //       begin
        maxLEDindex <= LEDindex;  // we assume LED data is sent from first to last 
// 	    end   
      end
    end     
end    

always @(posedge ti_clk)
begin
  if (LEDEnable == 1'b0) 
  begin
    ledcounter <= 24'd4800000;
    ledtimer <= 24'd0;  // timer for LEDS (0.1 sec per tick)   
  end
  else 
  begin
 	ledcounter <= ledcounter - 1;
    if (ledcounter == 24'd00)
    begin
        ledcounter <= 24'd4800000;   // 48Mhz/10 for 0.1sec tick, 
 //       LEDclk <= ~LEDclk;
        ledtimer <= ledtimer + 24'd1;            // always inc the timer
    end
  end     
end   

//assign tp[0] = tpreg;
//assign tp[1] = LEDclk;
//assign tp[5:1] = LEDbright[4:0]; //dutycycle0[4:0]; //LEDBrightFIFO[LEDptr][4:0]; //LED0[6:1];LEDptr[4:0]; //
//assign tp[7:6] =  LEDstate; 
//assign tp[7:4] = LEDBrightFIFO[LEDindex][3:0];
//assign tp[0] = LEDclk;
//assign tp[1] = do_reset;
//assign tp[3:1] = LEDptr[2:0];
//assign tp[7:4] = dutycycle0[3:0];
//assign tp[7] = LED0drive; 
localparam[1:0]
    LEDstart  = 2'd0,
    LEDwait   = 2'd1,
    LEDnext   = 2'd2,
    LEDend    = 2'd3;

reg [1:0] LEDstate;

always @(posedge ti_clk) //LEDclk)
begin
  
    if (LEDEnable == 1'b0) 
    begin
 //      ledtimer <= 24'd0;
       LEDptr <= 8'd0;
       LEDstate <= LEDstart;  
 //      tpreg = 1'b0;    
       LEDbright <= 16'd0;    
    end
    else
    begin
        case (LEDstate)
          LEDstart:
            begin
                //dutycycle0 <= 16'd85; //LEDBrightFIFO[0];  // start with first
                LEDbright <= LEDBrightFIFO[0]; 
                LEDptr <= 8'd0; 
                LEDstate <= LEDwait;
  //              tpreg <= 1'b1;
            end
          LEDwait:
            begin
              if( ledtimer >= LEDTimeFIFO[LEDptr] )    // if timer has reached next setting 
              begin                   
                LEDptr <= LEDptr + 8'd1;              // and point to the next timer/brightness values  
                LEDstate <= LEDnext;
              end
            end      
          LEDnext:
            begin
              if( LEDptr < maxLEDindex )
              begin          
                 //dutycycle0 <= 16'd85; //LEDBrightFIFO[LEDptr]; // << 1; //*2;  // update the LED brightness
                 LEDbright <= LEDBrightFIFO[LEDptr]; 
                 LEDstate <= LEDwait;
 //                tpreg <= ~tpreg;
              end
              else         
              begin
                 LEDstate <= LEDend; 
              end
            end  
          LEDend:
             begin
                //dutycycle0 <= 16'd0;  // LEDs off at end
               LEDbright <=- 16'd0;
 //               tpreg <= 1'b0;
             end    
         endcase   //       
     end       
 end   // end LED brightness updates

//always @(posedge ti_clk)
//begin
//	div1 <= div1 - 1;
//	if (div1 == 8'd00) begin
//		div1 <= 8'd2;   //24
//		clk1div <= ~clk1div;
////	state_next <= starthi;
//	end
// end
 
always @(posedge ti_clk) 
begin
 //  fifodata[15:14] <= {~LED1drive, ~LED0drive};  // always update the LED status 
   if (LEDEnable == 1'b0) 
   begin
      clockcnt <= 16'd0;
     // dutycycle0 <= 16'd0;
//      dutycycle1 <= 16'd0;
      LED0drive <= 1'b0;  
      LED1drive <= 1'b0; 
   end
   else
   begin
//   dutycycle0 <= 16'd500;  // for testing
     clockcnt <= clockcnt + 16'd1; 
     if( clockcnt == 16'd1000 )
     begin 
        clockcnt <= 16'd0;   
 //       if( dutycycle0 == 16'd0 )  // 0 is off, so just force it off
        if (LEDbright == 16'd0 ) 
        begin
           LED0drive <= 1'b0;
        end
        else
        begin
           LED0drive <= 1'b1;
        end   
     end
     else
     begin
         if( clockcnt == LEDbright ) //dutycycle0 )
         begin
            LED0drive <= 1'b0;
         end    
     end                     
   end   
end

// ========= end LED driver =======


// ==== TEMPERATURE ====  
always @(posedge ti_clk) 
begin
//   fifodata[13:12] <= {start, tmpvalid};
 //  fifodata[11:0] <= tmpdata[11:0];
end

// ===============================
// === Run the ADC SPI port ======  
// ===============================
// - The main data taking routine  - here we take the data and put it in the ouput FIFO
// 

reg [21:0] wrAdr;       // next address to write to
reg [21:0] rdAdr;       // next address to read from
reg [15:0] wrData;      // data to write
reg [15:0] rdData;      // data to read    
reg wr;                 // SRAM write strobe
reg oe;                 // SRAM output enable strobe for reading
reg wren;               // output enable for FPGA data out register ; 0 = hi-Z , 1 = enable FPGA wrData to SRAM data bus 
reg adrSource;          // use to mux write or read address to SRAM address bus ( 0 = write, 1 = read)  

wire portEnable;
wire [15:0] portOut;
wire [15:0] portIn;

assign RAMdata = portEnable ? portOut : 16'bz;
assign portIn = RAMdata;  

assign portEnable = wren;
assign portOut = wrData;

reg [21:0] bufferUsed; 


//assign RAMdata = (wren) ? wrData : 16'bz;  // this is our write data bus to the SRAM (1 put FPGA data bus out SRAM, 0 allows us to read the SRAM data bus) 
assign RAMadr = (adrSource) ? rdAdr : wrAdr;  // select which address goes to SRAM (0 for write, 1 for read)
assign RAMwr = wr;
assign RAMoe = !adrSource; // 1'b0; //oe;

reg [2:0] rdwait;


reg [4:0] adcstate;
reg [4:0] returnState;
reg [3:0] adcsavecnt; 
reg [15:0] reccnt;
reg [15:0] auxio;
reg [2:0] tempstate;
  
localparam[4:0]
    adcidle   = 5'd0,
    adcstart  = 5'd1,
    adcwait   = 5'd2,
    adctimer  = 5'd3,
    adcsave   = 5'd4,
    adcLED0   = 5'd5,
    adcLED1   = 5'd6,
    adctmpch  = 5'd7,
    adctmp    = 5'd8,
    adcdummy  = 5'd9,
    wr1       = 5'd10,
    wr2       = 5'd11,
    wr3       = 5'd12,
    wr4       = 5'd16,
    adcwaitrd = 5'd13,
    ram2fifo1 = 5'd14,
    ram2fifo2 = 5'd15;
    
 localparam[2:0]
    latchtemp = 3'd0,
    zero= 3'd1,
    ch  = 3'd2,
    hiCntsHOW = 3'd3,
    hiCntsLOW = 3'd4,
    loCntsHOW = 3'd5,
    loCntsLOW = 3'd6;
    
       
    
                   
always @(posedge ti_clk) 
begin
    if (do_reset == 1'b1) 
    begin
       wren  <= 1'b0;
       start  <= 1'b0;
       cmdcnt <= 3'd0; 
       adcstate <= adcidle;
       sampleclk <= 16'd0;
       samplecnt <= clksPerSmp; // user defined rate //16'd24000;  //24000 = 2000 smpl/sec   //16'd4800; // 48e6 clock /10000 samples/sec
       numrounds <= 16'd1000;
       lastvalid <= 16'd0;
       saveChs <= smplOnwire;  // get current list of channels to save      
      // fifoin <= 8'd0;     
       reccnt <= 16'h0000;   // testing; track number of records  
       wrAdr <= 22'd0;
       bufferUsed <= 22'd0;
       maxBuffer <= 22'd0;
       tempstate <= latchtemp; //zero;
    end      
    else
    begin
        sampleclk <= sampleclk + 1;  // always keep track of the sample timer 
        bufferUsed = wrAdr - rdAdr;
        case(adcstate)
           adcidle:
              if( adc_start == 1'b1 )  // do_reset == 1'b0 )
              begin
                  if( sampleclk > 16'd65000 )  // delay a bit, to let readBTpipe get ready
                  begin          
                    sampleclk <= 16'd0;
                    cmdcnt <= 3'd7;       // first conv is bogus, but sets up to start ch 0 
                   // fifoin <= 8'd0;      // 
                    syncadc <= 1'b0;      // run one adc conversions w/o saving, to get good data right off and sync up
                    command <= 8'hf4; //8'hf4;     // send comamnd to convert ch 0 
                    checkCh <= 96'b1;     // reset bit check walker                                         
                    adcstate <= adcLED0;  // start saving first data w/o waiting       
//                    auxio <= 1'b0;                                                               
                  end 
              end
              else
              begin
                 sampleclk <= 16'd0;
              end  
                             
           adctimer:
              begin             
                 if (sampleclk == samplecnt ) // time to start next round
                 begin
                    sampleclk <= 16'd0;   // reset sample clk count
                    adcstate <= adcwaitrd;  
                 end                    
              end   
              
            adcwaitrd:  // be sure any ongoing SRAM read is done
                begin   
                    if( adrSource == 1'b0 ) // when pipe out sets adress back to writing we can move on  
                    begin             
                        adcstate <= adcLED0;  //adcstart; 
                        //adrSource <= 1'b0;    // use write address while gathering data      
                        //oe = 1'b1;            // disable SRAM data out
                    end      
                end                  
              
            adcLED0:   // LED0 drive  status - this will be Channel 1 in the WAV file
               begin                     
//                  datafifo[fifoin] <=  LEDbright; //dutycycle0; //, 8'h0 };   //adcdata2[31:16]; //saveChs[15:0]; // 
//                 fifoin <= fifoin + 15'd1;          // point to next FIFO location
                   
                   //RAMadr <= wrAdr;                  
                   //wrAdr <= wrAdr + 21'd1;
                   wr <= 0;
                   wrData <= LEDbright;
                   returnState = adcLED1;
                  
                  if( syncadc == 1'b0 )              // just started ,
                     start <= 1'b1;                  //   kick off ADC to get ch0 mux set
 //                 adcstate <= adcLED1;       
                  adcstate <= wr1;
                  checkCh <= 96'b1;                  // reset walker through the channels 
                  
// if( reccnt == 16'hC7ab) 
//    tpreg = 1'b1;
// if( reccnt == 16'hc7ac )
//    tpreg = 1'b0;                 
               end 
                                         
            adcLED1:   // was LED 1 drive status - now it is camera sync count (mod 16) - this will be Channel 2 in the WAV file
               begin           
 //                 datafifo[fifoin] <= frameCount; //reccnt; //adcdata2[15:0]; // { dutycycle1, 8'h0 }; // saveChs[31:16]; // adcdata2[15:0];
                  reccnt = reccnt + 16'd1;
 //                 fifoin <= fifoin + 15'd1;          // point to next FIFO location         
                   //RAMadr <= wrAdr;
                   //wrAdr <= wrAdr + 21'd1;
                   wr <= 0;
                   wrData <= frameCount;
                      
                  if( syncadc == 1'b0 )                // if we just started
                  begin 
                     start <= 1'b0;                    //    reset ADC start
                     returnState <= adcdummy;   
                   //  adcstate <= adcdummy;             //    and go wait for end of dummy conversion
                  end
                  else
                  begin
                   //  adcstate <= adctmpch;             // else we go to temp ch save
                      returnState <= adctmpch; 
                  end       
                  adcstate <= wr1;
                  
               end       
                  
          adcdummy:       // dummy adc read to get first real ADC channel set up, only do this state once per run
              begin        // we will wait here until first ADC reading is ready
                syncadc <= 1'b1;       // do this state only one time                      
                if( adcdone == 1'b1 )  // yup, done, but don't save it
                begin
                   adcstate <= adctmpch;  // so go on with normal run      
                   cmdcnt <= cmdcnt + 1;  // and set for for next command
                end                             
              end  
                    
            adctmpch:   //save the temperature channel - this will be Channel 3 in the WAV file
              begin           
 //                adcstate <= adctmp;  // and save temperature data next
//                 datafifo[fifoin] <=  { 8'd0 , tmpvalid[7:0] }; //16'd200; //saveChs[47:32]; //adcdata2[47:32]; // !!! 16'd1; // adcdata2[47:32]; //\\                
//                 fifoin <= fifoin + 15'd1;          // point to next FIFO location      
                   //RAMadr <= wrAdr;
                   //wrAdr <= wrAdr + 21'd1;
                   wr <= 0;
                   wrData <= tmpvalid; // !!! { 8'd0 , tmpvalid[7:0] };
                   returnState <= adctmp;
                   adcstate <= wr1;
                  
//if( reccnt == 16'h7fff ) reccnt <= 16'd0;  

    
              end            
                                
           adctmp:  // and the temperature data - this will be Channel 4 in the WAV file
              begin
                   case( tempstate )
                        latchtemp:
                            begin
                              tempvalues <= tempinfo[95:0];
                              tempstate <= zero;
                              wrData <= 16'd0; // first data is always 0
                              tempstate <= ch;
                            end
//                        zero:
//                            begin
//                              wrData <= tempvalues[95:88];
//                              tempstate <= ch;
//                            end
                        ch:
                            begin
                              wrData <=  tempvalues[87:64];
                              tempstate <= hiCntsHOW;
                            end    
                        hiCntsHOW:
                            begin
                              wrData <=  tempvalues[63:48];
                              tempstate <= hiCntsLOW;
                            end  
                        hiCntsLOW:
                            begin
                              wrData <=  tempvalues[47:32];
                              tempstate <= loCntsHOW;
                            end                                                 
                        loCntsHOW:
                            begin
                              wrData <=  tempvalues[31:16];
                              tempstate <= loCntsLOW;
                            end  
                        loCntsLOW:
                            begin
                              wrData <=  tempvalues[15:0];
                              tempstate <= latchtemp;
                            end                    
                   endcase
                   wr <= 0;
                  //wrData <= tmpdata; // bufferUsed[21:6]; // 16'h00003; //tmpdata;
                   returnState <= adcstart;
                   adcstate <= wr1;
              end
                                                            
           adcstart:    // start next conversion and get ADC routine running
              begin  
                 start <= 1'b1;         // start signal    
                 adcstate <= adcwait;   // then go wait for ADC routine to be done
                 cmdcnt <= cmdcnt + 1;  // set for for next command       
              end   
               
           adcwait:  // wait for conversion complete
             begin   //   we read all 12 boards' selected channel in parallel
               start <= 1'b0;         // reset start signal
               if( adcdone == 1'b1 )  // we will loop here until we get a 'done' signal from ADC routine
               begin   // board has channels in reverse order to simplify layout, so our ch 0 is ADC ch 7, etc
                  case(cmdcnt)       // this cycles through the channel select commands for the 8 channels
                                     // commands with 8'hx4 are single ended, 8'hx8 are differential w/respect to ch 7 (ch 0 in data) 
                     3'd0: begin command <= 8'hb4; end // b8 // 8'hb4;  end
                     3'd1: begin command <= 8'he4; end // 8'he4;  end 
                     3'd2: begin command <= 8'ha4; end // 8'ha4;  end
                     3'd3: begin command <= 8'hd4; end // 8'hd4;  end         
                     3'd4: begin command <= 8'h94; end // 8'h94;  end
                     3'd5: begin command <= 8'hc4; end // 8'hc4;  end
                     3'd6: begin command <= 8'h84; end // 8'h84;  end
                     3'd7: begin command <= 8'hf4; end // 8'hf4;  end 
                  endcase  
                  adcstate <= adcsave; // if done, we can go save data
                  returnState <= adcsave;  // usually we come back to adcsave, channel 12 will modify this to start next round 
                  adcsavecnt <= 4'd0;  // start board check with board 0 of 11
  //                adctest <= adcdata;  // testing.....                                                                                         
               end
             end    
             
          adcsave:  // save the selected data to the fifo - this will be channels 5 through 100 (if all channels are on)
          begin     // we will stay in this state 12 times to save each board's data if needed     
          
             case (adcsavecnt)  // create sign bit at the same time
                4'd0:  begin wrData <= adcdata[15:0]    ^ 16'h8000; end // reccnt; end  // adcdata[15:0] ^ 16'h8000; end //    ^ 16'h8000; end  //{ adcsavecnt, 1'b0, cmdcnt, 8'h00 }; end //adcdata[15:0]     ^ 16'h8000; end  //{ 9'h00, cmdcnt, 4'd0 }; end //{{ adcsavecnt, 1'b0, cmdcnt, fifoin[7:0] }; adcstate <= adcsave;  end  // {9'b0, cmdcnt,  adcsavecnt }; end  //5'b0, cmdcnt-1, 8'h55}; end // 
                4'd1:  begin wrData <= adcdata[31:16]   ^ 16'h8000; end // 16'hc000; end //  ^ 16'h8000; end  //{ adcsavecnt, 1'b0, cmdcnt, 8'h00 }; end  { 9'h00, cmdcnt, 4'd1 }; end // { adcsavecnt, 1'b0, cmdcnt, fifoin[7:0] }; adcstate <= adcsave;  end  // {9'b0, cmdcnt,  adcsavecnt }; end  //fifoin + 16'h2000; end   //
                4'd2:  begin wrData <= adcdata[47:32]   ^ 16'h8000; end //  ^ 16'h8000; end  // adcsavecnt, 1'b0, cmdcnt, 8'h00 }; end //{ 9'h00, cmdcnt, 4'd2 }; end // { adcsavecnt, 1'b0, cmdcnt, fifoin[7:0] }; adcstate <= adcsave;  end  // {9'b0, cmdcnt,  adcsavecnt }; end  //
                4'd3:  begin wrData <= adcdata[63:48]   ^ 16'h8000; end //  ^ 16'h8000; end  //{ adcsavecnt, 1'b0, cmdcnt,  8'h00 }; end // { 9'h00, cmdcnt, 4'd3 }; end //  { adcsavecnt, 1'b0, cmdcnt, fifoin[7:0] }; adcstate <= adcsave;  end  // {9'b0, cmdcnt,  adcsavecnt }; end  //        
                4'd4:  begin wrData <= adcdata[79:64]   ^ 16'h8000; end //  ^ 16'h8000; end  //{ adcsavecnt, 1'b0, cmdcnt,  8'h00 }; end // //{ 9'h00, cmdcnt, 4'd4 }; end //  { adcsavecnt, 1'b0, cmdcnt, fifoin[7:0] }; adcstate <= adcsave;  end  // {9'b0, cmdcnt,  adcsavecnt }; end  //
                4'd5:  begin wrData <= adcdata[95:80]   ^ 16'h8000; end // ^ 16'h8000; end  // { adcsavecnt, 1'b0, cmdcnt,  8'h00 }; end //{ 9'h00, cmdcnt, 4'd5 }; end // { adcsavecnt, 1'b0, cmdcnt, fifoin[7:0] }; adcstate <= adcsave;  end  // {9'b0, cmdcnt,  adcsavecnt }; end  //
                4'd6:  begin wrData <= adcdata[111:96]  ^ 16'h8000; end // ^ 16'h8000; end  // { adcsavecnt, 1'b0, cmdcnt,  8'h00 }; end //{ 9'h00, cmdcnt, 4'd6 }; end // { adcsavecnt, 1'b0, cmdcnt, fifoin[7:0] }; adcstate <= adcsave;  end  // {9'b0, cmdcnt,  adcsavecnt }; end  //
                4'd7:  begin wrData <= adcdata[127:112] ^ 16'h8000; end // ^ 16'h8000; end  // { adcsavecnt, 1'b0, cmdcnt,  8'h00 }; end //{ 9'h00, cmdcnt, 4'd7 }; end //{ adcsavecnt, 1'b0, cmdcnt, fifoin[7:0] }; adcstate <= adcsave;  end  // {9'b0, cmdcnt,  adcsavecnt }; end  //
                4'd8:  begin wrData <= adcdata[143:128] ^ 16'h8000; end // ^ 16'h8000; end  // { adcsavecnt, 1'b0, cmdcnt,  8'h00 }; end //{ 9'h00, cmdcnt, 4'd8 }; end // { adcsavecnt, 1'b0, cmdcnt, fifoin[7:0] }; adcstate <= adcsave;  end  // {9'b0, cmdcnt,  adcsavecnt }; end  //
                4'd9:  begin wrData <= adcdata[159:144] ^ 16'h8000; end // ^ 16'h8000; end  //{ adcsavecnt, 1'b0, cmdcnt,  8'h00 }; end //{ 9'h00, cmdcnt, 4'd9 }; end //  { adcsavecnt, 1'b0, cmdcnt, fifoin[7:0] }; adcstate <= adcsave;  end  // {9'b0, cmdcnt,  adcsavecnt }; end  //
                4'd10: begin wrData <= adcdata[175:160] ^ 16'h8000; end // ^ 16'h8000; end  //{ adcsavecnt, 1'b0, cmdcnt,  8'h00}; end //{ 9'h00, cmdcnt, 4'd10 }; end // { adcsavecnt, 1'b0, cmdcnt, fifoin[7:0] }; adcstate <= adcsave;  end  // {9'b0, cmdcnt,  adcsavecnt }; end  //
                4'd11: begin 
                          wrData <= adcdata[191:176] ^ 16'h8000 ;  //^ 16'h8000; // { adcsavecnt, 1'b0, cmdcnt,  8'h00 }; //{ 9'h00, cmdcnt, 4'd11 };  { adcsavecnt, 1'b0, cmdcnt, fifoin[7:0] };   //    {9'b0, cmdcnt,  adcsavecnt };  //                    
                          if( cmdcnt == 3'd0)        // we have all 12 channels; have we gone thru all 8 channels from each board? 
                          begin
  //                           auxio <= 1'b0;       
                             returnState <= adctimer;   // yes, go wait for next conversion time before taking next set of data   
                             adcstate <= adctimer;      // if we don't save this channel, return to timer                        
                          end   
                          else                       // no, start next channel right away
                          begin
                             returnState <= adcstart;
                             adcstate <= adcstart;   // in case we don't need to write
                          end
                        end                                              
             endcase // which channel
                               
             adcsavecnt <= adcsavecnt + 4'd1;       // point to next board
             if( (checkCh & saveChs) == checkCh )   // save this channel? if match - save it, by incrementing FIFO pointer
             begin
                  //RAMadr <= wrAdr;
                  //wrAdr <= wrAdr + 21'd1;
                  wr <= 0;
                  adcstate <= wr1;                // go write data to SRAM  - data is in wrData register
 //                 fifoin <= fifoin + 15'd1;          // point to next FIFO location           
             end      
             checkCh = checkCh << 1;  // always walk to next position for next check
          end  // end case adcsave  
          
          // === Write a 16 bit data value to SRAM ===
          // enter with data in wrData and WE# low (we)
          
          wr1:  // DOUT should be tristated in SRAM by now       
          begin
              wren <= 1'b1;  // enable portOut (wrData) to SRAM Data bus
              adcstate <= wr2;
             // wrData <= wrAdr[15:0];  // frameCount; // !!! testing
          end  
          
          wr2:          // wait state - need 45 nsecs
          begin
              adcstate <= wr3;   
          end
          
          wr3:          // write the data
          begin
              wr = 1'b1;  // WE# high
              adcstate <= wr4;  
          end
          
          wr4:          // end write, inc ram pointer
          begin
              wren <= 1'b0;   // disable data in to SRAM; allows reading
              wrAdr <= wrAdr + 22'd1;    // point to next write address
              if( bufferUsed >maxBuffer[21:0] )   // track the buffer high water mark
              begin
                  maxBuffer[21:0] <= bufferUsed; //[21:6];
              end
              
              adcstate <= returnState;  // go back from where you came     
          end
           
          default:
             adcstate <= adcidle; 
        endcase  // adc state
   end  // if we are running                 
end 

 
// ========================
// === P I P E   O U T ====
// ========================     

// handle sending data out to host using Block Throttled Pipe
// Once a block is started, it will be pulled at full rate, so we need to move from slower SRAM to a FIFO a block at a time
// We will do this between data sampling rounds when the data collection is idle for a bit
// We watch for the data collection state machine to be at the adctimer state, which means it's just killing time. Then, if 512 words are
//  available we will move them to the FIFO. Here we set the adrSource to read address, and the data collection state machine will 
//  hold off the next sampling round while that's active. So we may delay a sample interval slightly from time to time (10's of nsecs)  
// !!! === It might be better to start filling the FIFO and stop when the state moves on to start sampling again ===
// After the fifo is full, we hand it off to the block throttle pipe states and that transfer can happen simultaneous with the sampling 
//   and filling more data into RAM 
// Since we collect, at most, 100 words each sampling time, we should easily keep up with the data  

localparam[3:0]
    po_idle   = 4'd0,
    po_ram2fifo = 4'd1,
    po_rd1    = 4'd2,
    po_rd2    = 4'd3,
    po_rd3    = 4'd4, 
    po_send  =  4'd5,
    po_wait   = 4'd6,
    po_start  = 4'd7,    
    po_end    = 4'd8;
   
    
reg [9:0]  po_rd_cnt;  
reg [8:0] fifoout;
reg [3:0]  po_state;  
reg rdFlag;
                       
always @(posedge ti_clk) 
begin

//   if( (fifoin - fifoout) >= 15'h7fff )
//      tpreg = 1'b1;
//   else 
//      tpreg = 1'b0;   

   if (do_reset == 1'b1) 
   begin
       adrSource = 1'b0;  // assume start with write
       po_state <= po_idle;
       po_ready <= 1'b0;  
       fifoout <= 9'd0;
       fifoin <= 9'd0;
       po_rd_cnt <= 10'd0;
       fifoword <= 16'h55aa;
       tpreg2 <= 1'b0;
       rdAdr <= 22'd0;
       rdFlag <= 1'b0;
   end  
   
   else   
   begin
    case (po_state)
    
      po_idle:  // waiting for new data to send
        begin
          rdFlag <= 1'b0;
          if( adcstate == adctimer ) // data taking is idle, we can read SRAM data
          begin
             if( wrAdr != rdAdr )     // any data available?
             begin
                adrSource <= 1'b1;        // select data out from RAM (and tell data taking state machine we have control of SRAM)
                po_state <= po_rd1;       // allow for read setup time
             end 
             else
             begin
                adrSource <= 1'b0;         // nothing to do then, give control back to data collection 
             end 
          end
          else
          begin
              adrSource <= 1'b0;         // data collection ready to start, relinquish SRAM control       
          end
        end  
        
     po_rd1:    // delay for address setup
         begin
            po_state <= po_rd2;  
         end
         
     po_rd2:    // more delay for address setup
         begin
            po_state <= po_rd3;  
            po_rd_cnt <= po_rd_cnt + 10'd1;  // count it off 
         end         
         
     po_rd3:   // get next value from SRAM
         begin  
            datafifo[fifoin] <= portIn; //RAMdata; //  transfer next value     
            fifoin <= fifoin + 9'd1;    // inc pointers     
            rdAdr <= rdAdr + 22'd1;      // point to next RAM location;
            rdFlag <= 1'b1;            
            if( po_rd_cnt == 10'd512  )  // if 1024 bytes (512 words)  that is a block
            begin            
               adrSource <= 1'b0;         // we are done with SRAM, give control back to data collection 
               po_state <= po_send;
            end  
            else   
            begin
               po_state <= po_idle;   // see if we have time for more reads
            end                                  
         end    
                      
     po_send:
       begin        
          rdFlag <= 1'b0;
          begin                           //   so 
             po_state <= po_wait;         //   go to reading state
             po_ready <= 1'b1;            //   let Host know we have data
             po_rd_cnt <= 10'd0;          //   nothing read yet
             fifoout <= 9'd0;       // reset fifo out pointer
          end
        end  
        
      po_wait:  // wait for host to tell us it's ready
        begin
            if(  pipe_out_strobe == 1'b1 ) //pipe_out_read == 1'b1 )  // this tells us the host is ready
            begin
               po_state <= po_start;
            end              
        end
           
     po_start:   // send data
         begin           
            fifoword <= datafifo[fifoout];   // send out next data value 
            po_rd_cnt <= po_rd_cnt + 10'd1;  // count it off
            fifoout <= fifoout + 9'd1;      // point to next FIFO location            
            if( po_rd_cnt == 10'd511  )      // if 1024 bytes (512 words)  // if 64 bytes (32 words), that is a block
            begin            
               po_state <= po_end;
            end           
         end                             
         
       po_end:  // done with data block
         begin   
              po_rd_cnt <= 10'd0;   // reset read counter
              po_ready <= 1'b0;     // drop ready line
              po_state <= po_idle;  // go back to idle state and wait for FIFO to build back   
         end // end senddata case 
      endcase  // of po state
   end // reset test
end  // data out


 assign led[5:0] = frameCount[5:0]; //adcstate[3:0];


// assign tp[4:0] = portIn[4:0]; //adcstate[3:0];
  assign tp[0] = tenPin;
  assign tp[1] = cnvPin;
  assign tp[2] = tmpPin;
  assign tp[3] = start;
// assign tp[5] = wr;
// assign tp[6] = wren;
// assign tp[7] = adrSource;
// assign tp[8] = rdFlag;
//// assign tp[3:0] = po_state[3:0];
// assign tp[2:0] = RAMadr[2:0]; 
 //assign tp[7:4] = fifoword[3:0]; // portIn[3:0]; //rdAdr[3:0];
// assign tp[8] = adrSource;
// assign tp[9] =  pipe_out_strobe; //RAMwr;
// assign tp[10] = adcdone;
 //assign tp[0] = clk1div;
 
// assign tp[3:0] = adcdata[3:0];
// assign tp[7:4] = adcdata[19:16];

//assign tp[7:1] = po_rd_cnt[6:0];//fifoout[6:0]; //
//assign tp[1] = fifoout[0];
//assign tp[11:5] =  fifoword[15:9];
////assign tp[9] = fifoin[0];
//assign tp[4] = ti_clk;
//assign tp[3] = pipe_out_strobe;
//assign tp[2] = pipe_out_ready; //tpreg;
//assign tp[1] = pipe_out_read; //tpreg;
//assign tp[0] = tpreg2; //tpreg2;

//assign tp[7] = pipe_out_strobe;
//assign tp[6:5] = po_state;
//assign tp[4:1] = fifoin[3:0];


//assign tp[5:0] = fifoword[5:0];
//assign tp[6]   = ti_clk; //start;
//assign tp[5]   = pipe_out_strobe; //po_rd_cnt[0];
//assign tp[6]   = po_ready;
//assign tp[7]   = pipe_out_read;

// ADC in      
//wire [7:0]   command = 8'hb4;
                                  
SPI   adc1     
(
   .clk        (ti_clk),
   .command    (command),
   .start      (start),
   .miso       (misoPins),
   .mosi       (mosiPin),
   .sclk       (sclkPin),
   .adccs      (adccsPin),
   .adcdata    (adcdata),
   .adcdone    (adcdone),
   .tp        (tp)  
);   
  


TMP06 temp
(
    .clk           (ti_clk),
    .led           (led), 
	.tmpPin        (tmpPin),
	.cnvPin        (cnvPin),
	.tenPin        (tenPin),
	.start         (tmp_start),
	.temperature   (tmpdata),     // temperature
	.tempvalid     (tmpvalid),    // channel
	.tempread      (tempread),
	.testdata      (tempinfo),
	.tp            (tp)
);

//assign led[7]   = doutvalid;
//assign led[6]   = dvdvalid;
// assign led[5:4] = d_state;
 
 //assign led[7]   = po_ready;
 //assign led[7]  = pipe_out_read;
 //assign led[6] = po_ready;
 //assign led[5] = onestart;
 //assign led[4] = do_reset;
 
 //assign led[5]   = do_reset;
 //assign led[4]   = trigger; //adc_start;
 //assign led[5:4] = datacnt[1:0]; // adcstate;
 // assign led[7:4] = command[7:4];

                                          
// Instantiate the okHost and connect endpoints.
// Host interface
okHost okHI(
	.hi_in(hi_in), .hi_out(hi_out), .hi_inout(hi_inout), .hi_aa(hi_aa), .ti_clk(ti_clk),
	.ok1(ok1), .ok2(ok2));

wire [17*6-1:0]  ok2x;
okWireOR # (.N(6)) wireOR (ok2, ok2x);
okWireIn     wi00 (.ok1(ok1),                           .ep_addr(8'h00), .ep_dataout(ep00wire));
okWireIn     wi01 (.ok1(ok1),                           .ep_addr(8'h01), .ep_dataout(numChs));
okWireIn     wi02 (.ok1(ok1),                           .ep_addr(8'h02), .ep_dataout(clksPerSmp));
okWireIn     wi03 (.ok1(ok1),                           .ep_addr(8'h03), .ep_dataout(LED0));
okWireIn     wi04 (.ok1(ok1),                           .ep_addr(8'h04), .ep_dataout(LED1));
okWireIn     wi05 (.ok1(ok1),                           .ep_addr(8'h05), .ep_dataout(smplOnwire[15:0]));
okWireIn     wi06 (.ok1(ok1),                           .ep_addr(8'h06), .ep_dataout(smplOnwire[31:16]));
okWireIn     wi07 (.ok1(ok1),                           .ep_addr(8'h07), .ep_dataout(smplOnwire[47:32]));
okWireIn     wi08 (.ok1(ok1),                           .ep_addr(8'h08), .ep_dataout(smplOnwire[63:48]));
okWireIn     wi09 (.ok1(ok1),                           .ep_addr(8'h09), .ep_dataout(smplOnwire[79:64]));
okWireIn     wi0A (.ok1(ok1),                           .ep_addr(8'h0a), .ep_dataout(smplOnwire[95:80]));
okWireIn     wi0B (.ok1(ok1),                           .ep_addr(8'h0b), .ep_dataout(LEDindex));
okWireIn     wi0C (.ok1(ok1),                           .ep_addr(9'h0c), .ep_dataout(syncRate));

okWireOut    wo23 (.ok1(ok1), .ok2(ok2x[ 4*17 +: 17 ]), .ep_addr(8'h23), .ep_datain(maxAdrLOW));
okWireOut    wo24 (.ok1(ok1), .ok2(ok2x[ 5*17 +: 17 ]), .ep_addr(8'h24), .ep_datain(maxAdrHOW));
okWireOut    wo20 (.ok1(ok1), .ok2(ok2x[ 3*17 +: 17 ]), .ep_addr(8'h20), .ep_datain(status));
okWireOut    wo21 (.ok1(ok1), .ok2(ok2x[ 0*17 +: 17 ]), .ep_addr(8'h21), .ep_datain(VERSIONDATE)); //tmpdata));  0:16
okWireOut    wo22 (.ok1(ok1), .ok2(ok2x[ 1*17 +: 17 ]), .ep_addr(8'h22), .ep_datain(VERSIONYEAR));   // 17
//okWireOut    wo22 (.ok1(ok1), .ok2(ok2),                .ep_addr(8'h22), .ep_datain(VERSION)); //tmpdata));
//okBTPipeIn   ep80 (.ok1(ok1), .ok2(ok2x[ 1*17 +: 17 ]), .ep_addr(8'h80), .ep_write(pipe_in_write), .ep_blockstrobe(), .ep_dataout(pipe_in_data), .ep_ready(pipe_in_ready));
okBTPipeOut  epA0 (.ok1(ok1), .ok2(ok2x[ 2*17 +: 17 ]), .ep_addr(8'ha0), .ep_read(pipe_out_read),  .ep_blockstrobe(pipe_out_strobe), .ep_datain(pipe_out_data), .ep_ready(pipe_out_ready));


endmodule