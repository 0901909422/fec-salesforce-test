public class TestEncryptWithManagedIV {
    /**
     * AES-256-GCM using Salesforce Managed IV
     * Output format: salt:iv:cipher (Base64)
     */
    public void buildEncryptedToken(String strText, String strKeyB64) {
        try {

            /* ===== 1. PAYLOAD ===== */

            String shortUsername = strText.substringBefore('@');
            Long expiredTime = (System.currentTimeMillis() / 1000) + 300;
            String payload = shortUsername + '|' + String.valueOf(expiredTime);
            Blob data = Blob.valueOf(payload);

            /* ===== 2. SALT (format alignment only) ===== */

            Blob salt = Crypto.generateDigest(
                'SHA256',
                Blob.valueOf(String.valueOf(Crypto.getRandomLong()))
            );

            String saltHex = EncodingUtil.convertToHex(salt).substring(0, 32);
            Blob finalSalt = EncodingUtil.convertFromHex(saltHex);

            /* ===== 3. AES KEY ===== */

            Blob aesKey = EncodingUtil.base64Decode(strKeyB64);

            /* ===== 4. ENCRYPT (Managed IV – BẮT BUỘC) ===== */

            Blob encryptedWithIv = Crypto.encryptWithManagedIV(
                'AES256-GCM',
                aesKey,
                data
            );

            /* ===== 5. TÁCH IV + CIPHER ===== */

            String hex = EncodingUtil.convertToHex(encryptedWithIv);

            // Byte 0 = IV length
            Integer ivLength = Integer.valueOf('0x' + hex.substring(0, 2));

            // IV bytes
            String ivHex = hex.substring(2, 2 + ivLength * 2);

            // Cipher + GCM Tag
            String cipherHex = hex.substring(2 + ivLength * 2);

            Blob iv = EncodingUtil.convertFromHex(ivHex);
            Blob cipher = EncodingUtil.convertFromHex(cipherHex);

            /* ===== 6. OUTPUT ===== */
            String token = EncodingUtil.base64Encode(finalSalt)
                + ':' + EncodingUtil.base64Encode(iv)
                + ':' + EncodingUtil.base64Encode(cipher);
            System.debug('### [FEC_ChatHub] Encryption token: ' + token);

        } catch (Exception e) {
            System.debug('### [FEC_ChatHub] Encryption Error: ' + e.getMessage());
        }
    }
}

// 3. Chuẩn bị dữ liệu trả về
String strUsername = 'long.nguyen.50';
String strEncryptKey = 'FEC_CHAT_HUB_2024'; 

TestEncryptWithManagedIV teiv = new TestEncryptWithManagedIV();
teiv.buildEncryptedToken(strUsername, strEncryptKey);