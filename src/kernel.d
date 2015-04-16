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

import cboxapp;
import types;
import utils;
import legacy;
import old;
import config;
import events.handler;
import events.keyboard;
import events.mouse;
import window;
import helper.x11;
import gui.cursor;
import gui.font;
import gui.bar;
import theme.layout;
import theme.manager;
import monitor;

static Drw *drw;
static Fnt *fnt;
static ClrScheme[SchemeLast] scheme;
static Key[] keys;
/* button definitions */
/* click can be ClkLtSymbol, ClkStatusText, ClkWinTitle, ClkClientWin, or ClkRootWin */
static Button[] buttons;
static void function(XEvent*)[LASTEvent] handler;
static immutable string VERSION = "0.1 Cobox";


void arrange(Monitor *m) 
{
    if(m) {
        windowManager.showhide(m.stack);
    } else foreach(m; mons.range) {
        windowManager.showhide(m.stack);
    }
    if(m) {
        arrangemon(m);
        restack(m);
    } else foreach(m; mons.range) {
        arrangemon(m);
    }
}

void arrangemon(Monitor *m) {
    
    m.ltsymbol = m.lt[m.sellt].symbol;

    if(m.lt[m.sellt].arrange)
        m.lt[m.sellt].arrange(m);
}

void attach(Client *c) {
    
    c.next = c.mon.clients;
    c.mon.clients = c;
}

void attachstack(Client *c) {
    
    c.snext = c.mon.stack;
    c.mon.stack = c;
}

