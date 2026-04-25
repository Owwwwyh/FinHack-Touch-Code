import 'dart:typed_data';
import 'dart:async';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

/// High-level NFC session for the sender (reader) role.
/// Implements the APDU exchange from docs/03-token-protocol.md §5.
class NfcSession {
  static const _aid = [0xF0, 0x54, 0x4E, 0x47, 0x50, 0x41, 0x59]; // F0 + "TNGPAY"
  static const _chunkSize = 240;
  static const _tapTimeout = Duration(seconds: 30);

  /// Phase A+B: SELECT AID and get receiver's public key.
  Future<Uint8List> selectAid() async {
    final availability = await FlutterNfcKit.nfcAvailability;
    if (!availability) throw NfcException('NFC not available');

    final tag = await FlutterNfcKit.poll(
      timeout: _tapTimeout,
      technology: NfcTechnology.isoDep,
    );

    // SELECT AID command
    final selectApdu = Uint8List.fromList([
      0x00, 0xA4, 0x04, 0x00, 0x07, ..._aid, 0x00
    ]);

    final response = await FlutterNfcKit.transceive(
      '00A40400 07F0544E47504159 00',
    );

    // Parse response: last 2 bytes are status, preceding bytes are receiver_pub
    final respBytes = _hexToBytes(response);
    if (respBytes.length < 34) throw NfcException('Invalid SELECT AID response');
    final status = (respBytes[respBytes.length - 2] << 8) | respBytes[respBytes.length - 1];
    if (status != 0x9000) throw NfcException('SELECT AID failed: 0x${status.toRadixString(16)}');

    return Uint8List.fromList(respBytes.sublist(0, respBytes.length - 2));
  }

  /// Phase C: Send JWS in chunks.
  Future<void> sendChunks(String jws, {Duration? timeout}) async {
    final data = Uint8List.fromList(jws.codeUnits);
    final totalChunks = (data.length / _chunkSize).ceil();

    for (int i = 0; i < totalChunks; i++) {
      final start = i * _chunkSize;
      final end = (start + _chunkSize > data.length) ? data.length : start + _chunkSize;
      final chunk = data.sublist(start, end);
      final p1 = i;
      final p2 = totalChunks;

      final apduHex = '80D0${p1.toRadixString(16).padLeft(2, '0')}'
          '${p2.toRadixString(16).padLeft(2, '0')}'
          '${chunk.length.toRadixString(16).padLeft(2, '0')}'
          '${_bytesToHex(chunk)}';

      await FlutterNfcKit.transceive(apduHex);
    }
  }

  /// Phase D: Get ack signature from receiver.
  Future<Uint8List> getAck() async {
    final response = await FlutterNfcKit.transceive('80C00000 40');
    final respBytes = _hexToBytes(response);
    return Uint8List.fromList(respBytes.sublist(0, respBytes.length - 2));
  }

  /// Full NFC tap flow: select AID, send JWS, get ack.
  Future<Uint8List> sendJws(String jws) async {
    await selectAid();
    await sendChunks(jws);
    return getAck();
  }

  Uint8List _hexToBytes(String hex) {
    hex = hex.replaceAll(' ', '').replaceAll('\n', '');
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }
}

class NfcException implements Exception {
  final String message;
  NfcException(this.message);
  @override
  String toString() => 'NfcException: $message';
}
