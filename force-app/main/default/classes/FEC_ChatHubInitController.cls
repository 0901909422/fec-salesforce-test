/** * FEC_ChatHubInitController
* Controller xử lý khởi tạo dữ liệu cho tích hợp ChatHub.
* @created      : 2025/12/03 long.nguyen.50
*/
public with sharing class FEC_ChatHubInitController {
    
    // Custom Metadata Type Developer Name
    private static final String CHATHUB_METADATA_DEV_NAME = 'ChatHub_Settings';
    // Todo: remove this comment when merge to uat
    private static final String CHATHUB_ENCRYPT_KEY = 'FEC_CHAT_HUB_2024';
    
    /** Lấy thông tin cấu hình ChatHub, kiểm tra quyền và tạo encrypted token.
    * @return strResult: Chuỗi thông tin (Username|URL|Token) hoặc 'false'
    */ 
    @AuraEnabled(cacheable=true)
    public static String getChatHubInfo() {
        // 1. Kiểm tra quyền truy cập của User
        if (!checkSystemAndUserAccess()) {
            return 'false';
        }

        // 2. Truy vấn cấu hình từ Custom Metadata
        FEC_SystemSetting__mdt chatHubSettings = getChatHubSettings();

        if (chatHubSettings == null || !chatHubSettings.FEC_ChatHubEnabled__c) {
            return 'false';
        }

        // 3. Chuẩn bị dữ liệu trả về
        String strUsername = UserInfo.getUserEmail().split('@')[0];
        String strChatHubUrl = chatHubSettings.FEC_ChatHubURL__c; 
        String strEncryptKey = chatHubSettings.FEC_ChatHubEncryptKey__c;
        String strSalt = chatHubSettings.FEC_ChatHubStaticSalt__c; 

        // 4. Thực hiện mã hóa Token
        String strUsernameEncrypted = buildEncryptedToken(strUsername, strEncryptKey, strSalt); 
        // String strUsernameEncrypted = '';
        // // Todo: remove this comment when merge to uat
        // String payload = '{"text": "' + strUsername.split('@')[0] + '","secretKey": "' + CHATHUB_ENCRYPT_KEY + '"}';
        // Map<String, String> header = new Map<String, String>{'X-API-KEY' => 'RkVDX1NBTEVTRk9SQ0U='};
        // HttpResponse res = FEC_Utils.sendRequest('POST', 'callout:FECredit_Service/archival/chathub/api/v1/crypto/encrypt',payload , header);
        // if (res != null && res.getStatusCode() == 200) {
        //    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        //     strUsernameEncrypted = (String) responseMap.get('data');
        // }
        // Định dạng trả về: username | urlChatHub | usernameEncrypted
        String strResult = strUsername + '|' + strChatHubUrl + '|' + strUsernameEncrypted;

        return strResult;
    }
    
    /** Kiểm tra Custom Permission và trạng thái Enable trong Metadata
    * @return isAllowed: Boolean
    * @created: 2025/12/03 long.nguyen.50
    */ 
    private static Boolean checkSystemAndUserAccess() {
        // Kiểm tra Custom Permission (Gán qua Permission Set)
        Boolean isAllowed = FeatureManagement.checkPermission('FEC_ChatHubAccess');

        // Kiểm tra xem record Metadata có tồn tại và đang được Enable không
        List<FEC_SystemSetting__mdt> listSettings = [
            SELECT Id, FEC_ChatHubEnabled__c 
            FROM FEC_SystemSetting__mdt 
            WHERE DeveloperName = :CHATHUB_METADATA_DEV_NAME 
            LIMIT 1
        ];
        Boolean isEnabled = !listSettings.isEmpty() && listSettings[0].FEC_ChatHubEnabled__c;
        return isAllowed && isEnabled;
    }

    /** * Lấy bản ghi Metadata Setting
    * @return FEC_SystemSetting__mdt record
    */ 
    private static FEC_SystemSetting__mdt getChatHubSettings() {
        return FEC_SystemSetting__mdt.getInstance(CHATHUB_METADATA_DEV_NAME);
    }
    
    /**
     * AES-256-GCM using Salesforce Managed IV
     * Output format: salt:iv:cipher (Base64)
     */
    private static String buildEncryptedToken(String strText, String strKeyB64, String strSaltB64) {
        try {
            /* ===== 1. PAYLOAD ===== */
            // Cắt domain email (giống Pega)
            String shortUsername = strText.contains('@') ? strText.substringBefore('@') : strText;
            
            // Timestamp: Hiện tại + 300s
            Long expiredTime = (System.currentTimeMillis() / 1000) + 300;
            
            String payload = shortUsername + '|' + String.valueOf(expiredTime);
            Blob data = Blob.valueOf(payload);
            /* ===== 2. KEY & SALT ===== */
            Blob aesKey = EncodingUtil.base64Decode(strKeyB64);
            /* ===== 3. ENCRYPT (Managed IV) ===== */
            // Salesforce tự sinh IV 12 bytes
            Blob encryptedWithIv = Crypto.encryptWithManagedIV('AES256-GCM', aesKey, data);

            /* ===== 4. TÁCH IV + CIPHER (FIX LỖI TẠI ĐÂY) ===== */
            String hex = EncodingUtil.convertToHex(encryptedWithIv);
            
            // Cấu trúc Hex từ SF: [0-2: Length=0c] [2-26: IV=12bytes] [26-End: Cipher]
            
            // BỎ QUA VIỆC PARSE Integer.valueOf('0x0c') -> GÂY LỖI
            // Ta biết chắc chắn IV dài 12 bytes = 24 ký tự Hex.
            
            // Lấy IV (Từ ký tự thứ 2 đến 26)
            String ivHex = hex.substring(2, 26);
            
            // Lấy Cipher (Từ ký tự thứ 26 đến hết)
            String cipherHex = hex.substring(26);
            
            /* ===== 5. OUTPUT ===== */
            Blob iv = EncodingUtil.convertFromHex(ivHex);
            Blob cipher = EncodingUtil.convertFromHex(cipherHex);
            
            String ivB64 = EncodingUtil.base64Encode(iv);
            String cipherB64 = EncodingUtil.base64Encode(cipher);
            
            // Format: iv:cipher
            return strSaltB64 + ':' + ivB64 + ':' + cipherB64;

        } catch (Exception e) {
            return '';
        }
    }
}