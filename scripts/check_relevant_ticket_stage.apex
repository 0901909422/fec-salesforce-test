// Kiểm tra stage của relevant tickets gần nhất
List<FEC_Relevant_Ticket__c> tickets = [
    SELECT Id, FEC_Stage_Name__c, FEC_Interaction__c,
           FEC_Interaction__r.FEC_ID_Search__c,
           FEC_Interaction__r.FEC_Current_Case_Stage__r.FEC_Code__c,
           CreatedDate
    FROM FEC_Relevant_Ticket__c
    ORDER BY CreatedDate DESC
    LIMIT 10
];
for (FEC_Relevant_Ticket__c t : tickets) {
    String caseStage = t.FEC_Interaction__r?.FEC_Current_Case_Stage__r?.FEC_Code__c;
    String ticketStage = t.FEC_Stage_Name__c;
    Boolean canDelete = ticketStage != null && ticketStage == caseStage;
    System.debug('TicketId=' + t.Id
        + ' CaseId=' + t.FEC_Interaction__c
        + ' CaseSearch=' + t.FEC_Interaction__r?.FEC_ID_Search__c
        + ' TicketStage=[' + ticketStage + ']'
        + ' CaseCurrentStage=[' + caseStage + ']'
        + ' CanDelete=' + canDelete);
}
