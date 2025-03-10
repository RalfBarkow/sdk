// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_util';
import 'dart:typed_data';

import 'package:expect/expect.dart';
import 'package:js/js.dart';

@JS()
external void eval(String code);

void createObjectTest() {
  Object o = newObject();
  Expect.isFalse(hasProperty(o, 'foo'));
  Expect.equals('bar', setProperty(o, 'foo', 'bar'));
  Expect.isTrue(hasProperty(o, 'foo'));
  Expect.equals('bar', getProperty(o, 'foo'));
}

// Unfortunately, lists do not currently compare identically.
void _expectListEquals(List<Object?> l, List<Object?> r) {
  Expect.equals(l.length, r.length);
  for (int i = 0; i < l.length; i++) {
    Expect.equals(l[i], r[i]);
  }
}

void evalAndConstructTest() {
  eval(r'''
    function JSClass(c) {
      this.c = c;
      this.sum = (a, b) => {
        return a + b + this.c;
      }
      this.list = ['a', 'b', 'c'];
    }
    globalThis.JSClass = JSClass;
  ''');
  Object gt = globalThis;
  Object constructor = getProperty(gt, 'JSClass');
  Object jsClass = callConstructor(constructor, ['world!']);
  Expect.equals('hello world!', callMethod(jsClass, 'sum', ['hello', ' ']));
  _expectListEquals(
      ['a', 'b', 'c'], getProperty(jsClass, 'list') as List<Object?>);
}

class Foo {
  final int i;
  Foo(this.i);
}

void dartObjectRoundTripTest() {
  Object o = newObject();
  setProperty(o, 'foo', Foo(4));
  Object foo = getProperty(o, 'foo')!;
  Expect.equals(4, (foo as Foo).i);
}

