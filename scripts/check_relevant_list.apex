// Check tất cả Relevant Tickets của case S-0452
Id caseId = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'S-0452' LIMIT 1].Id;
System.debug('Case S-0452 id=' + caseId);

List<FEC_Relevant_Ticket__c> rts = [
    SELECT Id, FEC_Relevant_Ticket_ID__c, FEC_Related_To__c, FEC_Interaction__c,
           FEC_Interaction__r.FEC_ID_Search__c, CreatedDate
    FROM FEC_Relevant_Ticket__c
    WHERE FEC_Related_To__c = :caseId
    ORDER BY CreatedDate DESC
];
System.debug('Relevant Tickets for S-0452: ' + rts.size());
for (FEC_Relevant_Ticket__c rt : rts) {
    System.debug('id=' + rt.Id + ' ticketId=' + rt.FEC_Relevant_Ticket_ID__c 
        + ' interaction=' + rt.FEC_Interaction__r?.FEC_ID_Search__c);
}
