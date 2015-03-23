module monitor;
//
//class Monitor
//{
//	void arrange(Monitor *m) 
//	{
//		if(m) {
//			showhide(m.stack);
//		} else foreach(m; mons.range) {
//			showhide(m.stack);
//		}
//		if(m) {
//			arrangemon(m);
//			restack(m);
//		} else foreach(m; mons.range) {
//			arrangemon(m);
//		}
//	}
//	
//	void arrangemon(Monitor *m) 
//	{
//		m.ltsymbol = m.lt[m.sellt].symbol;
//		
//		if(m.lt[m.sellt].arrange)
//			m.lt[m.sellt].arrange(m);
//	}
//
//	void attach(Client *c) 
//	{
//		c.next = c.mon.clients;
//		c.mon.clients = c;
//	}
//	
//	void attachstack(Client *c) 
//	{
//		c.snext = c.mon.stack;
//		c.mon.stack = c;
//	}
//
//}