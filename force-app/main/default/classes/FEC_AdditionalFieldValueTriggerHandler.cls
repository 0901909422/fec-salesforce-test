/**
 * @description Handler class xử lý logic cho FEC_MDM_AdditionalFieldListValueTrigger.
 * Tuân thủ nguyên tắc No SOQL/DML trong Loop và chuẩn Logging.
 * @date 2026-03-17
 * @author DAT NGO
 */
public with sharing class FEC_AdditionalFieldValueTriggerHandler {

    /**
     * @description Xử lý logic trước khi Insert bản ghi mới
     * @param newList Danh sách bản ghi Trigger.new
     */
    public static void handleBeforeInsert(List<FEC_MDM_Additional_Field_List_Value__c> newList) {
        System.debug('[handleBeforeInsert] START');
        
        checkDuplicateCodePerParent(newList, null);
        
        System.debug('[handleBeforeInsert] RETURN: void');
    }

    /**
     * @description Xử lý logic trước khi Update bản ghi hiện tại
     * @param newList Danh sách bản ghi Trigger.new
     * @param oldMap Map chứa bản ghi cũ Trigger.oldMap
     */
    public static void handleBeforeUpdate(List<FEC_MDM_Additional_Field_List_Value__c> newList, Map<Id, FEC_MDM_Additional_Field_List_Value__c> oldMap) {
        System.debug('[handleBeforeUpdate] START');
        
        checkDuplicateCodePerParent(newList, oldMap);
        
        System.debug('[handleBeforeUpdate] RETURN: void');
    }

    /**
     * @description Kiểm tra mã FEC_Code__c không được trùng lặp TRONG CÙNG MỘT trường cha (FEC_Additional_Field__c)
     * @param newList Danh sách bản ghi cần kiểm tra
     * @param oldMap Map bản ghi cũ (truyền null nếu là insert)
     */
    private static void checkDuplicateCodePerParent(List<FEC_MDM_Additional_Field_List_Value__c> newList, Map<Id, FEC_MDM_Additional_Field_List_Value__c> oldMap) {
        System.debug('[checkDuplicateCodePerParent] START');

        Set<Id> parentIds = new Set<Id>();
        Set<String> codesToCheck = new Set<String>();
        List<FEC_MDM_Additional_Field_List_Value__c> recordsToValidate = new List<FEC_MDM_Additional_Field_List_Value__c>();

        // 1. Gom nhóm ID của Parent và Code để chuẩn bị Query (Bulkify Pattern)
        for (FEC_MDM_Additional_Field_List_Value__c record : newList) {
            // SỬA: Dùng FEC_Additional_Field__c
            Boolean isInsert = (oldMap == null);
            Boolean isCodeChanged = !isInsert && record.FEC_Code__c != oldMap.get(record.Id).FEC_Code__c;
            Boolean isParentChanged = !isInsert && record.FEC_Additional_Field__c != oldMap.get(record.Id).FEC_Additional_Field__c;

            if (String.isNotBlank(record.FEC_Code__c) && record.FEC_Additional_Field__c != null && (isInsert || isCodeChanged || isParentChanged)) {
                parentIds.add(record.FEC_Additional_Field__c);
                codesToCheck.add(record.FEC_Code__c);
                recordsToValidate.add(record);
            }
        }

        if (recordsToValidate.isEmpty()) {
            System.debug('[checkDuplicateCodePerParent] RETURN: No records require validation');
            return;
        }

        // 2. Query dữ liệu hiện có trong Database
        Set<String> existingCompositeKeys = new Set<String>();
        
        // SỬA: Dùng FEC_Additional_Field__c
        for (FEC_MDM_Additional_Field_List_Value__c existingRecord : [
            SELECT Id, FEC_Code__c, FEC_Additional_Field__c 
            FROM FEC_MDM_Additional_Field_List_Value__c 
            WHERE FEC_Additional_Field__c IN :parentIds 
              AND FEC_Code__c IN :codesToCheck
        ]) {
            if (oldMap != null && oldMap.containsKey(existingRecord.Id)) {
                continue;
            }
            
            // Khóa kết hợp: ParentId-Code
            String compositeKey = String.valueOf(existingRecord.FEC_Additional_Field__c) + '-' + existingRecord.FEC_Code__c;
            existingCompositeKeys.add(compositeKey);
        }

        // 3. Set check trùng lặp chéo trong cùng Transaction
        Set<String> keysInCurrentTransaction = new Set<String>();

        // 4. So khớp và báo lỗi (addError)
        for (FEC_MDM_Additional_Field_List_Value__c record : recordsToValidate) {
            // SỬA: Dùng FEC_Additional_Field__c
            String compositeKey = String.valueOf(record.FEC_Additional_Field__c) + '-' + record.FEC_Code__c;

            if (existingCompositeKeys.contains(compositeKey) || keysInCurrentTransaction.contains(compositeKey)) {
                record.FEC_Code__c.addError('Mã Code này đã tồn tại trong danh sách của trường hiện tại. Vui lòng nhập Code khác.');
            } else {
                keysInCurrentTransaction.add(compositeKey);
            }
        }

        System.debug('[checkDuplicateCodePerParent] RETURN: Validation process completed');
    }
}