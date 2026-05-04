// tungnm37: Trigger chặn xóa Relevant Ticket đã liên kết
trigger FEC_RelevantTicketTrigger on FEC_Relevant_Ticket__c (before delete) {
    if (Trigger.isBefore && Trigger.isDelete) {
        for (FEC_Relevant_Ticket__c rt : Trigger.old) {
            // Không cho xóa nếu đã có liên kết 2 chiều (cả FEC_Interaction__c và FEC_Related_To__c đều có giá trị)
            if (String.isNotBlank(rt.FEC_Interaction__c) && String.isNotBlank(rt.FEC_Related_To__c)) {
                rt.addError(System.Label.FEC_RelevantTicket_Cannot_Delete);
            }
        }
    }
}
