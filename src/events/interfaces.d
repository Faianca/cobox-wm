module events.interfaces;

import x11.Xlib;

interface EventInterface
{
    void listen(XEvent *e);
    //void addEvent();
}
