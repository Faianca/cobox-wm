module events.handler;

import events.keyboard;
import events.mouse;
import kernel;
import old;
import config;
import types;
import gui.bar;
import cboxapp;
import window;
import monitor;

import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;
import std.stdio;
import std.c.locale;
import std.c.string;
import std.c.stdlib;

class EventHandler 
{
	KeyboardEvents keyboard;
	MouseEvents mouse;

	this(KeyboardEvents keyboardEvents, MouseEvents mouseEvents)
	{
		keyboard = keyboardEvents;
		mouse = mouseEvents;

	    handler[ClientMessage] = &clientmessage;
	    handler[ConfigureRequest] = &configurerequest;
	    handler[ConfigureNotify] = &configurenotify;
	    handler[DestroyNotify] = &destroynotify;
	    handler[EnterNotify] = &enternotify;
	    handler[Expose] = &expose;
	    handler[FocusIn] = &focusin;
	    handler[MappingNotify] = &mappingnotify;
	    handler[MapRequest] = &maprequest;
	    handler[MotionNotify] = &motionnotify;
	    handler[PropertyNotify] = &propertynotify;
	    handler[UnmapNotify] = &unmapnotify;
	}

	void function(XEvent*)[LASTEvent] handler;

	void listen(XEvent* ev)
	{
		this.keyboard.listen(ev);
		this.mouse.listen(ev);

		if(handler[ev.type]) {
            handler[ev.type](ev); /* call handler */
        }
	}
}

void maprequest(XEvent *e) 
{
    static XWindowAttributes wa;
    XMapRequestEvent *ev = &e.xmaprequest;

    if(!XGetWindowAttributes(AppDisplay.instance().dpy, ev.window, &wa))
        return;
    if(wa.override_redirect)
        return;
    if(!wintoclient(ev.window))
        manage(ev.window, &wa);
}

void propertynotify(XEvent *e) 
{
    
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
                    if(!c.isfloating && (XGetTransientForHint(AppDisplay.instance().dpy, c.win, &trans))) {
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

void focusin(XEvent *e) 
{  
	/* there are some broken focus acquiring clients */  
    XFocusChangeEvent *ev = &e.xfocus;
    if(selmon.sel && ev.window != selmon.sel.win) {
        setfocus(selmon.sel);
    }
}

void unmapnotify(XEvent *e) 
{
    
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

void destroynotify(XEvent *e) 
{
    Client *c;
    XDestroyWindowEvent *ev = &e.xdestroywindow;

    c = wintoclient(ev.window);
    if(c !is null) {
        unmanage(c, true);
    }
}


void enternotify(XEvent *e) 
{
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

void mappingnotify(XEvent *e) 
{
    XMappingEvent *ev = &e.xmapping;

    XRefreshKeyboardMapping(ev);
    if(ev.request == MappingKeyboard)
        keyboardEventHandler.grabkeys();
}


void expose(XEvent *e) 
{
    Monitor *m;
    XExposeEvent *ev = &e.xexpose;

    if(ev.count == 0) {
        m = wintomon(ev.window);
        if(m !is null) {
            drawbar(m);
        }
    }
}

void configurerequest(XEvent *e) 
{
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
                XMoveResizeWindow(AppDisplay.instance().dpy, c.win, c.x, c.y, c.w, c.h);
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
        XConfigureWindow(AppDisplay.instance().dpy, ev.window, ev.value_mask, &wc);
    }
    XSync(AppDisplay.instance().dpy, false);
}

void configurenotify(XEvent *e) 
{
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
                XMoveResizeWindow(AppDisplay.instance().dpy, m.barwin, m.wx, m.by, m.ww, bh);
            }
            focus(null);
            arrange(null);
        }
    }
}

void motionnotify(XEvent *e) 
{
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
