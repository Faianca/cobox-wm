module config;
import deimos.X11.X;
import types;
import old;
import theme.layout;

enum MODKEY = Mod1Mask;

static immutable Layout[] layouts = [
    /* symbol            arrange function */
    { symbol:"><>",      arrange:null },  /* no layout function means floating behavior */
    { symbol:"[]=",      arrange:&tile },    /* first entry is default */
    { symbol:"[M]",      arrange:&monocle },
];

static immutable Rule[] rules = [
/* xprop(1):
	 *  WM_CLASS(STRING) = instance, klass
	 *  WM_NAME(STRING) = title
	 */
	/* klass      instance    title       tags mask     isfloating   monitor */
	{ "xterm",     null,       null,       1 << 8,        false,  -1 },
	//{ "Firefox",  null,       null,       1 << 8,       false,       -1 },
];

static immutable string normbordercolor = "#cccccc";
static immutable string normbgcolor     = "#000000";
static immutable string normfgcolor     = "#cccccc";
static immutable string selbordercolor  = "#cccccc";
static immutable string selbgcolor      = "#FF0000";
static immutable string selfgcolor      = "#eeeeee";

static immutable uint borderpx  = 0;        /* border pixel of windows */
static immutable uint snap      = 32;       /* snap pixel */
static immutable bool showbar           = true;     /* false means no bar */
static immutable bool topbar            = true;     /* false means bottom bar */
static bool running = true;

immutable string broken = "broken";
immutable string[] tags = [ "asterix", "obelix", "idefix", "avoranfix", "logs" ];
static immutable string font            = "-*-terminus-medium-r-*-*-16-*-*-*-*-*-*-*";

/* commands */
static char[2] dmenumon = "0"; /* component of dmenucmd, manipulated in spawn() */
static immutable string[] dmenucmd = [ "dmenu_run", "-fn", font, "-nb", normbgcolor, "-nf", normfgcolor, "-sb", selbgcolor, "-sf", selfgcolor];
static immutable string[] termcmd = ["uxterm"];

/* layout(s) */
static immutable float mfact      = 0.55; /* factor of master area size [0.05..0.95] */
static immutable int nmaster      = 1;    /* number of clients in master area */
static immutable bool resizehints = true; /* true means respect size hints in tiled resizals */