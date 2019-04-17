import tink.testrunner.*;
import tink.unit.*;
import tink.unit.Assert.assert;
import hxdc.hxbit.SocketHost;
import hxdc.NetworkObject;

using haxe.Json;
using tink.CoreApi;
using hxdc.sys.Registry;

class RunTests {
	public static var client = false;
	public static var server = false;

	static function main() {
		client = Sys.args()[0] == 'client';
		server = Sys.args()[0] == 'server';
		trace(Sys.args());
		Runner.run(TestBatch.make([new SerializationTests(), new NetworkSynchronizationTests()])).handle(Runner.exit);
	}
}

class SerializationTests {
	public function new() {}

	public function symetry() {
		var user = new User();
		var serializer = new hxbit.Serializer();
		var serializedUser = serializer.serialize(user);
		var deserializedUser = serializer.unserialize(serializedUser, User);
		trace(serializedUser);
		return assert(user.name == deserializedUser.name);
	}
}

class NetworkSynchronizationTests {
	public function new() {}

	static var HOST = new sys.net.Host("127.0.0.1");
	static var PORT = 6676;
	static var UID = 0;
	static var registered = false;

	public var host:SocketHost;

	@:timeout(1000000)
	public function test_server() {
		if (!RunTests.server)
			return Future.sync(assert(true));
		trace("test_server");
		host = new SocketHost();
		host.setLogger(function(msg) trace(msg));
		var trigger = Future.trigger();

		try {
			host.wait(HOST, PORT, function(c) {
				trace('Client connected: $c');
				c.sendMessage("Connected");
			});
			host.onMessage = function(c, userBytes:haxe.io.Bytes) {
				var serializer = new hxbit.Serializer();
				var user = serializer.unserialize(userBytes, User);
				var uid = user.uid;
				trace("Client identified (" + uid + ")");
				// var user = new User("Client From Server", uid);
				if (user.name != "Bob")
					user.changeName("Steve");
				trace({name: user.name, userId: user.userId, __uid: user.__uid}.stringify());
				if (!registered) {
					registered = true;
					user.enableReplication = true;
				}
				c.ownerObject = user;
				c.sync();

				haxe.Timer.delay(function() {
					trigger.trigger(assert(uid == 1));
				}, 10000);
			}
			trace("Server started.");

			trace("Live");
			host.makeAlive();
		} catch (e:Dynamic) {}

		return trigger.asFuture();
	}

	public function test_client() {
		if (!RunTests.client)
			return Future.sync(assert(true));
		trace("test_client");
		host = new SocketHost();
		host.setLogger(function(msg) trace(msg));
		var trigger = Future.trigger();
		trace("Connecting");
		var user = new User("Client");

		host.self.ownerObject = user;
		UID = user.uid;
		host.connect(HOST, PORT, function(b) {
			if (!b) {
				trace("Failed to connect to sever" + b);
				return;
			}
			trace("Connected to server");

			while (user.name.indexOf("Steve") == -1) {
				Sys.sleep(1);
				trace(haxe.Json.stringify(user));
				var serializer = new hxbit.Serializer();
				host.sendMessage(serializer.serialize(user));
				trace("Message sent: " + {name: user.name, userId: user.userId, __uid: user.__uid}.stringify());
				var latest = user.latest();
				if (latest != null)
					user = cast(latest);
				trace(Registry.objects);
				Sys.sleep(1);
			}
			haxe.Timer.delay(function() {
				trace(user.name);
				trigger.trigger(assert(user.name == "Steve"));
			}, 500);
		});
		return trigger.asFuture();
	}
}

class User extends NetworkObject {
	@:s public var name:String;
	@:s public var userId:String;
	public var uid:Int;

	public function new(name:String = null, uid = 0) {
		super();
		this.name = (name != null ? name : "Test") + "-" + Math.random() * 10000;
		this.userId = "Test-" + Math.random() * 10000;
		this.uid = uid != 0 ? uid : this.__uid;
		this.__uid = uid != 0 ? uid : this.__uid;
	}

	@:rpc public function changeName(name:String) {
		trace("Changing name from " + this.name + " to " + name);
		this.name = name;
	}
	
}
