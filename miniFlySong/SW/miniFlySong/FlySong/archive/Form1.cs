#define LEDFIFO 

using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.IO;
using System.Globalization;
using System.Diagnostics;
using OpalKelly.FrontPanel;
using System.Threading;

//using com.opalkelly.frontpanel;
// --- todo ---
// - save temperature channel as 'A1', etc and divide return temperarture reading by 100 to get floating deg C
// - be sure brightness is saved as floating value (returned value / 10)



//  ==== V E R S I O N =====
// !!!! - change VERSION string -!!!!

// 20170508 sws
// - change transfer block size from 64 to 1024
//  need to ensure length of transfer is integer multiple of 1024
//  also make real time buffer 40960 (instead of 40000) for same reason

// 20170412 sws
// - started adding in ability to download the LED file info so we don't have to 
//      send each LED upodate while we are running.
// - added error check when board is opened

// 20170323 sws
// - sample rate sent to FPGA 

// 20170313 -sws
// - use Bit enum to replace hard coded bit patterns


// 20170214 -sws
// - add battery enable to wireins for port 0
// - turn battery off in FormClosing78

// 20170206 - sws
// - add clear names button

// 20161222 - sws
// - assume default WAV directory in wav text box so no click is needed if default
// - save all data to array and then write out at the end of a run to save disk write time

// 20161221 - sws
// - make LED brightness to 0.1% (x10 when sending), change FPGA code to match

// 20161220 - sws
// - add grid to select individual channels to save
// - add button to read in a CSV file of selected channels
//
// 20161215 - sws
// - different drive starting positions for each file
// - show board n out of 12
// - STOP button during run
// - limit LED and sample files to txt or csv
// - file dialog for where to save wav files
// - runtime shows two values
// - show running time
// - blank real time screen when in run mode - maybe show fly locations
// - add VERSION to Form Title


namespace cshrp_form
{



    [Flags]
    public enum Bit
    {
        batEnable   = 0x01,
        reset       = 0x04,
        adcEnable   = 0x10,
        tempEnable  = 0x20,
        LEDEnable   = 0x40
    }


    public partial class Form1 : Form
    {
        string VERSION = "20170508";
        string FPGAVERSION = "00000000";
        string fpgaDrive = "c:\\FlySong\\";  //"Y:\\PROJECTS\\STERN\\96CH_RECORDER\\FPGA\\96mic\\96mic.runs\\impl_1\\"; //  "C:\\PROJECTS\\STERN\\96CH_RECORDER\\FPGA\\96mic\\96mic.runs\\impl_1\\"  ; 
        string ledDrive = "c:\\FlySong\\";
        string samplesDrive = "c:\\FlySong";
        string wavDir = "c:\\FlySong";

        okCFrontPanel dev;

       // StreamReader samplesStream = null;
        float[] ledtime = new float[1000];  // hold led  times
        float[] led0bright = new float[1000]; // hold led brightess values
        string selected_rig;

        static uint CLOCKRATE = 48000000;

        // byte[] Buffer = new byte[40000];
        uint clocksPerSample = CLOCKRATE / 2000; // 24000;  // default to 2000 smpls/sec
        uint numBoards = 12;
        uint numChans = 100;
        uint num_recs = 0;
        float maxtime = 0;

       // int show = 0;  // 1 to show data in text box
        int run = 1;   // 1 to run, 0 to pause
        int NUMPTS = 100;

        byte[] tb = new byte[256];

        //    int lastn = 0;
        int ledptr = 0;
        int ledcnt = 0;
        //     UInt16 lasttemp = 99;
        Int32 pos;

        UInt32 xfrSize = 16384;
        Boolean stopRun = false;

        long frequency = Stopwatch.Frequency;

        Stopwatch stopWatch;

        String[,] samples = new String[2, 100];  // Chamber location, Fly Genotype
        UInt16[] sampleOn = new UInt16[6];       // bit map of active chanmbers [0].0 = chamber A1, [0].1 = A2,etc
        byte[] buffer = new byte[40960]; //[40000];

        // ============================================
        // ===  "REAL" TIME DATA TRANSFERS  ====
        // ============================================
        
