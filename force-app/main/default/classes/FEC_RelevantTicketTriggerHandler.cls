// tungnm37: Handler class cho FEC_RelevantTicketTrigger - theo pattern các trigger khác
public without sharing class FEC_RelevantTicketTriggerHandler {

    public static void handleBeforeDelete(List<FEC_Relevant_Ticket__c> oldList) {
        // tungnm37 sửa: chặn xóa ticket được tạo từ stage trước đó
        Set<Id> caseIds = new Set<Id>();
        for (FEC_Relevant_Ticket__c rt : oldList) {
            if (String.isNotBlank(rt.FEC_Interaction__c)) {
                caseIds.add(rt.FEC_Interaction__c);
            }
        }
        if (caseIds.isEmpty()) return;

        Map<Id, Case> caseMap = new Map<Id, Case>(
            [SELECT Id, FEC_Current_Case_Stage__r.FEC_Code__c FROM Case WHERE Id IN :caseIds]
        );
        for (FEC_Relevant_Ticket__c rt : oldList) {
            if (String.isBlank(rt.FEC_Interaction__c)) continue;
            Case c = caseMap.get(rt.FEC_Interaction__c);
            if (c == null) continue;
            String currentStage = c.FEC_Current_Case_Stage__r?.FEC_Code__c;
            // tungnm37 sửa: null stage_name (ticket cũ) hoặc khác stage hiện tại → chặn xóa
            if (String.isBlank(rt.FEC_Stage_Name__c) || rt.FEC_Stage_Name__c != currentStage) {
                rt.addError(System.Label.FEC_RelevantTicket_Cannot_Delete);
            }
        }
    }
}
