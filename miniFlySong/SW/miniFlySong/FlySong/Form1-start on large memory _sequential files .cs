#define LEDFIFO 

using System;
using System.Runtime;
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
using System.Runtime.InteropServices;

//using com.opalkelly.frontpanel;
// ==== T O  D O  ====
// - save temperature channel as 'A1', etc and divide return temperarture reading by 100 to get floating deg C
// - be sure brightness is saved as floating value (returned value / 10)
// - handle when LED setting exceed LED FIFO length, I trucate now, but maxtime refers to original end... hard set to 512 for now


//  ==== V E R S I O N =====
// !!!! - change VERSION string -!!!!

// 20190904 sws
// ====  HANDLE MORE THAN 2 GB OF DATA  ====
// - ok. so:
//   - a WAV file cannot store more than 2^32 or 4GB of data
//   - C#, in 32 bit mode, cannot deal with arrays over 2GB
//   - C# does have large array capability (gcAllowVeryLargeObjects enabled="true") but it requires 64 bit mode
//   - The code will not compile in 64 bit mode since, it seems, that the Opal Keley libraries don't handle it
//   - The inelegant solution is to create enough 2GB arrays to handle projected max file size:
//       60 minutes * 10000 SPS * 100 channels * 2 bytes per value = four 2GB blocks
//   - This is not too bad except that a single record (one sample of all enabled channels) can cross over two  
//      buffers. This will make data rearrangement --- interesting. 

//20190830 sws
// - change default FPS to 15 from 30 (sysRateUD)

// 20190507 sws
// if no FPGA board found make note in progess TB

// 20180705 sws
// - add this.refresh() to get form to show Reordering Label.

// 20180614 sws
// - move wave file name creation to start of run so date/time reflects the start time not end time

// 20180518 sws
// - fix FPGA date format
// - fix sync rate to FPGA

// 20180516 sws
// - if clear names, then put file text box back to default (Click to load Samples File)
// - if early stop, stop timer and reset

// 20180419 sws
// - add sync output (1-200 hz) setup and send to FPGA
//     to get maximum resolution and use 16 bit wires and reduce calcualtions in FPGA (no divides)
//     send 48e6 clock/ (1000 * rate) - this yields a value of 48000 for 1 Hz 

// 20180417 sws
// - add progress bar to track rearrange progress

// 20171201 sws
// - keep LED and tempertaure channels as channels 1-4
// - fix channel names in list so ISBJ is in same order as samples (row/col)

// 20171120 sws
// - rearrange the data so waveform 1 is board 1, ch1, waveform 2 is board 1 ch 2, etc. LED and temps at end
// - shift real time down 50 pixels to clear debug window

// 20170622 sws
// - was mixed up over actual data bytes needed (length) vs how many we need to take (more) to full block transfers (transferBytes)

// 20170611 sws
// - add zero offset correction

// 20170519 sws
// - move batery status bit from 0 to 15, move wire check into setBattery, check battery on FPGA init
// - add LED FIFO length from FPGA to status lower 12 bits

// 20170515 sws
// - use background worker to allow GUI updates while taking data
// - take data in blocks to allow cancellation - need to be sure this doesn't lose any data

// 20170508 sws
// - change transfer block size from 64 to 1024
//  need to ensure length of transfer is integer multiple of 1024
//  also make real time buffer 40960 (instead of 40000) for same reason