long getstate(Window w) 
{
    int format;
    long result = -1;
    ubyte *p = null;
    ulong n, extra;
    Atom realVal;

    if(XGetWindowProperty(AppDisplay.instance().dpy, w, wmatom[WMState], 0L, 2L, false, wmatom[WMState],
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

void updatetitle(Client *c) 
{
    if(!X11Helper.gettextprop(c.win, netatom[NetWMName], c.name)) {
        X11Helper.gettextprop(c.win, XA_WM_NAME, c.name);
    }

    if(c.name.length == 0) { /* hack to mark broken clients */
        c.name = broken;
    }
}

    void applyrules(Client *c) 
    {
        XClassHint ch = { null, null };
        /* rule matching */
        c.isfloating = false;
        c.tags = 0;
        XGetClassHint(AppDisplay.instance().dpy, c.win, &ch);
        immutable auto klass    = ch.res_class ? ch.res_class.to!string : broken;
        immutable auto instance = ch.res_name  ? ch.res_name.to!string : broken;
        foreach(immutable r; rules) {
            if( (r.title.length==0 || r.title.indexOf(c.name) >= 0) &&
                    (r.klass.length==0 || r.klass.indexOf(klass) >= 0) &&
                    (r.instance.length==0 || r.instance.indexOf(instance) >= 0)) {
                c.isfloating = r.isfloating;
                c.tags |= r.tags;

                auto m = mons.range.find!(mon => mon.num == r.monitor).front;
                if(m) {
                    c.mon = m;
                }
            }
        }
        if(ch.res_class)
            XFree(ch.res_class);
        if(ch.res_name)
            XFree(ch.res_name);
        c.tags = c.tags & TAGMASK ? c.tags & TAGMASK : c.mon.tagset[c.mon.seltags];
    }

    

void quit(const Arg *arg) 
{
    AppDisplay.instance().running = false;
}

EventHandler eventManager;
KeyboardEvents keyboardEventHandler;
MouseEvents mouseEventHandler;
WindowManager windowManager;

static Atom[WMLast] wmatom;
static Atom[NetLast] netatom;

class Kernel
{

    this()
    {
        keyboardEventHandler = new KeyboardEvents();

        mouseEventHandler = new MouseEvents();
        eventManager = new EventHandler(keyboardEventHandler, mouseEventHandler);
        windowManager = new WindowManager();

        wmatom = windowManager.getAllAtoms("WMLast");
        netatom = windowManager.getAllAtoms("NetLast");
    }

    void setup() 
    {
        XSetWindowAttributes wa;

        /* clean up any zombies immediately */
        sigchld(0);

        /* init screen */
        screen = DefaultScreen(AppDisplay.instance().dpy);
        rootWin = RootWindow(AppDisplay.instance().dpy, screen);

        fnt = new Fnt(AppDisplay.instance().dpy, font);
        sw = DisplayWidth(AppDisplay.instance().dpy, screen);
        sh = DisplayHeight(AppDisplay.instance().dpy, screen);
        bh = fnt.h + 2;

        drw = new Drw(AppDisplay.instance().dpy, screen, rootWin, sw, sh);
        drw.setfont(fnt);
        updategeom();

        /* init cursors */
        cursor[CurNormal] = new Cur(drw.dpy, CursorFont.XC_left_ptr);
        cursor[CurResize] = new Cur(drw.dpy, CursorFont.XC_sizing);
        cursor[CurMove] = new Cur(drw.dpy, CursorFont.XC_fleur);

        /* init appearance */
        scheme[SchemeNorm].border = new Clr(drw, normbordercolor);
        scheme[SchemeNorm].bg = new Clr(drw, normbgcolor);
        scheme[SchemeNorm].fg = new Clr(drw, normfgcolor);
        scheme[SchemeSel].border = new Clr(drw, selbordercolor);
        scheme[SchemeSel].bg = new Clr(drw, selbgcolor);
        scheme[SchemeSel].fg = new Clr(drw, selfgcolor);

        /* init bars */
        updatebars();
        updatestatus();

        /* EWMH support per view */
        XChangeProperty(
            AppDisplay.instance().dpy, 
            rootWin, 
            windowManager.getAtom("NetLast",NetSupported), 
            XA_ATOM, 32,
            PropModeReplace, 
            cast(ubyte*) windowManager.getAllAtoms("NetLast"), 
            NetLast
        );

        XDeleteProperty(
            AppDisplay.instance().dpy, 
            rootWin, 
            windowManager.getAtom("NetLast", NetClientList)
        );

        /* select for events */
        wa.cursor = cursor[CurNormal].cursor;
        wa.event_mask = SubstructureRedirectMask|SubstructureNotifyMask|ButtonPressMask|PointerMotionMask
                        |EnterWindowMask|LeaveWindowMask|StructureNotifyMask|PropertyChangeMask;

        XChangeWindowAttributes(AppDisplay.instance().dpy, rootWin, CWEventMask|CWCursor, &wa);
        XSelectInput(AppDisplay.instance().dpy, rootWin, wa.event_mask);
        keyboardEventHandler.grabkeys();

        focus(null);
    }

    void checkotherwm() 
    {
        xerrorxlib = XSetErrorHandler(&xerrorstart);
        /* this causes an error if some other window manager is running */
        XSelectInput(AppDisplay.instance().dpy, DefaultRootWindow(AppDisplay.instance().dpy), SubstructureRedirectMask);
        XSync(AppDisplay.instance().dpy, false);
        XSetErrorHandler(&xerror);
        XSync(AppDisplay.instance().dpy, false);
    }

    void scan() 
    {
        uint i, num;
        Window d1, d2;
        Window* wins = null;
        XWindowAttributes wa;

        if(XQueryTree(AppDisplay.instance().dpy, rootWin, &d1, &d2, &wins, &num)) {
            for(i = 0; i < num; i++) {
                if(!XGetWindowAttributes(AppDisplay.instance().dpy, wins[i], &wa)
                        || wa.override_redirect || XGetTransientForHint(AppDisplay.instance().dpy, wins[i], &d1))
                    continue;
                if(wa.map_state == IsViewable || getstate(wins[i]) == IconicState)
                    windowManager.manage(wins[i], &wa);
            }
            for(i = 0; i < num; i++) { /* now the transients */
                if(!XGetWindowAttributes(AppDisplay.instance().dpy, wins[i], &wa))
                    continue;
                if(XGetTransientForHint(AppDisplay.instance().dpy, wins[i], &d1)
                        && (wa.map_state == IsViewable || getstate(wins[i]) == IconicState))
                    windowManager.manage(wins[i], &wa);
            }
            if(wins)
                XFree(wins);
        }
    }

    void run() 
    {
        extern(C) __gshared XEvent ev;

        /* main event loop */
        XSync(AppDisplay.instance().dpy, false);
        while(AppDisplay.instance().running && !XNextEvent(AppDisplay.instance().dpy, &ev)) {
            eventManager.listen(&ev);
        }
    }

    int boot()
    {
        keys = keyboardEventHandler.getKeys();
        buttons = mouseEventHandler.getButtons();

        this.checkotherwm();
        this.setup();    
        this.scan();
        this.run();
        this.close();

        return 0;
    }

    void cleanup() 
    {
        auto a = Arg(-1);
        Layout foo = { "", null };

        view(&a);
        selmon.lt[selmon.sellt] = &foo;
        foreach(m; mons.range) {
            while(m.stack) {
                unmanage(m.stack, false);
            }
        }
        XUngrabKey(AppDisplay.instance().dpy, AnyKey, AnyModifier, rootWin);
        while(mons) {
            cleanupmon(mons);
        }
        Cur.free(cursor[CurNormal]);
        Cur.free(cursor[CurResize]);
        Cur.free(cursor[CurMove]);
        Fnt.free(AppDisplay.instance().dpy, fnt);
        Clr.free(scheme[SchemeNorm].border);
        Clr.free(scheme[SchemeNorm].bg);
        Clr.free(scheme[SchemeNorm].fg);
        Clr.free(scheme[SchemeSel].border);
        Clr.free(scheme[SchemeSel].bg);
        Clr.free(scheme[SchemeSel].fg);
        Drw.free(drw);
        XSync(AppDisplay.instance().dpy, false);
        XSetInputFocus(AppDisplay.instance().dpy, PointerRoot, RevertToPointerRoot, CurrentTime);
        XDeleteProperty(AppDisplay.instance().dpy, rootWin, netatom[NetActiveWindow]);
    }

    void close()
    {
        this.cleanup();
        XCloseDisplay(AppDisplay.instance().dpy);
    }
}