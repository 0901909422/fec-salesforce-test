/**
 * @description Trigger duy nhất cho Object FEC_MDM_Additional_Field_List_Value__c
 * @date 2026-03-17
 * @author DAT NGO
 */
trigger FEC_MDM_AdditionalFieldListValueTrigger on FEC_MDM_Additional_Field_List_Value__c (before insert, before update) {
    
    // Luôn bọc trong isBefore để đảm bảo an toàn context
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            // 1. Kiểm tra Validate trước (chặn trùng lặp Code)
            FEC_AdditionalFieldValueTriggerHandler.handleBeforeInsert(Trigger.new);
            
            // 2. Chạy logic xử lý Status của bạn
            FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeInsert(Trigger.new);
        }
        
        if (Trigger.isUpdate) {
            // 1. Kiểm tra Validate trước (chặn trùng lặp Code)
            FEC_AdditionalFieldValueTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
            
            // 2. Chạy logic xử lý Status của bạn
            FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}