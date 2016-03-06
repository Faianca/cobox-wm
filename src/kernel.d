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
import helper.process;

import core.sys.posix.signal;
import core.sys.posix.sys.wait;
import core.sys.posix.unistd;
import core.memory;

import x11.X;
import x11.Xlib;
import x11.keysymdef;
import x11.Xutil;
import x11.Xatom;

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
static Key[] keys;

/* button definitions */
/* click can be ClkLtSymbol, ClkStatusText, ClkWinTitle, ClkClientWin, or ClkRootWin */
static Button[] buttons;
static void function(XEvent*)[LASTEvent] handler;


EventHandler eventManager;
KeyboardEvents keyboardEventHandler;
MouseEvents mouseEventHandler;
WindowManager windowManager;

static Atom[WMLast] wmatom;
static Atom[NetLast] netatom;

void quit(const Arg *arg)
{
    AppDisplay.instance().running = false;
}

class Kernel
{
    this()
    {
        keyboardEventHandler = new KeyboardEvents();
        keyboardEventHandler.addEvent(MODKEY|ShiftMask, XK_q, &quit);
        keyboardEventHandler.addEvent(MODKEY, XK_p, &spawn, dmenucmd);

        mouseEventHandler = new MouseEvents();
        eventManager = new EventHandler(keyboardEventHandler, mouseEventHandler);
        windowManager = new WindowManager();

        wmatom = windowManager.getAllAtoms("WMLast");
        netatom = windowManager.getAllAtoms("NetLast");
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

    void checkotherwm()
    {
        xerrorxlib = XSetErrorHandler(&xerrorstart);
        /* this causes an error if some other window manager is running */
        XSelectInput(AppDisplay.instance().dpy, DefaultRootWindow(AppDisplay.instance().dpy), SubstructureRedirectMask);
        XSync(AppDisplay.instance().dpy, false);
        XSetErrorHandler(&xerror);
        XSync(AppDisplay.instance().dpy, false);
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
                if(wa.map_state == IsViewable || this.getstate(wins[i]) == IconicState)
                    windowManager.manage(wins[i], &wa);
            }
            for(i = 0; i < num; i++) { /* now the transients */
                if(!XGetWindowAttributes(AppDisplay.instance().dpy, wins[i], &wa))
                    continue;
                if(XGetTransientForHint(AppDisplay.instance().dpy, wins[i], &d1)
                        && (wa.map_state == IsViewable || this.getstate(wins[i]) == IconicState))
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
        Clr.free(ThemeManager.instance().getScheme(SchemeNorm).border);
        Clr.free(ThemeManager.instance().getScheme(SchemeNorm).bg);
        Clr.free(ThemeManager.instance().getScheme(SchemeNorm).fg);
        Clr.free(ThemeManager.instance().getScheme(SchemeSel).border);
        Clr.free(ThemeManager.instance().getScheme(SchemeSel).bg);
        Clr.free(ThemeManager.instance().getScheme(SchemeSel).fg);


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

    /**
    * Get window State
    **/
    long getstate(Window w)
    {
        int format;
        long result = -1;
        ubyte *p = null;
        ulong n, extra;
        Atom realVal;

        if(XGetWindowProperty(AppDisplay.instance().dpy, w, wmatom[WMState], 0L, 2L, false, wmatom[WMState],
           &realVal, &format, &n, &extra, cast(ubyte **)&p) != XErrorCode.Success) {
            return -1;
        }

        if(n != 0) {
            result = *p;
        }

        XFree(p);
        return result;
    }

}
