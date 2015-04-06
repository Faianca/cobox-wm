module legacy;

import core.sys.posix.signal;
import core.sys.posix.sys.wait;
import core.sys.posix.unistd;
import core.memory;
import std.stdio;

import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;

import utils;

// From core.sys.posix.sys.wait because waitpid is not nothrow @nogc @system
extern(C) pid_t waitpid(pid_t, int*, int) nothrow @nogc @system;

// From core.stdc.stdio due to conflict with std.stdio over stderr
extern(C) int close(int fd) @trusted;

extern(C) void sigchldImpl(int unused) nothrow @nogc @system 
{
	// wait for all child processes to exit.
	while(0 < waitpid(-1, null, WNOHANG)) {}
}

extern(C) int xerrorstart(Display *dpy, XErrorEvent *ee) nothrow 
{
   die("cobox: another window manager is already running");
   return -1;
}

extern(C) int xerror(Display *dpy, XErrorEvent *ee) nothrow {
	import deimos.X11.Xproto :
		    X_SetInputFocus, X_PolyText8, X_PolyFillRectangle, X_PolySegment,
		    X_ConfigureWindow, X_GrabButton, X_GrabKey, X_CopyArea;

	    if(ee.error_code == XErrorCode.BadWindow
			|| (ee.request_code == X_SetInputFocus && ee.error_code == XErrorCode.BadMatch)
			|| (ee.request_code == X_PolyText8 && ee.error_code == XErrorCode.BadDrawable)
			|| (ee.request_code == X_PolyFillRectangle && ee.error_code == XErrorCode.BadDrawable)
			|| (ee.request_code == X_PolySegment && ee.error_code == XErrorCode.BadDrawable)
			|| (ee.request_code == X_ConfigureWindow && ee.error_code == XErrorCode.BadMatch)
			|| (ee.request_code == X_GrabButton && ee.error_code == XErrorCode.BadAccess)
			|| (ee.request_code == X_GrabKey && ee.error_code == XErrorCode.BadAccess)
			|| (ee.request_code == X_CopyArea && ee.error_code == XErrorCode.BadDrawable)
		 ) {
		    printf(">>>> XERROR: %d", ee.error_code);
			return 0;
		 }
	
		printf("cobox: fatal error: request code=%d, error code=%d", ee.request_code, ee.error_code);
		
		return xerrorxlib(dpy, ee); 
}

extern(C) static int function(Display*, XErrorEvent*) nothrow xerrorxlib;