        unsafe void RTTransfer( UInt32 numsets)  
        {
           // UInt32 i;
            long ret = 0;
            // 0x02 pipe is used to send sample rate = 48e6/rate - so 2000 smpl/sec = 48e6/2000 = 24000
            dev.SetWireInValue(0x02, clocksPerSample);  //  number of 48Mhz clocks per sample
            dev.SetWireInValue(0x01, numBoards); // number of boards to save (1-12)
            dev.SetWireInValue(0x05, 0xffff);    // all chns on
            dev.SetWireInValue(0x06, 0xffff);
            dev.SetWireInValue(0x07, 0xffff);
            dev.SetWireInValue(0x08, 0xffff);
            dev.SetWireInValue(0x09, 0xffff);
            dev.SetWireInValue(0x0a, 0xffff);
            //           dev.SetWireInValue(0x00, 0 << 5 | 1 << 2 | 1);  // SET_THROTTLE=1 | MODE=LFSR | RESET=1 
            dev.SetWireInValue(0x00, (int)(Bit.reset | Bit.batEnable));  // SET_THROTTLE=1 | MODE=LFSR | RESET=1 
            dev.UpdateWireIns();
            //            dev.SetWireInValue(0x00, 0 << 5 | 0 << 2 | 1);  // SET_THROTTLE=0 | MODE=LFSR | RESET=0
            dev.SetWireInValue(0x00, (int) (Bit.batEnable));  // SET_THROTTLE=0 | MODE=LFSR | RESET=0
            dev.UpdateWireIns();
            //           dev.SetWireInValue(0x00, 1 << 6 | 1 << 5 | 1); // temperature and adc start = 1
//            dev.SetWireInValue(0x00, 1 << 5 | 1); // temperature and adc start = 1
            dev.SetWireInValue(0x00, (int)(Bit.adcEnable | Bit.tempEnable |  Bit.batEnable)); // temperature and adc start = 1
            dev.UpdateWireIns();

//            dev.SetWireInValue(0x03, (UInt16)0); // LED off
//            dev.UpdateWireIns();

            ret = dev.ReadFromBlockPipeOut(0xA0, 64, 40000, buffer);  // m_u32BlockSize,// u32SegmentSize, pBuffer);                                                                      //  	        } 
            ret = dev.ReadFromBlockPipeOut(0xA0, 1024, 40960, buffer);


            for (int j = 0; j < 40; j++)
                    tb[j] = buffer[j];

        }  // end Transfer


    public void DrawLinesPoint(PaintEventArgs e)
        {

            // Create pen.
            Pen pen = new Pen(Color.Black, 1);
            Pen zero = new Pen(Color.Red, 1);

            Point[] pts = new Point[NUMPTS];

   //         RTTransfer(1);

            int offset = 0; // track where were we are walking through the data

            for(int row = 0; row < 8; row++) 
            {
                int rowoff = 100 + row * 80;  // locate row starting point on display

                e.Graphics.DrawLine(zero, 5, rowoff, 1450, rowoff);

                for (int col = 0; col < 12; col++)
                {
                    int coloff = col * 120 + 10;  // locate column starting point on display
                    offset = row * 24 + col * 2 + 8;  // 12 cols * 2 bytes/value + 8 bytes for LED and temperature
                    for (int i = 0; i < NUMPTS; i++)
                    {                    
                        int data = (int)((short)(buffer[offset] + (buffer[offset + 1] << 8)));
                        data = data >> 10;  // compress
                        pts[i] = new Point(coloff + i, rowoff - data);
                        offset += 200;  // (96 ch + 4 for led, led, temp ch, temp) * 2 bytes/ch = 200
                    }
                    e.Graphics.DrawLines(pen, pts);
                } // col
            } // row        
        }

        public Form1()
        {
            //         char[] serial = new char[8];

            //         serial[0] = '\0';


            InitializeComponent();

            Text = "Fly Song Data Aquisition V:" + VERSION;

            dev = new okCFrontPanel();

            stopWatch = new Stopwatch();

            int count = dev.GetDeviceCount();
            int i;

            string[] FPGAlist = new string[count];

            for (i = 0; i < count; i++)
            {
                FPGAlist[i] = dev.GetDeviceListSerial(i);
            }

            selectRigLB.Items.AddRange(FPGAlist);

            if (count == 1)
            {
                selectRigLB.SetSelected(0, true);
                selected_rig = selectRigLB.GetItemText(selectRigLB.SelectedItem);
                setRig();
            }

            wavDirTB.Text  = wavDir;   // assume default directory

          //  openFileDialog1.InitialDirectory = drive;

        }

        private void Form1_Paint(object sender, PaintEventArgs e)
        { 
            if( runP.Visible == false)
                    DrawLinesPoint(e);
        }   

        private void takedata_Click(object sender, EventArgs e)
        {
            if (run == 1)
            {
                run = 0;
                timer1.Enabled = false;
            //    show = 1;
                string t;
                for (int j = 0; j < 40; j++)
                {
                    if( (j % 2) == 0 )
                       t = string.Format("{0}-", tb[j]);
                    else
                       t = string.Format("{0}   ", tb[j]);
                    progressTB.AppendText(t);
                }
            }
            else
            {
                run = 1;
                timer1.Enabled = true;
                //show = 0;
            }
        } // end take_data

