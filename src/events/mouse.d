module events.mouse;


import events.interfaces;
import kernel;
import old;
import config;
import types;
import cboxapp;
import gui.cursor;
import monitor;

import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;

import std.stdio;
import std.math;
import std.algorithm;

enum BUTTONMASK = ButtonPressMask | ButtonReleaseMask;
enum MOUSEMASK = ButtonPressMask | ButtonReleaseMask | PointerMotionMask;

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

class MouseEvents : EventInterface
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
	
	void addEvent()
	{

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

void movemouse(const Arg *arg) 
{
    writeln("yoo");
    int x, y, ocx, ocy, nx, ny;
    Client *c;
    Monitor *m;
    XEvent ev;
    Time lasttime = 0;

    c = selmon.sel;

    if(!c) {
        return;
    }

    if(c.isfullscreen) /* no support moving fullscreen windows by mouse */
        return;

    restack(selmon);
    ocx = c.x;
    ocy = c.y;
    if(XGrabPointer(AppDisplay.instance().dpy,
                    rootWin,
                    false,
                    MOUSEMASK,
                    GrabModeAsync,
                    GrabModeAsync,
                    None,
                    cursor[CurMove].cursor,
                    CurrentTime) != GrabSuccess) {
        return;
    }

    if(!getrootptr(&x, &y)) {
        return;
    }

    do {
        XMaskEvent(AppDisplay.instance().dpy, MOUSEMASK|ExposureMask|SubstructureRedirectMask, &ev);
        switch(ev.type) {
            case ConfigureRequest:
            case Expose:
            case MapRequest:
                writeln(ev.type);
                //handler[ev.type](&ev);
                break;
            case MotionNotify:

                if ((ev.xmotion.time - lasttime) <= (1000 / 60))
                    continue;
                lasttime = ev.xmotion.time;

                nx = ocx + (ev.xmotion.x - x);
                ny = ocy + (ev.xmotion.y - y);
                if(nx >= selmon.wx && nx <= selmon.wx + selmon.ww
                        && ny >= selmon.wy && ny <= selmon.wy + selmon.wh) {
                    if(abs(selmon.wx - nx) < snap)
                        nx = selmon.wx;
                    else if(abs((selmon.wx + selmon.ww) - (nx + WIDTH(c))) < snap)
                        nx = selmon.wx + selmon.ww - WIDTH(c);
                    if(abs(selmon.wy - ny) < snap)
                        ny = selmon.wy;
                    else if(abs((selmon.wy + selmon.wh) - (ny + HEIGHT(c))) < snap)
                        ny = selmon.wy + selmon.wh - HEIGHT(c);
                    if(!c.isfloating && selmon.lt[selmon.sellt].arrange
                            && (abs(nx - c.x) > snap || abs(ny - c.y) > snap))
                        togglefloating(null);
                }

                if(!selmon.lt[selmon.sellt].arrange || c.isfloating)
                    resize(c, nx, ny, c.w, c.h, true);
                break;
            default :
                break;
        }
    } while(ev.type != ButtonRelease);
    XUngrabPointer(AppDisplay.instance().dpy, CurrentTime);

    if((m = recttomon(c.x, c.y, c.w, c.h)) != selmon) {
        sendmon(c, m);
        selmon = m;
        focus(null);
    }
}

void resizemouse(const Arg *arg) 
{
    int ocx, ocy, nw, nh;
    Client *c;
    Monitor *m;
    XEvent ev;
    Time lasttime = 0;

    c = selmon.sel;
    if(!c) {
        return;
    }

    if(c.isfullscreen) /* no support resizing fullscreen windows by mouse */
        return;

    restack(selmon);
    ocx = c.x;
    ocy = c.y;

    if(XGrabPointer(AppDisplay.instance().dpy, rootWin, false, MOUSEMASK, GrabModeAsync, GrabModeAsync,
                    None, cursor[CurResize].cursor, CurrentTime) != GrabSuccess)
        return;
    
    XWarpPointer(AppDisplay.instance().dpy, None, c.win, 0, 0, 0, 0, c.w + c.bw - 1, c.h + c.bw - 1);
    do {
        XMaskEvent(AppDisplay.instance().dpy, MOUSEMASK|ExposureMask|SubstructureRedirectMask, &ev);
        switch(ev.type) {
            case ConfigureRequest:
            case Expose:
            case MapRequest:
                handler[ev.type](&ev);
                break;
            case MotionNotify:
                if ((ev.xmotion.time - lasttime) <= (1000 / 60))
                    continue;
                lasttime = ev.xmotion.time;

                nw = max(ev.xmotion.x - ocx - 2 * c.bw + 1, 1);
                nh = max(ev.xmotion.y - ocy - 2 * c.bw + 1, 1);
                if(c.mon.wx + nw >= selmon.wx && c.mon.wx + nw <= selmon.wx + selmon.ww
                        && c.mon.wy + nh >= selmon.wy && c.mon.wy + nh <= selmon.wy + selmon.wh) {
                    if(!c.isfloating && selmon.lt[selmon.sellt].arrange
                            && (abs(nw - c.w) > snap || abs(nh - c.h) > snap))
                        togglefloating(null);
                }
                if(!selmon.lt[selmon.sellt].arrange || c.isfloating)
                    resize(c, c.x, c.y, nw, nh, true);
                break;
            default :
                break;
        }
    } while(ev.type != ButtonRelease);
    XWarpPointer(AppDisplay.instance().dpy, None, c.win, 0, 0, 0, 0, c.w + c.bw - 1, c.h + c.bw - 1);
    XUngrabPointer(AppDisplay.instance().dpy, CurrentTime);
    while(XCheckMaskEvent(AppDisplay.instance().dpy, EnterWindowMask, &ev)) {}
    m = recttomon(c.x, c.y, c.w, c.h);
    if(m != selmon) {
        sendmon(c, m);
        selmon = m;
        focus(null);
    }
}