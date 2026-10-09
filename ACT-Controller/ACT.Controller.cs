using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

// Companion esterno: ACT menu e Creator Camera tramite XInput.
// Non intercetta né sopprime i comandi originali del gioco.
internal static class ActController
{
    private const ushort RightThumb = 0x0080;
    private const ushort LeftThumb = 0x0040;
    private const ushort DpadUp = 0x0001;
    private const ushort DpadDown = 0x0002;
    private const ushort DpadLeft = 0x0004;
    private const ushort DpadRight = 0x0008;
    private const ushort ButtonA = 0x1000;
    private const ushort ButtonB = 0x2000;
    private const ushort LeftShoulder = 0x0100;
    private const ushort RightShoulder = 0x0200;
    private const byte LeftTriggerPress = 60;
    private const byte LeftTriggerRelease = 30;
    private const ushort F4 = 0x73;
    private const ushort Enter = 0x0D;
    private const ushort Backspace = 0x08;
    private const ushort Up = 0x26;
    private const ushort Down = 0x28;
    private const ushort Left = 0x25;
    private const ushort Right = 0x27;
    private const ushort PageUp = 0x21;
    private const ushort PageDown = 0x22;
    private const uint InputKeyboard = 1;
    private const uint KeyUp = 0x0002;
    private const int PollMilliseconds = 16;

    private sealed class MenuLogState
    {
        private readonly string path;
        private long position;
        private string partial = "";
        private readonly bool diagnostics;
        public bool Open { get; private set; }
        public bool CameraActive { get; private set; }

        // Il log del bridge può arrivare dopo il primo input del menu: aggiorna
        // subito la stima locale, poi AcceptLine la sincronizza con Lua.
        public void EstimateToggle() { Open = !Open; }

        public MenuLogState(string gameDirectory, bool diagnostics = true)
        {
            this.diagnostics = diagnostics;
            string physical = Path.Combine(gameDirectory, "scripts", "lua_loader_printf.log");
            string relativeGame = gameDirectory.Substring(Path.GetPathRoot(gameDirectory).Length);
            string virtualized = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "VirtualStore", relativeGame, "scripts", "lua_loader_printf.log");
            path = File.Exists(virtualized) ? virtualized : physical;
            try { position = new FileInfo(path).Length; }
            catch (FileNotFoundException) { }
            if (diagnostics) Log("Lettura stato ACT: " + path);
        }

        public void AcceptLine(string line)
        {
            if (line.Contains("[ACT] menu aperto"))
            {
                if (!Open && diagnostics) Log("Menu ACT aperto");
                Open = true;
            }
            else if (line.Contains("[ACT] menu chiuso"))
            {
                if (Open && diagnostics) Log("Menu ACT chiuso");
                Open = false;
            }
            else if (line.Contains("[ACT Camera] attivata")) CameraActive = true;
            else if (line.Contains("[ACT Camera] disattivata")) CameraActive = false;
        }

