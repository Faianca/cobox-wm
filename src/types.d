module types;

import x11.X;
import x11.Xlib;
import x11.keysymdef;
import x11.Xutil;
import x11.Xatom;
import std.conv;
import cboxapp;
import config;
import old;
import monitor;

import std.traits;

static string stext;

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



enum { ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle,
       ClkClientWin, ClkRootWin, ClkLast }; /* clicks */

static int screen;
static int sw, sh;           /* X display screen geometry width, height */
static int bh, blw = 0;      /* bar geometry */
static uint numlockmask = 0;
static Monitor *mons, selmon;
static Window rootWin;

auto range(string NextField)(Client* head) 
{
    return Client.ClientRange!NextField(head);
}

auto range(Monitor* head) 
{
    return Monitor.MonitorRange(head);
}

auto makeArg(TIN)(TIN val) 
{
    alias T = Unqual!TIN;
    return Arg(val);
}

auto CLEANMASK(M)(auto ref in M mask) 
{
    return (mask & ~(numlockmask|LockMask) & (ShiftMask|ControlMask|Mod1Mask|Mod2Mask|Mod3Mask|Mod4Mask|Mod5Mask));
}

auto INTERSECT(T, M)(T x, T y, T w, T h, M m) 
{
    import std.algorithm;
    return max(0, min(x + w, m.wx + m.ww) - max(x, m.wx)) * max(0, min(y + h, m.wy + m.wh) - max(y, m.wy));
}

auto ISVISIBLE(C)(auto ref in C c) pure @safe @nogc nothrow 
{
    return c.tags & c.mon.tagset[c.mon.seltags];
}

auto LENGTH(X)(auto ref in X x) 
{
    return x.length;
}

auto WIDTH(X)(auto ref in X x) 
{
    return x.w + 2 * x.bw;
}

auto HEIGHT(X)(auto ref in X x) 
{
    return x.h + 2 * x.bw;
}

enum TAGMASK = ((1 << tags.length) - 1);

struct Rule 
{
    string klass;
    string instance;
    string title;
    uint tags;
    bool isfloating;
    int monitor;
}

struct Arg 
{
    union Vals
    {
        int ival;
        uint uival;
        float fval;
        string[] sval;
        void* vptr;
    }

    Vals val;

    //Variant val;
    this(TIN)(TIN val) 
    {
        alias T = Unqual!TIN;
        static if(isIntegral!T) {
            this.val.ival = cast(int)(val);
        } else static if(isFloatingPoint!T) {
            this.val.fval = cast(float)(val);
        } else static if(is(TIN == immutable(immutable(char)[])[])) {
            this.val.sval = cast(string[])val;
        } else {
            this.val.vptr = cast(void*)(val);
        }
    }

    @property int i() const 
    {
        return this.val.ival;
    }

    @property void i(int ival) 
    {
    	val.ival = cast(int)(ival);
    }

    @property uint ui() const 
    {
        return this.val.uival;
    }

    @property void ui(uint ival) 
    {
    	val.uival = cast(uint)(ival);
    }

    @property float f() const 
    {
        return this.val.fval;
    }

    @property void f(float ival) 
    {
    	val.fval = cast(float)(ival);
    }

    @property const(string[]) s() const
    {
        return this.val.sval;
    }

    @property void s(string[] ival) 
    {
    	val.sval = cast(string[])(ival);
    }

    @property const(void*) v() const 
    {
        return this.val.vptr;
    }

    @property void v(void* ival) 
    {
    	val.vptr = cast(void*)(ival);
    }
}



