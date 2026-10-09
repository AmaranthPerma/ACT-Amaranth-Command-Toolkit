using System;
using System.Globalization;
using System.Diagnostics;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

// Raw mouse input and normalized XInput axes, using the documented Lua Bridge TCP protocol.
// Captures mouse counts only while the game/freecam is foreground; sends no memory patches.
internal sealed class ActCameraInput : NativeWindow, IDisposable
{
    [StructLayout(LayoutKind.Sequential)] private struct Device { public ushort Page, Usage; public uint Flags; public IntPtr Target; }
    [DllImport("user32.dll", SetLastError=true)] private static extern bool RegisterRawInputDevices(Device[] devices, uint count, uint size);
    [DllImport("user32.dll")] private static extern uint GetRawInputData(IntPtr input, uint command, IntPtr data, ref uint size, uint headerSize);
    [DllImport("winmm.dll")] private static extern uint timeBeginPeriod(uint period);
    [DllImport("winmm.dll")] private static extern uint timeEndPeriod(uint period);
    private readonly object gate = new object();
    private readonly Thread sender;
    private volatile bool running = true;
    private bool capturing, preciseTimer;
    private IntPtr rawBuffer;
    private long mouseX, mouseY;
    private string latest;
    private int version;
    private int session = Environment.TickCount;
    public ActCameraInput()
    {
        CreateParams p = new CreateParams(); p.Parent = new IntPtr(-3); p.Caption = "ACT Camera Raw Input";
        CreateHandle(p);
        Device d = new Device(); d.Page=1; d.Usage=2; d.Flags=0x100; d.Target=Handle;
        if (!RegisterRawInputDevices(new Device[]{d}, 1, (uint)Marshal.SizeOf(typeof(Device))))
            throw new InvalidOperationException("Raw Input mouse registration failed: " + Marshal.GetLastWin32Error());
        rawBuffer=Marshal.AllocHGlobal(4096);
        sender = new Thread(SendLoop); sender.IsBackground=true; sender.Start();
    }
    protected override void WndProc(ref Message m)
    {
        if (m.Msg == 0xFF && capturing)
        {
            uint size=0, header=(uint)(8+2*IntPtr.Size);
            GetRawInputData(m.LParam, 0x10000003, IntPtr.Zero, ref size, header);
            if (size >= header+24 && size < 4096)
            {
                if (GetRawInputData(m.LParam, 0x10000003, rawBuffer, ref size, header)==size && Marshal.ReadInt32(rawBuffer)==0 && (Marshal.ReadInt16(rawBuffer,(int)header)&1)==0)
                { mouseX += Marshal.ReadInt32(rawBuffer,(int)header+12); mouseY += Marshal.ReadInt32(rawBuffer,(int)header+16); }
            }
        }
        base.WndProc(ref m);
    }
    public static double Axis(short value, int deadzone)
    {
        double n=Math.Abs((int)value);
        return n<=deadzone ? 0 : Math.Sign(value)*Math.Min(1,(n-deadzone)/(32767-deadzone));
    }
    public void Pump(bool active, bool focused, double forward, double strafe, double lookX, double lookY, int vertical)
    {
        bool capture=active && focused;
        // Windows can round Sleep(16) up to about 31ms. Request precise waits
        // only while actually controlling the camera; release them on exit/Alt-Tab.
        if(capture && !preciseTimer) preciseTimer=timeBeginPeriod(1)==0;
        else if(!capture && preciseTimer) { timeEndPeriod(1); preciseTimer=false; }
        if (capture && !capturing) { mouseX=0; mouseY=0; session++; }
        capturing=capture;
        Application.DoEvents();
        if (!active) { lock(gate) { latest=null; } return; }
        string packet=String.Format(CultureInfo.InvariantCulture,
          "if ACTCamera then ACTCamera.receive({0},{1},{2},{3:F4},{4:F4},{5:F4},{6:F4},{7},{8}) end\n<<<RUN>>>\n",
          session,mouseX,mouseY,focused?forward:0,focused?strafe:0,focused?lookX:0,focused?lookY:0,focused?vertical:0,focused?"true":"false");
        lock(gate) { if (latest != packet) { latest=packet; version++; } }
    }
    private void SendLoop()
    {
        TcpClient client=null; int sent=-1; long last=0;
        byte[] buffer=new byte[4096];
        while(running)
        {
            Thread.Sleep(4);
            string packet; int rev;
            lock(gate) { packet=latest; rev=version; }
            if(packet==null) { if(client!=null) {client.Close();client=null;} continue; }
            double elapsed=(Stopwatch.GetTimestamp()-last)*1000.0/Stopwatch.Frequency;
            if(elapsed<8) continue;
            // Heartbeats expire held axes safely, even when the controller isn't changing.
            if(rev==sent && elapsed<250) continue;
            try {
                if(client==null) {
                    client=new TcpClient(); client.NoDelay=true;
                    IAsyncResult connect=client.BeginConnect("127.0.0.1",27050,null,null);
                    using(connect.AsyncWaitHandle) { if(!connect.AsyncWaitHandle.WaitOne(1000)) throw new SocketException(); }
                    client.EndConnect(connect); client.ReceiveTimeout=1000; client.SendTimeout=1000;
                }
                NetworkStream stream=client.GetStream(); byte[] bytes=Encoding.ASCII.GetBytes(packet); stream.Write(bytes,0,bytes.Length);
                last=Stopwatch.GetTimestamp();
                string response="";
                // At most one outstanding chunk. Never flood the game thread with input work.
                while(!response.Contains("<<<END>>>")) {
                    int n=stream.Read(buffer,0,buffer.Length); if(n==0) throw new SocketException();
                    response+=Encoding.ASCII.GetString(buffer,0,n);
                    if(response.Length>16384) response=response.Substring(response.Length-512);
                }
                sent=rev;
            } catch(SocketException) { if(client!=null)client.Close();client=null;Thread.Sleep(250); }
              catch(System.IO.IOException) { if(client!=null)client.Close();client=null;Thread.Sleep(250); }
              catch(ObjectDisposedException) { client=null; }
        }
        if(client!=null)client.Close();
    }
    public void Dispose()
    {
        running=false; capturing=false;
        if(preciseTimer) { timeEndPeriod(1); preciseTimer=false; }
        Device d=new Device(); d.Page=1; d.Usage=2; d.Flags=1; d.Target=IntPtr.Zero;
        RegisterRawInputDevices(new Device[]{d},1,(uint)Marshal.SizeOf(typeof(Device)));
        DestroyHandle(); sender.Join(1500);
        if(rawBuffer!=IntPtr.Zero) { Marshal.FreeHGlobal(rawBuffer); rawBuffer=IntPtr.Zero; }
    }
}
