module old;
import core.memory;

import core.sys.posix.signal;
import core.sys.posix.sys.wait;
import core.sys.posix.unistd;

import std.c.locale;
import std.c.string;
import std.c.stdlib;

import std.stdio;
import std.string;
import std.algorithm;
import std.conv;
import std.process;
import std.traits;

import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;

import types;
import kernel;
import legacy;
import utils;
import config;
import cboxapp;
import window;
import helper.x11;
import gui.cursor;
import gui.font;
import theme.layout;
import theme.manager;
import gui.bar;
import monitor;

void updatenumlockmask() 
{
    XModifierKeymap *modmap;

    numlockmask = 0;
    modmap = XGetModifierMapping(AppDisplay.instance().dpy);
    foreach_reverse(i; 0..7) {
        if(numlockmask == 0) {
            break;
        }
        foreach_reverse(j; 0..modmap.max_keypermod-1) {
            if(modmap.modifiermap[i * modmap.max_keypermod + j] ==
                    XKeysymToKeycode(AppDisplay.instance().dpy, XK_Num_Lock)) {
                numlockmask = (1 << i);
                break;
            }
        }
    }
    XFreeModifiermap(modmap);
}

void updateclientlist() 
{
    
    Client *c;
    Monitor *m;

    XDeleteProperty(AppDisplay.instance().dpy, rootWin, netatom[NetClientList]);
    for(m = mons; m; m = m.next)
        for(c = m.clients; c; c = c.next)
            XChangeProperty(AppDisplay.instance().dpy, rootWin, netatom[NetClientList],
                            XA_WINDOW, 32, PropModeAppend,
                            cast(ubyte *)&(c.win), 1);
}



bool getrootptr(int *x, int *y) 
{
    int di;
    uint dui;
    Window dummy;

    return XQueryPointer(AppDisplay.instance().dpy, rootWin, &dummy, &dummy, x, y, &di, &di, &dui) != 0;
}

void setfocus(Client *c) 
{
    
    if(!c.neverfocus) {
        XSetInputFocus(AppDisplay.instance().dpy, c.win, RevertToPointerRoot, CurrentTime);
        XChangeProperty(AppDisplay.instance().dpy, rootWin, netatom[NetActiveWindow],
                        XA_WINDOW, 32, PropModeReplace,
                        cast(ubyte *) &(c.win), 1);
    }
    sendevent(c, wmatom[WMTakeFocus]);
}


bool sendevent(Client *c, Atom proto) 
{
    int n;
    Atom *protocols;
    bool exists = false;
    XEvent ev;

    if(XGetWMProtocols(AppDisplay.instance().dpy, c.win, &protocols, &n)) {
        while(!exists && n--)
            exists = protocols[n] == proto;
        XFree(protocols);
    }
    if(exists) {
        ev.type = ClientMessage;
        ev.xclient.window = c.win;
        ev.xclient.message_type = wmatom[WMProtocols];
        ev.xclient.format = 32;
        ev.xclient.data.l[0] = proto;
        ev.xclient.data.l[1] = CurrentTime;
        XSendEvent(AppDisplay.instance().dpy, c.win, false, NoEventMask, &ev);
    }
    return exists;
}

Client* nexttiled(Client *c) 
{
    return c.range!"next".find!(a => !a.isfloating && ISVISIBLE(a)).front;
}

void pop(Client *c) 
{
    detach(c);
    attach(c);
    focus(c);
    arrange(c.mon);
}

