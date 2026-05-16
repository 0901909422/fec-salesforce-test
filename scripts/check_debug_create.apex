// Xem debug log gần nhất của createRelevantTicket
List<FEC_Relevant_Ticket__c> tickets = [
    SELECT Id, FEC_Stage_Name__c, FEC_Interaction__c,
           FEC_Interaction__r.FEC_ID_Search__c,
           FEC_Related_To__c,
           FEC_Related_To__r.FEC_ID_Search__c,
           CreatedDate
    FROM FEC_Relevant_Ticket__c
    ORDER BY CreatedDate DESC LIMIT 3
];
for (FEC_Relevant_Ticket__c t : tickets) {
    System.debug('TicketId=' + t.Id
        + ' Interaction(relatedToId)=' + t.FEC_Interaction__r?.FEC_ID_Search__c
        + ' RelatedTo(interactionId)=' + t.FEC_Related_To__r?.FEC_ID_Search__c
        + ' StageName=[' + t.FEC_Stage_Name__c + ']'
        + ' CreatedAt=' + t.CreatedDate);
}
