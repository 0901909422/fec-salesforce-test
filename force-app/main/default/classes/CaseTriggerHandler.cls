/** * CaseTriggerHandler
* Handles all business logic executed from the CaseTrigger.
* It includes logic to check for duplicate External Interaction IDs (Story 4).
* @created    : 2025/12/03 long.nguyen.50
* @modified   : 
*/ 
public with sharing class CaseTriggerHandler {

    // Set of External IDs for checking against existing records
    private Set<String> setExternalIDs = new Set<String>();

    /** * onBeforeInsert
    * Checks for duplicate External Interaction ID on new Case records.
    * @param listNewCases: List of new Case records being inserted.
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 
    */ 
    public void onBeforeInsert(List<Case> listNewCases) {
        // Comment: Thu thập tất cả External IDs từ các Case mới để kiểm tra bulk
        for (Case c : listNewCases) {
            if (String.isNotBlank(c.FEC_ExternalInteractionID__c)) {
                setExternalIDs.add(c.FEC_ExternalInteractionID__c);
            }
        }
        
        if (!setExternalIDs.isEmpty()) {
            checkDuplicateExternalID(listNewCases);
        }
    }

    /** * onBeforeUpdate
    * Checks for duplicate External Interaction ID if the field is changed during update.
    * @param listNewCases: List of new Case records after update.
    * @param mapOldCases: Map of old Case records before update.
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 
    */ 
    public void onBeforeUpdate(List<Case> listNewCases, Map<Id, Case> mapOldCases) {
        // Comment: Chỉ kiểm tra trùng lặp nếu External ID bị thay đổi hoặc mới được thêm vào.
        for (Case c : listNewCases) {
            Case oldCase = mapOldCases.get(c.Id);
            if (String.isNotBlank(c.FEC_ExternalInteractionID__c) && 
                c.FEC_ExternalInteractionID__c != oldCase.FEC_ExternalInteractionID__c) 
            {
                setExternalIDs.add(c.FEC_ExternalInteractionID__c);
            }
        }

        if (!setExternalIDs.isEmpty()) {
            // Tránh kiểm tra với chính bản ghi đang được Trigger
            checkDuplicateExternalID(listNewCases);
        }
    }
    
    /** * checkDuplicateExternalID
    * Performs SOQL query to find existing Cases with the same External Interaction ID.
    * Adds an error message to the field if a duplicate is found (Story 4 Acceptance).
    * @param listCasesToCheck: List of Case records being processed.
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 
    */ 
    private void checkDuplicateExternalID(List<Case> listCasesToCheck) {
        // Comment: Sử dụng Map để thay thế SOQL trong vòng Loop (Bulkification)
        Map<String, Case> mapExistingCases = new Map<String, Case>();
        
        // SOQL for Loop để tránh limit heap size (nếu có nhiều ID cần check)
        for (Case existingCase : [
            SELECT Id, CaseNumber, FEC_ExternalInteractionID__c
            FROM Case
            WHERE FEC_ExternalInteractionID__c IN :setExternalIDs
        ]) {
            // Loại bỏ chính bản ghi đang được Trigger khỏi danh sách trùng lặp
            if (mapExistingCases.isEmpty() || !mapExistingCases.containsKey(existingCase.FEC_ExternalInteractionID__c)) {
                mapExistingCases.put(existingCase.FEC_ExternalInteractionID__c, existingCase);
            }
        }

        // Comment: Duyệt qua các Case đang được xử lý để thêm lỗi nếu tìm thấy trùng lặp
        for (Case c : listCasesToCheck) {
            if (String.isNotBlank(c.FEC_ExternalInteractionID__c) && 
                mapExistingCases.containsKey(c.FEC_ExternalInteractionID__c)) {
                
                Case duplicateCase = mapExistingCases.get(c.FEC_ExternalInteractionID__c);
                
                // Tránh lỗi khi bản ghi đang được xử lý là bản ghi trùng lặp chính nó
                if (c.Id != duplicateCase.Id) {
                    // Tương tự Message Error trong FRD: External Interaction ID has already been used for another Pega Interaction <I-12345>.
                    String errorMessage = 'External Interaction ID has already been used for another Pega Interaction <' + duplicateCase.CaseNumber + '>. Please check and re-enter.';
                    c.FEC_ExternalInteractionID__c.addError(errorMessage);
                }
            }
        }
    }
}