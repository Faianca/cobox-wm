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
import old;

static uint numlockmask = 0;

static Drw *drw;
static Fnt *fnt;
static Cur*[CurLast] cursor;
static ClrScheme[SchemeLast] scheme;

static immutable Layout[] layouts = [
                                        /* symbol     arrange function */
{ symbol:"[]=",      arrange:&tile },    /* first entry is default */
{ symbol:"><>",      arrange:null },    /* no layout function means floating behavior */
{ symbol:"[M]",      arrange:&monocle },
                                    ];

/* key definitions */
enum MODKEY = Mod1Mask;

static immutable string normbordercolor = "#444444";
static immutable string normbgcolor     = "#222222";
static immutable string normfgcolor     = "#bbbbbb";
static immutable string selbordercolor  = "#550077";
static immutable string selbgcolor      = "#550077";
static immutable string selfgcolor      = "#eeeeee";
static immutable uint borderpx  = 1;        /* border pixel of windows */
static immutable uint snap      = 32;       /* snap pixel */
static immutable bool showbar           = true;     /* false means no bar */
static immutable bool topbar            = true;     /* false means bottom bar */

static immutable string font            = "-*-terminus-medium-r-*-*-16-*-*-*-*-*-*-*";

/* commands */
static char[2] dmenumon = "0"; /* component of dmenucmd, manipulated in spawn() */
static immutable string[] dmenucmd = [ "dmenu_run", "-fn", font, "-nb", normbgcolor, "-nf", normfgcolor, "-sb", selbgcolor, "-sf", selfgcolor];
static immutable string[] termcmd = ["uxterm"];

static Key[] keys;


static this() {

    keys = [
        Key( MODKEY,                       XK_p,      &spawn,         dmenucmd ), // dmenucmd
        Key( MODKEY|ShiftMask,             XK_Return, &spawn,          termcmd ), // termcmd
        Key( MODKEY,                       XK_b,      &togglebar       ),
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
        Key( MODKEY|ControlMask|ShiftMask, XK_9,      &toggletag,      1<<8 ),
        Key( MODKEY|ShiftMask,             XK_q,      &quit                 )
    ];

    buttons = [
        /* click                event mask      button          function        argument */
        Button( ClkLtSymbol,          0,              Button1,        &setlayout ),
        Button( ClkLtSymbol,          0,              Button3,        &setlayout,      &layouts[2] ),
        Button( ClkWinTitle,          0,              Button2,        &zoom ),
        Button( ClkStatusText,        0,              Button2,        &spawn,          termcmd ), // &termcmd
        Button( ClkClientWin,         MODKEY,         Button1,        &movemouse ),
        Button( ClkClientWin,         MODKEY,         Button2,        &togglefloating ),
        Button( ClkClientWin,         MODKEY,         Button3,        &resizemouse ),
        Button( ClkTagBar,            0,              Button1,        &view ),
        Button( ClkTagBar,            0,              Button3,        &toggleview ),
        Button( ClkTagBar,            MODKEY,         Button1,        &tag ),
        Button( ClkTagBar,            MODKEY,         Button3,        &toggletag )
    ];



    handler[ButtonPress] = &buttonpress;
    handler[ClientMessage] = &clientmessage;
    handler[ConfigureRequest] = &configurerequest;
    handler[ConfigureNotify] = &configurenotify;
    handler[DestroyNotify] = &destroynotify;
    handler[EnterNotify] = &enternotify;
    handler[Expose] = &expose;
    handler[FocusIn] = &focusin;
    handler[KeyPress] = &keypress;
    handler[MappingNotify] = &mappingnotify;
    handler[MapRequest] = &maprequest;
    handler[MotionNotify] = &motionnotify;
    handler[PropertyNotify] = &propertynotify;
    handler[UnmapNotify] = &unmapnotify;

    /*extern(C) void sigsegvHandler(int i) nothrow @nogc @system {
      printf("\n\n\n>>>> sigsegv <<<<\n\n\n");
      exit(EXIT_FAILURE);
      }
      signal(SIGSEGV, &sigsegvHandler);*/
}
void grabkeys() {
    
    updatenumlockmask();
    {
        uint i, j;
        uint[] modifiers = [ 0, LockMask, numlockmask, numlockmask|LockMask ];
        KeyCode code;

        XUngrabKey(dpy, AnyKey, AnyModifier, rootWin);
        foreach(ref const key; keys) {
            code = XKeysymToKeycode(dpy, key.keysym);
            if(code) {
                foreach(ref const mod; modifiers) {
                    XGrabKey(dpy, code, key.mod | mod, rootWin,
                             True, GrabModeAsync, GrabModeAsync);
                }
            }
        }
    }
}