void setfullscreen(Client *c, bool fullscreen) 
{
    if(fullscreen) {
        XChangeProperty(AppDisplay.instance().dpy, c.win, netatom[NetWMState], XA_ATOM, 32,
                        PropModeReplace, cast(ubyte*)&netatom[NetWMFullscreen], 1);
        c.isfullscreen = true;
        c.oldstate = c.isfloating;
        c.oldbw = c.bw;
        c.bw = 0;
        c.isfloating = true;
        resizeclient(c, c.mon.mx, c.mon.my, c.mon.mw, c.mon.mh);
        XRaiseWindow(AppDisplay.instance().dpy, c.win);
    } else {
        XChangeProperty(AppDisplay.instance().dpy, c.win, netatom[NetWMState], XA_ATOM, 32,
                        PropModeReplace, cast(ubyte*)0, 0);
        c.isfullscreen = false;
        c.isfloating = c.oldstate;
        c.bw = c.oldbw;
        c.x = c.oldx;
        c.y = c.oldy;
        c.w = c.oldw;
        c.h = c.oldh;
        resizeclient(c, c.x, c.y, c.w, c.h);
        arrange(c.mon);
    }
}

void resize(Client *c, int x, int y, int w, int h, bool interact) 
{
    if(applysizehints(c, x, y, w, h, interact))
        resizeclient(c, x, y, w, h);
}

void resizeclient(Client *c, int x, int y, int w, int h) 
{
    XWindowChanges wc;

    c.oldx = c.x;
    c.x = wc.x = x;
    c.oldy = c.y;
    c.y = wc.y = y;
    c.oldw = c.w;
    c.w = wc.width = w;
    c.oldh = c.h;
    c.h = wc.height = h;
    wc.border_width = c.bw;
    XConfigureWindow(AppDisplay.instance().dpy, c.win, CWX|CWY|CWWidth|CWHeight|CWBorderWidth, &wc);
    configure(c);
    XSync(AppDisplay.instance().dpy, false);
}

void sendmon(Client *c, Monitor *m) 
{
    if(c.mon == m)
        return;
    unfocus(c, true);
    detach(c);
    detachstack(c);
    c.mon = m;
    c.tags = m.tagset[m.seltags]; /* assign tags of target monitor */
    attach(c);
    attachstack(c);
    focus(null);
    arrange(null);
}


