// miniFlySong

// Teensy 4 interface to a single FlySong 8-Channel Microphone Board. 
// Prints out raw data to USB-Serial as binary values 0x7FFF is reserved as the sync word so 0x7FFF data -> 0x7FFE
// Set NUMCHAN to the number of channels to digitize
// Did not implement temperature readings, but it could be added

// sws jET Janelia HHMI

// Hardware:
// - 3 cell AA or AAA pack connected to microphone power and 5V inputs (for older microphone boards with on
//    on board 3.3 V voltage regulator) 

//#define TESTMODE  // define to send ramp data 
#define NUMCHAN 8  // how many channels to record
#define SAMPLERATE  5000 // samples per second
// #define ASCIIOUT  // enable to put out data in ASCII

#define VERSION "20240320"

// 20240320 sws
// - added battery on/off

// 20240312 sws
// - add clock out (SYNC) and command polling

// 20230410 sws
// - basics working

#include <SPI.h>
#include <Cmd.h>


#define batOnPin 0
#define batCheckPin 1
#define batGoodPin 22
#define batBadPin 23

#define csPin 14
#define triggerPin 3

#define MINSYNC 0.01 // 1
#define MAXSYNC 5000
volatile boolean state = false;
float syncRate = 30;
boolean clockOutEnabled = false;
 
//int16_t data[12];
//int16_t data0, data1, data2, data3, data4, data5, data6, data7, data8, data9, data10, data11;

#define BUFSIZE 0x8000

uint16_t buff[BUFSIZE]; 
uint16_t * bp;
uint16_t readPtr;
uint16_t writePtr;
volatile uint16_t bufLevel = 0;

volatile int32_t sampleCount = 0;

IntervalTimer sampleTimer;
IntervalTimer syncTimer;

uint8_t numCh = NUMCHAN;

// channel order starts with 1 as cmd sets channel for the NEXT ch to digitize

uint16_t ADCcmd[] = {0xb400, 0xe400, 0xa400, 0xd400, 0x9400, 0xc400, 0x8400, 0xf400 };

uint16_t maxLevel;

union 
{
  uint16_t intData[8];
  uint8_t byteData[16];
} ADCdata; 

union
{
   uint16_t uint;
   uint8_t bytes[2];
} dataOut;

void writeToBuf(uint16_t data)
{
  if( bufLevel < BUFSIZE )
  {
     buff[writePtr] = data;
     writePtr++;
     if( writePtr == BUFSIZE ) writePtr = 0;
     bufLevel++;   
     if( bufLevel > maxLevel ) maxLevel = bufLevel;
  }
}

uint16_t readFromBuf(void)
{
uint16_t data;

   noInterrupts();
   data = buff[readPtr];
   readPtr++;
   if( readPtr == BUFSIZE ) readPtr = 0;
   bufLevel--;         
   interrupts();   
   return data;
}

void nextSample()
{  
uint16_t dataIn;
   
  writeToBuf(0x7fff);  // sync word

//  writeToBuf(maxLevel);
   
  for( uint ch = 0; ch < NUMCHAN; ch++)
  { 
      uint16_t cmd = ADCcmd[ch];
      if( ch == (NUMCHAN-1) ) cmd = ADCcmd[7]; // last one always goes back to ch 0
      digitalWriteFast(csPin, HIGH);
//      delayNanoseconds(100);   // this does not seem to work consistantly 
      delayMicroseconds(1);
      digitalWriteFast(csPin, LOW);  
      
      delayMicroseconds(4);  // conversion time

      dataIn = SPI.transfer16(cmd) ^ 0x8000;  // make into signed value

#ifdef TESTMODE
  dataIn = 0xffff & (sampleCount + 256 * ch);
#endif
      
      if( dataIn == 0x7fff) dataIn = 0x7ffe;  // no data can be same as sync word
         
      writeToBuf(dataIn);

//      ADCdata.intData[ch] = SPI.transfer16(cmd) ; //^ 0x8000;
//      if( ADCdata.intData[ch] == 0xffff ) ADCdata.intData[ch] = 0xfffe;
//
//      #ifdef ASCIIOUT
//        Serial.print(ADCdata.intData[ch]);  
//        if( ch < numCh-1)  Serial.print(',');
//      #endif  
 
   }

//   #ifdef ASCIIOUT
//     Serial.println(); 
//   #else  
//      Serial.write(0xff);
//      Serial.write(0xff);
//      Serial.write(ADCdata.byteData, NUMCHAN*2);
//   #endif   
   
   sampleCount++;
}

// ========================
// === S Y N C    I N T ===
// ========================

// camera sync
void syncInt(void)
{
  if ( state )
  {
    digitalWriteFast(triggerPin, HIGH);
    state = false;
  }
  else
  {
    digitalWriteFast(triggerPin, LOW);
    state = true;
  }
}


