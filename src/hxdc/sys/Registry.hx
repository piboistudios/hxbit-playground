package hxdc.sys;

import hxbit.Serializable;

using hxdc.sys.Registry;

class Registry {
	public static var objects:Map<String, Serializable> = new Map<String, Serializable>();

	public static function registryKey(object:Serializable) {
		return '${object.getCLID()}-${object.__uid}';
	}

	public static function latest(object:Serializable) {
		var key = object.registryKey();
		if (objects.exists(key))
			return objects[key];
		else
			return object;
	}

	public static function update(object:Serializable) {
		objects.set(object.registryKey(), object);
		return object.latest();
	}

	public static function drop(object:Serializable) {
		var key = object.registryKey();
		if (objects.exists(key)) {
			objects.remove(key);
		}
	}
}
