module window;

import cboxapp;
import config;
import types;
import std.string;
import std.conv;
import kernel;
import old;
import utils;
import legacy;
import monitor;
import helper.x11;
import theme.manager;

import std.algorithm;
import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;
import std.algorithm;

enum { 
	NetSupported, 
	NetWMName, 
	NetWMState,
    NetWMFullscreen, 
    NetActiveWindow,
    NetWMWindowType,
    NetWMWindowTypeDialog, 
    NetWMWindowOnTop,
    NetClientList, 
    NetLast 
}; /* EWMH atoms */

enum { 
	WMProtocols, 
	WMDelete, 
	WMState, 
	WMTakeFocus, 
	WMLast 
}; /* default atoms */

class WindowManager
{
	Atom[WMLast] wmatom;
	Atom[NetLast] netatom;

	this()
	{
		/* init atoms */
        wmatom[WMProtocols] = XInternAtom(AppDisplay.instance().dpy, cast(char*)("WM_PROTOCOLS".toStringz), false);
        wmatom[WMDelete] = XInternAtom(AppDisplay.instance().dpy, cast(char*)("WM_DELETE_WINDOW".toStringz), false);
        wmatom[WMState] = XInternAtom(AppDisplay.instance().dpy, cast(char*)("WM_STATE".toStringz), false);
        wmatom[WMTakeFocus] = XInternAtom(AppDisplay.instance().dpy, cast(char*)("WM_TAKE_FOCUS".toStringz), false);

        netatom[NetActiveWindow] = XInternAtom(AppDisplay.instance().dpy, cast(char*)("_NET_ACTIVE_WINDOW".toStringz), false);
        netatom[NetSupported] = XInternAtom(AppDisplay.instance().dpy, cast(char*)("_NET_SUPPORTED".toStringz), false);
        netatom[NetWMName] = XInternAtom(AppDisplay.instance().dpy, cast(char*)("_NET_WM_NAME".toStringz), false);
        netatom[NetWMState] = XInternAtom(AppDisplay.instance().dpy, cast(char*)("_NET_WM_STATE".toStringz), false);
        netatom[NetWMFullscreen] = XInternAtom(AppDisplay.instance().dpy, cast(char*)("_NET_WM_STATE_FULLSCREEN".toStringz), false);
        netatom[NetWMWindowType] = XInternAtom(AppDisplay.instance().dpy, cast(char*)("_NET_WM_WINDOW_TYPE".toStringz), false);
        netatom[NetWMWindowTypeDialog] = XInternAtom(AppDisplay.instance().dpy, cast(char*)("_NET_WM_WINDOW_TYPE_DIALOG".toStringz), false);
        netatom[NetClientList] = XInternAtom(AppDisplay.instance().dpy, cast(char*)("_NET_CLIENT_LIST".toStringz), false);	
	    netatom[NetWMWindowOnTop] = XInternAtom(AppDisplay.instance().dpy, cast(char*)("_NET_WM_STATE_ABOVE".toStringz), false);	
	}

	Atom[] getAllAtoms(string atomType = "NetLast")
	{
		Atom[] tmp;

		switch (atomType) {
			case "NetLast": 
				tmp = this.netatom;
				break;
			case "WMLast":
				tmp = this.wmatom;
				break;
			default: 
				throw new Exception(format("Only option NetLast and WMLast are available. You : %s", atomType));
		}

		return tmp;
	}

	Atom getAtom(string atomType, int atomId)
	{
		Atom tmp;

		switch (atomType) {
			case "NetLast":
				tmp = this.netatom[atomId];
				break;
			case "WMLast":
				tmp = this.wmatom[atomId];
				break;
			default: 
				throw new Exception(format("Only option NetLast and WMLast are available. You : %s", atomType));
		}

		return tmp;
	}