        private void timer1_Tick(object sender, EventArgs e)
        {

            RTTransfer(1);
/*
            if( show == 1)
            {
                int offset = 0;   
                for (int row = 0; row < 8; row++)
                {
                   for (int col = 0; col < 12; col++)
                   {
                       offset = row * 24 + col * 2 + 8;  // first 8 bytes are LED and temperature data
                       int data = (int)((short)(Buffer[offset] + (Buffer[offset + 1] << 8)));
                       progressTB.AppendText(String.Format("{0,10}", data));                                                                               
                   }
                   progressTB.AppendText(Environment.NewLine);
                }  // next row'
                progressTB.AppendText(Environment.NewLine);               
            }
            show = 0;
*/
            Invalidate();
        }

        //       private void button1_Click(object sender, EventArgs e)
        //        {
        //
        //}

        // === S E T U P    F P G A  ===

        private void setRig()
        {
            // open the FPGA board
            if( okCFrontPanel.ErrorCode.NoError != dev.OpenBySerial(selected_rig))
                progressTB.AppendText("Can't open selected FPGA board" + Environment.NewLine);
                
            // Download the configuration file.
            if (okCFrontPanel.ErrorCode.NoError != dev.ConfigureFPGA(fpgaDrive + "PipeTest.bit"))
            {
                progressTB.AppendText("Can't find bit file: " + fpgaDrive + "PipeTest.bit" + Environment.NewLine);
            }
            else
            {
                progressTB.AppendText("Opened board" + selected_rig + Environment.NewLine);
            }
            // progressTB.AppendText(Environment.NewLine);

            //           dev.SetWireInValue(0x00,  1 << 2 | 1 );  //  RESET=1, turn on battery 
            dev.SetWireInValue(0x00, (int)(Bit.reset | Bit.batEnable));  //  RESET=1, turn on battery 
            dev.SetWireInValue(0x03, 0x00); // set LED off
            dev.SetWireInValue(0x04, 0x00); // set LEDS off
            dev.UpdateWireIns();

            dev.UpdateWireOuts();
            uint VERSIONDATE = dev.GetWireOutValue(0x21);
            uint VERSIONYEAR = dev.GetWireOutValue(0x22);
            FPGAVERSION = String.Format("{0}{1}", VERSIONYEAR, VERSIONDATE);
            progressTB.AppendText(String.Format("FPGA code Version: {0}", FPGAVERSION)); //.ToString()));
            progressTB.AppendText(Environment.NewLine);
        }

        private void selectRigLB_MouseDoubleClick(object sender, MouseEventArgs e)
        {
            //string selected_rig;

            selected_rig = selectRigLB.GetItemText(selectRigLB.SelectedItem);
            setRig();
        }

        // === T R A N S F E R === DATA FROM FPGA ===

