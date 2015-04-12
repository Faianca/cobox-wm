module old;
import core.memory;
alias DGC = core.memory.GC;
alias XGC = deimos.X11.Xlib.GC;

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

void updateclientlist() {
    
    Client *c;
    Monitor *m;

    XDeleteProperty(dpy, rootWin, netatom[NetClientList]);
    for(m = mons; m; m = m.next)
        for(c = m.clients; c; c = c.next)
            XChangeProperty(dpy, rootWin, netatom[NetClientList],
                            XA_WINDOW, 32, PropModeAppend,
                            cast(ubyte *)&(c.win), 1);
}

void drawbar(Monitor *m) {
    
    uint occ = 0, urg = 0;

    foreach(c; m.clients.range!"next") {
        occ |= c.tags;
        if(c.isurgent) {
            urg |= c.tags;
        }
    }
    int x = 0, w;
    foreach(i, tag; tags) {
        w = TEXTW(tag);
        drw.setscheme((m.tagset[m.seltags] & (1 << i)) ? &scheme[SchemeSel] : &scheme[SchemeNorm]);
        drw.text(x, 0, w, bh, tag, urg & 1 << i);
        drw.rect(x, 0, w, bh, m == selmon && selmon.sel && selmon.sel.tags & 1 << i,
                 occ & 1 << i, urg & 1 << i);
        x += w;
    }
    w = blw = TEXTW(m.ltsymbol);
    drw.setscheme(&scheme[SchemeNorm]);
    drw.text(x, 0, w, bh, m.ltsymbol, 0);
    x += w;
    int xx = x;
    if(m == selmon) { /* status is only drawn on selected monitor */
        w = TEXTW(stext);
        x = m.ww - w;
        if(x < xx) {
            x = xx;
            w = m.ww - xx;
        }
        drw.text(x, 0, w, bh, stext, 0);
    } else {
        x = m.ww;
    }
    if((w = x - xx) > bh) {
        x = xx;
        if(m.sel) {
            drw.setscheme(m == selmon ? &scheme[SchemeSel] : &scheme[SchemeNorm]);
            drw.text(x, 0, w, bh, m.sel.name, 0);
            drw.rect(x, 0, w, bh, m.sel.isfixed, m.sel.isfloating, 0);
        } else {
            drw.setscheme(&scheme[SchemeNorm]);
            drw.text(x, 0, w, bh, null, 0);
        }
    }
    drw.map(m.barwin, 0, 0, m.ww, bh);
}

void drawbars() {
    
    foreach(m; mons.range) {
        drawbar(m);
    }

}



Atom getatomprop(Client *c, Atom prop) {
    
    int di;
    ulong dl;
    ubyte* p = null;
    Atom da, atom = None;

    if(XGetWindowProperty(dpy, c.win, prop, 0L, atom.sizeof, false, XA_ATOM,
                          &da, &di, &dl, &dl, &p) == XErrorCode.Success && p) {
        atom = *cast(Atom *)(p);
        XFree(p);
    }
    return atom;
}

bool getrootptr(int *x, int *y) {
    
    int di;
    uint dui;
    Window dummy;

    return XQueryPointer(dpy, rootWin, &dummy, &dummy, x, y, &di, &di, &dui) != 0;
}

void setfocus(Client *c) {
    
    if(!c.neverfocus) {
        XSetInputFocus(dpy, c.win, RevertToPointerRoot, CurrentTime);
        XChangeProperty(dpy, rootWin, netatom[NetActiveWindow],
                        XA_WINDOW, 32, PropModeReplace,
                        cast(ubyte *) &(c.win), 1);
    }
    sendevent(c, wmatom[WMTakeFocus]);
}


bool
sendevent(Client *c, Atom proto) {
    int n;
    Atom *protocols;
    bool exists = false;
    XEvent ev;

    if(XGetWMProtocols(dpy, c.win, &protocols, &n)) {
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
        XSendEvent(dpy, c.win, false, NoEventMask, &ev);
    }
    return exists;
}

Client* nexttiled(Client *c) {
    
    return c.range!"next".find!(a => !a.isfloating && ISVISIBLE(a)).front;
}

void pop(Client *c) {
    
    detach(c);
    attach(c);
    focus(c);
    arrange(c.mon);
}

