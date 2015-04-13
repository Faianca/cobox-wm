module events.handler;

import events.keyboard;
import events.mouse;
import kernel;
import old;
import config;
import types;

import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;
import std.stdio;

class EventHandler 
{
	KeyboardEvents keyboard;
	MouseEvents mouse;

	this(KeyboardEvents keyboardEvents, MouseEvents mouseEvents)
	{
		keyboard = keyboardEvents;
		mouse = mouseEvents;

	    handler[ClientMessage] = &clientmessage;
	    handler[ConfigureRequest] = &configurerequest;
	    handler[ConfigureNotify] = &configurenotify;
	    handler[DestroyNotify] = &destroynotify;
	    handler[EnterNotify] = &enternotify;
	    handler[Expose] = &expose;
	    handler[FocusIn] = &focusin;
	  
	    handler[MappingNotify] = &mappingnotify;
	    handler[MapRequest] = &maprequest;
	    handler[MotionNotify] = &motionnotify;
	    handler[PropertyNotify] = &propertynotify;
	    handler[UnmapNotify] = &unmapnotify;
	}

	void function(XEvent*)[LASTEvent] handler;

	void listen(XEvent* ev)
	{
		this.keyboard.listen(ev);
		this.mouse.listen(ev);

		if(handler[ev.type]) {
            handler[ev.type](ev); /* call handler */
        }
	}
}

//class MouseEvents
//{
//	void buttonpress(XEvent *e) 
//	{
//	    uint i, x, click;
//	    auto arg = Arg(0);
//	    Client *c;
//	    Monitor *m;
//	    XButtonPressedEvent *ev = &e.xbutton;

//	    click = ClkRootWin;
//	    /* focus monitor if necessary */
//	    m = wintomon(ev.window);
//	    if( (m !is null) && (m != selmon) ) {
//	        unfocus(selmon.sel, true);
//	        selmon = m;
//	        focus(null);
//	    }
//	    if(ev.window == selmon.barwin) {
//	        i = x = 0;
//	        do {
//	            x += TEXTW(tags[i]);
//	        } while(ev.x >= x && ++i < LENGTH(tags));
//	        if(i < LENGTH(tags)) {
//	            click = ClkTagBar;
//	            arg.ui = 1 << i;
//	        } else if(ev.x < x + blw)
//	            click = ClkLtSymbol;
//	        else if(ev.x > selmon.ww - TEXTW(stext))
//	            click = ClkStatusText;
//	        else
//	            click = ClkWinTitle;
//	    } else {
//	        c = wintoclient(ev.window);
//	        if(c !is null) {
//	            focus(c);
//	            click = ClkClientWin;
//	        }
//	    }

//	    foreach(ref const but; buttons) {
//	        if(click == but.click &&
//	                but.func !is null &&
//	                but.button == ev.button &&
//	                CLEANMASK(but.mask) == CLEANMASK(ev.state)) {
//	            but.func(click == ClkTagBar && but.arg.i == 0 ? &arg : &but.arg);
//	        }
//	    }
//	}
//}

