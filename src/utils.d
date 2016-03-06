module utils;

import legacy;
import std.stdio;
import core.sys.posix.signal;

import x11.X;
import x11.Xlib;
import x11.keysymdef;
import x11.Xutil;
import x11.Xatom;

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


