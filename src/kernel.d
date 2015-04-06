module kernel;

import std.c.locale;
import std.c.string;
import std.c.stdlib;

import std.stdio;
import std.string;
import std.algorithm;
import std.conv;
import std.process;
import std.traits;

import core.sys.posix.signal;
import core.sys.posix.sys.wait;
import core.sys.posix.unistd;
import core.memory;

import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;

import types;
import utils;
import legacy;

static immutable string VERSION = "0.1 Cobox";

void checkotherwm() 
{
	xerrorxlib = XSetErrorHandler(&xerrorstart);
	/* this causes an error if some other window manager is running */
	XSelectInput(dpy, DefaultRootWindow(dpy), SubstructureRedirectMask);
	XSync(dpy, false);
	XSetErrorHandler(&xerror);
	XSync(dpy, false);
}

void setup() 
{
    
    XSetWindowAttributes wa;

    /* clean up any zombies immediately */
    sigchld(0);

    /* init screen */
    screen = DefaultScreen(dpy);
    rootWin = RootWindow(dpy, screen);

    //fnt = new Fnt(dpy, font);
    sw = DisplayWidth(dpy, screen);
    sh = DisplayHeight(dpy, screen);
    //bh = fnt.h + 2;
    //drw = new Drw(dpy, screen, rootWin, sw, sh);
    //drw.setfont(fnt);
    //updategeom();


    /* init atoms */
    wmatom[WMProtocols] = XInternAtom(dpy, cast(char*)("WM_PROTOCOLS".toStringz), false);
    wmatom[WMDelete] = XInternAtom(dpy, cast(char*)("WM_DELETE_WINDOW".toStringz), false);
    wmatom[WMState] = XInternAtom(dpy, cast(char*)("WM_STATE".toStringz), false);
    wmatom[WMTakeFocus] = XInternAtom(dpy, cast(char*)("WM_TAKE_FOCUS".toStringz), false);
    netatom[NetActiveWindow] = XInternAtom(dpy, cast(char*)("_NET_ACTIVE_WINDOW".toStringz), false);
    netatom[NetSupported] = XInternAtom(dpy, cast(char*)("_NET_SUPPORTED".toStringz), false);
    netatom[NetWMName] = XInternAtom(dpy, cast(char*)("_NET_WM_NAME".toStringz), false);
    netatom[NetWMState] = XInternAtom(dpy, cast(char*)("_NET_WM_STATE".toStringz), false);
    netatom[NetWMFullscreen] = XInternAtom(dpy, cast(char*)("_NET_WM_STATE_FULLSCREEN".toStringz), false);
    netatom[NetWMWindowType] = XInternAtom(dpy, cast(char*)("_NET_WM_WINDOW_TYPE".toStringz), false);
    netatom[NetWMWindowTypeDialog] = XInternAtom(dpy, cast(char*)("_NET_WM_WINDOW_TYPE_DIALOG".toStringz), false);
    netatom[NetClientList] = XInternAtom(dpy, cast(char*)("_NET_CLIENT_LIST".toStringz), false);
    
    /* init cursors */
    //cursor[CurNormal] = new Cur(drw.dpy, CursorFont.XC_left_ptr);
    //cursor[CurResize] = new Cur(drw.dpy, CursorFont.XC_sizing);
    //cursor[CurMove] = new Cur(drw.dpy, CursorFont.XC_fleur);

    /* init appearance */
    //scheme[SchemeNorm].border = new Clr(drw, normbordercolor);
    //scheme[SchemeNorm].bg = new Clr(drw, normbgcolor);
    //scheme[SchemeNorm].fg = new Clr(drw, normfgcolor);
    //scheme[SchemeSel].border = new Clr(drw, selbordercolor);
    //scheme[SchemeSel].bg = new Clr(drw, selbgcolor);
    //scheme[SchemeSel].fg = new Clr(drw, selfgcolor);

    /* init bars */
    //updatebars();
    //updatestatus();
    /* EWMH support per view */
    //XChangeProperty(dpy, rootWin, netatom[NetSupported], XA_ATOM, 32,
     //               PropModeReplace, cast(ubyte*) netatom, NetLast);
    //XDeleteProperty(dpy, rootWin, netatom[NetClientList]);
    /* select for events */
    //wa.cursor = cursor[CurNormal].cursor;
    //wa.event_mask = SubstructureRedirectMask|SubstructureNotifyMask|ButtonPressMask|PointerMotionMask
    //                |EnterWindowMask|LeaveWindowMask|StructureNotifyMask|PropertyChangeMask;
    //XChangeWindowAttributes(dpy, rootWin, CWEventMask|CWCursor, &wa);
    //XSelectInput(dpy, rootWin, wa.event_mask);
    //grabkeys();
    //focus(null);
}


void updatebars()
{
    XSetWindowAttributes wa = {
		override_redirect : True,
		background_pixmap : ParentRelative,
		event_mask :  ButtonPressMask|ExposureMask
    };

    foreach(m; mons.range) {
        if (m.barwin)
            continue;

        m.barwin = XCreateWindow(dpy, rootWin, m.wx, m.by, m.ww, bh, 0, DefaultDepth(dpy, screen),
                                 CopyFromParent, DefaultVisual(dpy, screen),
                                 CWOverrideRedirect|CWBackPixmap|CWEventMask, &wa);

        //XDefineCursor(dpy, m.barwin, cursor[CurNormal].cursor);
        XMapRaised(dpy, m.barwin);
    }
}

long getstate(Window w) {
    int format;
    long result = -1;
    ubyte *p = null;
    ulong n, extra;
    Atom realVal;

    if(XGetWindowProperty(dpy, w, wmatom[WMState], 0L, 2L, false, wmatom[WMState],
       &realVal, &format, &n, &extra, cast(ubyte **)&p) != XErrorCode.Success) {
       	writeln("here");
        return -1;
    }
    if(n != 0) {
        result = *p;
    }
    XFree(p);
    return result;
}

void scan() 
{
    uint i, num;
    Window d1, d2;
    Window* wins = null;
    XWindowAttributes wa;

    if(XQueryTree(dpy, rootWin, &d1, &d2, &wins, &num)) {
        for(i = 0; i < num; i++) {
            if(!XGetWindowAttributes(dpy, wins[i], &wa)
               || wa.override_redirect || XGetTransientForHint(dpy, wins[i], &d1)
            ) continue;

            if(wa.map_state == IsViewable || getstate(wins[i]) == IconicState)
                writeln(wins[i]);
                //manage(wins[i], &wa);
        }

        for(i = 0; i < num; i++) { /* now the transients */
            if(!XGetWindowAttributes(dpy, wins[i], &wa))
                continue;
            if(XGetTransientForHint(dpy, wins[i], &d1)
                    && (wa.map_state == IsViewable || getstate(wins[i]) == IconicState))
                writeln(wins[i]);
                //manage(wins[i], &wa);
        }

        if(wins)
            XFree(wins);
    }
}

int init()
{
	dpy = XOpenDisplay(null);

	if(dpy is null) {
		stderr.writeln("cbox: cannot open display");
		return -1;
	}

 	//checkotherwm();	
 	scan();
	XCloseDisplay(dpy);

	return 0;
}
