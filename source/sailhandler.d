module sailhandler;

import core.thread;
import core.sync.condition;
import core.sync.mutex;
import std.conv, std.math;

import saillog, config;
import hardware.hardware;

class SailHandler {
	this() {
		SailLog.Notify("Starting ",typeof(this).stringof," instantiation in ",Thread.getThis().name," thread...");
		//Get configuration

		m_nMaxTension = Hardware.Get!Sail(DeviceID.Sail).max;

		m_bEnabled = true;
		m_stopCond = new Condition(new Mutex);

		//Start the thread
		m_thread = new Thread(&ThreadFunction);
		m_thread.name(typeof(this).stringof);
		m_thread.isDaemon(true);
		m_thread.start();

		SailLog.Success(typeof(this).stringof~" instantiated in ",Thread.getThis().name," thread");
	}
	~this(){
		SailLog.Critical("Destroying ",typeof(this).stringof);
		m_stop = true;
		m_stopCond.notifyAll;
		m_thread.join();
	}


	@property{
		bool enabled()const{return m_bEnabled;}
		void enabled(bool b){m_bEnabled = b;}
	}

private:
	Thread m_thread;
	shared bool m_stop = false;
	Condition m_stopCond;
	bool m_bEnabled;

	void ThreadFunction(){
		while(!m_stop){
			try{
				debug(thread){
					SailLog.Post("Running "~typeof(this).stringof~" thread");
				}
				if(m_bEnabled)
					AdjustSail();

			}catch(Throwable t){
				SailLog.Critical("In thread ",m_thread.name,": ",t.toString);
			}

			synchronized(m_stopCond.mutex) m_stopCond.wait(dur!("msecs")(Config.Get!uint("SailHandler", "Period")));
		}
	}

	/**
		Do a sail adjustment, to match the wind direction
	*/
	void AdjustSail(){
		float fWind = abs(Hardware.Get!WindDir(DeviceID.WindDir).value);
		auto sail = Hardware.Get!Sail(DeviceID.Sail);
		auto roll = Hardware.Get!Roll(DeviceID.Roll).value;

		if(fWind<25){
			sail.value = m_nMaxTension;
		}
		else{
			//Linear function
			sail.value = to!(typeof(sail.value))(m_nMaxTension-(m_nMaxTension-sail.min)*(fWind-25)/(180-25));
		}

		auto danger = Config.Get!float("SailHandler", "Danger");

		//Handling m_nMaxTension (safety max tension)
		if(abs(roll)>danger){
			ubyte nDelta = Config.Get!ubyte("SailHandler", "Delta");

			//Reduce max tension, minimum to sail.max/4
			if(m_nMaxTension-sail.max/4 >= nDelta)
				m_nMaxTension-=nDelta;
			else
				m_nMaxTension = sail.max/4;

			SailLog.Warning("Roll is too dangerous (",roll,"°), reducing sail max tension to ",m_nMaxTension);
		}
		else if(m_nMaxTension!=sail.max && abs(roll)<danger/2.0){
			ubyte nDelta = Config.Get!ubyte("SailHandler", "Delta");

			//Reduce max tension, minimum to sail.max/4
			if(sail.max - m_nMaxTension >= nDelta)
				m_nMaxTension+=nDelta;
			else
				m_nMaxTension = sail.max;

			SailLog.Notify("Roll seems safe (",roll,"°), raising sail max tension to ",m_nMaxTension);
		}
	}

	ubyte m_nMaxTension;
}







unittest {
	import decisioncenter;

	auto dec = DecisionCenter.Get();
	auto sh = dec.sailhandler;
	auto wind = Hardware.Get!WindDir(DeviceID.WindDir);
	auto sail = Hardware.Get!Sail(DeviceID.Sail);
	auto roll = Hardware.Get!Roll(DeviceID.Roll);

	assert(sh.enabled==true);

	dec.enabled = false;
	sh.enabled = false;
	Thread.sleep(dur!("msecs")(100));

	wind.isemulated = true;

	wind.value = 20;
	sh.AdjustSail();
	assert(sail.value==sail.max);

	wind.value = wind.max;
	sh.AdjustSail();
	assert(sail.value==sail.min);

	wind.value = wind.min;
	sh.AdjustSail();
	assert(sail.value==sail.min);

	//Roll danger
	roll.isemulated = true;
	roll.value = 0.0;
	auto delta = Config.Get!ubyte("SailHandler", "Delta");
	auto danger = Config.Get!float("SailHandler", "Danger");

	sh.AdjustSail();
	assert(sh.m_nMaxTension==sail.max);
	roll.value = danger+1.0;
	sh.AdjustSail();
	assert(sh.m_nMaxTension==sail.max-1*delta);
	sh.AdjustSail();
	assert(sh.m_nMaxTension==sail.max-2*delta);
	sh.AdjustSail();
	assert(sh.m_nMaxTension==sail.max-3*delta);
	roll.value = danger-1.0;
	sh.AdjustSail();
	assert(sh.m_nMaxTension==sail.max-3*delta);
	sh.AdjustSail();
	assert(sh.m_nMaxTension==sail.max-3*delta);
	roll.value = danger/2.0-1.0;
	sh.AdjustSail();
	assert(sh.m_nMaxTension==sail.max-2*delta);
	sh.AdjustSail();
	assert(sh.m_nMaxTension==sail.max-1*delta);
	sh.AdjustSail();
	sh.AdjustSail();
	sh.AdjustSail();
	assert(sh.m_nMaxTension==sail.max);
	roll.value = danger+1.0;
	foreach(int i ; 0..100)sh.AdjustSail();
	assert(sail.max/4-delta<=sh.m_nMaxTension && sh.m_nMaxTension<=sail.max/4);


	SailLog.Notify("SailHandler unittest done");
}