        public void Poll()
        {
            try
            {
                using (FileStream file = new FileStream(path, FileMode.Open, FileAccess.Read,
                    FileShare.ReadWrite | FileShare.Delete))
                {
                    if (file.Length < position)
                    {
                        position = 0;
                        partial = "";
                        Open = false;
                        CameraActive = false;
                    }
                    file.Seek(position, SeekOrigin.Begin);
                    byte[] data = new byte[file.Length - position];
                    int count = 0;
                    while (count < data.Length)
                    {
                        int n = file.Read(data, count, data.Length - count);
                        if (n == 0) break;
                        count += n;
                    }
                    position += count;
                    if (count == 0) return;
                    string text = partial + Encoding.UTF8.GetString(data, 0, count);
                    string[] lines = text.Split('\n');
                    partial = lines[lines.Length - 1];
                    for (int i = 0; i < lines.Length - 1; i++) AcceptLine(lines[i]);
                }
            }
            catch (FileNotFoundException) { Open = false; CameraActive = false; position = 0; partial = ""; }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }

    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Gamepad
    {
        public ushort Buttons;
        public byte LeftTrigger;
        public byte RightTrigger;
        public short LeftX;
        public short LeftY;
        public short RightX;
        public short RightY;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct XinputState
    {
        public uint PacketNumber;
        public Gamepad Gamepad;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MouseInput
    {
        public int X;
        public int Y;
        public uint MouseData;
        public uint Flags;
        public uint Time;
        public IntPtr ExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KeyboardInput
    {
        public ushort VirtualKey;
        public ushort ScanCode;
        public uint Flags;
        public uint Time;
        public IntPtr ExtraInfo;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputData
    {
        [FieldOffset(0)] public MouseInput Mouse;
        [FieldOffset(0)] public KeyboardInput Keyboard;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Input
    {
        public uint Type;
        public InputData Data;
    }

    [DllImport("xinput1_4.dll", EntryPoint = "XInputGetState")]
    private static extern uint XInputGetState14(uint userIndex, out XinputState state);

    [DllImport("xinput1_3.dll", EntryPoint = "XInputGetState")]
    private static extern uint XInputGetState13(uint userIndex, out XinputState state);

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint count, [In] Input[] inputs, int size);

    private static uint ReadController(uint index, out XinputState state)
    {
        try { return XInputGetState14(index, out state); }
        catch (DllNotFoundException) { return XInputGetState13(index, out state); }
        catch (EntryPointNotFoundException) { return XInputGetState13(index, out state); }
    }

    private static bool GameInForeground()
    {
        IntPtr window = GetForegroundWindow();
        if (window == IntPtr.Zero) return false;
        uint id;
        GetWindowThreadProcessId(window, out id);
        try
        {
            using (Process process = Process.GetProcessById((int)id))
                return String.Equals(process.ProcessName, "Mercenaries2", StringComparison.OrdinalIgnoreCase);
        }
        catch (ArgumentException) { return false; }
    }

    private static bool PressKey(ushort key, int holdMilliseconds)
    {
        Input[] input = new Input[1];
        input[0].Type = InputKeyboard;
        input[0].Data.Keyboard.VirtualKey = key;
        bool pressed = SendInput(1, input, Marshal.SizeOf(typeof(Input))) == 1;
        if (!pressed) return false;
        // Il bridge puo rilevare il tasto tramite polling: tenerlo premuto per alcuni frame.
        Thread.Sleep(holdMilliseconds);
        input[0].Data.Keyboard.Flags = KeyUp;
        return SendInput(1, input, Marshal.SizeOf(typeof(Input))) == 1;
    }

    private static bool SetKey(ushort key, bool down)
    {
        Input[] input = new Input[1];
        input[0].Type = InputKeyboard;
        input[0].Data.Keyboard.VirtualKey = key;
        input[0].Data.Keyboard.Flags = down ? 0u : KeyUp;
        return SendInput(1, input, Marshal.SizeOf(typeof(Input))) == 1;
    }

    private static bool ShouldToggle(ref bool latched, bool l3, byte leftTrigger)
    {
        if (!l3 || leftTrigger <= LeftTriggerRelease) latched = false;
        if (!l3 || leftTrigger < LeftTriggerPress || latched) return false;
        latched = true;
        return true;
    }

    private static void Log(string message)
    {
        try
        {
            File.AppendAllText(Path.Combine(Path.GetTempPath(), "ACT-controller.log"),
                DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") + " " + message + Environment.NewLine);
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }

    private static int SelfTest()
    {
        bool latched = false;
        int toggles = 0;
        toggles += ShouldToggle(ref latched, true, 80) ? 1 : 0;
        toggles += ShouldToggle(ref latched, true, 80) ? 1 : 0;
        toggles += ShouldToggle(ref latched, true, 0) ? 1 : 0;
        toggles += ShouldToggle(ref latched, true, 80) ? 1 : 0;
        MenuLogState menu = new MenuLogState(Path.GetTempPath(), false);
        menu.AcceptLine("[ACT] menu aperto");
        bool opened = menu.Open;
        menu.AcceptLine("[ACT] menu chiuso");
        bool closed = !menu.Open;
        menu.AcceptLine("[ACT] menu aperto");
        menu.AcceptLine("[ACT Camera] attivata; F4 o L2+L3 per uscire");
        bool cameraOpened = menu.CameraActive;
        menu.AcceptLine("[ACT Camera] disattivata");
        bool cameraClosed = !menu.CameraActive;
        bool axesOk = ActCameraInput.Axis(0,6500)==0 && ActCameraInput.Axis(6500,6500)==0
            && ActCameraInput.Axis(32767,6500)==1 && ActCameraInput.Axis(-32768,6500)==-1;
        bool ok = axesOk && toggles == 2 && opened && closed && menu.Open && cameraOpened && cameraClosed;
        Console.WriteLine("ACT toggle ripetuto: " + (ok ? "OK" : "ERRORE"));
        return ok ? 0 : 1;
    }

    [STAThread]
    private static int Main(string[] args)
    {
        bool probe = args.Length > 0 && args[0] == "--probe";
        if (args.Length > 0 && args[0] == "--self-test") return SelfTest();
        bool firstInstance;
        using (Mutex instance = new Mutex(true, "Local\\ACT.Controller", out firstInstance))
        {
            if (!firstInstance) return 0;
            using (ActCameraInput cameraInput = new ActCameraInput()) return Run(probe, cameraInput);
        }
    }

    private static int Run(bool probe, ActCameraInput cameraInput)
    {
        bool[] latched = new bool[4];
        ushort[] previousButtons = new ushort[4];
        bool[] triggerDown = new bool[4];
        bool[] triggerBlocked = new bool[4];
        bool[] previousTriggerNav = new bool[4];
        DateTime[] nextUp = new DateTime[4];
        DateTime[] nextDown = new DateTime[4];
        DateTime[] nextLeft = new DateTime[4];
        DateTime[] nextRight = new DateTime[4];
        bool seenGame = false;
        DateTime nextGameCheck = DateTime.MinValue;
        DateTime nextLogPoll = DateTime.MinValue;
        string gameDirectory = Directory.GetParent(AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\')).FullName;
        MenuLogState menu = new MenuLogState(gameDirectory);
        Console.WriteLine("ACT Controller: L2 + L3 / A / B / D-Pad");
        Log("Companion avviato: L2 + L3");

        while (true)
        {
            DateTime loopNow = DateTime.UtcNow;
            if (loopNow >= nextGameCheck) {
                Process[] games = Process.GetProcessesByName("Mercenaries2");
                if (games.Length > 0) seenGame = true;
                foreach (Process game in games) game.Dispose();
                if (seenGame && games.Length == 0) { Log("Gioco chiuso: companion terminato"); return 0; }
                nextGameCheck = loopNow.AddMilliseconds(500);
            }
            bool active = GameInForeground();
            if (loopNow >= nextLogPoll) {
                menu.Poll(); nextLogPoll = loopNow.AddMilliseconds(50);
            }
            bool connected = false;
            double forward=0, strafe=0, lookX=0, lookY=0;
            int vertical=0;
            bool cameraController=false;
            for (uint index = 0; index < 4; index++)
            {
                XinputState state;
                if (ReadController(index, out state) != 0)
                {
                    latched[index] = false;
                    previousButtons[index] = 0;
                    triggerDown[index] = triggerBlocked[index] = previousTriggerNav[index] = false;
                    continue;
                }
                connected = true;
                bool l3 = (state.Gamepad.Buttons & LeftThumb) != 0;
                if (state.Gamepad.LeftTrigger <= LeftTriggerRelease) {
                    triggerDown[index] = false; triggerBlocked[index] = false;
                } else if (state.Gamepad.LeftTrigger >= LeftTriggerPress) triggerDown[index] = true;
                // Consuming L2 for the menu chord prevents a stray Down after opening/closing.
                if (l3 && triggerDown[index]) triggerBlocked[index] = true;
                bool triggerNav = triggerDown[index] && !triggerBlocked[index];
                bool triggerFresh = triggerNav && !previousTriggerNav[index];
                previousTriggerNav[index] = triggerNav;
                if (ShouldToggle(ref latched[index], l3, state.Gamepad.LeftTrigger))
                {
                    if (active)
                    {
                        bool sent = PressKey(F4, 65);
                        if (sent) menu.EstimateToggle();
                        Console.WriteLine(sent ? "ACT: F4 inviato" : "ACT: invio F4 non riuscito");
                        Log("Controller " + index + (sent ? ": F4 inviato" : ": invio F4 fallito"));
                    }
                    else Log("Controller " + index + ": combinazione ignorata, gioco non in primo piano");
                }
                ushort buttons = state.Gamepad.Buttons;
                ushort fresh = (ushort)(buttons & ~previousButtons[index]);
                previousButtons[index] = buttons;
                if (active && menu.Open)
                {
                    if ((fresh & (ButtonA | RightShoulder)) != 0) Log(PressKey(Enter, 50) ? "A/Croce o R1/RB -> Invio" : "Conferma: invio fallito");
                    if ((fresh & ButtonB) != 0) Log(PressKey(Backspace, 50) ? "B/Cerchio -> Backspace" : "B/Cerchio: invio fallito");
                    if ((fresh & LeftShoulder) != 0) PressKey(PageUp, 50);
                    DateTime now = DateTime.UtcNow;
                    bool navUp = (buttons & DpadUp) != 0 || state.Gamepad.LeftY > 16000;
                    bool navDown = triggerNav || (buttons & DpadDown) != 0 || state.Gamepad.LeftY < -16000;
                    bool navLeft = (buttons & DpadLeft) != 0 || state.Gamepad.LeftX < -16000;
                    bool navRight = (buttons & DpadRight) != 0 || state.Gamepad.LeftX > 16000;
                    if (navUp && ((fresh & DpadUp) != 0 || now >= nextUp[index]))
                    {
                        PressKey(Up, 50);
                        nextUp[index] = now.AddMilliseconds((fresh & DpadUp) != 0 ? 320 : 130);
                    }
                    if (navDown && (triggerFresh || (fresh & DpadDown) != 0 || now >= nextDown[index]))
                    {
                        PressKey(Down, 50);
                        nextDown[index] = now.AddMilliseconds(triggerFresh || (fresh & DpadDown) != 0 ? 320 : 130);
                    }
                    if (navLeft && ((fresh & DpadLeft) != 0 || now >= nextLeft[index]))
                    {
                        PressKey(Left, 50);
                        nextLeft[index] = now.AddMilliseconds((fresh & DpadLeft) != 0 ? 320 : 130);
                    }
                    if (navRight && ((fresh & DpadRight) != 0 || now >= nextRight[index]))
                    {
                        PressKey(Right, 50);
                        nextRight[index] = now.AddMilliseconds((fresh & DpadRight) != 0 ? 320 : 130);
                    }
                }
                if (active && menu.CameraActive)
                {
                    if (!cameraController) {
                        forward=ActCameraInput.Axis(state.Gamepad.LeftY, 6500);
                        strafe=ActCameraInput.Axis(state.Gamepad.LeftX, 6500);
                        lookX=ActCameraInput.Axis(state.Gamepad.RightX, 6500);
                        lookY=ActCameraInput.Axis(state.Gamepad.RightY, 6500);
                        // L2+L3 remains the exit chord; it must not also raise the camera.
                        vertical=((buttons & LeftThumb)!=0 && state.Gamepad.LeftTrigger < LeftTriggerPress ? 1:0)
                                 - ((buttons & RightThumb)!=0 ? 1:0);
                        cameraController=true;
                    }
                }
            }
            cameraInput.Pump(menu.CameraActive, active, forward, strafe, lookX, lookY, vertical);
            if (probe)
            {
                Console.WriteLine(connected ? "Controller XInput rilevato" : "Nessun controller XInput rilevato");
                return connected ? 0 : 1;
            }
            Thread.Sleep(menu.CameraActive && active ? 8 : PollMilliseconds);
        }
    }
}
