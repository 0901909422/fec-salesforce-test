// Check case S-2947 trên QA - đang ở Stage 1 sau Revert
String caseId = '';

List<Case> caseBySearch = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'S-3168' LIMIT 1];
if (!caseBySearch.isEmpty()) caseId = caseBySearch[0].Id;
else { System.debug('S-3168 not found'); return; }

List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Is_Submited__c,
           FEC_Current_Case_Stage__c, FEC_Current_Case_Stage__r.Name,
           FEC_Current_Case_Stage__r.FEC_Default_Stage__c
    FROM Case WHERE Id = :caseId LIMIT 1
];
if (cases.isEmpty()) { System.debug('Not found'); return; }
Case c = cases[0];
System.debug('Case: ' + c.FEC_ID_Search__c);
System.debug('FEC_Is_Submited__c: ' + c.FEC_Is_Submited__c);
System.debug('Current Stage: ' + c.FEC_Current_Case_Stage__r?.Name);
System.debug('Is Default Stage: ' + c.FEC_Current_Case_Stage__r?.FEC_Default_Stage__c);

// Check latest routing history
List<FEC_Routing_Action_History__c> histories = [
    SELECT Id, FEC_Routing_Action__c, FEC_IsReverted__c,
           FEC_Previous_Stage__c, FEC_Next_Stage__c,
           FEC_Next_Stage__r.FEC_Default_Stage__c,
           CreatedDate
    FROM FEC_Routing_Action_History__c
    WHERE FEC_Case__c = :caseId
    ORDER BY CreatedDate DESC LIMIT 3
];
System.debug('=== ROUTING HISTORY ===');
for (FEC_Routing_Action_History__c h : histories) {
    System.debug('Action=' + h.FEC_Routing_Action__c + ' | IsReverted=' + h.FEC_IsReverted__c
        + ' | NextStage.DefaultStage=' + h.FEC_Next_Stage__r?.FEC_Default_Stage__c
        + ' | NextStage=' + h.FEC_Next_Stage__c
        + ' | CurrentStage=' + c.FEC_Current_Case_Stage__c
        + ' | Match=' + (h.FEC_Next_Stage__c == c.FEC_Current_Case_Stage__c));
}

// Simulate lockApiLwcsAfterRevertToDefaultStage logic
Boolean lockApiLwcs = false;
if (!histories.isEmpty() && 'Revert'.equals(histories[0].FEC_Routing_Action__c)) {
    FEC_Routing_Action_History__c hRevert = histories[0];
    lockApiLwcs = hRevert.FEC_Next_Stage__c != null
        && hRevert.FEC_Next_Stage__c == c.FEC_Current_Case_Stage__c
        && hRevert.FEC_Next_Stage__r != null
        && hRevert.FEC_Next_Stage__r.FEC_Default_Stage__c == true;
}
System.debug('lockApiLwcsAfterRevertToDefaultStage = ' + lockApiLwcs);
System.debug('isSubmited (after fix) = ' + (c.FEC_Is_Submited__c == true && lockApiLwcs != true));
