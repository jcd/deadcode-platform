module deadcode.platform.linuxlinetrace;

// Tracewrapper by Adam D. Ruppe
version (linux):

import core.runtime;

class WrappedTraceHandler : Throwable.TraceInfo {
	Throwable.TraceInfo ti;
	this(Throwable.TraceInfo ti) {
		this.ti = ti;
	}

	int opApply(scope int delegate(ref const(char[])) dg) const {
		return opApply( (ref size_t, ref const(char[]) buf)
			{ return dg(buf); });
	}

	int opApply(scope int delegate(ref size_t, ref const(char[])) dg) const 
	{
		// disable the custom tracehandler while we're in here
		// to avoid any recursive calls
		auto backToIt = Runtime.traceHandler;
		Runtime.traceHandler = null;
		scope(exit) Runtime.traceHandler = backToIt;
		return opApplyInternal(dg, ti);
	}

	private int opApplyInternal(T)(scope int delegate(ref size_t, ref const(char[])) dg, T ti)
	{
		int ret = 0;
		foreach(size_t i, const(char[]) tmpbuf; ti) {
			const(char)[] b = tmpbuf;
			// the address is in brackets right at the end
			if(b.length > 2 && b[$-1] == ']') {
				int idx;
				inner: for(idx = cast(int) b.length - 1; idx > 0; idx--)
					if(b[idx] == '[') {
						idx++;
						break inner;
					}

				if(idx) {
					auto addr = b[idx .. $-1];

					try {
						string pretty;

						import std.process;
						auto exe = execute(["addr2line", "-e", Runtime.args[0], addr]);

						if(exe.status == 0 && exe.output.length && exe.output[0] != '?') {
							pretty = exe.output[0 .. $-1];
							version(hide_names)
								b = pretty;
							else
								b = b[0 .. idx] ~ pretty ~ b[$-1 .. $];
						} else {
							version(hide_names)
								continue;
						}
					} catch(Exception e) {
						// failure isn't a big deal to me
					}
				}
			}
			ret = dg(i, b);
			if(ret) break;
		}

		return ret;
	}

	unittest
	{
		import deadcode.test;
		auto h = new WrappedTraceHandler(null);

		enum testTrace = "./deadcode-platform-test-unittest(_D4core7runtime18runModuleUnitTestsUZ19unittestSegvHandlerUNbiPS4core3sys5posix6signal9siginfo_tPvZv+0x38)[0x9079d0]";
		enum testV = 42;

		struct MockTraceInfo
		{
			int opApply(scope int delegate(ref size_t, ref const(char[])) dg) const 
			{
				auto r = dg(testV, testTrace);
				return r;
			}
		}


		int cb(ref size_t v, ref const(char[]) msg)
		{
			Assert(testV, v);
			AssertContains(msg.idup, "deadcode-platform-test-unittest");			
		}
	
		MockTraceInfo mock;
		int res = h.opApplyInternal(cb, mock);

		Assert(testV, res);
	}

	override string toString() const {
		string s = ti.toString();
		return s ~ "\ncool\n";
	}
}

Throwable.TraceInfo handler(void* ptr) {
	return new WrappedTraceHandler(defaultTraceHandler(ptr));
}

static this() {
	Runtime.traceHandler = &handler;
}
