// Decode inContextOfRef để xem format
// Lấy từ URL: 1.eyJ0eXBlIjoic3RhbmRhcmRfX3JlY29yZFBhZ2UiLCJhdHRyaWJ1dGVzIjp7InJlY29yZElkIjoiNTAw
String encoded = '1.eyJ0eXBlIjoic3RhbmRhcmRfX3JlY29yZFBhZ2UiLCJhdHRyaWJ1dGVzIjp7InJlY29yZElkIjoiNTAwQXowMDAwME5DanM5SUFBRCJ9fQ';
// Remove "1." prefix
String base64Part = encoded.substringAfter('1.');
Blob decoded = EncodingUtil.base64Decode(base64Part);
System.debug(decoded.toString());
