module events.mouse;

import kernel;
import old;
import config;
import types;
import cboxapp;

import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;
import std.stdio;

struct Button 
{
	uint click;
	uint mask;
	uint button;

    void function(const Arg* a) func;
    const Arg arg;

    this(uint click, uint mask, uint button, void function(const Arg* a) func) {
        this(click, mask, button, func, 0);
    }
    this(T)(uint click, uint mask, uint button, void function(const Arg* a) func, T arg) {
        this.click = click;
        this.mask = mask;
        this.button = button;
        this.func = func;
        this.arg = makeArg(arg);
    }
};

class MouseEvents
{
	Button[] buttons;

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
	}

	Button[] getButtons()
	{
		return this.buttons;
	}

	void listen(XEvent *e)
    {
    	switch (e.type) {
    		case ButtonPress:
				this.buttonpress(e);
    			break;
    		default: { }
    	}
    }

    void grabbuttons(Client *c, bool focused) 
    {
	    updatenumlockmask();
	    uint i, j;
	    uint[] modifiers = [ 0, LockMask, numlockmask, numlockmask|LockMask ];
	    XUngrabButton(AppDisplay.instance().dpy, AnyButton, AnyModifier, c.win);
	    if(focused) {
	        foreach(ref const but; this.buttons) {
	            if(but.click == ClkClientWin) {
	                foreach(ref const mod; modifiers) {
	                    XGrabButton(AppDisplay.instance().dpy, but.button,
	                                but.mask | mod,
	                                c.win, false, BUTTONMASK,
	                                GrabModeAsync, GrabModeSync,
	                                cast(ulong)None, cast(ulong)None);
	                }
	            }
	        }
	    } else {
	        XGrabButton(AppDisplay.instance().dpy, AnyButton, AnyModifier, c.win, false,
	                    BUTTONMASK, GrabModeAsync, GrabModeSync, None, None);
	    }
	}

	private void updatenumlockmask() 
	{
	    XModifierKeymap *modmap;

	    numlockmask = 0;
	    modmap = XGetModifierMapping(AppDisplay.instance().dpy);
	    foreach_reverse(i; 0..7) {
	        if(numlockmask == 0) {
	            break;
	        }
	        //for(i = 7; numlockmask == 0 && i >= 0; --i) {
	        foreach_reverse(j; 0..modmap.max_keypermod-1) {
	            //for(j = modmap.max_keypermod-1; j >= 0; --j) {
	            if(modmap.modifiermap[i * modmap.max_keypermod + j] ==
	                    XKeysymToKeycode(AppDisplay.instance().dpy, XK_Num_Lock)) {
	                numlockmask = (1 << i);
	                break;
	            }
	        }
	    }
	    XFreeModifiermap(modmap);
	}

	void buttonpress(XEvent *e) 
	{
	    uint i, x, click;
	    auto arg = Arg(0);
	    Client *c;
	    Monitor *m;
	    XButtonPressedEvent *ev = &e.xbutton;

	    click = ClkRootWin;

	    /* focus monitor if necessary */
	    m = cast(Monitor*)wintomon(ev.window);

	    //if( (m !is null) && (m != selmon) ) {
	       //unfocus(selmon.sel, true);
	       //selmon = m;
	       //focus(null);
	    //}

	    if(ev.window == selmon.barwin) {
	        i = x = 0;
	        do {
	            x += TEXTW(tags[i]);
	        } while(ev.x >= x && ++i < LENGTH(tags));
	        if(i < LENGTH(tags)) {
	            click = ClkTagBar;
	            arg.ui = 1 << i;
	        } else if(ev.x < x + blw)
	            click = ClkLtSymbol;
	        else if(ev.x > selmon.ww - TEXTW(stext))
	            click = ClkStatusText;
	        else
	            click = ClkWinTitle;
	    } else {
	        c = wintoclient(ev.window);
	        if(c !is null) {
	            focus(c);
	            click = ClkClientWin;
	        }
	    }
	    foreach(ref const but; buttons) {
	        if(click == but.click &&
	                but.func !is null &&
	                but.button == ev.button &&
	                CLEANMASK(but.mask) == CLEANMASK(ev.state)) {
	            but.func(click == ClkTagBar && but.arg.i == 0 ? &arg : &but.arg);
	        }
	    }
	}
}