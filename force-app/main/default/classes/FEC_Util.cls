/**
 * @description Class tiện ích dùng chung cho dự án FEC.
 * @date 2026-01-26
 * @author DAT NGO
 */
public with sharing class FEC_Util {

    /**
     * @description Ghi log chuẩn hóa cho Apex.
     * @param methodName Tên phương thức gọi log.
     * @param message Nội dung cần log.
     */
    public static void log(String methodName, String message) {
        System.debug('[' + methodName + '] : ' + message);
    }

    /**
     * @description Xử lý và ném ngoại lệ chuẩn AuraHandledException.
     * @param methodName Tên phương thức xảy ra lỗi.
     * @param e Exception bắt được.
     */
    public static void throwAuraException(String methodName, Exception e) {
        String errorMsg = 'Error in ' + methodName + ': ' + e.getMessage();
        log(methodName, 'EXCEPTION: ' + errorMsg);
        throw new AuraHandledException(errorMsg);
    }

    /**
     * @description Kiểm tra quyền xóa của người dùng đối với một Object.
     * @param sObjType Loại SObject cần kiểm tra.
     */
    public static void checkDeletable(SObjectType sObjType) {
        if (sObjType == null) throw new AuraHandledException(System.Label.FEC_Error_Invalid_SObject_Prefix);
        if (!sObjType.getDescribe().isDeletable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
        }
    }

    /**
     * @description Lấy RecordType ID một cách an toàn (tránh Hardcode ID).
     * @param sObjName Tên Object.
     * @param developerName Developer Name của RecordType.
     * @return Id của RecordType.
     */
    public static Id getRecordTypeId(String sObjName, String developerName) {
        if (String.isBlank(sObjName)) return null;
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(sObjName)) {
            throw new AuraHandledException(System.Label.FEC_Error_Invalid_SObject_Prefix + ' ' + sObjName);
        }
        Schema.SObjectType t = gd.get(sObjName);
        try {
            Schema.DescribeSObjectResult dr = t.getDescribe();
            Map<String, Schema.RecordTypeInfo> rtMap = dr.getRecordTypeInfosByDeveloperName();
            if (!rtMap.containsKey(developerName)) return null;
            return rtMap.get(developerName).getRecordTypeId();
        } catch (Exception e) {
            log('getRecordTypeId', 'Failed to fetch record type for ' + sObjName + ' developerName=' + developerName + ' error=' + e.getMessage());
            throw new AuraHandledException(System.Label.FEC_Error_Invalid_RecordType);
        }
    }

    /**
     * Chuyển Object (từ JSON/Map) sang String an toàn
     * Trả về null nếu input null
     */
    public static String toString(Object val) {
        if (val == null) return null;
        String str = String.valueOf(val).trim();
        return String.isBlank(str) ? null : str;
    }

    /**
     * Chuyển Object sang Decimal an toàn
     * Hữu ích cho các cột Number 1..5
     */
    public static Decimal toDecimal(Object val) {
        if (val == null) return null;
        try {
            // Xử lý cả trường hợp số dạng chuỗi "100.50" hoặc số 100
            return Decimal.valueOf(String.valueOf(val).trim());
        } catch (Exception e) {
            return null; // Hoặc return 0 tùy logic business
        }
    }

    /**
     * Chuyển Timestamp (Long) sang DateTime
     * Dùng cho việc convert ngày tháng từ Excel
     */
    public static DateTime toDateTime(Object val) {
        if (val == null) return null;
        try {
            // Nếu là số Long (Timestamp)
            if (val instanceof Long || val instanceof Integer || val instanceof Decimal) {
                Long timeInMilli = (Long) val;
                return DateTime.newInstance(timeInMilli);
            }
            // Nếu lỡ Front-end gửi String ISO
            return (DateTime) JSON.deserialize('"' + val + '"', DateTime.class);
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Chuyển sang Boolean an toàn
     * (VD: "true", 1, true -> true)
     */
    public static Boolean toBoolean(Object val) {
        if (val == null) return false;
        String s = String.valueOf(val).toLowerCase();
        return s == 'true' || s == '1' || s == 'on' || s == 'yes';
    }

    // Tạo Exception
    public static void throwCreateException(String msg) {
        AuraHandledException e = new AuraHandledException(msg);
        e.setMessage(msg);
        throw e;
    }

    // Check number
    public static Boolean checkIsNumber(Object val) {
        if (val == null) return false; 
        String sVal = String.valueOf(val);
        if (String.isBlank(sVal)) return false; 
        try {
            Decimal.valueOf(sVal);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Lấy mốc 00:00:00 của ngày hôm nay
     */
    public static DateTime getStartOfToday() {
        return DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
    }

    /**
     * Lấy mốc 23:59:59 của ngày hôm nay
     */
    public static DateTime getEndOfToday() {
        return DateTime.newInstance(Date.today(), Time.newInstance(23, 59, 59, 999));
    }

    /**
     * Lấy phần chuỗi đứng trước một substring cụ thể.
     * Tương đương với logic @whatComesBeforeSubstring trong Pega.
     */
    public static String getBeforeSubstring(String input, String substring) {
        // Logic: if (input == null || substring == null) return "";
        if (String.isBlank(input) || String.isBlank(substring)) {
            return '';
        }
        
        // Logic: return input.contains(substring) ? input.split(substring)[0] : null;
        if (input.contains(substring)) {
            // Sử dụng substringBefore sẽ an toàn và nhanh hơn split (vì split dùng Regex)
            return input.substringBefore(substring); 
        }
        
        return null;
    }
}
