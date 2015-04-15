module types;

import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;
import cboxapp;

struct Extnts 
{
	uint w;
	uint h;
}

enum Keys 
{
	MOD1 = Mod1Mask,
	MOD4 = Mod4Mask,
	CONTROL = ControlMask,
	SHIFT = ShiftMask
};

enum { SchemeNorm, SchemeSel, SchemeLast }; /* color schemes */

enum { ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle,
       ClkClientWin, ClkRootWin, ClkLast }; /* clicks */

static int screen;
static int sw, sh;           /* X display screen geometry width, height */
static int bh, blw = 0;      /* bar geometry */


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

