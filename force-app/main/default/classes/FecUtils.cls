public with sharing class FecUtils {
    public static final String MSG_FILE_ERR = 'Uploaded file contains errors';
    public static final String MSG_DUP_ERR  = 'Duplicate records found';
    public static final String MSG_SUCCESS  = 'Success';

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
}