// Thay bằng ID của Case S-0463
String caseId = 'YOUR_CASE_ID_S0463';

Case c = [
  SELECT Id, FEC_Current_Case_Stage__c, FEC_Current_Case_Stage__r.FEC_Code__c,
         FEC_Current_Case_Stage__r.FEC_Default_Stage__c,
         FEC_Business_Process__c, FEC_Business_Process__r.FEC_Code__c,
         FEC_Actual_Nature_of_Case__c, FEC_Nature_of_Cases__c,
         OwnerId, Owner.Name, FEC_Is_Submited__c
  FROM Case WHERE Id = :caseId LIMIT 1
];
System.debug('=== CASE INFO ===');
System.debug('CurrentStage: ' + c.FEC_Current_Case_Stage__c);
System.debug('StageCode: ' + c.FEC_Current_Case_Stage__r.FEC_Code__c);
System.debug('IsDefault: ' + c.FEC_Current_Case_Stage__r.FEC_Default_Stage__c);
System.debug('BusinessCode: ' + c.FEC_Business_Process__r.FEC_Code__c);
System.debug('ActualNOC: ' + c.FEC_Actual_Nature_of_Case__c);
System.debug('NOC: ' + c.FEC_Nature_of_Cases__c);
System.debug('IsSubmited: ' + c.FEC_Is_Submited__c);

// Xem Stage Change từ stage hiện tại
if (c.FEC_Current_Case_Stage__c != null) {
  List<FEC_Stage_Change__c> changes = [
    SELECT Id, FEC_Previous_Stage__c, FEC_Next_Stage__c,
           FEC_Action_Button__c, FEC_Action_Button__r.FEC_Code__c,
           FEC_Action_Button__r.FEC_Type__c, FEC_Active__c, FEC_IsReverted__c
    FROM FEC_Stage_Change__c
    WHERE FEC_Previous_Stage__c = :c.FEC_Current_Case_Stage__c
  ];
  System.debug('=== STAGE CHANGES from current stage (' + changes.size() + ') ===');
  for (FEC_Stage_Change__c sc : changes) {
    System.debug('  actionBtn=' + sc.FEC_Action_Button__c
      + ' code=' + sc.FEC_Action_Button__r.FEC_Code__c
      + ' active=' + sc.FEC_Active__c
      + ' isReverted=' + sc.FEC_IsReverted__c);
  }
} else {
  System.debug('CurrentStage is NULL - will use default stage lookup');
}