	void showhide(Client *c) 
	{
	    if(!c)
	        return;
	    if(ISVISIBLE(c)) { /* show clients top down */
	        XMoveWindow(AppDisplay.instance().dpy, c.win, c.x, c.y);
	        if((!c.mon.lt[c.mon.sellt].arrange || c.isfloating) && !c.isfullscreen)
	            resize(c, c.x, c.y, c.w, c.h, false);
	        showhide(c.snext);
	    } else { /* hide clients bottom up */
	        showhide(c.snext);
	        XMoveWindow(AppDisplay.instance().dpy, c.win, WIDTH(c) * -2, c.y);
	    }
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

	void manage(Window w, XWindowAttributes *wa) 
	{
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
	    if(XGetTransientForHint(AppDisplay.instance().dpy, w, &trans)) {
	        t = wintoclient(trans);
	        if(t) {
	            c.mon = t.mon;
	            c.tags = t.tags;
	        }
	    } 

	    if(!c.mon) {
	        c.mon = selmon;
	        this.applyrules(c);
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

	    XConfigureWindow(AppDisplay.instance().dpy, w, CWBorderWidth, &wc);
	    XSetWindowBorder(AppDisplay.instance().dpy, w, ThemeManager.instance().getScheme(SchemeNorm).border.rgb);

	    configure(c); /* propagates border_width, if size doesn't change */
	    updatewindowtype(c);
	    updatesizehints(c);
	    updatewmhints(c);

	    XSelectInput(AppDisplay.instance().dpy, w, EnterWindowMask|FocusChangeMask|PropertyChangeMask|StructureNotifyMask);
	    mouseEventHandler.grabbuttons(c, false);
	    
	    if(!c.isfloating)
	        c.isfloating = c.oldstate = trans != None || c.isfixed;

	    if(c.isfloating)
	        XRaiseWindow(AppDisplay.instance().dpy, c.win);

	    attach(c);
	    attachstack(c);

	    XChangeProperty(AppDisplay.instance().dpy, rootWin, netatom[NetClientList], XA_WINDOW, 32, PropModeAppend,
	                    cast(ubyte*)(&(c.win)), 1);
	    XMoveResizeWindow(AppDisplay.instance().dpy, c.win, c.x + 2 * sw, c.y, c.w, c.h); /* some windows require this */
	    
	    setclientstate(c, NormalState);

	    if (c.mon == selmon)
	        unfocus(selmon.sel, false);
	    c.mon.sel = c;

	    arrange(c.mon);
	    XMapWindow(AppDisplay.instance().dpy, c.win);
	    focus(null);
	}


	Atom getatomprop(Client *c, Atom prop) 
	{
	    int di;
	    ulong dl;
	    ubyte* p = null;
	    Atom da, atom = None;

	    if(XGetWindowProperty(AppDisplay.instance().dpy, c.win, prop, 0L, atom.sizeof, false, XA_ATOM,
	                          &da, &di, &dl, &dl, &p) == XErrorCode.Success && p) {
	        atom = *cast(Atom *)(p);
	        XFree(p);
	    }
	    return atom;
	}

	void updatewindowtype(Client *c) 
	{
	    
	    Atom state = getatomprop(c, netatom[NetWMState]);
	    Atom wtype = getatomprop(c, netatom[NetWMWindowType]);

	    if(state == netatom[NetWMFullscreen])
	        setfullscreen(c, true);
	    if(wtype == netatom[NetWMWindowTypeDialog])
	        c.isfloating = true;
	}
}

void updatetitle(Client *c) 
{
    if(!X11Helper.gettextprop(c.win, netatom[NetWMName], c.name)) {
        X11Helper.gettextprop(c.win, XA_WM_NAME, c.name);
    }
    
    /* hack to mark broken clients */
    if(c.name.length == 0) { 
        c.name = broken;
    }
}

void unmanage(Client *c, bool destroyed) 
{
    Monitor *m = c.mon;
    XWindowChanges wc;

    /* The server grab construct avoids race conditions. */
    detach(c);
    detachstack(c);

    if(!destroyed) {
        wc.border_width = c.oldbw;
        XGrabServer(AppDisplay.instance().dpy);
        XSetErrorHandler(&xerrordummy);
        XConfigureWindow(AppDisplay.instance().dpy, c.win, CWBorderWidth, &wc); /* restore border */
        XUngrabButton(AppDisplay.instance().dpy, AnyButton, AnyModifier, c.win);
        setclientstate(c, WithdrawnState);
        XSync(AppDisplay.instance().dpy, false);
        XSetErrorHandler(&xerror);
        XUngrabServer(AppDisplay.instance().dpy);
    }
    
    DGC.free(c);
    focus(null);
    updateclientlist();
    arrange(m);
}


