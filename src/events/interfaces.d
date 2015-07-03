module events.interfaces;

import deimos.X11.Xlib;

interface EventInterface
{
    void listen(XEvent *e);
    //void addEvent();
}
