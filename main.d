module main;
import cbox;

void main()
{
	const VERSION = 0.1;

	auto base = new App();

	if(args.length == 2 && args[1] == "-v") {
		stderr.writeln("cbox-wm-"~VERSION~"\n"~
			"The Cteam Window Manager.\n\t"~
			"© 2015 Cbox, see LICENSE for details\n\t"~
			"© 2014-2015 cbox engineers, see LICENSE for details");
		return -1;

	} else if(args.length != 1) {
		stderr.writeln("usage: cbox-wm [-v]");
		return -1;
	}

	if(!setlocale(LC_CTYPE, "".toStringz) || !XSupportsLocale()) {
		stderr.writeln("warning: no locale support");
		return -1;
	}
	dpy = XOpenDisplay(null);
	if(dpy is null) {
		stderr.writeln("cbox: cannot open display");
		return -1;
	}
	checkotherwm();
	setup();
	scan();
	run();
	cleanup();
	XCloseDisplay(dpy);
	lout("cbox-"~VERSION~" end");
	return 0;
}