void keypress(XEvent *e) {
    
    uint i;
    KeySym keysym;
    XKeyEvent *ev;

    ev = &e.xkey;
    keysym = XKeycodeToKeysym(dpy, cast(KeyCode)ev.keycode, 0);
    foreach(ref const key; keys) {
        if(keysym == key.keysym
                && CLEANMASK(key.mod) == CLEANMASK(ev.state)
                && key.func) {
            key.func( &(key.arg) );
        }
    }
}

immutable string broken = "broken";
static immutable string VERSION = "0.1 Cobox";
static bool running = true;
static void function(XEvent*)[LASTEvent] handler;
immutable string[] tags = [ "1", "2", "3", "4", "5", "6", "7", "8", "9" ];

static immutable Rule[] rules = [
/* xprop(1):
 *  WM_CLASS(STRING) = instance, klass
 *  WM_NAME(STRING) = title
 */
/* klass      instance    title       tags mask     isfloating   monitor */
{ "Gimp",     null,       null,       0,            true,        -1 },
{ "Firefox",  null,       null,       1 << 8,       false,       -1 },
                                ];
                                
void checkotherwm() 
{
	xerrorxlib = XSetErrorHandler(&xerrorstart);
	/* this causes an error if some other window manager is running */
	XSelectInput(dpy, DefaultRootWindow(dpy), SubstructureRedirectMask);
	XSync(dpy, false);
	XSetErrorHandler(&xerror);
	XSync(dpy, false);
}

