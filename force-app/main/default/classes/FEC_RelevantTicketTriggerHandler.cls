// tungnm37: Handler class cho FEC_RelevantTicketTrigger - theo pattern các trigger khác
public without sharing class FEC_RelevantTicketTriggerHandler {

    public static void handleBeforeDelete(List<FEC_Relevant_Ticket__c> oldList) {
        for (FEC_Relevant_Ticket__c rt : oldList) {
            // Không cho xóa nếu đã có liên kết 2 chiều (cả FEC_Interaction__c và FEC_Related_To__c đều có giá trị)
            if (String.isNotBlank(rt.FEC_Interaction__c) && String.isNotBlank(rt.FEC_Related_To__c)) {
                rt.addError(System.Label.FEC_RelevantTicket_Cannot_Delete);
            }
        }
    }
}