bool applysizehints(Client *c, ref int x, ref int y, ref int w, ref int h, bool interact) 
{
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

void clientmessage(XEvent *e) 
{
    XClientMessageEvent *cme = &e.xclient;
    Client *c = wintoclient(cme.window);

    if(!c)
        return;
    if(cme.message_type == netatom[NetWMState]) {
        if(cme.data.l[1] == netatom[NetWMFullscreen] || cme.data.l[2] == netatom[NetWMFullscreen]) {
            setfullscreen(c, (cme.data.l[0] == 1 /* _NET_WM_STATE_ADD    */
                              || (cme.data.l[0] == 2 /* _NET_WM_STATE_TOGGLE */ && !c.isfullscreen)));
        }
    } else if(cme.message_type == netatom[NetActiveWindow]) {
        if(!ISVISIBLE(c)) {
            c.mon.seltags ^= 1;
            c.mon.tagset[c.mon.seltags] = c.tags;
        }
        pop(c);
    }
}

void togglefloating(const Arg *arg) 
{
    if(!selmon.sel)
        return;
    if(selmon.sel.isfullscreen) /* no support for fullscreen windows */
        return;
    selmon.sel.isfloating = !selmon.sel.isfloating || selmon.sel.isfixed;
    if(selmon.sel.isfloating)
        resize(selmon.sel, selmon.sel.x, selmon.sel.y,
               selmon.sel.w, selmon.sel.h, false);
    arrange(selmon);
}

void tag(const Arg *arg) {
    
    if(selmon.sel && arg.ui & TAGMASK) {
        selmon.sel.tags = arg.ui & TAGMASK;
        focus(null);
        arrange(selmon);
    }
}

void tagmon(const Arg *arg) {
    
    if(!selmon.sel || !mons.next)
        return;
    sendmon(selmon.sel, dirtomon(arg.i));
}

void toggletag(const Arg *arg) {
    
    uint newtags;

    if(!selmon.sel)
        return;
    newtags = selmon.sel.tags ^ (arg.ui & TAGMASK);
    if(newtags) {
        selmon.sel.tags = newtags;
        focus(null);
        arrange(selmon);
    }
}

void toggleview(const Arg *arg) {
    
    uint newtagset = selmon.tagset[selmon.seltags] ^ (arg.ui & TAGMASK);

    if(newtagset) {
        selmon.tagset[selmon.seltags] = newtagset;
        focus(null);
        arrange(selmon);
    }
}


void spawn(const Arg *arg) {
    import std.variant;
    Variant v = arg.val;
    const(string[]) args = arg.s;
    if(args[0] == dmenucmd[0]) {
        dmenumon[0] =cast(char)('0' + selmon.num);
    }
    try {
        auto pid = spawnProcess(args);
    } catch {
        die("Failed to spawn '%s'", args);
    }
}

void zoom(const Arg *arg) {
    
    Client *c = selmon.sel;

    if(!selmon.lt[selmon.sellt].arrange ||
            (selmon.sel && selmon.sel.isfloating)) {
        return;
    }
    if(c == nexttiled(selmon.clients)) {
        if(c) {
            c = nexttiled(c.next);
        }
        if(!c) {
            return;
        }
    }
    pop(c);
}

void setlayout(const Arg *arg) 
{
    if(!arg || !arg.v || arg.v != selmon.lt[selmon.sellt])
        selmon.sellt ^= 1;
    if(arg && arg.v) {
        selmon.lt[selmon.sellt] = cast(Layout *)arg.v;
    }
    selmon.ltsymbol = selmon.lt[selmon.sellt].symbol;
    if(selmon.sel)
        arrange(selmon);
    else
        drawbar(selmon);
}

void view(const Arg *arg) {
    
    if((arg.ui & TAGMASK) == selmon.tagset[selmon.seltags]) {
        return;
    }
    selmon.seltags ^= 1; /* toggle sel tagset */
    if(arg.ui & TAGMASK) {
        selmon.tagset[selmon.seltags] = arg.ui & TAGMASK;
    }
    focus(null);
    arrange(selmon);
}

void killclient(const Arg *arg) {
    
    if(!selmon.sel)
        return;

    if(!sendevent(selmon.sel, wmatom[WMDelete])) {
        XGrabServer(AppDisplay.instance().dpy);
        XSetErrorHandler(&xerrordummy);
        XSetCloseDownMode(AppDisplay.instance().dpy, CloseDownMode.DestroyAll);
        XKillClient(AppDisplay.instance().dpy, selmon.sel.win);
        XSync(AppDisplay.instance().dpy, false);
        XSetErrorHandler(&xerror);
        XUngrabServer(AppDisplay.instance().dpy);
    }
}

void incnmaster(const Arg *arg) {
    
    selmon.nmaster = max(selmon.nmaster + arg.i, 0);
    arrange(selmon);
}

void setmfact(const Arg *arg) {
    
    float f;

    if(!arg || !selmon.lt[selmon.sellt].arrange)
        return;
    f = arg.f < 1.0 ? arg.f + selmon.mfact : arg.f - 1.0;
    if(f < 0.1 || f > 0.9)
        return;
    selmon.mfact = f;
    arrange(selmon);
}

void tile(Monitor *m) 
{
    uint i, n, h, mw, my, ty;
    Client *c;

    for(n = 0, c = nexttiled(m.clients); c; c = nexttiled(c.next), n++) {}
    if(n == 0) {
        return;
    }

    if(n > m.nmaster) {
        mw = cast(uint)(m.nmaster ? m.ww * m.mfact : 0);
    } else {
        mw = m.ww;
    }
    for(i = my = ty = 0, c = nexttiled(m.clients); c; c = nexttiled(c.next), i++) {
        if(i < m.nmaster) {
            h = (m.wh - my) / (min(n, m.nmaster) - i);
            resize(c, m.wx, m.wy + my, mw - (2*c.bw), h - (2*c.bw), false);
            my += HEIGHT(c);
        } else {
            h = (m.wh - ty) / (n - i);
            resize(c, m.wx + mw, m.wy + ty, m.ww - mw - (2*c.bw), h - (2*c.bw), false);
            ty += HEIGHT(c);
        }
    }
}

void monocle(Monitor *m) 
{
    uint n = 0;

    n = m.clients.range!"next".map!(a=>ISVISIBLE(a)).sum;
    if(n > 0) { /* override layout symbol */
        m.ltsymbol = format("[%d]", n);
    }
    for(auto c = nexttiled(m.clients); c; c = nexttiled(c.next)) {
        resize(c, m.wx, m.wy, m.ww - 2 * c.bw, m.wh - 2 * c.bw, false);
    }
}

bool updategeom() {
    
    bool dirty = false;

    Bool isXineramaActive = false;

    version(XINERAMA) {
        isXineramaActive = XineramaIsActive(AppDisplay.instance().dpy);
    }
    if(isXineramaActive) {
        version(XINERAMA) {
            import std.range;
            int nn;
            Client *c;
            XineramaScreenInfo *info = XineramaQueryScreens(AppDisplay.instance().dpy, &nn);
            auto n = mons.range.walkLength;
            XineramaScreenInfo[] unique = new XineramaScreenInfo[nn];
            if(!unique.length) {
                die("fatal: could not malloc() %u bytes\n", XineramaScreenInfo.sizeof * nn);
            }

            /* only consider unique geometries as separate screens */
            int j=0;
            foreach(i; 0..nn) {
                if(isuniquegeom(&unique[j], j, &info[i])) {
                    unique[j++] = info[i];
                }
            }
            XFree(info);
            nn = j;
            if(n <= nn) {
                foreach(i; 0..(nn-n)) { /* new monitors available */
                    auto m = mons.range.find!"a.next is null".front;
                    if(m) {
                        m.next = createmon();
                    } else {
                        mons = createmon();
                    }
                }
                foreach(i, m; iota(nn).lockstep(mons.range)) {
                    if(i >= n ||
                            (unique[i].x_org != m.mx || unique[i].y_org != m.my ||
                             unique[i].width != m.mw || unique[i].height != m.mh)) {
                        dirty = true;
                        m.num = i;
                        m.mx = m.wx = unique[i].x_org;
                        m.my = m.wy = unique[i].y_org;
                        m.mw = m.ww = unique[i].width;
                        m.mh = m.wh = unique[i].height;
                        updatebarpos(m);
                    }
                }
            } else { /* less monitors available nn < n */
                foreach(i; nn..n) {
                    auto m = mons.range.find!"a.next is null".front;
                    if(m) {
                        while(m.clients) {
                            dirty = true;
                            c = m.clients;
                            m.clients = c.next;
                            detachstack(c);
                            c.mon = mons;
                            attach(c);
                            attachstack(c);
                        }
                        if(m == selmon)
                            selmon = mons;
                        cleanupmon(m);
                    }
                }
            }
            unique = null;
        }
    } else {
        /* default monitor setup */
        if(!mons) {
            mons = createmon();
        }
        if(mons.mw != sw || mons.mh != sh) {
            dirty = true;
            mons.mw = mons.ww = sw;
            mons.mh = mons.wh = sh;
            updatebarpos(mons);
        }
    }
    if(dirty) {
        selmon = mons;
        selmon = wintomon(rootWin);
    }
    return dirty;
}

void updatewmhints(Client *c) {
    
    XWMHints *wmh;
    wmh = XGetWMHints(AppDisplay.instance().dpy, c.win);
    if(wmh) {
        if(c == selmon.sel && wmh.flags & XUrgencyHint) {
            wmh.flags &= ~XUrgencyHint;
            XSetWMHints(AppDisplay.instance().dpy, c.win, wmh);
        } else
            c.isurgent = (wmh.flags & XUrgencyHint) ? true : false;
        if(wmh.flags & InputHint)
            c.neverfocus = !wmh.input;
        else
            c.neverfocus = false;
        XFree(wmh);
    }
}

void setclientstate(Client *c, long state) {
    
    long[] data = [ state, None ];

    XChangeProperty(AppDisplay.instance().dpy, c.win, wmatom[WMState], wmatom[WMState], 32,
                    PropModeReplace, cast(ubyte *)data, 2);
}

void configure(Client *c) {
    
    XConfigureEvent ce;

    ce.type = ConfigureNotify;
    ce.display = AppDisplay.instance().dpy;
    ce.event = c.win;
    ce.window = c.win;
    ce.x = c.x;
    ce.y = c.y;
    ce.width = c.w;
    ce.height = c.h;
    ce.border_width = c.bw;
    ce.above = None;
    ce.override_redirect = false;
    XSendEvent(AppDisplay.instance().dpy, c.win, false, StructureNotifyMask, cast(XEvent *)&ce);
}




void updatesizehints(Client *c) {
    
    long msize;
    XSizeHints size;

    if(!XGetWMNormalHints(AppDisplay.instance().dpy, c.win, &size, &msize)) {
        /* size is uninitialized, ensure that size.flags aren't used */
        size.flags = PSize;
    }
    if(size.flags & PBaseSize) {
        c.basew = size.base_width;
        c.baseh = size.base_height;
    } else if(size.flags & PMinSize) {
        c.basew = size.min_width;
        c.baseh = size.min_height;
    } else {
        c.basew = c.baseh = 0;
    }

    if(size.flags & PResizeInc) {
        c.incw = size.width_inc;
        c.inch = size.height_inc;
    } else {
        c.incw = c.inch = 0;
    }
    if(size.flags & PMaxSize) {
        c.maxw = size.max_width;
        c.maxh = size.max_height;
    } else {
        c.maxw = c.maxh = 0;
    }
    if(size.flags & PMinSize) {
        c.minw = size.min_width;
        c.minh = size.min_height;
    } else if(size.flags & PBaseSize) {
        c.minw = size.base_width;
        c.minh = size.base_height;
    } else {
        c.minw = c.minh = 0;
    }
    if(size.flags & PAspect) {
        c.mina = cast(float)size.min_aspect.y / size.min_aspect.x;
        c.maxa = cast(float)size.max_aspect.x / size.max_aspect.y;
    } else {
        c.maxa = c.mina = 0.0;
    }
    c.isfixed = (c.maxw && c.minw && c.maxh && c.minh
                 && c.maxw == c.minw && c.maxh == c.minh);
}

void focus(Client *c) {
    if(!c || !ISVISIBLE(c)) {
        c = selmon.stack.range!"snext".find!(a => ISVISIBLE(a)).front;
    }
    /* was if(selmon.sel) */
    if(selmon.sel && selmon.sel != c)
        unfocus(selmon.sel, false);
    if(c) {
        if(c.mon != selmon)
            selmon = c.mon;
        if(c.isurgent)
            clearurgent(c);
        detachstack(c);
        attachstack(c);
        mouseEventHandler.grabbuttons(c, true);
        XSetWindowBorder(AppDisplay.instance().dpy, c.win, scheme[SchemeSel].border.rgb);
        setfocus(c);
    } else {
        XSetInputFocus(AppDisplay.instance().dpy, rootWin, RevertToPointerRoot, CurrentTime);
        XDeleteProperty(AppDisplay.instance().dpy, rootWin, netatom[NetActiveWindow]);
    }
    selmon.sel = c;
    drawbars();
}

void focusmon(const Arg *arg) {
    
    Monitor *m;

    if(mons && !mons.next) {
        return;
    }
    m = dirtomon(arg.i);
    if(m == selmon) {
        return;
    }
    unfocus(selmon.sel, false); /* s/true/false/ fixes input focus issues
					in gedit and anjuta */
    selmon = m;
    focus(null);
}

void focusstack(const Arg *arg) {
    
    Client *c = null, i;

    if(!selmon.sel)
        return;
    if(arg.i > 0) {
        c = selmon.sel.range!"next".find!(a => ISVISIBLE(a)).front;
        if(!c) {
            c = selmon.clients.range!"next".find!(a => ISVISIBLE(a)).front;
        }
    } else {
        for(i = selmon.clients; i != selmon.sel; i = i.next) {
            if(ISVISIBLE(i)) {
                c = i;
            }
        }
        if(!c) {
            for(; i; i = i.next) {
                if(ISVISIBLE(i)) {
                    c = i;
                }
            }
        }
    }
    if(c) {
        focus(c);
        restack(selmon);
    }
}

Client* wintoclient(Window w) {
    
    foreach(m; mons.range) {
        auto c = m.clients.range!"next".find!(client => client.win == w).front;
        if(c) {
            return c;
        }
    }
    return null;
}

void unfocus(Client *c, bool setfocus) {
    
    if(!c)
        return;
    mouseEventHandler.grabbuttons(c, false);
    XSetWindowBorder(AppDisplay.instance().dpy, c.win, scheme[SchemeNorm].border.rgb);
    if(setfocus) {
        XSetInputFocus(AppDisplay.instance().dpy, rootWin, RevertToPointerRoot, CurrentTime);
        XDeleteProperty(AppDisplay.instance().dpy, rootWin, netatom[NetActiveWindow]);
    }
}



void restack(Monitor *m) 
{
    XEvent ev;
    XWindowChanges wc;

    drawbar(m);
    if(!m.sel)
        return;
    if(m.sel.isfloating || !m.lt[m.sellt].arrange)
        XRaiseWindow(AppDisplay.instance().dpy, m.sel.win);
    if(m.lt[m.sellt].arrange) {
        wc.stack_mode = Below;
        wc.sibling = m.barwin;
        auto stacks = m.stack.range!"snext".filter!(a => !a.isfloating && ISVISIBLE(a));
        foreach(c; stacks) {
            XConfigureWindow(AppDisplay.instance().dpy, c.win, CWSibling|CWStackMode, &wc);
            wc.sibling = c.win;
        }
    }
    XSync(AppDisplay.instance().dpy, false);
    while(XCheckMaskEvent(AppDisplay.instance().dpy, EnterWindowMask, &ev)) {}
}

auto TEXTW(X)(auto ref in X x)
if(isSomeString!X) {
    return drw.font.getexts_width(x) + drw.font.h;
}

void cleanupmon(Monitor *mon) 
{
    if(mon && mon == mons) {
        mons = mons.next;
    } else {
        auto m = mons.range.find!(a => a.next == mon).front;
        if(m) {
            m.next = mon.next;
        }
    }
    XUnmapWindow(AppDisplay.instance().dpy, mon.barwin);
    XDestroyWindow(AppDisplay.instance().dpy, mon.barwin);
    DGC.free(mon);
}

void clearurgent(Client *c) {
    
    XWMHints *wmh;

    c.isurgent = false;
    wmh = XGetWMHints(AppDisplay.instance().dpy, c.win);
    if(wmh is null) {
        return;
    }
    wmh.flags &= ~XUrgencyHint;
    XSetWMHints(AppDisplay.instance().dpy, c.win, wmh);
    XFree(wmh);
}



void detachstack(Client *c) 
{
    Client **tc;


    for(tc = &c.mon.stack; *tc && *tc != c; tc = &(*tc).snext) {}
    *tc = c.snext;

    if(c && c == c.mon.sel) {
        auto t = c.mon.stack.range!"snext".find!(a=>ISVISIBLE(a)).front;
        c.mon.sel = t;
    }
}

void detach(Client *c) 
{
    Client **tc;
    for(tc = &c.mon.clients; *tc && *tc != c; tc = &(*tc).next) {}
    *tc = c.next;
}