        private UInt32 Transfer(UInt32 numRecords, BinaryWriter wavf)
        {
            //        UInt32 i;
            int blockSize = 1024;

            long ret = 0;
            UInt32 length;
    //        Int64 lastmsec = 0;

            stopRun = false;

            length = numRecords * numChans * 2;
            length = (UInt32)numChans * (UInt32)blockSize * (length / (UInt32)(blockSize * numChans));


            byte[] membuf = new byte[length];
       //     byte[] membuf2 = new byte[length / 2];

            clocksPerSample = CLOCKRATE / (uint)smplrateUD.Value;

            int timeout = (int)(1500000000 / (numChans * smplrateUD.Value));
            dev.SetTimeout( timeout);

            string dstr = string.Format("{0} bytes, {1} recs, {2} chans, {3}s timeout\n", length, numRecords, numChans, ((float)timeout)/1000);
            progressTB.AppendText(dstr);

            dev.UpdateWireOuts();
            setBattery(dev.GetWireOutValue(0x20));
 
            dev.SetWireInValue(0x02, clocksPerSample);  //  number of 48Mhz clocks per sample
            dev.SetWireInValue(0x01, numBoards); // number of boards to save (1-12)
            dev.SetWireInValue(0x05, sampleOn[0]);  // mask to show which channels we will save
            dev.SetWireInValue(0x06, sampleOn[1]);
            dev.SetWireInValue(0x07, sampleOn[2]);
            dev.SetWireInValue(0x08, sampleOn[3]);
            dev.SetWireInValue(0x09, sampleOn[4]);
            dev.SetWireInValue(0x0a, sampleOn[5]);
            dev.SetWireInValue(0x00, (int)( Bit.reset | Bit.batEnable)); //  temp, adc off , RESET=1 , bat enabled
            dev.UpdateWireIns();


            // Send over LED timing and brightness info
            for ( UInt16 lp = 0; lp < ledcnt; lp++)
            {
                UInt16 bright =(UInt16) (led0bright[lp] * 10);
                if (bright > 1000) bright = 1000;  // brightness must be <= 100.0 %  (we send it over x 10) 
                UInt16 time = (UInt16)(ledtime[lp] / 100);
                dev.SetWireInValue(0x03, (UInt16)bright);   // new LED setting
                dev.SetWireInValue(0x04, (UInt16)time);     // LED time in 0.1 secs
                dev.SetWireInValue(0x0B, (UInt16)(lp + 1)); // start fifo count at 1, 0 means no data
                dev.UpdateWireIns();
                dev.SetWireInValue(0x0B, (UInt16)0);        // '0' so we don't keep updating FIFO value in FPGA
                dev.UpdateWireIns();
                string ledstr = String.Format("LED: {0}, {1}, {2}\n", lp, bright,time);
                progressTB.AppendText(ledstr);
            }

            // now we are ready to start, drop the reset bit and enable everything else
            dev.SetWireInValue(0x00, (int)(Bit.LEDEnable | Bit.tempEnable | Bit.adcEnable | Bit.batEnable)); // temperature and adc start = 1
            dev.UpdateWireIns();

            //Thread t = new Thread(() =>
            //{
                //       timer2.Enabled = true;
                ret = dev.ReadFromBlockPipeOut(0xA0, blockSize, (int)(length), membuf);  // read 1024 bytes per block
                                                                                         //});

            //t.Start();

            //           ret = dev.ReadFromBlockPipeOut(0xA0, 64, (int)(length), membuf);  //40000 m_u32BlockSize,// u32SegmentSize, pBuffer);
            //           ret = dev.ReadFromBlockPipeOut(0xA0, 64, (int)(length / 2), membuf2);

            //            for (UInt32 ptr = 0xfffc00; ptr < 0xFFFe80; ptr += 2)
            //          {
            //                string dstr2= String.Format("{0:X} : {1:X}{2:X}\n", ptr, membuf[ptr + 1], membuf[ptr]);
            //                progressTB.AppendText(dstr2);
            //            }   

            if (ret < 0)
            {
                //ok_NoError = 0,
                //ok_Failed = -1,
                ///ok_Timeout = -2,
                //ok_DoneNotHigh = -3,
                //ok_TransferError = -4,
                //ok_CommunicationError = -5,
                //ok_InvalidBitstream = -6,
                //ok_FileError = -7,
                //ok_DeviceNotOpen = -8,
                //ok_InvalidEndpoint = -9,
                //ok_InvalidBlockSize = -10,
                //ok_I2CRestrictedAddress = -11,
                //ok_I2CBitError = -12,
                //ok_I2CNack = -13,
                //ok_I2CUnknownStatus = -14,
                //ok_UnsupportedFeature = -15,
                //ok_FIFOUnderflow = -16,
                //ok_FIFOOverflow = -17,
                //ok_DataAlignmentError = -18,
                //ok_InvalidResetProfile = -19,
                //ok_InvalidParameter = -20

                switch (ret)
                {
                    case 0:
                        progressTB.AppendText("No error\n");
                        break;

                    case -1: // ok_Failed = -1
                        progressTB.AppendText("Failed\n");
                        break;

                    case -2: //ok_Timeout = -2,
                        progressTB.AppendText("Timeout\n");
                        break;
                    case -9: // ok_InvalidEndpoint = -9,
                        progressTB.AppendText("Invalid Endpoint\n");
                        break;

                    case -10:  //okCFrontPanel.InvalidBlockSize:
                        progressTB.AppendText("Block Size Not Supported\n");
                        break;

                    case -15: // okCFrontPanel::UnsupportedFeature:
                        progressTB.AppendText("Unsupported Feature\n");
                        break;

                    default:
                        string estr = string.Format("Transfer fail: {0}", ret);
                        progressTB.AppendText(estr);
                        break;
                }

                if (dev.IsOpen() == false)
                {
                    progressTB.AppendText("Device disconnected");
                    //                 exit(-1);
                }

                return (UInt32)0;
            } // endif bad ret

            // reset FPGA
            //           dev.SetWireInValue(0x00, 0 << 6 | 0 << 5 | 1 << 2 | 1);  // temp off, adc off, reset, bat still on 
            dev.SetWireInValue(0x00, (int) (Bit.reset | Bit.batEnable));  // temp off, adc off, reset, bat still on 
            dev.UpdateWireIns();

            timer2.Enabled = false;

            wavf.Write(membuf, 0, (int)(length) );
            //         wavf.Write(membuf2, 0, (int)(length / 2));

            return length;

            //}  //endwhile
        }  // loop Transfer

