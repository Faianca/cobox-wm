module utils;

import legacy;
import std.stdio;
import core.sys.posix.signal;

import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;

void sigchld(int unused) nothrow
{
	if(signal(SIGCHLD, &sigchldImpl) == SIG_ERR) {
		die("Can't install SIGCHLD handler");
	}
	sigchldImpl(unused);
}

auto die(F, A...)(lazy F fmt, lazy A args) nothrow
{
	import std.c.stdlib;
	try {
		std.stdio.stderr.writefln("\n\n"~fmt~"\n\n", args);
	} catch {}
	exit(EXIT_FAILURE);
}


