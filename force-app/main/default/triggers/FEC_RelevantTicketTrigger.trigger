// tungnm37: Trigger chặn xóa Relevant Ticket đã liên kết
trigger FEC_RelevantTicketTrigger on FEC_Relevant_Ticket__c (before delete) {
    if (Trigger.isBefore && Trigger.isDelete) {
        FEC_RelevantTicketTriggerHandler.handleBeforeDelete(Trigger.old);
    }
}
