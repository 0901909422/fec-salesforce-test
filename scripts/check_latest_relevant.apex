// Tìm case mới nhất có relevant ticket để debug
List<FEC_Relevant_Ticket__c> tickets = [
    SELECT Id, FEC_Stage_Name__c, FEC_Interaction__c,
           FEC_Interaction__r.FEC_ID_Search__c,
           FEC_Interaction__r.FEC_Current_Case_Stage__c,
           FEC_Interaction__r.FEC_Current_Case_Stage__r.FEC_Code__c,
           CreatedDate
    FROM FEC_Relevant_Ticket__c
    ORDER BY CreatedDate DESC
    LIMIT 5
];
for (FEC_Relevant_Ticket__c t : tickets) {
    String caseStage = t.FEC_Interaction__r?.FEC_Current_Case_Stage__r?.FEC_Code__c;
    Boolean blocked = String.isNotBlank(t.FEC_Stage_Name__c) && t.FEC_Stage_Name__c != caseStage;
    System.debug('TicketId=' + t.Id
        + ' Case=' + t.FEC_Interaction__r?.FEC_ID_Search__c
        + ' TicketStage=[' + t.FEC_Stage_Name__c + ']'
        + ' CaseCurrentStage=[' + caseStage + ']'
        + ' => ' + (blocked ? 'SHOULD BE BLOCKED' : 'ALLOWED'));
}
