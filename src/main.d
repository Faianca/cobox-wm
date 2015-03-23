module main;	

import std.c.locale;
import std.c.string;
import std.c.stdlib;

import std.stdio;
import std.string;
import std.algorithm;
import std.conv;
import std.process;
import std.traits;
//import utils;

immutable string VERSION = "0.1";
import core.memory;
alias DGC = core.memory.GC;

import core.sys.posix.signal;
import core.sys.posix.sys.wait;
import core.sys.posix.unistd;

import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;

Display *dpy; 

int main(string[] args)
{
	if(args.length == 2 && args[1] == "-v") {
		stderr.writeln(
			"cbox-wm-"~VERSION~"\n"~
			"The Cteam Window Manager.\n\t"~
			"© 2015 Cbox, see LICENSE for details\n\t"~
			"© 2014-2015 cbox engineers, see LICENSE for details"
		);
		return -1;
	} 	

	writeln("tau");
	dpy = XOpenDisplay(null);

	if(dpy is null) {
		stderr.writeln("cbox: cannot open display");
		return -1;
	}
//
//	auto app = new App(dpy);
//
//	app.kernel();
//	app.run();
//	app.shutdown();
//
	XCloseDisplay(dpy);
    writeln("cbox-"~VERSION~" end");
	return 0;
}

