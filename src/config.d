module config;
import deimos.X11.X;
import types;
import old;

enum MODKEY = Mod1Mask;

static immutable Layout[] layouts = [
    /* symbol            arrange function */
    { symbol:"[]=",      arrange:&tile },    /* first entry is default */
    { symbol:"><>",      arrange:null },    /* no layout function means floating behavior */
    { symbol:"[M]",      arrange:&monocle },
];

static immutable Rule[] rules = [
/* xprop(1):
	 *  WM_CLASS(STRING) = instance, klass
	 *  WM_NAME(STRING) = title
	 */
	/* klass      instance    title       tags mask     isfloating   monitor */
	{ "Gimp",     null,       null,       0,            true,        -1 },
	{ "Firefox",  null,       null,       1 << 8,       false,       -1 },
];

static immutable string normbordercolor = "#cccccc";
static immutable string normbgcolor     = "#000000";
static immutable string normfgcolor     = "#cccccc";
static immutable string selbordercolor  = "#cccccc";
static immutable string selbgcolor      = "#550077";
static immutable string selfgcolor      = "#eeeeee";

static immutable uint borderpx  = 1;        /* border pixel of windows */
static immutable uint snap      = 32;       /* snap pixel */
static immutable bool showbar           = true;     /* false means no bar */
static immutable bool topbar            = true;     /* false means bottom bar */
static bool running = true;

immutable string broken = "broken";
immutable string[] tags = [ "1", "2", "3", "4", "5", "6", "7", "8", "9" ];
static immutable string font            = "-*-terminus-medium-r-*-*-16-*-*-*-*-*-*-*";

/* commands */
static char[2] dmenumon = "0"; /* component of dmenucmd, manipulated in spawn() */
static immutable string[] dmenucmd = [ "dmenu_run", "-fn", font, "-nb", normbgcolor, "-nf", normfgcolor, "-sb", selbgcolor, "-sf", selfgcolor];
static immutable string[] termcmd = ["uxterm"];