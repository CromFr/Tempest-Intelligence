module hardware.hardware;

import std.process;
import logger;

public import hardware.devices;

unittest
{ 
	import std.stdio;
	writeln("Starting hardware unittests");

	//HWAct test
	Sail s = Hardware.Get!Sail(DeviceID.Sail);
	s.isemulated = true;
	s.value = 8;
	assert(s.value == 8);

	s.isemulated = false;
	assert(s.value == 8);
	s.value = 42;
	assert(s.value == 42);

	//HWSens test
	Roll r = Hardware.Get!Roll(DeviceID.Roll);
	r.isemulated = true;
	r.value = 2.5;
	assert(r.value == 2.5);

	r.isemulated = false;
	assert(r.value != 2.5);//get via pipe
	try{
		r.value = 12.3;
		assert("Should have throwed");
	}catch(Exception e){

	}

	writeln("hardware unittests done");
}

class Hardware {

public:
	static T Get(T)(DeviceID id){
		if(m_inst is null) m_inst = new Hardware();

		if(id in m_inst.m_hwlist){
			return cast(T)(m_inst.m_hwlist[id]);
		}
		else{
			Logger.Critical("Hardware element not found : ", id);
			throw new Exception("Hardware element not found : "~id.stringof);
		}

	}

package:
	static Hardware GetClass(){
		if(m_inst is null) m_inst = new Hardware();
		return m_inst;
	}

	T QueryGet(T)(DeviceID id){
		return T.init;
	}

	void QuerySet(T)(DeviceID id, T data){

	}



private:
	this() {
		//Open Pipe

		HWElementsInit();

		Logger.Success(typeof(this).stringof~" instantiation");
	}

	void HWElementsInit(){
		m_hwlist[DeviceID.Sail] = new Sail();
		m_hwlist[DeviceID.Roll] = new Roll();
		//...
	}

	static __gshared Hardware m_inst;

	Pipe m_pipe;
	Object[DeviceID] m_hwlist;
	//HWWatchdog m_wd;

}