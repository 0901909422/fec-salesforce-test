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
}
