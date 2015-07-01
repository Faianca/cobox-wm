module events.keyboard;

import kernel;
import old;
import config;
import types;
import cboxapp;
import gui.bar;

import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;
import std.stdio;
import events.interfaces;

struct Key {
	uint mod;
	KeySym keysym;
    void function(const Arg* a) func;
    const Arg arg;

    this(uint mod, KeySym keysym, void function(const Arg* a) func) {
        this(mod, keysym, func, null);
    }
    this(T)(uint mod, KeySym keysym, void function(const Arg* a) func, T arg) {
        this.mod = mod;
        this.keysym = keysym;
        this.func = func;
        this.arg = makeArg(arg);
    }
}

struct EventKey {
	uint mod;
	KeySym keysym;
    void delegate() func;
    const Arg arg;

    this(uint mod, KeySym keysym, void delegate() func) {
        this(mod, keysym, func, null);
    }
    this(T)(uint mod, KeySym keysym, void delegate() func, T arg) {
        this.mod = mod;
        this.keysym = keysym;
        this.func = func;
        this.arg = makeArg(arg);
    }
}

class KeyboardEvents : EventInterface
{
	Key[] keys;
	EventKey[] eventKeys;

	this() 
	{
		keys = [
	        Key( MODKEY,                       XK_p,      &spawn,         dmenucmd ), // dmenucmd
	        Key( MODKEY|ShiftMask,             XK_Return, &spawn,          termcmd ), // termcmd
	        Key( MODKEY,                       XK_b,      &togglebar       ), // TopBar.instance().togglebar
	        Key( MODKEY,                       XK_j,      &focusstack,     +1  ),
	        Key( MODKEY,                       XK_k,      &focusstack,     -1  ),
	        Key( MODKEY,                       XK_i,      &incnmaster,     +1  ),
	        Key( MODKEY,                       XK_d,      &incnmaster,     -1  ),
	        Key( MODKEY,                       XK_h,      &setmfact,       -0.05 ),
	        Key( MODKEY,                       XK_l,      &setmfact,       +0.05 ),
	        Key( MODKEY,                       XK_Return, &zoom            ),
	        Key( MODKEY,                       XK_Tab,    &view            ),
	        Key( MODKEY|ShiftMask,             XK_c,      &killclient      ),
	        Key( MODKEY,                       XK_t,      &setlayout,      &layouts[0] ),
	        Key( MODKEY,                       XK_f,      &setlayout,      &layouts[1] ),
	        Key( MODKEY,                       XK_m,      &setlayout,      &layouts[2] ),
	        Key( MODKEY,                       XK_space,  &setlayout,      0 ),
	        Key( MODKEY|ShiftMask,             XK_space,  &togglefloating, 0 ),
	        Key( MODKEY,                       XK_0,      &view,           ~0  ),
	        Key( MODKEY|ShiftMask,             XK_0,      &tag,            ~0  ),
	        Key( MODKEY,                       XK_comma,  &focusmon,       -1  ),
	        Key( MODKEY,                       XK_period, &focusmon,       +1  ),
	        Key( MODKEY|ShiftMask,             XK_comma,  &tagmon,         -1  ),
	        Key( MODKEY|ShiftMask,             XK_period, &tagmon,         +1  ),
	        Key( MODKEY,                       XK_1,      &view,           1<<0 ),
	        Key( MODKEY|ControlMask,           XK_1,      &toggleview,     1<<0 ),
	        Key( MODKEY|ShiftMask,             XK_1,      &tag,            1<<0 ),
	        Key( MODKEY|ControlMask|ShiftMask, XK_1,      &toggletag,      1<<0 ),
	        Key( MODKEY,                       XK_2,      &view,           1<<1 ),
	        Key( MODKEY|ControlMask,           XK_2,      &toggleview,     1<<1 ),
	        Key( MODKEY|ShiftMask,             XK_2,      &tag,            1<<1 ),
	        Key( MODKEY|ControlMask|ShiftMask, XK_2,      &toggletag,      1<<1 ),
	        Key( MODKEY,                       XK_3,      &view,           1<<2 ),
	        Key( MODKEY|ControlMask,           XK_3,      &toggleview,     1<<2 ),
	        Key( MODKEY|ShiftMask,             XK_3,      &tag,            1<<2 ),
	        Key( MODKEY|ControlMask|ShiftMask, XK_3,      &toggletag,      1<<2 ),
	        Key( MODKEY,                       XK_4,      &view,           1<<3 ),
	        Key( MODKEY|ControlMask,           XK_4,      &toggleview,     1<<3 ),
	        Key( MODKEY|ShiftMask,             XK_4,      &tag,            1<<3 ),
	        Key( MODKEY|ControlMask|ShiftMask, XK_4,      &toggletag,      1<<3 ),
	        Key( MODKEY,                       XK_5,      &view,           1<<4 ),
	        Key( MODKEY|ControlMask,           XK_5,      &toggleview,     1<<4 ),
	        Key( MODKEY|ShiftMask,             XK_5,      &tag,            1<<4 ),
	        Key( MODKEY|ControlMask|ShiftMask, XK_5,      &toggletag,      1<<4 ),
	        Key( MODKEY,                       XK_6,      &view,           1<<5 ),
	        Key( MODKEY|ControlMask,           XK_6,      &toggleview,     1<<5 ),
	        Key( MODKEY|ShiftMask,             XK_6,      &tag,            1<<5 ),
	        Key( MODKEY|ControlMask|ShiftMask, XK_6,      &toggletag,      1<<5 ),
	        Key( MODKEY,                       XK_7,      &view,           1<<6 ),
	        Key( MODKEY|ControlMask,           XK_7,      &toggleview,     1<<6 ),
	        Key( MODKEY|ShiftMask,             XK_7,      &tag,            1<<6 ),
	        Key( MODKEY|ControlMask|ShiftMask, XK_7,      &toggletag,      1<<6 ),
	        Key( MODKEY,                       XK_8,      &view,           1<<7 ),
	        Key( MODKEY|ControlMask,           XK_8,      &toggleview,     1<<7 ),
	        Key( MODKEY|ShiftMask,             XK_8,      &tag,            1<<7 ),
	        Key( MODKEY|ControlMask|ShiftMask, XK_8,      &toggletag,      1<<7 ),
	        Key( MODKEY,                       XK_9,      &view,           1<<8 ),
	        Key( MODKEY|ControlMask,           XK_9,      &toggleview,     1<<8 ),
	        Key( MODKEY|ShiftMask,             XK_9,      &tag,            1<<8 ),
	        Key( MODKEY|ControlMask|ShiftMask, XK_9,      &toggletag,      1<<8 )
	        //Key( MODKEY|ShiftMask,             XK_q,      &quit					)
	    ];
    }

