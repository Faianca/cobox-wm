import kernel;
import types;
import cboxapp;
import cli.options;
import config;

import std.stdio;
import x11.X;
import x11.Xlib;
import std.datetime;

int main(string[] args)
{
    CboxOptions opts = new CboxOptions();
    int exitcode = opts.parse(args);

    if (exitcode == -1) {
       return exitcode;
    }

    opts.update();

    if(AppDisplay.instance().dpy is null) {
        stderr.writeln("cbox: cannot open display");
        return -1;
    }

	writeln("Codename: Nikola 0.2");

	Kernel kernel = new Kernel();
	int response = kernel.boot();

	writeln("cbox-"~VERSION~" end");
	return response;
}
