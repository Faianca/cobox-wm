module events.handler;

import events.keyboard;
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

	this()
	{
	    buttons = [
	        /* click                event mask      button          function        argument */
	        Button( ClkLtSymbol,          0,              Button1,        &setlayout ),
	        Button( ClkLtSymbol,          0,              Button3,        &setlayout,      &layouts[2] ),
	        Button( ClkWinTitle,          0,              Button2,        &zoom ),
	        Button( ClkStatusText,        0,              Button2,        &spawn,          termcmd ), // &termcmd
	        Button( ClkClientWin,         MODKEY,         Button1,        &movemouse ),
	        Button( ClkClientWin,         MODKEY,         Button2,        &togglefloating ),
	        Button( ClkClientWin,         MODKEY,         Button3,        &resizemouse ),
	        Button( ClkTagBar,            0,              Button1,        &view ),
	        Button( ClkTagBar,            0,              Button3,        &toggleview ),
	        Button( ClkTagBar,            MODKEY,         Button1,        &tag ),
	        Button( ClkTagBar,            MODKEY,         Button3,        &toggletag )
	    ];

	    handler[ButtonPress] = &buttonpress;
	    handler[ClientMessage] = &clientmessage;
	    handler[ConfigureRequest] = &configurerequest;
	    handler[ConfigureNotify] = &configurenotify;
	    handler[DestroyNotify] = &destroynotify;
	    handler[EnterNotify] = &enternotify;
	    handler[Expose] = &expose;
	    handler[FocusIn] = &focusin;
	    handler[KeyPress] = &keypress;
	    handler[MappingNotify] = &mappingnotify;
	    handler[MapRequest] = &maprequest;
	    handler[MotionNotify] = &motionnotify;
	    handler[PropertyNotify] = &propertynotify;
	    handler[UnmapNotify] = &unmapnotify;
	}

	void function(XEvent*)[LASTEvent] handler;

	void listen(XEvent* ev)
	{
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

