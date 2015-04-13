module types;

import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;

enum Keys 
{
	MOD1 = Mod1Mask,
	MOD4 = Mod4Mask,
	CONTROL = ControlMask,
	SHIFT = ShiftMask
};

enum { CurNormal, CurResize, CurMove, CurLast }; /* cursor */
enum { SchemeNorm, SchemeSel, SchemeLast }; /* color schemes */
enum { NetSupported, NetWMName, NetWMState,
       NetWMFullscreen, NetActiveWindow, NetWMWindowType,
       NetWMWindowTypeDialog, NetClientList, NetLast }; /* EWMH atoms */
enum { WMProtocols, WMDelete, WMState, WMTakeFocus, WMLast }; /* default atoms */
enum { ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle,
       ClkClientWin, ClkRootWin, ClkLast }; /* clicks */

static int screen;
static int sw, sh;           /* X display screen geometry width, height */
static int bh, blw = 0;      /* bar geometry */

static Atom[WMLast] wmatom;
static Atom[NetLast] netatom;
static Display *dpy;
static Monitor *mons, selmon;
static Window rootWin;

auto range(string NextField)(Client* head) 
{
    return Client.ClientRange!NextField(head);
}

auto range(Monitor* head) {
    return Monitor.MonitorRange(head);
}

struct Layout 
{
	const string symbol;
    void function(Monitor* m) arrange;
}

struct Client 
{
	string name;
	float mina, maxa;
	int x, y, w, h;
	int oldx, oldy, oldw, oldh;
	int basew, baseh, incw, inch, maxw, maxh, minw, minh;
	int bw, oldbw;
	uint tags;
	bool isfixed, isfloating, isurgent, neverfocus, oldstate, isfullscreen;
	Client *next;
	Client *snext;
	Monitor *mon;
	Window win;

    /**
     * A range to iterate over the client list via 'next' or 'snext',
     * as specified by the template string.
     * Example:
     * ---
     * auto r = ClientRange!"next"(clientPtr);
     * auto sr = ClientRange!"snext"(clientPtr);
     * ---
     */
    struct ClientRange(string NextField) {
        Client* client;
        @property bool empty() {return client is null;}
        @property auto front() {return client;}
        auto popFront() {
            mixin(`client = client.`~NextField~`;`);
        }
    }
}

struct Monitor 
{
	string ltsymbol;
	float mfact;
	int nmaster;
	int num;
	int by;               /* bar geometry */
	int mx, my, mw, mh;   /* screen size */
	int wx, wy, ww, wh;   /* window area  */
	uint seltags;
	uint sellt;
	uint[2] tagset;
	bool showbar;
	bool topbar;
	Client *clients;
	Client *sel;
	Client *stack;
	Monitor *next;
	Window barwin;
	const(Layout)*[2] lt;


    struct MonitorRange {
        Monitor* monitor;
        @property empty() {
            return monitor is null;
        }
        @property auto front() {
            return monitor;
        }
        auto popFront() {
            monitor = monitor.next;
        }

        int opApply(int delegate(Monitor*) dg)
        {
            int result = 0;
            while(!this.empty)
            {
                result = dg(this.front);
                if(result)
                {
                    break;
                }
                this.popFront;
            }
            return result;
        }
        int opApply(int delegate(size_t, Monitor*) dg) 
        {
            int result = 0;
            size_t ii = 0;
            while(!this.empty)
            {
                result = dg(ii++, this.front);
                if(result)
                {
                    break;
                }
                this.popFront;
            }
            return result;
        }
    }
}