// ==================================
// === S Y N C   R A T E   C M D  ===
// ==================================
// set the sync output rate for triggering camera

void syncRateCmd(int arg_cnt, char **args)
{
  float tsync;
//Serial.println( args[1]);
  if ( arg_cnt > 1 )
  {
    tsync = cmdStr2Float(args[1]);
    if ( (tsync > MINSYNC) && (tsync < MAXSYNC) )
    {
      syncRate = tsync;
      digitalWriteFast(triggerPin, HIGH);
      state = false;
      if( clockOutEnabled )
      {       
        syncTimer.update( 500000/syncRate);
      }
      else
      {
        syncTimer.begin(syncInt, 500000 / syncRate); // change immediately (or start if ended)
      }
      clockOutEnabled = true;
    }
    else
    {
      if ( (tsync > -0.001) && (tsync < 0.001) ) // if '0' then turn sync off
      {
        clockOutEnabled = false;
        syncTimer.end();
        digitalWriteFast(triggerPin, LOW);
      }
    }
  }
  else
  {
    Stream *s = cmdGetStream();
    s->println(syncRate);
  }
}

// ==================================
// === R U N    E X P E R I M E N T  ===
// ==================================

void runExperiment(int arg_cnt, char **args)
{
  state = false;
  digitalWriteFast(triggerPin, HIGH);
  if( clockOutEnabled )
  {       
    syncTimer.update( 500000/syncRate);
  }
  else
  {
    syncTimer.begin(syncInt, 500000 / syncRate); // change immediately (or start if ended)
  }
  clockOutEnabled = true;
}


// ==================================
// === S T O P   E X P E R I M E N T  ===
// ==================================

void stopExperiment(int arg_cnt, char **args)
{
  digitalWriteFast( triggerPin, LOW);
  syncTimer.end(); // stop clock out
  clockOutEnabled = false;
}

// ==================================
// === B A T  O N  C M D   ===
// ==================================

void batOnCmd(int arg_cnt, char **args)
{
  digitalWriteFast(batOnPin, HIGH);
}

// ==================================
// === B A T  O F F  C M D   ===
// ==================================

void batOffCmd(int arg_cnt, char **args)
{
  digitalWriteFast(batOnPin, LOW);
}


// ==================================
// === H E L P   C M D   ===
// ==================================

void helpCmd(int arg_cnt, char **args)
{
  Serial.println(VERSION);
}

boolean batOn = false;

void setup() 
{

  pinMode(csPin, OUTPUT);
  digitalWriteFast(csPin, LOW);

  pinMode( triggerPin, OUTPUT);
  digitalWriteFast( triggerPin, LOW);

  pinMode( batOnPin, OUTPUT);    // battery off until we connect
  digitalWriteFast( batOnPin, LOW);
 
  Serial.begin(15200);
  while(!Serial); 
  
  digitalWriteFast( batOnPin, HIGH); 
  batOn = true;

  SPI.begin();
  
  SPI.beginTransaction(SPISettings(20000000, MSBFIRST, SPI_MODE0));
  
  bp = buff;
  readPtr = 0;
  writePtr = 0;
  bufLevel = 0;
  sampleCount = 0;
  maxLevel = 0;

  cmdInit(&Serial);
  cmdAdd("SYNC", syncRateCmd);
  cmdAdd("RX", runExperiment);
  cmdAdd("SX", stopExperiment);
  cmdAdd("ON", batOnCmd);
  cmdAdd("OFF", batOffCmd);
//  cmdAdd("BAT", batCheckCmd);
  cmdAdd("???", helpCmd);
  
  delay(1000);
  
 // sampleTimer.begin( nextSample, 1e6/SAMPLERATE); 
}


void loop() 
{

   cmdPoll();  // watch for sync commands

   if( Serial )
   {
      if( batOn == false)  // if connected and battery off , turn on
      {
         digitalWriteFast(batOnPin, HIGH);
         batOn == true;
      }   
   }
   else
   {
      if( batOn == true )
      {
        digitalWriteFast(batOnPin, LOW);
        batOn = false;
      }
   }

   if( bufLevel > 0 ) 
   {
     dataOut.uint = readFromBuf();
     Serial.write(dataOut.bytes, 2);   
   }
  // comment all this out for continuous running
  // following is for testing - send 1 million samples, stop, wait 5 secs, go again
  
//  if( sampleCount >= 1e6 ) 
//  {
//    Serial.write( (uint8_t) maxLevel >> 8);
//    Serial.write( (uint8_t) maxLevel & 0xff);
//    sampleTimer.end();     
//    delay(10000);
//    sampleTimer.begin( nextSample, 1e6/SAMPLERATE); 
//    readPtr = 0;
//    writePtr = 0;
//    bufLevel = 0;
//    maxLevel = 0;
//    sampleCount = 0;
//  }
  

  
}
