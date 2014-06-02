package com.cc14514.zoo;

import java.util.HashMap;
import java.util.Map;

public abstract class Config {
	public Map<String,String> publicConfig = new HashMap<String,String>();
	public Map<String,String> privateConfig = new HashMap<String,String>();
	public Map<String,String> privateConfigReg = new HashMap<String,String>();
	public abstract String getProperty(String key,String def);
}