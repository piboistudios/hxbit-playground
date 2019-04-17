package hxdc;

using hxdc.sys.Registry;

class NetworkObject implements hxbit.NetworkSerializable {
	public function alive() {
		this.update();
	}
    public function networkAllow(op:hxbit.NetworkSerializable.Operation, propId:Int, client:hxbit.NetworkSerializable):Bool {
		return true;
	}
}
