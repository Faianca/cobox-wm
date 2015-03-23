module cbox;
//
//import std.stdio;
//import std.datetime;
//import std.exception;
//
//import deimos.X11.X;
//import deimos.X11.Xlib;
//import deimos.X11.keysymdef;
//import deimos.X11.Xutil;
//import deimos.X11.Xatom;
//
//class App
//{
//	Display *dpy;
//	auto timers = [];
//	int pointer_x;
//	int pointer_y;
//
//	enum x_event_map {
//		ButtonPress 		=  "on_button_press",
//		ConfigureRequest    =  "on_configure_request",
//		ConfigureNotify  	=  "on_configure_notify",
//		DestroyNotify		=  "on_destroy_notify",
//		EnterNotify			=  "on_enter_notify", 
//		Expose				=  "on_expose",
//		KeyPress			=  "on_key_press",
//		MappingNotify		=  "on_mapping_notify",
//		MapRequest			=  "on_map_request",
//		PropertyNotify		=  "on_property_notify",
//		UnmapNotify			=  "on_unmap_notify",
//		ClientMessage		=  "on_client_message"
//	};
//
//	this(Display *dpy)
//	{
//		this.dpy = dpy;
//		pointer_x = 0;
//		pointer_y = 0;
//	}
//
//	void setup() 
//	{
//		
//		XSetWindowAttributes wa;
//		
//		/* clean up any zombies immediately */
//		sigchld(0);
//		
//		/* init screen */
//		screen = DefaultScreen(dpy);
//		rootWin = RootWindow(dpy, screen);
//
//		fnt = new Fnt(dpy, font);
//		sw = DisplayWidth(dpy, screen);
//		sh = DisplayHeight(dpy, screen);
//		bh = fnt.h + 2;
//
//		drw = new Drw(dpy, screen, rootWin, sw, sh);
//		drw.setfont(fnt);
//		updategeom();
//
//		/* init atoms */
//		wmatom[WMProtocols] = XInternAtom(dpy, cast(char*)("WM_PROTOCOLS".toStringz), false);
//		wmatom[WMDelete] = XInternAtom(dpy, cast(char*)("WM_DELETE_WINDOW".toStringz), false);
//		wmatom[WMState] = XInternAtom(dpy, cast(char*)("WM_STATE".toStringz), false);
//		wmatom[WMTakeFocus] = XInternAtom(dpy, cast(char*)("WM_TAKE_FOCUS".toStringz), false);
//		netatom[NetActiveWindow] = XInternAtom(dpy, cast(char*)("_NET_ACTIVE_WINDOW".toStringz), false);
//		netatom[NetSupported] = XInternAtom(dpy, cast(char*)("_NET_SUPPORTED".toStringz), false);
//		netatom[NetWMName] = XInternAtom(dpy, cast(char*)("_NET_WM_NAME".toStringz), false);
//		netatom[NetWMState] = XInternAtom(dpy, cast(char*)("_NET_WM_STATE".toStringz), false);
//		netatom[NetWMFullscreen] = XInternAtom(dpy, cast(char*)("_NET_WM_STATE_FULLSCREEN".toStringz), false);
//		netatom[NetWMWindowType] = XInternAtom(dpy, cast(char*)("_NET_WM_WINDOW_TYPE".toStringz), false);
//		netatom[NetWMWindowTypeDialog] = XInternAtom(dpy, cast(char*)("_NET_WM_WINDOW_TYPE_DIALOG".toStringz), false);
//		netatom[NetClientList] = XInternAtom(dpy, cast(char*)("_NET_CLIENT_LIST".toStringz), false);
//
//		/* init cursors */
//		cursor[CurNormal] = new Cur(drw.dpy, CursorFont.XC_left_ptr);
//		cursor[CurResize] = new Cur(drw.dpy, CursorFont.XC_sizing);
//		cursor[CurMove] = new Cur(drw.dpy, CursorFont.XC_fleur);
//
//		/* init appearance */
//		scheme[SchemeNorm].border = new Clr(drw, normbordercolor);
//		scheme[SchemeNorm].bg = new Clr(drw, normbgcolor);
//		scheme[SchemeNorm].fg = new Clr(drw, normfgcolor);
//		scheme[SchemeSel].border = new Clr(drw, selbordercolor);
//		scheme[SchemeSel].bg = new Clr(drw, selbgcolor);
//		scheme[SchemeSel].fg = new Clr(drw, selfgcolor);
//
//		/* init bars */
//		updatebars();
//		updatestatus();
//
//		/* EWMH support per view */
//		XChangeProperty(dpy, rootWin, netatom[NetSupported], XA_ATOM, 32,
//			PropModeReplace, cast(ubyte*) netatom, NetLast);
//		XDeleteProperty(dpy, rootWin, netatom[NetClientList]);
//
//		/* select for events */
//		wa.cursor = cursor[CurNormal].cursor;
//		wa.event_mask = SubstructureRedirectMask|SubstructureNotifyMask|ButtonPressMask|PointerMotionMask
//			|EnterWindowMask|LeaveWindowMask|StructureNotifyMask|PropertyChangeMask;
//		XChangeWindowAttributes(dpy, rootWin, CWEventMask|CWCursor, &wa);
//		XSelectInput(dpy, rootWin, wa.event_mask);
//		grabkeys();
//		focus(null);
//	}
//	/** 
//	 * Startup Error handler to check if another window manager
//	 * is already running. 
//	 **/
//	extern(C) int xerrorstart(Display *dpy, XErrorEvent *ee) nothrow 
//	{
//		die("cbox: another window manager is already running");
//		return 1;
//	}
//
//	void checkotherwm() 
//	{
//		xerrorxlib = XSetErrorHandler(&xerrorstart);
//		/* this causes an error if some other window manager is running */
//		XSelectInput(dpy, DefaultRootWindow(dpy), SubstructureRedirectMask);
//		XSync(dpy, false);
//		XSetErrorHandler(&xerror);
//		XSync(dpy, false);
//	}
//
//	void scan() 
//	{
//		uint i, num;
//		Window d1, d2;
//		Window* wins = null;
//		XWindowAttributes wa;
//		
//		if(XQueryTree(dpy, rootWin, &d1, &d2, &wins, &num)) {
//			for(i = 0; i < num; i++) {
//				if(!XGetWindowAttributes(dpy, wins[i], &wa)
//					|| wa.override_redirect || XGetTransientForHint(dpy, wins[i], &d1))
//					continue;
//				if(wa.map_state == IsViewable || getstate(wins[i]) == IconicState)
//					manage(wins[i], &wa);
//			}
//			for(i = 0; i < num; i++) { /* now the transients */
//				if(!XGetWindowAttributes(dpy, wins[i], &wa))
//					continue;
//				if(XGetTransientForHint(dpy, wins[i], &d1)
//					&& (wa.map_state == IsViewable || getstate(wins[i]) == IconicState))
//					manage(wins[i], &wa);
//			}
//			if(wins)
//				XFree(wins);
//		}
//	}
//
//	void shutdown() 
//	{
//		auto a = Arg(-1);
//		Layout foo = { "", null };
//		
//		view(&a);
//		selmon.lt[selmon.sellt] = &foo;
//		foreach(m; mons.range) {
//			while(m.stack) {
//				unmanage(m.stack, false);
//			}
//		}
//
//		XUngrabKey(dpy, AnyKey, AnyModifier, rootWin);
//		while(mons) {
//			cleanupmon(mons);
//		}
//
//		Cur.free(cursor[CurNormal]);
//		Cur.free(cursor[CurResize]);
//		Cur.free(cursor[CurMove]);
//		Fnt.free(dpy, fnt);
//		Clr.free(scheme[SchemeNorm].border);
//		Clr.free(scheme[SchemeNorm].bg);
//		Clr.free(scheme[SchemeNorm].fg);
//		Clr.free(scheme[SchemeSel].border);
//		Clr.free(scheme[SchemeSel].bg);
//		Clr.free(scheme[SchemeSel].fg);
//		Drw.free(drw);
//		XSync(dpy, false);
//		XSetInputFocus(dpy, PointerRoot, RevertToPointerRoot, CurrentTime);
//		XDeleteProperty(dpy, rootWin, netatom[NetActiveWindow]);
//	}
//
//	void kernel()
//	{
//			this.checkotherwm();
//			this.setup();
//			this.scan();
//	}
//
//	/**
//	 * Main Event Loop
//	 */
//	void run() 
//	{
//		extern(C) __gshared XEvent ev;
//
//		XSync(dpy, false);
//		while(running && !XNextEvent(dpy, &ev)) {
//			if(handler[ev.type]) {
//				handler[ev.type](&ev); /* call handler */
//			}
//		}
//
//	}
//
//}	