    void addEvent(int keyMod, const(int) keySymbol, void delegate() dg)
    {
    	eventKeys[] = EventKey(keyMod, keySymbol, dg);	
    }	

    void addEvent(T)(int keyMod, const(int) keySymbol, void delegate() dg, T arg)
    {
    	eventKeys[] = EventKey(keyMod, keySymbol, dg, arg);	
    }

    void listen(XEvent *e)
    {
    	switch (e.type) {
    		case KeyPress:
				this.keypress(e);
    			break;
    		default: { }
    	}
    }

    void keypress(XEvent *e) 
    {
	    uint i;
	    KeySym keysym;
	    XKeyEvent *ev;

	    ev = &e.xkey;
	    keysym = XKeycodeToKeysym(AppDisplay.instance().dpy, cast(KeyCode)ev.keycode, 0);
	    foreach(ref const key; keys) {
	        if(keysym == key.keysym
	                && CLEANMASK(key.mod) == CLEANMASK(ev.state)
	                && key.func) {
	            key.func( &(key.arg) );
	        }
	    }
	}

    void grabkeys() 
    {
    	updatenumlockmask();
	    {
	        uint i, j;
	        uint[] modifiers = [ 0, LockMask, numlockmask, numlockmask|LockMask ];
	        KeyCode code;

	        XUngrabKey(AppDisplay.instance().dpy, AnyKey, AnyModifier, rootWin);
	        foreach(ref const key; keys) {
	            code = XKeysymToKeycode(AppDisplay.instance().dpy, key.keysym);
	            if(code) {
	                foreach(ref const mod; modifiers) {
	                    XGrabKey(AppDisplay.instance().dpy, code, key.mod | mod, rootWin,
	                             True, GrabModeAsync, GrabModeAsync);
	                }
	            }
	        }
	    }
	}

    Key[] getKeys()
	{
		return this.keys;
	}
}