void setfullscreen(Client *c, bool fullscreen) {
    
    if(fullscreen) {
        XChangeProperty(dpy, c.win, netatom[NetWMState], XA_ATOM, 32,
                        PropModeReplace, cast(ubyte*)&netatom[NetWMFullscreen], 1);
        c.isfullscreen = true;
        c.oldstate = c.isfloating;
        c.oldbw = c.bw;
        c.bw = 0;
        c.isfloating = true;
        resizeclient(c, c.mon.mx, c.mon.my, c.mon.mw, c.mon.mh);
        XRaiseWindow(dpy, c.win);
    } else {
        XChangeProperty(dpy, c.win, netatom[NetWMState], XA_ATOM, 32,
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





void movemouse(const Arg *arg) {
    
    int x, y, ocx, ocy, nx, ny;
    Client *c;
    Monitor *m;
    XEvent ev;
    Time lasttime = 0;

    c = selmon.sel;
    if(!c) {
        return;
    }
    if(c.isfullscreen) /* no support moving fullscreen windows by mouse */
        return;
    restack(selmon);
    ocx = c.x;
    ocy = c.y;
    if(XGrabPointer(dpy,
                    rootWin,
                    false,
                    MOUSEMASK,
                    GrabModeAsync,
                    GrabModeAsync,
                    None,
                    cursor[CurMove].cursor,
                    CurrentTime) != GrabSuccess) {
        return;
    }
    if(!getrootptr(&x, &y)) {
        return;
    }
    do {
        XMaskEvent(dpy, MOUSEMASK|ExposureMask|SubstructureRedirectMask, &ev);
        switch(ev.type) {
            case ConfigureRequest:
            case Expose:
            case MapRequest:
                handler[ev.type](&ev);
                break;
            case MotionNotify:
                if ((ev.xmotion.time - lasttime) <= (1000 / 60))
                    continue;
                lasttime = ev.xmotion.time;

                nx = ocx + (ev.xmotion.x - x);
                ny = ocy + (ev.xmotion.y - y);
                if(nx >= selmon.wx && nx <= selmon.wx + selmon.ww
                        && ny >= selmon.wy && ny <= selmon.wy + selmon.wh) {
                    if(abs(selmon.wx - nx) < snap)
                        nx = selmon.wx;
                    else if(abs((selmon.wx + selmon.ww) - (nx + WIDTH(c))) < snap)
                        nx = selmon.wx + selmon.ww - WIDTH(c);
                    if(abs(selmon.wy - ny) < snap)
                        ny = selmon.wy;
                    else if(abs((selmon.wy + selmon.wh) - (ny + HEIGHT(c))) < snap)
                        ny = selmon.wy + selmon.wh - HEIGHT(c);
                    if(!c.isfloating && selmon.lt[selmon.sellt].arrange
                            && (abs(nx - c.x) > snap || abs(ny - c.y) > snap))
                        togglefloating(null);
                }
                if(!selmon.lt[selmon.sellt].arrange || c.isfloating)
                    resize(c, nx, ny, c.w, c.h, true);
                break;
            default :
                break;
        }
    } while(ev.type != ButtonRelease);
    XUngrabPointer(dpy, CurrentTime);
    if((m = recttomon(c.x, c.y, c.w, c.h)) != selmon) {
        sendmon(c, m);
        selmon = m;
        focus(null);
    }
}



void resizemouse(const Arg *arg) {
    
    int ocx, ocy, nw, nh;
    Client *c;
    Monitor *m;
    XEvent ev;
    Time lasttime = 0;

    c = selmon.sel;
    if(!c) {
        return;
    }

    if(c.isfullscreen) /* no support resizing fullscreen windows by mouse */
        return;

    restack(selmon);
    ocx = c.x;
    ocy = c.y;

    if(XGrabPointer(dpy, rootWin, false, MOUSEMASK, GrabModeAsync, GrabModeAsync,
                    None, cursor[CurResize].cursor, CurrentTime) != GrabSuccess)
        return;
    
    XWarpPointer(dpy, None, c.win, 0, 0, 0, 0, c.w + c.bw - 1, c.h + c.bw - 1);
    do {
        XMaskEvent(dpy, MOUSEMASK|ExposureMask|SubstructureRedirectMask, &ev);
        switch(ev.type) {
            case ConfigureRequest:
            case Expose:
            case MapRequest:
                handler[ev.type](&ev);
                break;
            case MotionNotify:
                if ((ev.xmotion.time - lasttime) <= (1000 / 60))
                    continue;
                lasttime = ev.xmotion.time;

                nw = max(ev.xmotion.x - ocx - 2 * c.bw + 1, 1);
                nh = max(ev.xmotion.y - ocy - 2 * c.bw + 1, 1);
                if(c.mon.wx + nw >= selmon.wx && c.mon.wx + nw <= selmon.wx + selmon.ww
                        && c.mon.wy + nh >= selmon.wy && c.mon.wy + nh <= selmon.wy + selmon.wh) {
                    if(!c.isfloating && selmon.lt[selmon.sellt].arrange
                            && (abs(nw - c.w) > snap || abs(nh - c.h) > snap))
                        togglefloating(null);
                }
                if(!selmon.lt[selmon.sellt].arrange || c.isfloating)
                    resize(c, c.x, c.y, nw, nh, true);
                break;
            default :
                break;
        }
    } while(ev.type != ButtonRelease);
    XWarpPointer(dpy, None, c.win, 0, 0, 0, 0, c.w + c.bw - 1, c.h + c.bw - 1);
    XUngrabPointer(dpy, CurrentTime);
    while(XCheckMaskEvent(dpy, EnterWindowMask, &ev)) {}
    m = recttomon(c.x, c.y, c.w, c.h);
    if(m != selmon) {
        sendmon(c, m);
        selmon = m;
        focus(null);
    }
}


void configurenotify(XEvent *e) {
    
    XConfigureEvent *ev = &e.xconfigure;
    bool dirty;

    // TODO: updategeom handling sucks, needs to be simplified
    if(ev.window == rootWin) {
        dirty = (sw != ev.width || sh != ev.height);
        sw = ev.width;
        sh = ev.height;
        if(updategeom() || dirty) {
            drw.resize(sw, bh);
            updatebars();
            foreach(m; mons.range) {
                XMoveResizeWindow(dpy, m.barwin, m.wx, m.by, m.ww, bh);
            }
            focus(null);
            arrange(null);
        }
    }
}

void configurerequest(XEvent *e) {
    
    Client *c;
    Monitor *m;
    XConfigureRequestEvent *ev = &e.xconfigurerequest;
    XWindowChanges wc;
    c = wintoclient(ev.window);
    if(c) {
        if(ev.value_mask & CWBorderWidth) {
            c.bw = ev.border_width;
        } else if(c.isfloating || !selmon.lt[selmon.sellt].arrange) {
            m = c.mon;
            if(ev.value_mask & CWX) {
                c.oldx = c.x;
                c.x = m.mx + ev.x;
            }
            if(ev.value_mask & CWY) {
                c.oldy = c.y;
                c.y = m.my + ev.y;
            }
            if(ev.value_mask & CWWidth) {
                c.oldw = c.w;
                c.w = ev.width;
            }
            if(ev.value_mask & CWHeight) {
                c.oldh = c.h;
                c.h = ev.height;
            }
            if((c.x + c.w) > m.mx + m.mw && c.isfloating)
                c.x = m.mx + (m.mw / 2 - WIDTH(c) / 2); /* center in x direction */
            if((c.y + c.h) > m.my + m.mh && c.isfloating)
                c.y = m.my + (m.mh / 2 - HEIGHT(c) / 2); /* center in y direction */
            if((ev.value_mask & (CWX|CWY)) && !(ev.value_mask & (CWWidth|CWHeight)))
                configure(c);
            if(ISVISIBLE(c))
                XMoveResizeWindow(dpy, c.win, c.x, c.y, c.w, c.h);
        } else {
            configure(c);
        }
    } else {
        wc.x = ev.x;
        wc.y = ev.y;
        wc.width = ev.width;
        wc.height = ev.height;
        wc.border_width = ev.border_width;
        wc.sibling = ev.above;
        wc.stack_mode = ev.detail;

        // HACK to fix the slowdown XError issue. value_mask recieved is 36 but needs to be 12
        // 36 ==> b2:width, b5:sibling
        // 12 ==> b2:width, b3:height
        ev.value_mask = 12;
        XConfigureWindow(dpy, ev.window, ev.value_mask, &wc);
    }
    XSync(dpy, false);
}

void destroynotify(XEvent *e) {
    
    Client *c;
    XDestroyWindowEvent *ev = &e.xdestroywindow;

    c = wintoclient(ev.window);
    if(c !is null) {
        unmanage(c, true);
    }
}


void enternotify(XEvent *e) {
    
    Client *c;
    Monitor *m;
    XCrossingEvent *ev = &e.xcrossing;

    if((ev.mode != NotifyNormal || ev.detail == NotifyInferior) && ev.window != rootWin)
        return;
    c = wintoclient(ev.window);
    m = c ? c.mon : wintomon(ev.window);
    if(m != selmon) {
        unfocus(selmon.sel, true);
        selmon = m;
    } else if(!c || c == selmon.sel) {
        return;
    }
    focus(c);
}

void mappingnotify(XEvent *e) {
    
    XMappingEvent *ev = &e.xmapping;

    XRefreshKeyboardMapping(ev);
    if(ev.request == MappingKeyboard)
        keyboardEventHandler.grabkeys();
}

void maprequest(XEvent *e) {
    
    static XWindowAttributes wa;
    XMapRequestEvent *ev = &e.xmaprequest;

    if(!XGetWindowAttributes(dpy, ev.window, &wa))
        return;
    if(wa.override_redirect)
        return;
    if(!wintoclient(ev.window))
        manage(ev.window, &wa);
}


void propertynotify(XEvent *e) {
    
    Client *c;
    Window trans;
    XPropertyEvent *ev = &e.xproperty;
    if((ev.window == rootWin) && (ev.atom == XA_WM_NAME))
        updatestatus();
    else if(ev.state == PropertyDelete)
        return; /* ignore */
    else {
        c = wintoclient(ev.window);
        if(c) {
            switch(ev.atom) {
                default:
                    break;
                case XA_WM_TRANSIENT_FOR:
                    if(!c.isfloating && (XGetTransientForHint(dpy, c.win, &trans))) {
                        c.isfloating = (wintoclient(trans) !is null);
                        if(c.isfloating) {
                            arrange(c.mon);
                        }
                    }
                    break;
                case XA_WM_NORMAL_HINTS:
                    updatesizehints(c);
                    break;
                case XA_WM_HINTS:
                    updatewmhints(c);
                    drawbars();
                    break;
            }
            if(ev.atom == XA_WM_NAME || ev.atom == netatom[NetWMName]) {
                updatetitle(c);
                if(c == c.mon.sel)
                    drawbar(c.mon);
            }
            if(ev.atom == netatom[NetWMWindowType])
                updatewindowtype(c);
        }
    }
}
void quit(const Arg *arg) {
    
    running = false;
}
void unmapnotify(XEvent *e) {
    
    Client *c;
    XUnmapEvent *ev = &e.xunmap;

    c=  wintoclient(ev.window);
    if(c) {
        if(ev.send_event)
            setclientstate(c, WithdrawnState);
        else
            unmanage(c, false);
    }
}

Monitor* recttomon(int x, int y, int w, int h) {
    
    auto r = selmon;
    int a, area = 0;

    foreach(m; mons.range) {
        a = INTERSECT(x, y, w, h, m);
        if(a > area) {
            area = a;
            r = m;
        }
    }
    return r;
}

void resize(Client *c, int x, int y, int w, int h, bool interact) {
    
    if(applysizehints(c, x, y, w, h, interact))
        resizeclient(c, x, y, w, h);
}

void resizeclient(Client *c, int x, int y, int w, int h) {
    
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
    XConfigureWindow(dpy, c.win, CWX|CWY|CWWidth|CWHeight|CWBorderWidth, &wc);
    configure(c);
    XSync(dpy, false);
}

void sendmon(Client *c, Monitor *m) {
    
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

void updatebars() {
    
    XSetWindowAttributes wa = {
override_redirect :
        True,
background_pixmap :
        ParentRelative,
event_mask :
        ButtonPressMask|ExposureMask
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

void updatebarpos(Monitor *m) {
    
    m.wy = m.my;
    m.wh = m.mh;
    if(m.showbar) {
        m.wh -= bh;
        m.by = m.topbar ? m.wy : m.wy + m.wh;
        m.wy = m.topbar ? m.wy + bh : m.wy;
    } else
        m.by = -bh;
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


void motionnotify(XEvent *e) {
    
    static Monitor *mon = null;
    Monitor *m;
    XMotionEvent *ev = &e.xmotion;

    if(ev.window != rootWin)
        return;
    if((m = recttomon(ev.x_root, ev.y_root, 1, 1)) != mon && mon) {
        unfocus(selmon.sel, true);
        selmon = m;
        focus(null);
    }
    mon = m;
}

void clientmessage(XEvent *e) {
    
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



void togglebar(const Arg *arg) {
    
    selmon.showbar = !selmon.showbar;
    updatebarpos(selmon);
    XMoveResizeWindow(dpy, selmon.barwin, selmon.wx, selmon.by, selmon.ww, bh);
    arrange(selmon);
}

void togglefloating(const Arg *arg) {
    
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

void setlayout(const Arg *arg) {
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
        XGrabServer(dpy);
        XSetErrorHandler(&xerrordummy);
        XSetCloseDownMode(dpy, CloseDownMode.DestroyAll);
        XKillClient(dpy, selmon.sel.win);
        XSync(dpy, false);
        XSetErrorHandler(&xerror);
        XUngrabServer(dpy);
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

void cleanup() {
    
    auto a = Arg(-1);
    Layout foo = { "", null };

    view(&a);
    selmon.lt[selmon.sellt] = &foo;
    foreach(m; mons.range) {
        while(m.stack) {
            unmanage(m.stack, false);
        }
    }
    XUngrabKey(dpy, AnyKey, AnyModifier, rootWin);
    while(mons) {
        cleanupmon(mons);
    }
    Cur.free(cursor[CurNormal]);
    Cur.free(cursor[CurResize]);
    Cur.free(cursor[CurMove]);
    Fnt.free(dpy, fnt);
    Clr.free(scheme[SchemeNorm].border);
    Clr.free(scheme[SchemeNorm].bg);
    Clr.free(scheme[SchemeNorm].fg);
    Clr.free(scheme[SchemeSel].border);
    Clr.free(scheme[SchemeSel].bg);
    Clr.free(scheme[SchemeSel].fg);
    Drw.free(drw);
    XSync(dpy, false);
    XSetInputFocus(dpy, PointerRoot, RevertToPointerRoot, CurrentTime);
    XDeleteProperty(dpy, rootWin, netatom[NetActiveWindow]);
}


void tile(Monitor *m) {
    
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

void monocle(Monitor *m) {
    
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
        isXineramaActive = XineramaIsActive(dpy);
    }
    if(isXineramaActive) {
        version(XINERAMA) {
            import std.range;
            int nn;
            Client *c;
            XineramaScreenInfo *info = XineramaQueryScreens(dpy, &nn);
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

void updatenumlockmask() {
    
    XModifierKeymap *modmap;

    numlockmask = 0;
    modmap = XGetModifierMapping(dpy);
    foreach_reverse(i; 0..7) {
        if(numlockmask == 0) {
            break;
        }
        //for(i = 7; numlockmask == 0 && i >= 0; --i) {
        foreach_reverse(j; 0..modmap.max_keypermod-1) {
            //for(j = modmap.max_keypermod-1; j >= 0; --j) {
            if(modmap.modifiermap[i * modmap.max_keypermod + j] ==
                    XKeysymToKeycode(dpy, XK_Num_Lock)) {
                numlockmask = (1 << i);
                break;
            }
        }
    }
    XFreeModifiermap(modmap);
}


void updatewindowtype(Client *c) {
    
    Atom state = getatomprop(c, netatom[NetWMState]);
    Atom wtype = getatomprop(c, netatom[NetWMWindowType]);

    if(state == netatom[NetWMFullscreen])
        setfullscreen(c, true);
    if(wtype == netatom[NetWMWindowTypeDialog])
        c.isfloating = true;
}

void updatewmhints(Client *c) {
    
    XWMHints *wmh;
    wmh = XGetWMHints(dpy, c.win);
    if(wmh) {
        if(c == selmon.sel && wmh.flags & XUrgencyHint) {
            wmh.flags &= ~XUrgencyHint;
            XSetWMHints(dpy, c.win, wmh);
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

    XChangeProperty(dpy, c.win, wmatom[WMState], wmatom[WMState], 32,
                    PropModeReplace, cast(ubyte *)data, 2);
}

void configure(Client *c) {
    
    XConfigureEvent ce;

    ce.type = ConfigureNotify;
    ce.display = dpy;
    ce.event = c.win;
    ce.window = c.win;
    ce.x = c.x;
    ce.y = c.y;
    ce.width = c.w;
    ce.height = c.h;
    ce.border_width = c.bw;
    ce.above = None;
    ce.override_redirect = false;
    XSendEvent(dpy, c.win, false, StructureNotifyMask, cast(XEvent *)&ce);
}

void grabbuttons(Client *c, bool focused) {
    
    updatenumlockmask();
    uint i, j;
    uint[] modifiers = [ 0, LockMask, numlockmask, numlockmask|LockMask ];
    XUngrabButton(dpy, AnyButton, AnyModifier, c.win);
    if(focused) {
        foreach(ref const but; buttons) {
            if(but.click == ClkClientWin) {
                foreach(ref const mod; modifiers) {
                    XGrabButton(dpy, but.button,
                                but.mask | mod,
                                c.win, false, BUTTONMASK,
                                GrabModeAsync, GrabModeSync,
                                cast(ulong)None, cast(ulong)None);
                }
            }
        }
    } else {
        XGrabButton(dpy, AnyButton, AnyModifier, c.win, false,
                    BUTTONMASK, GrabModeAsync, GrabModeSync, None, None);
    }
}


void updatesizehints(Client *c) {
    
    long msize;
    XSizeHints size;

    if(!XGetWMNormalHints(dpy, c.win, &size, &msize)) {
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
        grabbuttons(c, true);
        XSetWindowBorder(dpy, c.win, scheme[SchemeSel].border.rgb);
        setfocus(c);
    } else {
        XSetInputFocus(dpy, rootWin, RevertToPointerRoot, CurrentTime);
        XDeleteProperty(dpy, rootWin, netatom[NetActiveWindow]);
    }
    selmon.sel = c;
    drawbars();
}

void focusin(XEvent *e) {  /* there are some broken focus acquiring clients */  
    XFocusChangeEvent *ev = &e.xfocus;
    if(selmon.sel && ev.window != selmon.sel.win) {
        setfocus(selmon.sel);
    }
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

struct Button {
	uint click;
	uint mask;
	uint button;

    void function(const Arg* a) func;
    const Arg arg;

    this(uint click, uint mask, uint button, void function(const Arg* a) func) {
        this(click, mask, button, func, 0);
    }
    this(T)(uint click, uint mask, uint button, void function(const Arg* a) func, T arg) {
        this.click = click;
        this.mask = mask;
        this.button = button;
        this.func = func;
        this.arg = makeArg(arg);
    }
};

/* button definitions */
/* click can be ClkLtSymbol, ClkStatusText, ClkWinTitle, ClkClientWin, or ClkRootWin */
static Button[] buttons;

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
    grabbuttons(c, false);
    XSetWindowBorder(dpy, c.win, scheme[SchemeNorm].border.rgb);
    if(setfocus) {
        XSetInputFocus(dpy, rootWin, RevertToPointerRoot, CurrentTime);
        XDeleteProperty(dpy, rootWin, netatom[NetActiveWindow]);
    }
}

Monitor* wintomon(Window w) {
    
    int x, y;

    if(w == rootWin && getrootptr(&x, &y)) {
        return recttomon(x, y, 1, 1);
    }
    auto m = mons.range.find!(mon => mon.barwin == w).front;
    if(m) {
        return m;
    }

    auto c = wintoclient(w);
    if(c) {
        return c.mon;
    }
    return selmon;
}

auto makeArg(TIN)(TIN val) {
    alias T = Unqual!TIN;
    return Arg(val);
}

struct Arg {
    union Vals{
        int ival;
        uint uival;
        float fval;
        string[] sval;
        void* vptr;
    }
    Vals val;
    //Variant val;
    this(TIN)(TIN val) {
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
    @property int i() const {
        return this.val.ival;
    }
    @property void i(int ival) {val.ival = cast(int)(ival);}
    @property uint ui() const {
        return this.val.uival;
    }
    @property void ui(uint ival) {val.uival = cast(uint)(ival);}
    @property float f() const {
        return this.val.fval;
    }
    @property void f(float ival) {val.fval = cast(float)(ival);}
    @property const(string[]) s() const {
        return this.val.sval;
    }
    @property void s(string[] ival) {val.sval = cast(string[])(ival);}

    @property const(void*) v() const {
        return this.val.vptr;
    }
    @property void v(void* ival) {val.vptr = cast(void*)(ival);}
}

void restack(Monitor *m) {
    
    XEvent ev;
    XWindowChanges wc;

    drawbar(m);
    if(!m.sel)
        return;
    if(m.sel.isfloating || !m.lt[m.sellt].arrange)
        XRaiseWindow(dpy, m.sel.win);
    if(m.lt[m.sellt].arrange) {
        wc.stack_mode = Below;
        wc.sibling = m.barwin;
        auto stacks = m.stack.range!"snext".filter!(a => !a.isfloating && ISVISIBLE(a));
        foreach(c; stacks) {
            XConfigureWindow(dpy, c.win, CWSibling|CWStackMode, &wc);
            wc.sibling = c.win;
        }
    }
    XSync(dpy, false);
    while(XCheckMaskEvent(dpy, EnterWindowMask, &ev)) {}
}

void showhide(Client *c) {
    
    if(!c)
        return;
    if(ISVISIBLE(c)) { /* show clients top down */
        XMoveWindow(dpy, c.win, c.x, c.y);
        if((!c.mon.lt[c.mon.sellt].arrange || c.isfloating) && !c.isfullscreen)
            resize(c, c.x, c.y, c.w, c.h, false);
        showhide(c.snext);
    } else { /* hide clients bottom up */
        showhide(c.snext);
        XMoveWindow(dpy, c.win, WIDTH(c) * -2, c.y);
    }
}

immutable string[] tags = [ "1", "2", "3", "4", "5", "6", "7", "8", "9" ];

/* layout(s) */
static immutable float mfact      = 0.55; /* factor of master area size [0.05..0.95] */
static immutable int nmaster      = 1;    /* number of clients in master area */
static immutable bool resizehints = true; /* true means respect size hints in tiled resizals */

//###################################################
// MACROS
enum BUTTONMASK = ButtonPressMask | ButtonReleaseMask;
auto CLEANMASK(M)(auto ref in M mask) {
    return (mask & ~(numlockmask|LockMask) & (ShiftMask|ControlMask|Mod1Mask|Mod2Mask|Mod3Mask|Mod4Mask|Mod5Mask));
}
auto INTERSECT(T, M)(T x, T y, T w, T h, M m) {
    import std.algorithm;
    return max(0, min(x + w, m.wx + m.ww) - max(x, m.wx)) * max(0, min(y + h, m.wy + m.wh) - max(y, m.wy));
}
auto ISVISIBLE(C)(auto ref in C c) pure @safe @nogc nothrow {
    return c.tags & c.mon.tagset[c.mon.seltags];
}
auto LENGTH(X)(auto ref in X x) {
    return x.length;
}
enum MOUSEMASK = ButtonPressMask | ButtonReleaseMask | PointerMotionMask;

auto WIDTH(X)(auto ref in X x) {
    return x.w + 2 * x.bw;
}
auto HEIGHT(X)(auto ref in X x) {
    return x.h + 2 * x.bw;
}
enum TAGMASK = ((1 << tags.length) - 1);
auto TEXTW(X)(auto ref in X x)
if(isSomeString!X) {
    return drw.font.getexts_width(x) + drw.font.h;
}

struct Extnts {
	uint w;
	uint h;
}

struct Rule {
	string klass;
	string instance;
	string title;
	uint tags;
	bool isfloating;
	int monitor;
}

/**
 * Drw provides an interface for working with drawable surfaces.
 */
struct Drw {
    uint w, h; /// The width and height of the drawable area
    Display *dpy; /// The X display
    int screen; /// The X screen ID
    Window root; /// The root window for this drawable
    Drawable drawable; /// The X drawable encapsulated by this.
    XGC gc; /// The X graphic context
    ClrScheme *scheme; /// The colour scheme to use
    Fnt *font; /// The X font to use for rendering text.

    /**
     * Ctor to initialise the draw object
     * Params:
     *  dpy=        X display to render with.
     *  screen=     X screen id
     *  root=       Root X window for this drawable
     *  w=          Width of the drawable
     *  h=          Height of the drawable
     * Example:
     * ---
     * drw = new Drw(dpy, screen, root, sw, sh);
     * ---
     */
    this(Display* dpy, int screen, Window root, uint w, uint h) {
        this.dpy = dpy;
        this.screen = screen;
        this.root = root;
        this.w = w;
        this.h = h;
        this.drawable = XCreatePixmap(dpy, root, w, h, DefaultDepth(dpy, screen));
        this.gc = XCreateGC(dpy, root, 0, null);
        XSetLineAttributes(dpy, this.gc, 1, LineSolid, CapButt, JoinMiter);

    }
    /**
     * Resize the drawable to a new width and height
     * Params:
     *  w=      Width
     *  h=      Height
     * Example:
     * ---
     * drw.resize(100, 100);
     * ---
     */
    void resize(uint w, uint h) {
        this.w = w;
        this.h = h;
        if(this.drawable != 0) {
            XFreePixmap(this.dpy, this.drawable);
        }
        this.drawable = XCreatePixmap(this.dpy, this.root, w, h, DefaultDepth(this.dpy, this.screen));
    }
    /**
     * Destroy the X resources used by this drawable.
     */
    void destroy() {
        XFreePixmap(this.dpy, this.drawable);
        XFreeGC(this.dpy, this.gc);
    }
    /**
     * Set the font to use for rendering.
     * Params:
     *  font=       Pointer to the font to use.
     */
    void setfont(Fnt *font) {
        this.font = font;
    }
    /**
     * Set the scheme for this drawable
     * Params:
     *  scheme=     Pointer to the scheme to use
     */
    void setscheme(ClrScheme *scheme) {
        if(scheme)
            this.scheme = scheme;
    }
    /**
     * Draw a rectangle to the X display using the current settings. Note that
     * filled and empty are not mutually exclusive.
     * Params:
     *  x=      Left edge of the rect
     *  y=      Top edge of the rect
     *  w=      Width of the rect
     *  h=      Height of the rect
     *  filled= If true the rect will be filled
     *  empty=  If true the rect will be empty
     *  invert= If true the colours will be inverted.
     * Example:
     * ---
     * drw.rect(10, 10, 90, 90, true, false, false);
     * ---
     */
    void rect(int x, int y, uint w, uint h, int filled, int empty, int invert) {
        int dx;

        if(!this.font || !this.scheme)
            return;
        XSetForeground(this.dpy, this.gc, invert ? this.scheme.bg.rgb : this.scheme.fg.rgb);
        dx = (this.font.ascent + this.font.descent + 2) / 4;
        if(filled)
            XFillRectangle(this.dpy, this.drawable, this.gc, x+1, y+1, dx+1, dx+1);
        else if(empty)
            XDrawRectangle(this.dpy, this.drawable, this.gc, x+1, y+1, dx, dx);
    }

    /**
     * Render some text to the display using the current font.
     * Params:
     *  x=      Left edge of the text area
     *  y=      Top of the text area
     *  w=      Width of the text area
     *  h=      Height of the text area
     *  text=   Text to write
     *  invert= true the text bg/fg coluors will be inverted
     * Example:
     * ---
     * drw.text(10, 10, 100, 100, "this is a test", false);
     * ---
     */
    void text(int x, int y, uint w, uint h, in string text, int invert) {
        char[256] buf;
        Extnts tex;

        if(!this.scheme) {
            return;
        }
        XSetForeground(this.dpy, this.gc, invert ? this.scheme.fg.rgb : this.scheme.bg.rgb);
        XFillRectangle(this.dpy, this.drawable, this.gc, x, y, w, h);
        if(!text || !this.font) {
            return;
        }
        this.font.getexts(text, &tex);
        auto th = this.font.ascent + this.font.descent;
        auto ty = y + (h / 2) - (th / 2) + this.font.ascent;
        auto tx = x + (h / 2);
        /* shorten text if necessary */
        auto len = min(text.length, buf.sizeof);        
        for(; len && (tex.w > w - tex.h || w < tex.h); len--) {
            this.font.getexts(text[0..len], &tex);
        }
        if(!len) {
            return;
        }
        memcpy(buf.ptr, text.ptr, len);

        XSetForeground(this.dpy, this.gc, invert ? this.scheme.bg.rgb : this.scheme.fg.rgb);
        if(this.font.set)
            XmbDrawString(this.dpy, this.drawable, this.font.set, this.gc, tx, ty, buf.ptr, cast(uint)(len));
        else
            XDrawString(this.dpy, this.drawable, this.gc, tx, ty, buf.ptr, cast(int)len);
    }

    /**
     * Copy the drawable area to a window.
     * Params:
     *  win= Destination to copy to.
     *  x=      Left edge of area to copy
     *  y=      Top of area to copy
     *  w=      Width of area to copy
     *  h=      Height of area to copy
     * Example:
     * ---
     * drw.map(win, 10, 10, 100, 100);
     * ---
     */
    void map(Window win, int x, int y, uint w, uint h) {
        XCopyArea(this.dpy, this.drawable, win, this.gc, x, y, w, h, x, y);
        XSync(this.dpy, false);
    }

    /**
     * Release the GC memory used for the Drw object
     * Params:
     *  drw=        Drw object to release
     */
    static void free(Drw* drw) {
        drw.destroy;
        DGC.free(drw);
    }

}


enum CursorFont : int {
    XC_num_glyphs = 154,
    XC_X_cursor = 0,
    XC_arrow = 2,
    XC_based_arrow_down = 4,
    XC_based_arrow_up = 6,
    XC_boat = 8,
    XC_bogosity = 10,
    XC_bottom_left_corner = 12,
    XC_bottom_right_corner = 14,
    XC_bottom_side = 16,
    XC_bottom_tee = 18,
    XC_box_spiral = 20,
    XC_center_ptr = 22,
    XC_circle = 24,
    XC_clock = 26,
    XC_coffee_mug = 28,
    XC_cross = 30,
    XC_cross_reverse = 32,
    XC_crosshair = 34,
    XC_diamond_cross = 36,
    XC_dot = 38,
    XC_dotbox = 40,
    XC_double_arrow = 42,
    XC_draft_large = 44,
    XC_draft_small = 46,
    XC_draped_box = 48,
    XC_exchange = 50,
    XC_fleur = 52,
    XC_gobbler = 54,
    XC_gumby = 56,
    XC_hand1 = 58,
    XC_hand2 = 60,
    XC_heart = 62,
    XC_icon = 64,
    XC_iron_cross = 66,
    XC_left_ptr = 68,
    XC_left_side = 70,
    XC_left_tee = 72,
    XC_leftbutton = 74,
    XC_ll_angle = 76,
    XC_lr_angle = 78,
    XC_man = 80,
    XC_middlebutton = 82,
    XC_mouse = 84,
    XC_pencil = 86,
    XC_pirate = 88,
    XC_plus = 90,
    XC_question_arrow = 92,
    XC_right_ptr = 94,
    XC_right_side = 96,
    XC_right_tee = 98,
    XC_rightbutton = 100,
    XC_rtl_logo = 102,
    XC_sailboat = 104,
    XC_sb_down_arrow = 106,
    XC_sb_h_double_arrow = 108,
    XC_sb_left_arrow = 110,
    XC_sb_right_arrow = 112,
    XC_sb_up_arrow = 114,
    XC_sb_v_double_arrow = 116,
    XC_shuttle = 118,
    XC_sizing = 120,
    XC_spider = 122,
    XC_spraycan = 124,
    XC_star = 126,
    XC_target = 128,
    XC_tcross = 130,
    XC_top_left_arrow = 132,
    XC_top_left_corner = 134,
    XC_top_right_corner = 136,
    XC_top_side = 138,
    XC_top_tee = 140,
    XC_trek = 142,
    XC_ul_angle = 144,
    XC_umbrella = 146,
    XC_ur_angle = 148,
    XC_watch = 150,
    XC_xterm = 152
}

/**
 * Font object to encapsulate the X font.
 */
struct Fnt {
    int ascent; /// Ascent of the font
    int descent;/// Descent of the font
    uint h; /// Height of the font. This equates to ascent + descent.
    XFontSet set; // Font set to use
    XFontStruct *xfont; /// The X font we're covering.
    Display* dpy;

    /**
     * Ctor. Creates a Fnt object wrapping the specified font for a given display.
     * Params:
     *  dpy=        X display
     *  fontname=   Name of the font to wrap (X font name)
     * Example:
     * ---
     * auto f = Fnt(display, "-*-terminus-medium-r-*-*-16-*-*-*-*-*-*-*");
     * ---
     */
    this(Display *dpy, in string fontname) {
        if(dpy is null) {
            exit(EXIT_FAILURE);
        }
        this,dpy = dpy;
        char *def;
        char **missing;
        int n;
        this.set = XCreateFontSet(dpy, cast(char*)fontname.toStringz, &missing, &n, &def);
        if(missing) {
            while(n--) {
                //lout("drw: missing fontset: %s", missing[n].fromStringz);
            }
            XFreeStringList(missing);
        }
        if(this.set) {
            XFontStruct **xfonts;
            char **font_names;
            XExtentsOfFontSet(this.set);
            n = XFontsOfFontSet(this.set, &xfonts, &font_names);
            while(n--) {
                this.ascent = max(this.ascent, (*xfonts).ascent);
                this.descent = max(this.descent,(*xfonts).descent);
                xfonts++;
            }
        }
        else {
            this.xfont = XLoadQueryFont(dpy, cast(char*)(fontname.toStringz));
            if(this.xfont is null) {
                this.xfont = XLoadQueryFont(dpy, cast(char*)("fixed".toStringz));
                if(this.xfont is null) {
                    //lout("error, cannot load font: %s", fontname);
                    exit(EXIT_FAILURE);
                }
            }
            this.ascent = this.xfont.ascent;
            this.descent = this.xfont.descent;
        }
        this.h = this.ascent + this.descent;
    }

    /**
     * Destroy the X resources for this font.
     */
    private void destroy(Display* dpy) {
        if(this.set) {
            XFreeFontSet(dpy, this.set);
        }
        else if(this.xfont) {
            XFreeFont(dpy, this.xfont);
        }
        this.set = null;
        this.xfont = null;
    }

    /**
     * Free the given font object associated with a display. This will release
     * the GC allocated memory.
     * Params:
     *  fnt=        Pointer to the font to destroy.
     *  dpy=        Display associated with the font to destroy
     * Example:
     * ---
     * auto f = Fnt(display, "-*-terminus-medium-r-*-*-16-*-*-*-*-*-*-*");
     *
     * // work with the font object
     *
     * Fnt.free(f)
     * ---
     */
    static void free(Display* dpy, Fnt* fnt) {
        fnt.destroy(dpy);
        DGC.free(fnt);
    }

    /**
     * Get the font extents for a given string.
     * Params:
     *  text=   Text to get the extents
     *  tex=    Extents struct to fill in with the font information
     */
    void getexts(in string text, Extnts *tex) {
        XRectangle r;

        if(text.length == 0) {
            return;
        }
        if(this.set) {
            XmbTextExtents(this.set, cast(char*)text.ptr, cast(int)text.length, null, &r);
            tex.w = r.width;
            tex.h = r.height;
        }
        else {
            tex.h = this.ascent + this.descent;
            tex.w = XTextWidth(this.xfont, cast(char*)text.ptr, cast(int)text.length);
        }
    }
    /**
     * Get the rendered width of a string for the wrapped font.
     * Params:
     *  text=       Text to get the width for
     * Returns:
     *  Width of the text for the wrapped font.
     */
    uint getexts_width(in string text) {
        Extnts tex;

        this.getexts(text, &tex);
        return tex.w;
    }
}


struct Clr {
    ulong rgb;

    this(Drw* drw, in string clrname) {
        if(drw is null) {
           // lout(__FUNCTION__~"\n\t--> NULL Drw* parm");
            exit(EXIT_FAILURE);
        }
        Colormap cmap;
        XColor color;

        cmap = DefaultColormap(drw.dpy, drw.screen);
        if(!XAllocNamedColor(drw.dpy, cmap, cast(char*)clrname.toStringz, &color, &color)) {
           // lout("error, cannot allocate color '%s'", clrname);
            exit(EXIT_FAILURE);
        }
        this.rgb = color.pixel;
    }

    static void free(Clr *clr) {
        if(clr) {
            DGC.free(clr);
        }
    }
}

struct ClrScheme {
	Clr *fg;
	Clr *bg;
	Clr *border;
}

/**
 * Wraps a X cursor.
 */
struct Cur {
    Cursor cursor;
    Display* dpy;

    /**
     * Ctor constructing a Cursor with a given display object.
     * Params:
     *  dpy=        Display object
     *  shape=      X cursor shape
     */
    this(Display* dpy, CursorFont shape) {
        if(dpy is null) {
           // lout(__FUNCTION__~"\n\t--> NULL Display* parm");
            exit(EXIT_FAILURE);
        }
        this.dpy = dpy;
        this.cursor = XCreateFontCursor(this.dpy, shape);
    }
    private void destroy() {
        XFreeCursor(this.dpy, this.cursor);
    }
    static void free(Cur* c) {
        if(c is null) {
           // lout(__FUNCTION__~"\n\t--> NULL Cur* parm");
            exit(EXIT_FAILURE);
        }
        c.destroy();
        DGC.free(c);
    }

}

void cleanupmon(Monitor *mon) {
    if(mon && mon == mons) {
        mons = mons.next;
    } else {
        auto m = mons.range.find!(a => a.next == mon).front;
        if(m) {
            m.next = mon.next;
        }
    }
    XUnmapWindow(dpy, mon.barwin);
    XDestroyWindow(dpy, mon.barwin);
    DGC.free(mon);
}

void clearurgent(Client *c) {
    
    XWMHints *wmh;

    c.isurgent = false;
    wmh = XGetWMHints(dpy, c.win);
    if(wmh is null) {
        return;
    }
    wmh.flags &= ~XUrgencyHint;
    XSetWMHints(dpy, c.win, wmh);
    XFree(wmh);
}

Monitor* dirtomon(int dir) {
    
    Monitor *m = null;

    if(dir > 0) {
        m = selmon.next;
        if(m is null) {
            m = mons;
        }
    } else if(selmon == mons) {
        m = mons.range.find!"a.next is null".front;
    } else {
        m = mons.range.find!(a => a.next == selmon).front;
    }
    return m;
}

Monitor* createmon() {
    
    Monitor* m = new Monitor();

    import std.string;
    if(m is null) {
        die("fatal: could not malloc() %s bytes\n", Monitor.sizeof);
    }
    m.tagset[0] = m.tagset[1] = 1;
    m.mfact = mfact;
    m.nmaster = nmaster;
    m.showbar = showbar;
    m.topbar = topbar;
    m.lt[0] = &layouts[0];
    m.lt[1] = &layouts[1 % LENGTH(layouts)];
    m.ltsymbol = layouts[0].symbol;
    //strncpy(m.ltsymbol.ptr, layouts[0].symbol, m.ltsymbol.sizeof);
    return m;
}

void detachstack(Client *c) {
    
    Client **tc;


    for(tc = &c.mon.stack; *tc && *tc != c; tc = &(*tc).snext) {}
    *tc = c.snext;

    if(c && c == c.mon.sel) {
        auto t = c.mon.stack.range!"snext".find!(a=>ISVISIBLE(a)).front;
        c.mon.sel = t;
    }
}

void updatestatus() {
    
    if(!gettextprop(rootWin, XA_WM_NAME, stext)) {
        stext = "ddwm-"~VERSION;
    }
    drawbar(selmon);
}

void unmanage(Client *c, bool destroyed) {
    
    Monitor *m = c.mon;
    XWindowChanges wc;

    /* The server grab construct avoids race conditions. */
    detach(c);
    detachstack(c);
    if(!destroyed) {
        wc.border_width = c.oldbw;
        XGrabServer(dpy);
        XSetErrorHandler(&xerrordummy);
        XConfigureWindow(dpy, c.win, CWBorderWidth, &wc); /* restore border */
        XUngrabButton(dpy, AnyButton, AnyModifier, c.win);
        setclientstate(c, WithdrawnState);
        XSync(dpy, false);
        XSetErrorHandler(&xerror);
        XUngrabServer(dpy);
    }
    DGC.free(c);
    focus(null);
    updateclientlist();
    arrange(m);
}

void detach(Client *c) {
    
    Client **tc;
    for(tc = &c.mon.clients; *tc && *tc != c; tc = &(*tc).next) {}
    *tc = c.next;
}

static string stext;

void expose(XEvent *e) {
    

    Monitor *m;
    XExposeEvent *ev = &e.xexpose;

    if(ev.count == 0) {
        m = wintomon(ev.window);
        if(m !is null) {
            drawbar(m);
        }
    }
}