        private void timer2_Tick(object sender, EventArgs e)
        {
            runClockTB.Text = "" + stopWatch.ElapsedMilliseconds / 1000;
            //          lastmsec = stopWatch.ElapsedMilliseconds / 1000;
            Application.DoEvents();

            //if (stopRun == true) ;
        }



        // === S T A R T   R U N  ===

        private void startB_Click(object sender, EventArgs e)
        {
            // first get the Samples Info
            UInt16 inuse = 0;
            for (UInt16 bits = 0; bits < 6; bits++) sampleOn[bits] = 0;  // reset the 'on' bits
            for (UInt16 i = 1; i <= 96; i++)
            {
                TextBox textBox = (TextBox)samplesTLP.Controls["textBox" + i];
                if (!string.IsNullOrWhiteSpace(textBox.Text))
                {   // - save the text version of the filled rows and columns ('A1', etc) and the genotype 
                    samples[0, inuse] = string.Format("{0}{1}", (char)('A' + (i / 12)), i % 12);
                    samples[1, inuse] = textBox.Text;
                    // add this to the 96 bit 'on' pattern for the FPGA to use
                    UInt16 on = (UInt16)(i - 1);   
                    sampleOn[on/16] |= (UInt16)(1 << (on % 16));
                    // inuseTB.AppendText(samples[0, inuse] + "  " + samples[1, inuse] + Environment.NewLine);
                    inuse++;
                    //   button1.Text = textBox.Text + string.Format("{0}", i);
                }
                //             
            }
            numChans = (UInt16)(inuse + 4); // # audio channels + LED and temp chs
            progressTB.AppendText(string.Format("BITS: {0:X4} {1:X4} {2:X4} {3:X4} {4:X4} {5:X4} Chans:{6}\n", sampleOn[5], sampleOn[4], sampleOn[3], sampleOn[2], sampleOn[1], sampleOn[0], numChans));

            startB.Text = "Running";
            startB.Enabled = false;
            stopB.Visible = true;
            stopRun = false;
            Refresh();
            // make new WAV file;
            DateTime datetime = DateTime.Now;
            string fn = wavDir + "\\" + datetime.ToString("yyyyMMddHHmmss_");
            fn = fn + selected_rig + ".wav";
            progressTB.AppendText(fn + Environment.NewLine);
            filenameL.Text = fn;

            num_recs = (uint)(((float)smplrateUD.Value * maxtime / 1000));

            ledptr = 0;  // reset location in LED array

            using (BinaryWriter wavf = new BinaryWriter(File.Open(fn, FileMode.Create)))
            {
                wavHeader(wavf); // write out header information
                progressTB.AppendText("start" + Environment.NewLine);
                stopWatch.Reset();  // set stopwatch count to 0
                stopWatch.Start();

                // ----- Go take the data -----------
                UInt32 actualLength = Transfer(num_recs, wavf);

                string nr = string.Format("Done, actual records:{0}" + Environment.NewLine, actualLength);
                progressTB.AppendText(nr);

                stopWatch.Stop();
             //   progressTB.AppendText("stop" + Environment.NewLine);

                dev.SetWireInValue(0x03, 0x00); // set LED off
                dev.SetWireInValue(0x04, 0x00); // set LEDS off
                dev.UpdateWireIns();

/*
                 for (int j = 0; j < 40; j++)
                {
                    string t = string.Format("{0},", tb[j]);
                    progressTB.AppendText(t);
                }
*/
                waveINFO(wavf); // save INFO before rewinding to fix header lengths

                //             progressTB.AppendText(String.Format("pos={0:X}", pos) + Environment.NewLine);

                wavf.Seek(pos, SeekOrigin.Begin);  // go fill in the data size
                UInt32 datasize = actualLength; // num_recs * 2 * numChans;  // number of records * number of channels * 2 bytes/value
                wavf.Write(datasize);
                wavf.Seek(4, SeekOrigin.Begin);
                datasize += 36;
                wavf.Write(datasize);
            }

            dev.SetWireInValue(0x03, 0x00); // set LED off
            dev.SetWireInValue(0x04, 0x00); // set LEDS off
            dev.UpdateWireIns();

            startB.Text = "Start";
            startB.Enabled = true;
            stopB.Visible = false;
            stopRun = false;
        }

        // ===   W R I T E   W A V   R I F F    H E A D E R   ===


