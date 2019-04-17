package hxdc.hxbit;

import hxbit.Serializer;

using Lambda;

import sys.net.Socket;
import hxbit.NetworkHost;

using haxe.Json;

class SocketClient extends NetworkClient {
	public var socket:Socket;

	var connected = false;

	public function new(host, s) {
		super(host);
		socket = s;
		connected = true;
	}

	public function doReadData() {
		socket.output.bigEndian = true;
		socket.input.bigEndian = true;
		var retVal = readData(socket.input, 5);
		return retVal;
	}

	override function error(msg:String) {
		socket.close();
		super.error(msg);
	}

	override function send(bytes:haxe.io.Bytes) {
		var output = socket.output;
		socket.output.bigEndian = true;
		socket.input.bigEndian = true;
		output.writeInt32(bytes.length);
		output.write(bytes);
		output.flush();
	}

	override function stop() {
		connected = false;
		super.stop();
		if (socket != null) {
			socket.close();
			socket = null;
		}
	}
}

class SocketHost extends NetworkHost {
	var connected = false;
	var listening = false;
	var clientSockets:Array<Socket> = [];
	var socket:Socket;

	public var enableSound:Bool = true;

	public function new() {
		super();
		isAuth = false;
	}

	override function dispose() {
		super.dispose();
		close();
	}

	function close() {
		if (socket != null) {
			socket.close();
			socket = null;
		}
		if (self != null) {
			self.stop();
		}
		listening = false;
		connected = false;
	}

	public function connect(host:sys.net.Host, port:Int, ?onConnect:Bool->Void) {
		close();
		isAuth = false;
		socket = new Socket();
		socket.output.bigEndian = true;
		try {
			socket.connect(host, port);
			var client = new SocketClient(this, socket);
			self = client;
			trace('Connected to $host:$port');
			// socket.waitForRead();
			connected = true;
			sys.thread.Thread.create(function() {
				while (this.connected) {
					for (socket in Socket.select([socket], [], []).read) {
						client.doReadData();
					}
				}
			});
			if (host.toString() == "127.0.0.1")
				enableSound = false;
			clients = [self];
			onConnect(true);
		} catch (exception:Dynamic) {
			trace("ERROR: " + exception);
			onConnect(false);
		}
	}

	public var allClients:Array<SocketClient> = [];

	public function wait(host:sys.net.Host, port:Int, ?onConnected:NetworkClient->Void) {
		close();
		isAuth = false;
		socket = new Socket();
		self = new SocketClient(this, null);
		socket.bind(host, port);
		socket.listen(10);
		socket.output.bigEndian = true;
		listening = true;

		sys.thread.Thread.create(function() {
			while (listening) {
				socket.waitForRead();
				var s = socket.accept();
				var c = new SocketClient(this, s);
				pendingClients.push(c);
				allClients.push(c);

				if (onConnected != null) {
					onConnected(c);
				}
			}
		});
		sys.thread.Thread.create(function() {
			while (listening) {
				if (allClients.length == 0)
					continue;

				for (socket in Socket.select(allClients.map(client -> client.socket), [], []).read) {
					var client = allClients.find(client -> client.socket == socket);
					client.doReadData();
				}
			}
		});

		isAuth = true;
	}

	public function offlineServer() {
		close();
		self = new SocketClient(this, null);
		isAuth = true;
	}
}
