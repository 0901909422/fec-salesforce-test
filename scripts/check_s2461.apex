List<Case> cases = [
    SELECT Id, FEC_ID_Search__c,
           FEC_Current_Case_Stage__c,
           FEC_Current_Case_Stage__r.FEC_Code__c,
           FEC_Current_Case_Stage__r.Name,
           FEC_Stage_Name__c,
           FEC_Is_Submited__c
    FROM Case WHERE FEC_ID_Search__c IN ('S-2461', 'S-2268')
];
for (Case c : cases) {
    System.debug('Case=' + c.FEC_ID_Search__c
        + ' StageId=' + c.FEC_Current_Case_Stage__c
        + ' StageCode=[' + c.FEC_Current_Case_Stage__r?.FEC_Code__c + ']'
        + ' StageName=[' + c.FEC_Stage_Name__c + ']'
        + ' IsSubmited=' + c.FEC_Is_Submited__c);
}

// Check relevant tickets của S-2461
List<Case> c2461 = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'S-2461' LIMIT 1];
if (!c2461.isEmpty()) {
    List<FEC_Relevant_Ticket__c> tickets = [
        SELECT Id, FEC_Stage_Name__c, FEC_Interaction__c,
               FEC_Interaction__r.FEC_ID_Search__c,
               FEC_Interaction__r.FEC_Current_Case_Stage__r.FEC_Code__c,
               FEC_Related_To__r.FEC_ID_Search__c,
               CreatedDate
        FROM FEC_Relevant_Ticket__c
        WHERE FEC_Interaction__c = :c2461[0].Id OR FEC_Related_To__c = :c2461[0].Id
        ORDER BY CreatedDate DESC
    ];
    System.debug('=== Relevant Tickets of S-2461 ===');
    for (FEC_Relevant_Ticket__c t : tickets) {
        String caseStage = t.FEC_Interaction__r?.FEC_Current_Case_Stage__r?.FEC_Code__c;
        Boolean hasStage = String.isNotBlank(caseStage);
        Boolean blocked = hasStage && (String.isBlank(t.FEC_Stage_Name__c) || t.FEC_Stage_Name__c != caseStage);
        System.debug('TicketId=' + t.Id
            + ' Interaction=' + t.FEC_Interaction__r?.FEC_ID_Search__c
            + ' RelatedTo=' + t.FEC_Related_To__r?.FEC_ID_Search__c
            + ' TicketStage=[' + t.FEC_Stage_Name__c + ']'
            + ' CaseStage=[' + caseStage + ']'
            + ' => ' + (blocked ? 'BLOCKED' : 'ALLOWED'));
    }
}