        private void wavHeader(BinaryWriter wavf)
        {
            uint[] hdrvals = new uint[5];


            hdrvals[0] = 16; // subchunk1 size = 16 bytes
            hdrvals[1] = 0x10000 * numChans + 1;                 // number of channels (High order word) +  audio format = 1(PCM) 
            hdrvals[2] = (uint)smplrateUD.Value;               // sample rate, smpls/sec
            hdrvals[3] = (uint)smplrateUD.Value * numChans * 2; // byte rate = smpl rate * nchs * bits/smpl/8
            hdrvals[4] = numChans * 2 + 0x10000 * 16;            // bits/sampl (16)  + block align = nchs * bits/smpl /8 

            wavf.Write(Encoding.UTF8.GetBytes("RIFF----WAVEfmt "));

            for (int i = 0; i < 5; i++)
                wavf.Write(hdrvals[i]); //

            // Write the data chunk header
            //	size_t data_chunk_pos = wavf.tellp();
            //wavf << ;  // (chunk size to be filled in later)
            wavf.Write(Encoding.UTF8.GetBytes("data"));   // = numsamples * numchannels * bytes/sample = numsamples * 96 * 2
            pos = (Int32)wavf.BaseStream.Position;
            wavf.Write((uint)0);   // = numsamples * numchannels * bytes/sample = numsamples * 96 * 2      
        }

        private void writeEvenString(BinaryWriter wavf, string str)
        {
            str += '\0'; // be sure we have a null at the end of the string - perhaps Matlab needs it.
            byte[] array = Encoding.ASCII.GetBytes(str);

            if ((array.Length % 2) != 0)  // be sure it's even - Audacity seems to want even bytes
            {
                str += '\0';
                array = Encoding.ASCII.GetBytes(str);
            }

            wavf.Write(array.Length);

            foreach (byte element in array)  // write the string
                wavf.Write(element);
        }

        // ===  W R I T E   W A V   I N F O    H E A D E R  ===


        private void waveINFO(BinaryWriter wavf)
        {  // assume we are at the end of the file already

            int infopos = (Int32)wavf.BaseStream.Position + 4;
            wavf.Write(Encoding.UTF8.GetBytes("LIST----INFOINAM"));
            //          string fns = "WAV|" + filenameL.Text + " LED|" + ledFileTB.Text + " SMP|" + samplesFileTB.Text;
            string fns = "LED=" + ledFileTB.Text;
            if (samplesFileTB.Text.StartsWith("Click") )
                fns += " SMP=(no file)";
            else
                fns += " SMP=" + samplesFileTB.Text;
            writeEvenString(wavf, fns);

            byte[] array = Encoding.ASCII.GetBytes("ISFT");
            foreach (byte element in array)
                wavf.Write(element);
            writeEvenString(wavf, "FlySongDAQ:" + VERSION + " FPGA:" + FPGAVERSION);

            array = Encoding.ASCII.GetBytes("IART");
            foreach (byte element in array)
                wavf.Write(element);
            writeEvenString(wavf, ExperimenterTB.Text);

            array = Encoding.ASCII.GetBytes("ICMT");
            foreach (byte element in array)
                wavf.Write(element);
            writeEvenString(wavf, CommentTB.Text);

            array = Encoding.ASCII.GetBytes("ISBJ----");
            foreach (byte element in array)
                wavf.Write(element);

            int samplspos = (Int32)wavf.BaseStream.Position-4;

            // - write out samples info
            string smplstr = "LED1,%BRIGHT1,LED2,%BRIGHT2,TEMP CH,CH #,TEMP,DEG C";
            for (UInt16 i = 0; i <= numChans-4; i++)  // numChans includes the 4 LED and temperature channels
            {
                smplstr += "," + samples[0, i] + "," + samples[1, i];         
            }
            writeEvenString(wavf,smplstr);

            // - and fix length data
            Int32 samplslen = (Int32)wavf.BaseStream.Position - samplspos - 4;
            if ((samplslen % 2) != 0)
            {
                wavf.Write('\0'); // if not even , add a null
                samplslen++;
            }
            Int32 infolen = (Int32)wavf.BaseStream.Position - infopos;
            wavf.Seek(infopos, SeekOrigin.Begin);  //
            wavf.Write(infolen);
            //           progressTB.AppendText(String.Format("spos={0:X}, {1}", samplspos, samplslen) + Environment.NewLine);
            wavf.Seek(samplspos, SeekOrigin.Begin);  //
            wavf.Write(samplslen);

            /*           
                       int samplspos = (Int32)wavf.BaseStream.Position;

                       // === READ IN SAMPLES FILE (if opened) ===
                       if (samplesStream != null)
                       {
                           wavf.Write((int)0);
                           while (!samplesStream.EndOfStream)
                           {
                               string line = samplesStream.ReadLine();
                               array = Encoding.ASCII.GetBytes(line);
                               foreach (byte element in array)
                               {
                                   wavf.Write(element);
                               }
                               wavf.Write('\n'); // add line feed
                           }
                       }
                       Int32 samplslen = (Int32)wavf.BaseStream.Position - samplspos - 4;
                       if ((samplslen % 2) != 0)
                       {
                           wavf.Write('\0'); // if not even , add a null
                           samplslen++;
                       }
                       Int32 infolen = (Int32)wavf.BaseStream.Position - infopos;
                       wavf.Seek(infopos, SeekOrigin.Begin);  //
                       wavf.Write(infolen);
                       //           progressTB.AppendText(String.Format("spos={0:X}, {1}", samplspos, samplslen) + Environment.NewLine);
                       wavf.Seek(samplspos, SeekOrigin.Begin);  //
                       wavf.Write(samplslen);
           */
            //     samplesStream.Close();
        }

   

