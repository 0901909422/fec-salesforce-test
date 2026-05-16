List<Case> c2461 = [SELECT Id, FEC_ID_Search__c, FEC_Current_Case_Stage__r.FEC_Code__c FROM Case WHERE FEC_ID_Search__c = 'S-2461' LIMIT 1];
if (c2461.isEmpty()) return;

// Ticket
List<FEC_Relevant_Ticket__c> tickets = [
    SELECT Id, FEC_Stage_Name__c, CreatedDate
    FROM FEC_Relevant_Ticket__c WHERE FEC_Interaction__c = :c2461[0].Id
    ORDER BY CreatedDate DESC
];
System.debug('Case stage now: ' + c2461[0].FEC_Current_Case_Stage__r?.FEC_Code__c);
for (FEC_Relevant_Ticket__c t : tickets) {
    System.debug('Ticket created=' + t.CreatedDate + ' stage_name=[' + t.FEC_Stage_Name__c + ']');
}

// Routing history - xem khi nào case được route sang stage 1
List<FEC_Routing_Action_History__c> hist = [
    SELECT FEC_Stage_Name__c, FEC_Submitted_On__c, FEC_Routing_Action__c
    FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :c2461[0].Id
    ORDER BY FEC_Submitted_On__c ASC
];
System.debug('=== Routing History ===');
for (FEC_Routing_Action_History__c h : hist) {
    System.debug('Action=' + h.FEC_Routing_Action__c + ' Stage=[' + h.FEC_Stage_Name__c + '] At=' + h.FEC_Submitted_On__c);
}
