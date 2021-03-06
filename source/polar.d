module polar;

import saillog;

import std.string;
import std.file;
import std.algorithm;

import vibe.data.json;



struct Polar {

    this(float[float] curve){
        m_curve = curve;
        m_left = true;
        m_right = true;
    }
    
    this(in string filename){
        this(getDataFromFile(filename));
    }
    
    
    /**
        Get value asssociated to a key. If value doesn't exist, interpolate the value.
    */
    float getValue(float key) const{
        float _key = (key + 360.0) % 360.0;
        
        //Return value only if this side is allowed
        if( (_key<180.0 && m_right) || (_key>=180 && m_left) ){
            float value = m_curve.get(_key, -1.0);
            //If value isn't in the table, we interpolate it
            if(value == -1.0){
                value = interpolate(_key);
            }
            return value;
        }
        
        return 0;
    }
    
    /**
        Interpolate a value associatied to the given key
    */
    float interpolate(float key) const{

        float key_prev = minPos(m_curve.keys)[0]; //TODO : buggy line. curve is []
        float val_prev = m_curve[key_prev];
        
        float key_next = minPos!("a > b")(m_curve.keys)[0];
        float val_next = m_curve[key_next];
        
        foreach(index, value ; m_curve){
            
            //find previous key
            if(index<key && index>key_prev){
                key_prev = index;
                val_prev = value;
            }
            //find next key
            else if(index>key && index<key_next){
                key_next = index;
                val_next = value;
            }
        }
        
        //interpolate value
        float value = val_prev + (key - key_prev) * (val_next - val_prev) / (key_next - key_prev);
        
        //return value
        return value;
    }
    
    /**
        Add new value if the key doesn't exist. Change the value if the key altready exist.
    */
    void setValue(float key, float value){
        float _key = (key + 360.0) % 360.0;
        m_curve[_key] = value;
    }
    
    /**
        Enable and/or disable sides of the curve.
        Doesn't override curve value.
    */
    void setSide(bool left = true, bool right = true){
        m_left = left;
        m_right = right;
    }
    
private :
    float m_curve[float];
    
    bool m_left;
    bool m_right;

    /**
        Get points of the curve from Json file.
        Format : 
            [
                {
                    "key": float_key_1,
                    "value" : float_value_2
                },
                ...
                {
                    "key" : float_key_N,
                    "value" : float_value_N
                }
            ]
    */
    float[float] getDataFromFile(in string filename){
        float curve[float];
        try{
            string jsonText = readText(filename);
            Json json = parseJsonString(jsonText);
            foreach(Json el ; json){
                curve[to!float(el.key)] = to!float(el.value);
            }
        }
        catch(Exception e){
            SailLog.Warning("Error while parsing polar curve file "~filename~" : " , e);
        }
        
        return curve;
    }
    
    
    unittest {
        import std.math;
    
        float[float] values = [0.0:0.0, 90.0:0.5, 180.0:1.0];    
        Polar p = Polar(values);
        
        //Given values
        assert(p.getValue(0.0) == 0.0);
        assert(p.getValue(90.0) == 0.5);
        assert(p.getValue(180.0) == 1.0);
        
        //Extrapolated values
        assert(abs(p.getValue(22.5) - 0.125) <0.001);
        assert(abs(p.getValue(45.0) - 0.25) <0.001);
        assert(abs(p.getValue(135.0) - 0.75) <0.001);
        
        p.setValue(45.0, 0.0);
        
        assert(abs(p.getValue(22.42) - 0) <0.0001);
        assert(abs(p.getValue(67.5) - 0.25) <0.001);
        
        
        SailLog.Notify("Polar unittest done");
    }

}