        private void savedataRB_CheckedChanged(object sender, EventArgs e)
        {
            // since we were running real time, reset the FPGA
            dev.SetWireInValue(0x00, 1 << 2 | 1);  //  RESET=1 , batt en
            dev.SetWireInValue(0x03, 0x00); // set LED off
            dev.SetWireInValue(0x04, 0x00); // set LEDS off
            dev.UpdateWireIns();

            timer1.Enabled = false;
            runP.Visible = true;
            Invalidate();
        }

        // === E N A B L E   R E A L   T I M E    S C R E E N  ===

        private void realtimeRB_CheckedChanged(object sender, EventArgs e)
        {
           runP.Visible = false;
           timer1.Enabled = true;
        }

        // === R E A D    S A M P L E    F I L E ===

        private void samplesFileTB_MouseClick(object sender, MouseEventArgs e)
        {
            string smplline;
            int col = 1;
            int idx;

            OpenFileDialog openFileDialog1 = new OpenFileDialog();

            openFileDialog1.InitialDirectory = samplesDrive;
            openFileDialog1.Filter = "Text files (*.txt;*.csv)|*.txt;*.csv|All files (*.*)|*.*";
            openFileDialog1.FilterIndex = 1;
            openFileDialog1.RestoreDirectory = true;

            if (openFileDialog1.ShowDialog() == DialogResult.OK)
            {

                clearNames();
                // use File.OpenRead to open read only in case the file is open by another program
                using (StreamReader smplStream = new StreamReader(File.OpenRead(openFileDialog1.FileName)))
                {
                    samplesFileTB.Text = openFileDialog1.FileName;
                    progressTB.AppendText("Sample File" + samplesFileTB.Text + " opened" + Environment.NewLine);
                    char[] charSeparators = new char[] { ',' };
                    while ((smplline = smplStream.ReadLine()) != null)
                    {
                        idx = col; 
                        progressTB.AppendText(smplline + '\n');
                        string[] values = smplline.Split(charSeparators); //, StringSplitOptions.RemoveEmptyEntries);
                        foreach (var s in values)
                        {
                            TextBox textBox = (TextBox)samplesTLP.Controls["textBox" + idx];
                            textBox.Text = s;
                            idx++;
                        }
                        col += 12;
                    } // end while data
                } // end using samples data file 

            }  // endif opened samples file success
        }

        // ===  R E A D   L E D   F I L E ===

        private void ledFileTB_MouseClick(object sender, MouseEventArgs e)
        {
            string ledline;
            string ledvalues;
            int idx = 0;

            OpenFileDialog openFileDialog1 = new OpenFileDialog();

            openFileDialog1.InitialDirectory = ledDrive;
            openFileDialog1.Filter = "Text files (*.txt;*.csv)|*.txt;*.csv|All files (*.*)|*.*";
            openFileDialog1.FilterIndex = 1;
            openFileDialog1.RestoreDirectory = true;

            if (openFileDialog1.ShowDialog() == DialogResult.OK)
            {
                using (StreamReader ledStream = new StreamReader(openFileDialog1.FileName))
                {
                    ledFileTB.Text = openFileDialog1.FileName;
                    progressTB.AppendText("Sample File" + ledFileTB.Text + " opened" + Environment.NewLine);
                    maxtime = 0;
                    char[] charSeparators = new char[] { ',' };
                    while ((ledline = ledStream.ReadLine()) != null)
                    {
                        ledvalues = System.Text.RegularExpressions.Regex.Replace(ledline, "[^.0-9]", ",");
                        //   progressTB.AppendText(ledvalues);
                        string[] values = ledvalues.Split(charSeparators); //, StringSplitOptions.RemoveEmptyEntries);

                        if (Single.TryParse(values[0], out led0bright[idx]))
                        {
                            if (Single.TryParse(values[1], out ledtime[idx]))
                            {
                                maxtime += (ledtime[idx] * 1000);   // save as milliseconds  
                                ledtime[idx] = maxtime;
                                progressTB.AppendText(string.Format("{0} {1} {2} {3}\n", ledtime[idx], led0bright[idx], values[0], values[1]));
                                idx++;
                            }
                        }
                    } // end while data
                } // end using led data file 
                ledcnt = idx;

                runtimeL.Text = "Run time = ";
                runtimeL.Text += string.Format("{0}", maxtime / 1000);
                runtimeL.Text += " secs";
                startB.Enabled = true;
            }  // endif opened ledfile success
        }

