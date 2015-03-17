module cbox;

import std.stdio;
import std.datetime;


/***
 * 
 */
class Timer
{
	string[] slots = [
		"app", 
		"func", 
		"interval", 
		"call_time", 
		"repeat"
	];

	SysTime callTime;
	App app;

	this(App app, string func, int interval, bool repeat = false)
	{
		app = app;
		func = func;
		interval = interval;
		callTime = Clock.currTime();
		repeat = repeat;
	}

	void cancel()
	{
		app.removeTimer(this);
	}

}

class App
{
	auto timers = [];
	int pointer_x;
	int pointer_y;

	enum x_event_map {
		ButtonPress 		=  "on_button_press",
		ConfigureRequest    =  "on_configure_request",
		ConfigureNotify  	=  "on_configure_notify",
		DestroyNotify		=  "on_destroy_notify",
		EnterNotify			=  "on_enter_notify", 
		Expose				=  "on_expose",
		KeyPress			=  "on_key_press",
		MappingNotify		=  "on_mapping_notify",
		MapRequest			=  "on_map_request",
		PropertyNotify		=  "on_property_notify",
		UnmapNotify			=  "on_unmap_notify",
		ClientMessage		=  "on_client_message"
	};

	this()
	{
		writeln("im alive");

		
		pointer_x = 0;
		pointer_y = 0;
	}

	/** 
	 * Startup Error handler to check if another window manager
	 * is already running. 
	 **/
	extern(C) int xerrorstart(Display *dpy, XErrorEvent *ee) nothrow 
	{
		die("cbox: another window manager is already running");
		return 1;
	}

	void checkotherwm() 
	{
		xerrorxlib = XSetErrorHandler(&xerrorstart);
		/* this causes an error if some other window manager is running */
		XSelectInput(dpy, DefaultRootWindow(dpy), SubstructureRedirectMask);
		XSync(dpy, false);
		XSetErrorHandler(&xerror);
		XSync(dpy, false);
	}

	void addFdHandler()
	{
	}

	void removeFdHandler()
	{

	}

	void addTimer()
	{
	}

	void removeTimer(Timer t)
	{
	}

	void stop()
	{

	}

	void run()
	{

	}

	void xcbEvents()
	{

	}

}	