void applyrules(Client *c) {
    

    XClassHint ch = { null, null };
    /* rule matching */
    c.isfloating = false;
    c.tags = 0;
    XGetClassHint(dpy, c.win, &ch);
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

bool applysizehints(Client *c, ref int x, ref int y, ref int w, ref int h, bool interact) {
    
    bool baseismin;
    Monitor *m = c.mon;

    /* set minimum possible */
    w = max(1, w);
    h = max(1, h);
    if(interact) {
        if(x > sw)
            x = sw - WIDTH(c);
        if(y > sh)
            y = sh - HEIGHT(c);
        if(x + w + 2 * c.bw < 0)
            x = 0;
        if(y + h + 2 * c.bw < 0)
            y = 0;
    } else {
        if(x >= m.wx + m.ww)
            x = m.wx + m.ww - WIDTH(c);
        if(y >= m.wy + m.wh)
            y = m.wy + m.wh - HEIGHT(c);
        if(x + w + 2 * c.bw <= m.wx)
            x = m.wx;
        if(y + h + 2 * c.bw <= m.wy)
            y = m.wy;
    }
    if(h < bh)
        h = bh;
    if(w < bh)
        w = bh;
    if(resizehints || c.isfloating || !c.mon.lt[c.mon.sellt].arrange) {
        /* see last two sentences in ICCCM 4.1.2.3 */
        baseismin = c.basew == c.minw && c.baseh == c.minh;
        if(!baseismin) { /* temporarily remove base dimensions */
            w -= c.basew;
            h -= c.baseh;
        }
import std.math :
        nearbyint;
        /* adjust for aspect limits */
        if(c.mina > 0 && c.maxa > 0) {
            if(c.maxa < float(w) / h)
                w = cast(int)(h * c.maxa + 0.5);
            else if(c.mina < float(h) / w)
                h = cast(int)(w * c.mina + 0.5);
        }
        if(baseismin) { /* increment calculation requires this */
            w -= c.basew;
            h -= c.baseh;
        }
        /* adjust for increment value */
        if(c.incw)
            w -= w % c.incw;
        if(c.inch)
            h -= h % c.inch;
        /* restore base dimensions */
        w = max(w + c.basew, c.minw);
        h = max(h + c.baseh, c.minh);
        if(c.maxw)
            w = min(w, c.maxw);
        if(c.maxh)
            h = min(h, c.maxh);
    }
    return x != c.x || y != c.y || w != c.w || h != c.h;
}


void arrange(Monitor *m) {
    
    if(m) {
        showhide(m.stack);
    } else foreach(m; mons.range) {
        showhide(m.stack);
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

void buttonpress(XEvent *e) {
    
    uint i, x, click;
    auto arg = Arg(0);
    Client *c;
    Monitor *m;
    XButtonPressedEvent *ev = &e.xbutton;

    click = ClkRootWin;
    /* focus monitor if necessary */
    m = wintomon(ev.window);
    if( (m !is null) && (m != selmon) ) {
        unfocus(selmon.sel, true);
        selmon = m;
        focus(null);
    }
    if(ev.window == selmon.barwin) {
        i = x = 0;
        do {
            x += TEXTW(tags[i]);
        } while(ev.x >= x && ++i < LENGTH(tags));
        if(i < LENGTH(tags)) {
            click = ClkTagBar;
            arg.ui = 1 << i;
        } else if(ev.x < x + blw)
            click = ClkLtSymbol;
        else if(ev.x > selmon.ww - TEXTW(stext))
            click = ClkStatusText;
        else
            click = ClkWinTitle;
    } else {
        c = wintoclient(ev.window);
        if(c !is null) {
            focus(c);
            click = ClkClientWin;
        }
    }
    foreach(ref const but; buttons) {
        if(click == but.click &&
                but.func !is null &&
                but.button == ev.button &&
                CLEANMASK(but.mask) == CLEANMASK(ev.state)) {
            but.func(click == ClkTagBar && but.arg.i == 0 ? &arg : &but.arg);
        }
    }
}


void setup() {
    
    XSetWindowAttributes wa;

    /* clean up any zombies immediately */
    sigchld(0);

    /* init screen */
    screen = DefaultScreen(dpy);
    rootWin = RootWindow(dpy, screen);
    fnt = new Fnt(dpy, font);
    sw = DisplayWidth(dpy, screen);
    sh = DisplayHeight(dpy, screen);
    bh = fnt.h + 2;
    drw = new Drw(dpy, screen, rootWin, sw, sh);
    drw.setfont(fnt);
    updategeom();
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
    XChangeProperty(dpy, rootWin, netatom[NetSupported], XA_ATOM, 32,
                    PropModeReplace, cast(ubyte*) netatom, NetLast);
    XDeleteProperty(dpy, rootWin, netatom[NetClientList]);
    /* select for events */
    wa.cursor = cursor[CurNormal].cursor;
    wa.event_mask = SubstructureRedirectMask|SubstructureNotifyMask|ButtonPressMask|PointerMotionMask
                    |EnterWindowMask|LeaveWindowMask|StructureNotifyMask|PropertyChangeMask;
    XChangeWindowAttributes(dpy, rootWin, CWEventMask|CWCursor, &wa);
    XSelectInput(dpy, rootWin, wa.event_mask);
    grabkeys();
    focus(null);
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

        XDefineCursor(dpy, m.barwin, cursor[CurNormal].cursor);
        XMapRaised(dpy, m.barwin);
    }
}

bool gettextprop(Window w, Atom atom, out string text) {
    
    static immutable size_t MAX_TEXT_LENGTH = 256;
    XTextProperty name;
    XGetTextProperty(dpy, w, &name, atom);
    if(!name.nitems)
        return false;
    if(name.encoding == XA_STRING) {
        text = (cast(char*)(name.value)).fromStringz.to!string;
    } else {
        char **list = null;
        int n;
        if(XmbTextPropertyToTextList(dpy, &name, &list, &n) >= XErrorCode.Success &&
                n > 0 &&
                *list) {
            text = (*list).fromStringz.to!string;
            XFreeStringList(list);
        }
    }
    XFree(name.value);
    return true;
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

void updatetitle(Client *c) {
    
    if(!gettextprop(c.win, netatom[NetWMName], c.name)) {
        gettextprop(c.win, XA_WM_NAME, c.name);
    }
    if(c.name.length == 0) { /* hack to mark broken clients */
        c.name = broken;
    }
}

void manage(Window w, XWindowAttributes *wa) {
    
    Client *c, t = null;
    Window trans = None;
    XWindowChanges wc;

    c = new Client();
    if(c is null) {
        die("fatal: could not malloc() %u bytes\n", Client.sizeof);
    }
    c.win = w;
    updatetitle(c);

    c.mon = null;
    if(XGetTransientForHint(dpy, w, &trans)) {
        t = wintoclient(trans);
        if(t) {
            c.mon = t.mon;
            c.tags = t.tags;
        }
    } 
    if(!c.mon) {
        c.mon = selmon;
        applyrules(c);
    }
    /* geometry */
    c.x = c.oldx = wa.x;
    c.y = c.oldy = wa.y;
    c.w = c.oldw = wa.width;
    c.h = c.oldh = wa.height;
    c.oldbw = wa.border_width;

    if(c.x + WIDTH(c) > c.mon.mx + c.mon.mw)
        c.x = c.mon.mx + c.mon.mw - WIDTH(c);
    if(c.y + HEIGHT(c) > c.mon.my + c.mon.mh)
        c.y = c.mon.my + c.mon.mh - HEIGHT(c);
    c.x = max(c.x, c.mon.mx);
    /* only fix client y-offset, if the client center might cover the bar */
    c.y = max(c.y, ((c.mon.by == c.mon.my) && (c.x + (c.w / 2) >= c.mon.wx)
                    && (c.x + (c.w / 2) < c.mon.wx + c.mon.ww)) ? bh : c.mon.my);
    c.bw = borderpx;

    wc.border_width = c.bw;
    XConfigureWindow(dpy, w, CWBorderWidth, &wc);
    XSetWindowBorder(dpy, w, scheme[SchemeNorm].border.rgb);
    configure(c); /* propagates border_width, if size doesn't change */
    updatewindowtype(c);
    updatesizehints(c);
    updatewmhints(c);
    XSelectInput(dpy, w, EnterWindowMask|FocusChangeMask|PropertyChangeMask|StructureNotifyMask);
    grabbuttons(c, false);
    if(!c.isfloating)
        c.isfloating = c.oldstate = trans != None || c.isfixed;
    if(c.isfloating)
        XRaiseWindow(dpy, c.win);
    attach(c);
    attachstack(c);
    XChangeProperty(dpy, rootWin, netatom[NetClientList], XA_WINDOW, 32, PropModeAppend,
                    cast(ubyte*)(&(c.win)), 1);
    XMoveResizeWindow(dpy, c.win, c.x + 2 * sw, c.y, c.w, c.h); /* some windows require this */
    setclientstate(c, NormalState);
    if (c.mon == selmon)
        unfocus(selmon.sel, false);
    c.mon.sel = c;
    arrange(c.mon);
    XMapWindow(dpy, c.win);
    focus(null);
}

void scan() {
    
    uint i, num;
    Window d1, d2;
    Window* wins = null;
    XWindowAttributes wa;

    if(XQueryTree(dpy, rootWin, &d1, &d2, &wins, &num)) {
        for(i = 0; i < num; i++) {
            if(!XGetWindowAttributes(dpy, wins[i], &wa)
                    || wa.override_redirect || XGetTransientForHint(dpy, wins[i], &d1))
                continue;
            if(wa.map_state == IsViewable || getstate(wins[i]) == IconicState)
                manage(wins[i], &wa);
        }
        for(i = 0; i < num; i++) { /* now the transients */
            if(!XGetWindowAttributes(dpy, wins[i], &wa))
                continue;
            if(XGetTransientForHint(dpy, wins[i], &d1)
                    && (wa.map_state == IsViewable || getstate(wins[i]) == IconicState))
                manage(wins[i], &wa);
        }
        if(wins)
            XFree(wins);
    }
}

void run() {
    
    extern(C) __gshared XEvent ev;
    /* main event loop */
    XSync(dpy, false);
    while(running && !XNextEvent(dpy, &ev)) {
        writeln(ev.type);
        if(handler[ev.type]) {
            handler[ev.type](&ev); /* call handler */
        }
    }
}

int init()
{
	dpy = XOpenDisplay(null);

	if(dpy is null) {
		stderr.writeln("cbox: cannot open display");
		return -1;
	}

    checkotherwm();
    setup();
    scan();
    run();
    cleanup();
	XCloseDisplay(dpy);

	return 0;
}
