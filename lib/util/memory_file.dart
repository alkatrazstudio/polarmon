// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

class MemoryFile {
  static const int bufferLen = 10_000;
  final ByteData _bytes;
  int _length;
  var _pos = 0;

  MemoryFile({int? length, ByteBuffer? buffer}):
    _bytes = buffer == null ? ByteData(length ?? bufferLen) : ByteData.view(buffer),
    _length = buffer == null ? bufferLen : buffer.lengthInBytes;

  void writeInt(int x) {
    _bytes.setInt64(_pos, x);
    _pos += 8;
    _length = _pos;
  }

  void writeInt16(int x) {
    _bytes.setInt16(_pos, x);
    _pos += 2;
    _length = _pos;
  }

  void writeUint8(int x) {
    _bytes.setUint8(_pos, x);
    _pos += 1;
    _length = _pos;
  }

  void writeBool(bool x) {
    writeUint8(x ? 1 : 0);
  }

  void reset() {
    _pos = 0;
    _length = 0;
  }

  void seek(int pos) {
    if(pos >= 0)
      _pos = pos;
    else
      _pos = _length + pos;
  }

  int readInt() {
    var x = _bytes.getInt64(_pos);
    _pos += 8;
    return x;
  }

  int readInt16() {
    var x = _bytes.getInt16(_pos);
    _pos += 2;
    return x;
  }

  int readUint8() {
    var x = _bytes.getUint8(_pos);
    _pos += 1;
    return x;
  }

  bool readBool() {
    var x = readUint8();
    return x != 0;
  }

  Uint8List toUint8List() {
    var rawBytes = _bytes.buffer.asUint8List(0, _length);
    return rawBytes;
  }

  int get length => _length;
}
