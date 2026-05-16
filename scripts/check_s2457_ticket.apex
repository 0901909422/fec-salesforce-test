// Check case S-2457 - stage hiện tại và relevant tickets
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Current_Case_Stage__c,
           FEC_Current_Case_Stage__r.FEC_Code__c,
           FEC_Current_Case_Stage__r.Name
    FROM Case WHERE FEC_ID_Search__c = 'S-2457' LIMIT 1
];
if (cases.isEmpty()) { System.debug('Case not found'); return; }
Case c = cases[0];
System.debug('Case=' + c.FEC_ID_Search__c
    + ' CurrentStageId=' + c.FEC_Current_Case_Stage__c
    + ' StageCode=[' + c.FEC_Current_Case_Stage__r?.FEC_Code__c + ']'
    + ' StageName=[' + c.FEC_Current_Case_Stage__r?.Name + ']');

List<FEC_Relevant_Ticket__c> tickets = [
    SELECT Id, FEC_Stage_Name__c, CreatedDate
    FROM FEC_Relevant_Ticket__c
    WHERE FEC_Interaction__c = :c.Id
    ORDER BY CreatedDate DESC
];
String currentStage = c.FEC_Current_Case_Stage__r?.FEC_Code__c;
for (FEC_Relevant_Ticket__c t : tickets) {
    Boolean blocked = String.isNotBlank(t.FEC_Stage_Name__c) && t.FEC_Stage_Name__c != currentStage;
    System.debug('TicketId=' + t.Id
        + ' TicketStage=[' + t.FEC_Stage_Name__c + ']'
        + ' CaseStage=[' + currentStage + ']'
        + ' => ' + (blocked ? 'BLOCKED' : 'ALLOWED'));
}
