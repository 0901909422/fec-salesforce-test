// Thay caseId bằng ID Case đang test
String caseId = 'YOUR_CASE_ID';

Case c = [
  SELECT Id, FEC_Current_Case_Stage__c, FEC_Current_Case_Stage__r.FEC_Code__c,
         FEC_Current_Case_Stage__r.FEC_Default_Stage__c, OwnerId, Owner.Name
  FROM Case WHERE Id = :caseId LIMIT 1
];
System.debug('Current Stage: ' + c.FEC_Current_Case_Stage__c + ' | Code: ' + c.FEC_Current_Case_Stage__r.FEC_Code__c);
System.debug('Owner: ' + c.Owner.Name);

// Xem tất cả Stage Change từ stage hiện tại
List<FEC_Stage_Change__c> changes = [
  SELECT Id, FEC_Previous_Stage__c, FEC_Next_Stage__c, FEC_Action_Button__c,
         FEC_Action_Button__r.FEC_Code__c, FEC_Action_Button__r.FEC_Type__c,
         FEC_Active__c, FEC_IsReverted__c
  FROM FEC_Stage_Change__c
  WHERE FEC_Previous_Stage__c = :c.FEC_Current_Case_Stage__c
];
System.debug('Stage Changes count: ' + changes.size());
for (FEC_Stage_Change__c sc : changes) {
  System.debug('  SC: actionBtn=' + sc.FEC_Action_Button__c
    + ' code=' + sc.FEC_Action_Button__r.FEC_Code__c
    + ' type=' + sc.FEC_Action_Button__r.FEC_Type__c
    + ' active=' + sc.FEC_Active__c
    + ' isReverted=' + sc.FEC_IsReverted__c);
}
