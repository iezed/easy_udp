import 'dart:async';
import 'dart:io';
import 'package:async/async.dart';

/// EasyUDPSocket is a wrapper over RawDatagramSocket
/// to make life easier.
class EasyUDPSocket {
  final RawDatagramSocket rawSocket;
  final StreamQueue _eventQueue;

  /// create an EasyUDPSocket with a RawDatagramSocket
  EasyUDPSocket(this.rawSocket) : _eventQueue = StreamQueue(rawSocket);

  /// create an EasyUDPSocket and bind to host:port
  static Future<EasyUDPSocket> bind(dynamic host, int port,
      {bool reuseAddress = true, bool reusePort = false, int ttl = 1}) async {
    final socket = await RawDatagramSocket.bind(host, port,
        reuseAddress: reuseAddress, reusePort: reusePort, ttl: ttl);
    return EasyUDPSocket(socket);
  }

  /// create an EasyUDPSocket and bind to random port.
  static Future<EasyUDPSocket> bindRandom(dynamic host,
      {bool reuseAddress = true, bool reusePort = false, int ttl = 1}) {
    return bind(host, 0, reuseAddress: reuseAddress, reusePort: reusePort, ttl: ttl);
  }

  /// receive a Datagram from the socket.
  Future<Datagram> receive({int? timeout, bool explode = false}) {
    final completer = Completer<Datagram>.sync();
    if (timeout != null) {
      Future.delayed(Duration(milliseconds: timeout)).then((_) {
        if (!completer.isCompleted) {
          if (explode) {
            completer.completeError('EasyUDP: Receive Timeout');
          } else {
            var result;
            completer.complete(result);
          }
        }
      });
    }
    Future.microtask(() async {
      while ((await _eventQueue.peek) != RawSocketEvent.read) {
        await _eventQueue.next;
      }
      if (!completer.isCompleted) {
        await _eventQueue.next;
        completer.complete(rawSocket.receive());
      }
    });
    return completer.future;
  }

  /// send some data with this socket.
  Future<int> send(List<int> buffer, dynamic address, int port) async {
    InternetAddress addr;
    if (address is InternetAddress) {
      addr = address;
    } else if (address is String) {
      addr = (await InternetAddress.lookup(address))[0];
    } else {
      throw 'address must be either an InternetAddress or a String';
    }
    return rawSocket.send(buffer, addr, port);
  }

  /// use `sendBack` to send message to where a Datagram comes from.
  /// This is a shorthand of socket.send(somedata, datagram.address, datagram.port);
  int sendBack(Datagram datagram, List<int> buffer) {
    return rawSocket.send(buffer, datagram.address, datagram.port);
  }

  /// close the socket.
  Future<void> close() async {
    rawSocket.close();
    while ((await _eventQueue.next) != RawSocketEvent.closed) {
      continue;
    }
  }
}
