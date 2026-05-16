// Check Relevant Ticket records tạo hôm nay - xem FEC_Related_To__c và FEC_Interaction__c
List<FEC_Relevant_Ticket__c> rts = [
    SELECT Id, FEC_Relevant_Ticket_ID__c, FEC_Related_To__c, FEC_Interaction__c, 
           FEC_Related_To__r.FEC_ID_Search__c, FEC_Interaction__r.FEC_ID_Search__c,
           CreatedDate
    FROM FEC_Relevant_Ticket__c
    WHERE CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 20
];
System.debug('Total today: ' + rts.size());
for (FEC_Relevant_Ticket__c rt : rts) {
    System.debug('id=' + rt.Id 
        + ' relatedTo=' + rt.FEC_Related_To__c + '(' + rt.FEC_Related_To__r?.FEC_ID_Search__c + ')'
        + ' interaction=' + rt.FEC_Interaction__c + '(' + rt.FEC_Interaction__r?.FEC_ID_Search__c + ')'
    );
}