        // === S T O P   R U N  ===

        private void stopB_MouseClick(object sender, MouseEventArgs e)
        {
            stopRun = true;
        }

        // ===  S E T  W A V   D I R E C T O R Y  ===

        private void wavDirTB_MouseClick(object sender, MouseEventArgs e)
        {
            // Show the FolderBrowserDialog.
            DialogResult result = folderBrowserDialog1.ShowDialog();
            if (result == DialogResult.OK)
            {
                wavDir = folderBrowserDialog1.SelectedPath;

                openFileDialog1.InitialDirectory = wavDir;
          //      openFileDialog1.FileName = null;
                wavDirTB.Text = wavDir;
            }
        }

        private void runP_Paint(object sender, PaintEventArgs e)
        {

        }

        private void samplesGB_Enter(object sender, EventArgs e)
        {

        }

        private void samplesB_MouseClick(object sender, MouseEventArgs e)
        {

        }

        private void ledFileTB_TextChanged(object sender, EventArgs e)
        {

        }

        private void clearB_Click(object sender, EventArgs e)
        {
            clearNames();
        }

        private void clearNames()
        {
            // clear out old entries
            for( int tb = 1; tb <= 96; tb++)
            {
               TextBox textBox = (TextBox)samplesTLP.Controls["textBox" + tb];
                textBox.Text = "";
            }
        }

        private void batteryB_Click(object sender, EventArgs e)
        {
            dev.UpdateWireOuts();
            setBattery(dev.GetWireOutValue(0x20));
        }


        private void setBattery(uint status)
        {
            if( (status & 0x01) == 0 )  // if battery good, then comparator goes high, turns on LED, pulls OC low
                batteryB.BackColor = System.Drawing.Color.Green;
            else
                batteryB.BackColor = System.Drawing.Color.Red;
        }
          
        private void Form1_FormClosing(object sender, FormClosingEventArgs e)
        {
            dev.SetWireInValue(0x00, 0 << 6 | 0 << 5 | 1 << 2 | 0);  // temp off, adc off, reset, bat off
            dev.UpdateWireIns();
        }

    // - old version of sample file read that assumes a 2 column CSV, GRID position (A1, etc), and string
    private void readGridValueSamples()
        {
            string smplline;
            int idx = 0;

            OpenFileDialog openFileDialog1 = new OpenFileDialog();

            openFileDialog1.InitialDirectory = samplesDrive;
            openFileDialog1.Filter = "Text files (*.txt;*.csv)|*.txt;*.csv|All files (*.*)|*.*";
            openFileDialog1.FilterIndex = 1;
            openFileDialog1.RestoreDirectory = true;

            if (openFileDialog1.ShowDialog() == DialogResult.OK)
            {
                using (StreamReader smplStream = new StreamReader(openFileDialog1.FileName))
                {
                    samplesFileTB.Text = openFileDialog1.FileName;
                    progressTB.AppendText("Sample File" + samplesFileTB.Text + " opened" + Environment.NewLine);
                    char[] charSeparators = new char[] { ',' };
                    while ((smplline = smplStream.ReadLine()) != null)
                    {
                        progressTB.AppendText(smplline + '\n');

                        //           smplvalues = System.Text.RegularExpressions.Regex.Replace(smplline, "[^.0-9]", ",");


                        string[] values = smplline.Split(charSeparators); //, StringSplitOptions.RemoveEmptyEntries);
                        progressTB.AppendText(values[0] + "--" + values[1] + '\n');
                        values[0] = values[0].ToUpper();  // guard against row saved as lower case a-h
                        char rowc = values[0][0];
                        if (('A' <= rowc) && (rowc <= 'H')) // first character should be row
                            rowc -= 'A'; // convert to row number
                        String cols = values[0].Substring(1);
                        int colnum;
                        if (int.TryParse(cols, out colnum))
                        {
                            idx = rowc * 12 + colnum;
                            TextBox textBox = (TextBox)samplesTLP.Controls["textBox" + idx];
                            textBox.Text = values[1];
                        }
                    } // end while data
                } // end using samples data file 

            }  // endif opened samples file success
        }


    }
}