// 20170412 sws
// - started adding in ability to download the LED file info so we don't have to 
//      send each LED update while we are running.
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
        string VERSION = "20190830";
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

        string wavfn;   // filename of wave file

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
        //        int ledptr = 0;
        int ledcnt = 0;
        //     UInt16 lasttemp = 99;
        Int32 pos;

        //       UInt32 xfrSize = 16384;
        Boolean stopRun = false;

        long frequency = Stopwatch.Frequency;

        Stopwatch stopWatch;

        String[,] samples = new String[2, 100];  // Chamber location, Fly Genotype
        UInt16[] sampleOn = new UInt16[6];       // bit map of active chanmbers [0].0 = chamber A1, [0].1 = A2,etc
        byte[] buffer = new byte[40960]; //[40000];

        BinaryWriter wavf;

        Boolean transferInProgress = false;

        //UInt32 transferBytes; // how many bytes we need to transfer to get 'length' bytes of needed data
        UInt64 length;

        byte[] memBuffer1;
        byte[] memBuffer2;
        byte[] memBuffer3;
        byte[] memBuffer4;

        int numRuns;
        

        // ============================================
        // ===  "REAL" TIME DATA TRANSFERS  ====
        // ============================================

        unsafe void RTTransfer(UInt32 numsets)
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
            dev.SetWireInValue(0x0c, CLOCKRATE / (1000 * (uint)syncRateUD.Value));
            //           dev.SetWireInValue(0x00, 0 << 5 | 1 << 2 | 1);  // SET_THROTTLE=1 | MODE=LFSR | RESET=1 
            dev.SetWireInValue(0x00, (int)(Bit.reset | Bit.batEnable));  // SET_THROTTLE=1 | MODE=LFSR | RESET=1 
            dev.UpdateWireIns();
            //            dev.SetWireInValue(0x00, 0 << 5 | 0 << 2 | 1);  // SET_THROTTLE=0 | MODE=LFSR | RESET=0
            dev.SetWireInValue(0x00, (int)(Bit.batEnable));  // SET_THROTTLE=0 | MODE=LFSR | RESET=0
            dev.UpdateWireIns();
            //           dev.SetWireInValue(0x00, 1 << 6 | 1 << 5 | 1); // temperature and adc start = 1
            //            dev.SetWireInValue(0x00, 1 << 5 | 1); // temperature and adc start = 1
            dev.SetWireInValue(0x00, (int)(Bit.adcEnable | Bit.tempEnable | Bit.batEnable)); // temperature and adc start = 1
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

            int offset = 0; // track where were we are walking through the data

            for (int row = 0; row < 8; row++)
            {
                int rowoff = 150 + row * 80;  // locate row starting point on display

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
            else
            {
                progressTB.AppendText("NO BOARD FOUND" + Environment.NewLine);
            }

            wavDirTB.Text = wavDir;   // assume default directory
            //  openFileDialog1.InitialDirectory = drive;
        }

        private void Form1_Paint(object sender, PaintEventArgs e)
        {
            if (runP.Visible == false)
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
                    if ((j % 2) == 0)
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
            Invalidate();
        }


        // === S E T U P    F P G A  ===

        private void setRig()
        {
            // open the FPGA board
            if (okCFrontPanel.ErrorCode.NoError != dev.OpenBySerial(selected_rig))
                progressTB.AppendText("Can't open selected FPGA board" + Environment.NewLine);

            // Download the configuration file.
            if (okCFrontPanel.ErrorCode.NoError != dev.ConfigureFPGA(fpgaDrive + "PipeTest.bit"))
            {
                progressTB.AppendText("PROBLEM WITH FPGA FILE: " + fpgaDrive + "PipeTest.bit" + Environment.NewLine);
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
            dev.SetWireInValue(0x0c, CLOCKRATE / (1000 * (uint)syncRateUD.Value)); //(uint)syncRateUD.Value);
            dev.UpdateWireIns();

            dev.UpdateWireOuts();
            uint VERSIONDATE = dev.GetWireOutValue(0x21);
            uint VERSIONYEAR = dev.GetWireOutValue(0x22);
            FPGAVERSION = String.Format("{0}{1:0000}", VERSIONYEAR, VERSIONDATE);
            progressTB.AppendText(String.Format("FPGA code Version: {0}", FPGAVERSION)); //.ToString()));
            progressTB.AppendText(Environment.NewLine);

            setBattery();  // check battery status and show
        }

        private void selectRigLB_MouseDoubleClick(object sender, MouseEventArgs e)
        {
            //string selected_rig;

            selected_rig = selectRigLB.GetItemText(selectRigLB.SelectedItem);
            setRig();
        }


        private void timer2_Tick(object sender, EventArgs e)
        {
            runClockTB.Text = "" + stopWatch.ElapsedMilliseconds / 1000;
        }

        // === S T A R T   R U N  ===

        private void startB_Click(object sender, EventArgs e)
        {
            // first get the Samples Info
            UInt16 inuse = 0;
            for (UInt16 bits = 0; bits < 6; bits++) sampleOn[bits] = 0;  // reset the 'on' bits
            for( UInt16 col = 0; col < 12; col++)  // count down each row then across to mimic data storage
            {
                for (UInt16 row = 0; row < 8; row++)
                //        for (UInt16 i = 1; i <= 96; i++)  // we count across the grid, then down
                {
                    UInt16 i = (UInt16)(col + row*12 + 1);   // get text box number (which goes col, row) & starts at 1
                    TextBox textBox = (TextBox)samplesTLP.Controls["textBox" + i];
                    if (!string.IsNullOrWhiteSpace(textBox.Text))
                    {   // - save the text version of the filled rows and columns ('A1', etc) and the genotype (.Text)
                        samples[0, inuse] = string.Format("{0}{1}", (char)('A'+row), col+1);
                        samples[1, inuse] = textBox.Text;
                        // add this to the 96 bit 'on' pattern for the FPGA to use
                        UInt16 on = (UInt16)(i - 1);
                        sampleOn[on / 16] |= (UInt16)(1 << (on % 16));
                        // !!!   
                        progressTB.AppendText(samples[0, inuse] + "  " + samples[1, inuse] + Environment.NewLine);

                        inuse++;
                        //   button1.Text = textBox.Text + string.Format("{0}", i);
                    }
                } // next row
            }  // next column - endloop check for active (named) channels
            numChans = (UInt16)(inuse + 4); // # audio channels + LED and temp chs
            progressTB.AppendText(string.Format("BITS: {0:X4} {1:X4} {2:X4} {3:X4} {4:X4} {5:X4} Chans:{6}\n", sampleOn[5], sampleOn[4], sampleOn[3], sampleOn[2], sampleOn[1], sampleOn[0], numChans));

            DateTime datetime = DateTime.Now;
            wavfn = wavDir + "\\" + datetime.ToString("yyyyMMddHHmmss_");
            wavfn = wavfn + selected_rig + ".wav";


            startB.Text = "Running";
            startB.Enabled = false;
            stopB.Visible = true;
            stopRun = false;
            Refresh();

            num_recs = (uint)(((float)smplrateUD.Value * maxtime / 1000));

            progressTB.AppendText("start" + Environment.NewLine);
            stopWatch.Reset();  // set stopwatch count to 0
            timer2.Enabled = true;
            stopWatch.Start();

            // ----- Go take the data -----------
            if (backgroundWorker1.IsBusy != true)
            {
                // Start the asynchronous operation.
                progressTB.AppendText("Start BGW");
                transferInProgress = true;
                backgroundWorker1.RunWorkerAsync();
            }
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

            // -- File names
            int infopos = (Int32)wavf.BaseStream.Position + 4;
            wavf.Write(Encoding.UTF8.GetBytes("LIST----INFOINAM"));
            //          string fns = "WAV|" + filenameL.Text + " LED|" + ledFileTB.Text + " SMP|" + samplesFileTB.Text;
            string fns = "LED=" + ledFileTB.Text;
            if (samplesFileTB.Text.StartsWith("Click"))
                fns += " SMP=(no file)";
            else
                fns += " SMP=" + samplesFileTB.Text;
            writeEvenString(wavf, fns);
            
            // -- Versions
            byte[] array = Encoding.ASCII.GetBytes("ISFT");
            foreach (byte element in array)
                wavf.Write(element);
            writeEvenString(wavf, "FlySongDAQ:" + VERSION + " FPGA:" + FPGAVERSION);

            // -- Experimenter name
            array = Encoding.ASCII.GetBytes("IART");
            foreach (byte element in array)
                wavf.Write(element);
            writeEvenString(wavf, ExperimenterTB.Text);

            // -- comments
            array = Encoding.ASCII.GetBytes("ICMT");
            foreach (byte element in array)
                wavf.Write(element);
            writeEvenString(wavf, CommentTB.Text);

            // -- 
            array = Encoding.ASCII.GetBytes("ISBJ----");
            foreach (byte element in array)
                wavf.Write(element);

            int samplspos = (Int32)wavf.BaseStream.Position - 4;

            // -- write out samples info
            // - first the LED and temperature channels
            string smplstr = "LED1,%BRIGHT1,LED2,%BRIGHT2,TEMP CH,CH #,TEMP,DEG C";
            // - then the sample names and positions
            for (UInt16 i = 0; i <= numChans - 4; i++)  // numChans includes the 4 LED and temperature channels
            {
                smplstr += "," + samples[0, i] + "," + samples[1, i];
            }
            writeEvenString(wavf, smplstr);

            // -- and fix length data
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
            uint maxLEDcnt = getLEDFIFOsize();

            progressTB.AppendText(string.Format("LED FIFO SIZE: {0}\n", maxLEDcnt));

            OpenFileDialog openFileDialog1 = new OpenFileDialog();

            openFileDialog1.InitialDirectory = ledDrive;
            openFileDialog1.Filter = "Text files (*.txt;*.csv)|*.txt;*.csv|All files (*.*)|*.*";
            openFileDialog1.FilterIndex = 1;
            openFileDialog1.RestoreDirectory = true;

            if (openFileDialog1.ShowDialog() == DialogResult.OK)
            {
                using (StreamReader ledStream = new StreamReader(openFileDialog1.FileName))
                {
                    progressTB.BackColor = SystemColors.Window;
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

                if ((uint)ledcnt > maxLEDcnt)
                {
                    progressTB.BackColor = Color.Yellow;
                    progressTB.AppendText(string.Format("Too many LED settings, truncating {0} to {1}\n", ledcnt, maxLEDcnt));
                    // progressTB.ForeColor = SystemColors.WindowText;
                    ledcnt = (int)maxLEDcnt;
                }
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
            // zero and turn off stopwatch 
  //          stopWatch.Stop();
 //           stopWatch.Reset();  // set stopwatch count to 0
            timer2.Enabled = false;
            
            if (backgroundWorker1.WorkerSupportsCancellation == true)
            {
                // Cancel the asynchronous operation.
                backgroundWorker1.CancelAsync();
            }
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
                wavDirTB.Text = wavDir;
            }
        }

        private void clearB_Click(object sender, EventArgs e)
        {
            clearNames();
        }

        private void clearNames()
        {
            // clear out old entries
            for (int tb = 1; tb <= 96; tb++)
            {
                TextBox textBox = (TextBox)samplesTLP.Controls["textBox" + tb];
                textBox.Text = "";
            }
            
            samplesFileTB.Text = "Click to load Samples File";
        }

        private uint getLEDFIFOsize()
        {
            //          dev.UpdateWireOuts();
            //          return(dev.GetWireOutValue(0x20) & 0x0FFF);
            return (512);
        }

        private void batteryB_Click(object sender, EventArgs e)
        {
            setBattery();
        }

        private void setBattery()
        {
            dev.UpdateWireOuts();
            uint status = dev.GetWireOutValue(0x20);  // bit 15 is battery status
            if ((status & 0x8000) == 0)  // if battery good, then comparator goes high, turns on LED, pulls OC low
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

        // === Z E R O   C O R R E C T =====

        // subtract the mean value of each channel from each channel value for zero offset

        private void zeroCorrect()
        {

            Int64[] meansum = new Int64[numChans];  // sum data, init to 0 
            Int16[] mean = new Int16[numChans];     // will hold the mean value for each channel

            // get the sum of data
            for (UInt32 rec = 0; rec < num_recs; rec++)  // go thru each record
            {
                for (UInt32 ch = 0; ch < numChans; ch++)
                {
                    meansum[ch] += BitConverter.ToInt16(membuf, (Int32)(2 * (rec * numChans + ch)));  // add in next value - *2 since membuf is byte array
                }
            }

            // calculate the mean for each channels
            for (UInt32 ch = 0; ch < numChans; ch++)
            {
                mean[ch] = (Int16)(meansum[ch] / num_recs);
            }

            // Now subtract out the mean for each microphone channel
            for (UInt32 rec = 0; rec < num_recs; rec++)
            {
                for (UInt32 ch = 4; ch < numChans; ch++)   // don't 'fix' led or temperature channels
                {
                    Int16 val = BitConverter.ToInt16(membuf, (Int32)(2 * (rec * numChans + ch)));
                    val -= mean[ch];
                    byte[] bytes = BitConverter.GetBytes(val);
                    membuf[2 * (rec * numChans + ch)] = bytes[0];  // store LOB
                    membuf[2 * (rec * numChans + ch) + 1] = bytes[1];  // store HOB
                }
            }
        }

        // === R E A R R A G E  I N   P L A C E ===

        private void rearrangeInPlace()
        {
            // go thru the memory array, one record at a time, and rearrange the data.
            // data comes from board as:
            //   LEDs and temp, then 1st board, chan 1, 2nd board chan 1, etc. 
            // But we want the data file to be:
            //  LEDs and temp, then 1st board 1-8, 2nd board 1-8, etc
            // -- so we need to rearrange the data in place before storing it to the file. 
            // We can reaarange the data in place, then the file write routine does a straight memory transfer
            // We will reararnge one record at a time, but the problem is that a record can span two memory buffers

            Int16[] temp = new Int16[numChans]; // temp store to rearrange to
            byte[] rawRecord = new byte[numChans*2];  // place next record from memory here to then process
            Int16[,] newLocation = new Int16[12,8]; // map of offset to this location's data
            Int16 oldChan = 4;  // startup with first offset (point past LED and temp data)
            Int64 recordSize = (Int64)(numChans * 2);  // size of each record
            Int64 totalBytes = -1;   // track our byte count - this will be equal to the last value in each set
            const Int64 twoGB = 0x80000000;

            rearrangePB.Visible = true;
            rearrangePB.Minimum = 0;
            rearrangePB.Maximum = (int) num_recs;
            rearrangePB.Value = 0;
            rearrangePB.Step = 1;

            string dstr = string.Format("rearrange \n");
            progressTB.AppendText(dstr);
            ReorderL.Visible = true;
            this.Refresh();

            // find all active channels and place their memory offset into a 2-D array
            for (Int32 row = 0; row < 8; row++)   // walk through the channels in order
            {
                for (Int32 col = 0; col < 12; col++ )
                {
                    Int32 chan = row * 12 + col;
                    if ((sampleOn[chan / 16] & (UInt16)(1 << chan % 16)) > 0)  // this channel on
                    {
                        newLocation[col, row] = oldChan++;  // save the order of this channel (offset with LED and temp locations) 
 //                       string nr = string.Format("COL: {0}  ROW: {1}  VAL: {2}" + Environment.NewLine, col, row, newLocation[col, row]);
 //                       progressTB.AppendText(nr);
                    }
                    else
                        newLocation[col, row] = -1;  // signifies unused channel
                } // next column           
            }  // next row - finding which channels are saved

            // we've mapped the offset of each active channel, now rearrange the data

            for (UInt32 rec = 0; rec < num_recs; rec++)  // go thru each record
            {
                totalBytes += recordSize * rec;  // track where the last value in the next set is

                if( totalBytes < twoGB )  // in first buffer
                {
                    Array.Copy(memBuffer1, (Int32)(rec * numChans * 2), rawRecord, (Int32)0,  (Int32)recordSize );  
                }
                else if ((totalBytes >= twoGB) && ((totalBytes - recordSize) < twoGB) ) // in between 1st and second buffer 
                {
                     
                }

                // move LED and temp to front
                for (UInt32 ch = 0; ch < 4; ch++)
                {
                    temp[ch] = BitConverter.ToInt16(membuf, (Int32)(2 * (rec * numChans + ch)));
                }
                // and now the microphone data
                Int16 newChan = 4; // offset pointer to new channel order - starts after LED and temperature
                for (Int32 col = 0; col < 12; col++ )    // each board
                {
                    for( Int32 row = 0; row < 8; row++ )   // each mic on this board to get order right
                    {
                        if (newLocation[col, row] >= 0 )   // unused channel order was set to -1 above
                        {
                            temp[newChan] = BitConverter.ToInt16( membuf, (Int32)(2 * (rec * numChans + newLocation[col, row])) );
                            newChan++;
                        }
                    } // end col check
                } // next row rearranging into new array

                for (Int16 ch = 0; ch < newChan; ch++)  // save LED and temps plus all data
                {
                    byte[] bytes = BitConverter.GetBytes(temp[ch]);
                    membuf[2 * (rec * numChans + ch)] = bytes[0];  // store LOB
                    membuf[2 * (rec * numChans + ch) + 1] = bytes[1];  // store HOB
                }

                rearrangePB.PerformStep();
            } // next record
            rearrangePB.Visible = false;
            ReorderL.Visible = false;
         
        }  // end rearrangeInPlace function




        // === T R A N S F E R === DATA FROM FPGA ===
        // --- B A C K G R O U N D   W O R K E R ---

        private void backgroundWorker1_DoWork(object sender, DoWorkEventArgs e)
        {

            BackgroundWorker worker = sender as BackgroundWorker;
            const UInt64 twoGB = 0x80000000;
            const Int32 transferSize = 0x10000;
            //const UInt32 blocks2GB = (UInt32) (twoGB / transferSize);

            UInt64 transferBytes; // how many bytes we need to transfer to get 'length' bytes of needed data
            int blockSize = 1024;
            long ret = 0;
            stopRun = false;
            length = num_recs * numChans * 2;    // this is nominally how many bytes we want to fullfill the request
    
            transferBytes = transferSize * (1 + (length / transferSize));     // make one full extra run to get fractional part we need
            numRuns = (int)(transferBytes / 0x10000);               // number of times we need to transfer blocks from FPGA
            int numBuffs = (int)((transferBytes + (ulong)(twoGB-1) )/ twoGB);   // number of 2GB buffers we need - round up

            // only create the necessary buffers
            if (numBuffs < 2)
            {
                memBuffer1 = new byte[transferBytes];
            }
            else
            {
                memBuffer1 = new byte[twoGB];
                if( numBuffs < 3 )
                {
                    memBuffer2 = new byte[transferBytes - twoGB];
                }
                memBuffer2 = new byte[twoGB];
                if( numBuffs < 4 )
                {
                    memBuffer3 = new byte[(UInt32)(transferBytes - 2 * twoGB)];
                }
                else
                {
                    memBuffer3 = new byte[twoGB];
                    memBuffer4 = new byte[(UInt32)(transferBytes - 3 * twoGB)];
                }
            }


                // memarray = new byte[numBuffs, 0x80000000];              // create number of required 2GB buffers

            clocksPerSample = CLOCKRATE / (uint)smplrateUD.Value;
            int timeout = (int)(1500000000 / (numChans * smplrateUD.Value));

            dev.SetTimeout(timeout);

           // dev.UpdateWireOuts();
            setBattery();
            dev.SetWireInValue(0x02, clocksPerSample);  //  number of 48Mhz clocks per sample
            dev.SetWireInValue(0x01, numBoards);        // number of boards to save (1-12)
            dev.SetWireInValue(0x05, sampleOn[0]);      // mask to show which channels we will save
            dev.SetWireInValue(0x06, sampleOn[1]);
            dev.SetWireInValue(0x07, sampleOn[2]);
            dev.SetWireInValue(0x08, sampleOn[3]);
            dev.SetWireInValue(0x09, sampleOn[4]);
            dev.SetWireInValue(0x0a, sampleOn[5]);
            dev.SetWireInValue(0x0c, CLOCKRATE / (1000 * (uint)syncRateUD.Value) );
            dev.SetWireInValue(0x00, (int)(Bit.reset | Bit.batEnable)); //  temp, adc off , RESET=1 , bat enabled
            dev.UpdateWireIns();

            // Send over LED timing and brightness info
            for (UInt16 lp = 0; lp < ledcnt; lp++)
            {
                UInt16 bright = (UInt16)(led0bright[lp] * 10);
                if (bright > 1000) bright = 1000;  // brightness must be <= 100.0 %  (we send it over x 10) 
                UInt16 time = (UInt16)(ledtime[lp] / 100);
                dev.SetWireInValue(0x03, (UInt16)bright);   // new LED setting
                dev.SetWireInValue(0x04, (UInt16)time);     // LED time in 0.1 secs
                dev.SetWireInValue(0x0B, (UInt16)(lp + 1)); // start fifo count at 1, 0 means no data
                dev.UpdateWireIns();
                dev.SetWireInValue(0x0B, (UInt16)0);        // '0' so we don't keep updating FIFO value in FPGA
                dev.UpdateWireIns();
                string ledstr = String.Format("LED: {0}, {1}, {2}\n", lp, bright, time);
     //           progressTB.AppendText(ledstr);
            }

            // now we are ready to start, drop the reset bit and enable everything else
            dev.SetWireInValue(0x00, (int)(Bit.LEDEnable | Bit.tempEnable | Bit.adcEnable | Bit.batEnable)); // temperature and adc start = 1
            dev.UpdateWireIns();
            unsafe  
            {
                for (int bufCnt = 0; bufCnt < numBuffs; bufCnt++)
                { 
                    for (int i = 0; i < (int)(twoGB / transferSize); i++)
                    {
                        if (worker.CancellationPending == true)
                        {
                            e.Cancel = true;
                            break;
                        }
                        else
                        {
                            if (bufCnt == 0)
                            {
                                ret = dev.ReadFromBlockPipeOutX(0xA0, blockSize, transferSize, memBuffer1, (int)transferSize * i);  // read 1024 bytes per bloc
                            }
                            else if (bufCnt == 1)
                            {
                                ret = dev.ReadFromBlockPipeOutX(0xA0, blockSize, transferSize, memBuffer2, (int)transferSize * i);  // read 1024 bytes per bloc
                            }
                            else if (bufCnt == 2)
                            {
                                ret = dev.ReadFromBlockPipeOutX(0xA0, blockSize, transferSize, memBuffer3, (int)transferSize * i);  // read 1024 bytes per bloc
                            }
                            else
                            {
                                ret = dev.ReadFromBlockPipeOutX(0xA0, blockSize, transferSize, memBuffer4, (int)transferSize * i);  // read 1024 bytes per bloc
                            }
                        }
                    }
                }            
            }
            if (ret < 0)
            {
                if (dev.IsOpen() == false)
                {
   //                 progressTB.AppendText("Device disconnected");
                    //                 exit(-1);
                }
            } // endif bad ret

            dev.SetWireInValue(0x00, (int)(Bit.reset | Bit.batEnable));  // temp off, adc off, reset, bat still on 
            dev.UpdateWireIns();

            worker.ReportProgress(9);
        }

        // =====================================
        // === END OF TRANSFER =================
        //
        // ZERO CORRECT AND SAVE DATA AS WAV 
        // =====================================

        private void backgroundWorker1_RunWorkerCompleted(object sender, RunWorkerCompletedEventArgs e)
        {

            transferInProgress = false;  

            if (e.Cancelled == true)    // early cancel, scrap data 
            {
                progressTB.AppendText( "Cancelled!");
            }
            else if (e.Error != null)   // error, scrap data
            {
                string estr = string.Format("Error: {0}",  e.Error.Message);
                progressTB.AppendText(estr);
            }
            else   // good run, create WAV file and save zero corrected data
            {
                progressTB.AppendText("Done!\r");

                string dstr = string.Format(" {0} bytes, {1} recs, {2} chans, {3} runs, \n", length, num_recs, numChans, numRuns);
                progressTB.AppendText(dstr);

                // make new WAV file;
               // DateTime datetime = DateTime.Now;
               // string fn = wavDir + "\\" + datetime.ToString("yyyyMMddHHmmss_");
               // fn = fn + selected_rig + ".wav";
                progressTB.AppendText(wavfn + Environment.NewLine);
                filenameL.Text = wavfn;

                string fstr = string.Format("zero - {0} recs, {1} chans, {2} bytes, {3} length\n", num_recs, numChans, 2 * ((num_recs - 1) * numChans), length);
                progressTB.AppendText(fstr);

                //             zeroCorrect();  // remove any zero offset

                // --- originally stored LED and temperature channels followed by data in the form we 
                //     read it in, 1st channel of each board (1-12) then 2nd of each, etc
                // --- now we want microphone data first and board by board, so we will rearrange the data in place
                
                rearrangeInPlace();

                using (wavf = new BinaryWriter(File.Open(wavfn, FileMode.Create)))
                {
                    wavHeader(wavf); // write out header information
                    
                    // store all the data 
                    wavf.Write(membuf, 0, (int)(length));   // write out data, length is total bytes (total chs * total records * 2 bytes/
                    
                    timer2.Enabled = false;

                    string nr = string.Format("Done, actual records:{0}" + Environment.NewLine, length);
                    progressTB.AppendText(nr);

                    stopWatch.Stop();

                    dev.SetWireInValue(0x03, 0x00); // set LED off
                    dev.SetWireInValue(0x04, 0x00); // set LEDS off
                    dev.UpdateWireIns();

                    waveINFO(wavf); // save INFO before rewinding to fix header lengths

                    wavf.Seek(pos, SeekOrigin.Begin);  // go fill in the data size
                    UInt32 datasize = length; // num_recs * 2 * numChans;  // number of records * number of channels * 2 bytes/value
                    wavf.Write(datasize);
                    wavf.Seek(4, SeekOrigin.Begin);
                    datasize += 36;
                    wavf.Write(datasize);
                }

                dev.SetWireInValue(0x03, 0x00); // set LED off
                dev.SetWireInValue(0x04, 0x00); // set LEDS off
                dev.UpdateWireIns();

            } // end of normal background end

            startB.Text = "Start";
            startB.Enabled = true;
            stopB.Visible = false;
            stopRun = false;
        }

        private void backgroundWorker1_ProgressChanged(object sender, ProgressChangedEventArgs e)
        {
            string pstr = string.Format("{0},", e.ProgressPercentage);
            progressTB.AppendText(pstr);
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
    }
}
