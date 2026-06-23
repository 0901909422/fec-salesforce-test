/**
 * @description Tính "vân tay" nội dung (MD5) của các field nghiệp vụ trên Master Data Setting,
 *              dùng so sánh Live ↔ MDM nhanh & heap-safe (chỉ cần so 1 field hash thay vì 17 field).
 *              Chuẩn hóa giống hệt 2 bên: null→'', mọi giá trị → String.valueOf (Boolean→'true'/'false').
 *              KHÔNG đưa hash vào COMMON_FIELD_MAP — đây là metadata kỹ thuật, không phải field nghiệp vụ.
 * @author      DAT NGO
 * @date        2026-06-12
 */
public with sharing class FEC_MDMHashUtil {

    public static final String HASH_FIELD = 'FEC_Sync_Hash__c';

    // Bộ field định nghĩa "giống nhau" — THỨ TỰ CỐ ĐỊNH, dùng chung Live & MDM.
    // Đồng bộ với FEC_MasterDataReviewController.ComparisonWrapper.
    public static final List<String> HASH_FIELDS = new List<String>{
        'FEC_Section__c','FEC_Sub_Section__c','FEC_Sub_Section_Order__c','FEC_Sub_Section_Layout__c',
        'FEC_Sub_Section_Field_Layout__c','FEC_Field_Order_Display__c','FEC_Field_Status__c',
        'FEC_Field_Mandatory__c','FEC_Field_ReadOnly__c','FEC_Field_Editable__c','FEC_Field_Masking__c',
        'FEC_Field_Reverted__c','FEC_Applicable_Role__c','FEC_Editable_Role__c','FEC_Masking_Type__c',
        'FEC_Data_Integration_Mapping__c','FEC_Editable_User_Group__c'
    };

    /**
     * Tính hash hex 32 ký tự từ các field nghiệp vụ của 1 record.
     * @param rec record MDS (Live hoặc MDM) — phải đã query đủ HASH_FIELDS.
     */
    public static String compute(SObject rec) {
        List<String> parts = new List<String>();
        for (String f : HASH_FIELDS) {
            Object v;
            try {
                v = rec.get(f);
            } catch (Exception e) {
                v = null; // field không có trên record → coi như rỗng
            }
            parts.add(v == null ? '' : String.valueOf(v));
        }
        String canonical = String.join(parts, '|');
        Blob digest = Crypto.generateDigest('MD5', Blob.valueOf(canonical));
        return EncodingUtil.convertToHex(digest);
    }

    /**
     * Gán FEC_Sync_Hash__c cho danh sách record (dùng trong before-trigger).
     */
    public static void applyHash(List<SObject> records) {
        if (records == null) return;
        for (SObject rec : records) {
            rec.put(HASH_FIELD, compute(rec));
        }
    }
}