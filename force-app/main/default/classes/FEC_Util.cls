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
        if (!sObjType.getDescribe().isDeletable()) {
            throw new AuraHandledException('Bạn không có quyền xóa bản ghi này.');
        }
    }

    /**
     * @description Lấy RecordType ID một cách an toàn (tránh Hardcode ID).
     * @param sObjName Tên Object.
     * @param developerName Developer Name của RecordType.
     * @return Id của RecordType.
     */
    public static Id getRecordTypeId(String sObjName, String developerName) {
        return Schema.getGlobalDescribe().get(sObjName).getDescribe().getRecordTypeInfosByDeveloperName().get(developerName).getRecordTypeId();
    }
}
