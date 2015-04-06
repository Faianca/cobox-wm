module main;

import kernel;
import std.stdio;
import deimos.X11.X;

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

	writeln("Codename: Nikola 0.2");
	
	int response = kernel.init();

	writeln("cbox-"~VERSION~" end");
	return response;
}
