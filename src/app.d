import kernel;
import types;
import cboxapp;

import std.stdio;
import deimos.X11.X;
import deimos.X11.Xlib;

int main(string[] args)
{
	if(args.length == 2 && args[1] == "-v") {
		stderr.writeln(
			"cbox-wm-"~VERSION~"\n"~
			"The Cteam Window Manager.\n\t"~
			"© 2015 Cbox, see LICENSE for details\n\t"
			);
		return -1;
	}

	writeln("Codename: Nikola 0.2");

    if(AppDisplay.instance().dpy is null) {
        stderr.writeln("cbox: cannot open display");
        return -1;
    }

	Kernel kernel = new Kernel();
	int response = kernel.boot();

	writeln("cbox-"~VERSION~" end");
	return response;
}