void deepConversionsTest() {
  // Dart to JS.
  // TODO(joshualitt): Consider supporting `null` in jsify.
  // Expect.isNull(dartify(jsify(null)));
  Expect.equals(true, dartify(jsify(true)));
  Expect.equals(2.0, dartify(jsify(2.0)));
  Expect.equals('foo', dartify(jsify('foo')));
  _expectListEquals(
      ['a', 'b', 'c'], dartify(jsify(['a', 'b', 'c'])) as List<Object?>);
  // TODO(joshualitt): Debug the cast failure.
  //List<Object?> l = Int8List.fromList(<int>[-128, 0, 127]);
  //_expectListEquals(l, dartify(jsify(l)) as Int8List);
  List<Object?> l = Uint8List.fromList([-1, 0, 255, 256]);
  _expectListEquals(l, dartify(jsify(l)) as Uint8List);
  l = Uint8ClampedList.fromList([-1, 0, 255, 256]);
  _expectListEquals(l, dartify(jsify(l)) as Uint8ClampedList);
  l = Int16List.fromList([-32769, -32768, 0, 32767, 32768]);
  _expectListEquals(l, dartify(jsify(l)) as Int16List);
  l = Uint16List.fromList([-1, 0, 65535, 65536]);
  _expectListEquals(l, dartify(jsify(l)) as Uint16List);
  l = Int32List.fromList([-2147483648, 0, 2147483647]);
  _expectListEquals(l, dartify(jsify(l)) as Int32List);
  l = Uint32List.fromList([-1, 0, 4294967295, 4294967296]);
  _expectListEquals(l, dartify(jsify(l)) as Uint32List);
  l = Float32List.fromList([-1000.488, -0.00001, 0.0001, 10004.888]);
  _expectListEquals(l, dartify(jsify(l)) as Float32List);
  l = Float64List.fromList([-1000.488, -0.00001, 0.0001, 10004.888]);
  _expectListEquals(l, dartify(jsify(l)) as Float64List);
  ByteBuffer buffer = Uint8List.fromList([0, 1, 2, 3]).buffer;
  _expectListEquals(buffer.asUint8List(),
      (dartify(jsify(buffer)) as ByteBuffer).asUint8List());
  ByteData byteData = ByteData.view(buffer);
  _expectListEquals(byteData.buffer.asUint8List(),
      (dartify(jsify(byteData)) as ByteData).buffer.asUint8List());

  // JS to Dart.
  eval(r'''
    globalThis.a = null;
    globalThis.b = 'foo';
    globalThis.c = ['a', 'b', 'c'];
    globalThis.d = 2.5;
    globalThis.e = true;
    globalThis.f = function () { return 'hello world'; };
    globalThis.invoke = function (f) { return f(); }
    // TODO(joshualitt): Fix int8 failure.
    // globalThis.int8Array = new Int8Array([-128, 0, 127]);
    globalThis.uint8Array = new Uint8Array([-1, 0, 255, 256]);
    globalThis.uint8ClampedArray = new Uint8ClampedArray([-1, 0, 255, 256]);
    globalThis.int16Array = new Int16Array([-32769, -32768, 0, 32767, 32768]);
    globalThis.uint16Array = new Uint16Array([-1, 0, 65535, 65536]);
    globalThis.int32Array = new Int32Array([-2147483648, 0, 2147483647]);
    globalThis.uint32Array = new Uint32Array([-1, 0, 4294967295, 4294967296]);
    globalThis.float32Array = new Float32Array([-1000.488, -0.00001, 0.0001,
        10004.888]);
    globalThis.float64Array = new Float64Array([-1000.488, -0.00001, 0.0001,
        10004.888]);
    globalThis.arrayBuffer = globalThis.uint8Array.buffer;
    globalThis.dataView = new DataView(globalThis.arrayBuffer);
  ''');
  Object gt = globalThis;
  Expect.isNull(getProperty(gt, 'a'));
  Expect.equals('foo', getProperty(gt, 'b'));
  _expectListEquals(['a', 'b', 'c'], getProperty<List<Object?>>(gt, 'c'));
  Expect.equals(2.5, getProperty(gt, 'd'));
  Expect.equals(true, getProperty(gt, 'e'));
  _expectListEquals(Uint8List.fromList([-1, 0, 255, 256]),
      getProperty(gt, 'uint8Array') as Uint8List);
  _expectListEquals(Uint8ClampedList.fromList([-1, 0, 255, 256]),
      getProperty(gt, 'uint8ClampedArray') as Uint8ClampedList);
  _expectListEquals(Int16List.fromList([-32769, -32768, 0, 32767, 32768]),
      getProperty(gt, 'int16Array') as Int16List);
  _expectListEquals(Uint16List.fromList([-1, 0, 65535, 65536]),
      getProperty<List<Object?>>(gt, 'uint16Array') as Uint16List);
  _expectListEquals(Int32List.fromList([-2147483648, 0, 2147483647]),
      getProperty(gt, 'int32Array') as Int32List);
  _expectListEquals(Uint32List.fromList([-1, 0, 4294967295, 4294967296]),
      getProperty(gt, 'uint32Array') as Uint32List);
  _expectListEquals(
      Float32List.fromList([-1000.488, -0.00001, 0.0001, 10004.888]),
      getProperty(gt, 'float32Array') as Float32List);
  _expectListEquals(
      Float64List.fromList([-1000.488, -0.00001, 0.0001, 10004.888]),
      getProperty(gt, 'float64Array') as Float64List);
  _expectListEquals(Uint8List.fromList([-1, 0, 255, 256]),
      (getProperty(gt, 'arrayBuffer') as ByteBuffer).asUint8List());
  _expectListEquals(Uint8List.fromList([-1, 0, 255, 256]),
      (getProperty(gt, 'dataView') as ByteData).buffer.asUint8List());

  // Confirm a function that takes a roundtrip remains a function.
  Expect.equals('hello world',
      callMethod(gt, 'invoke', <Object?>[dartify(getProperty(gt, 'f'))]));
}

void main() {
  createObjectTest();
  evalAndConstructTest();
  dartObjectRoundTripTest();
  deepConversionsTest();
}
