// Thay bằng Case ID đang test (lấy từ URL)
String caseId = 'YOUR_CASE_ID';

Case c = [
  SELECT Id, CaseNumber, FEC_Current_Case_Stage__c,
         FEC_Business_Process__c, FEC_Business_Process__r.FEC_Code__c,
         FEC_Actual_Nature_of_Case__c, FEC_Nature_of_Cases__c,
         FEC_Is_Submited__c, OwnerId, Owner.Name,
         FEC_Customer_Type__c
  FROM Case WHERE Id = :caseId LIMIT 1
];
System.debug('=== CASE ===');
System.debug('CaseNumber: ' + c.CaseNumber);
System.debug('CurrentStage: ' + c.FEC_Current_Case_Stage__c);
System.debug('BusinessCode: ' + c.FEC_Business_Process__r.FEC_Code__c);
System.debug('ActualNOC: ' + c.FEC_Actual_Nature_of_Case__c);
System.debug('NOC: ' + c.FEC_Nature_of_Cases__c);
System.debug('IsSubmited: ' + c.FEC_Is_Submited__c);

// Nếu stage null, check NOC có default stage không
if (c.FEC_Actual_Nature_of_Case__c != null) {
  String nocId = c.FEC_Actual_Nature_of_Case__c;
  List<FEC_Nature_of_Case__c> nocList = [
    SELECT Id, FEC_Business_Process__c, FEC_User_Group__c
    FROM FEC_Nature_of_Case__c WHERE Id = :nocId LIMIT 1
  ];
  if (!nocList.isEmpty()) {
    System.debug('NOC found: ' + nocList[0].Id + ' BP: ' + nocList[0].FEC_Business_Process__c);
    List<FEC_Case_Stage__c> stages = [
      SELECT Id, FEC_Code__c, FEC_Default_Stage__c, FEC_User_Group__c
      FROM FEC_Case_Stage__c
      WHERE FEC_Nature_of_Cases__c = :nocId
        AND FEC_Active__c = TRUE
        AND FEC_Default_Stage__c = TRUE
    ];
    System.debug('Default stages found: ' + stages.size());
    for (FEC_Case_Stage__c s : stages) {
      System.debug('  Stage: ' + s.Id + ' code=' + s.FEC_Code__c + ' userGroup=' + s.FEC_User_Group__c);
    }
    // Check Stage Change từ default stage
    if (!stages.isEmpty()) {
      List<FEC_Stage_Change__c> changes = [
        SELECT Id, FEC_Action_Button__c, FEC_Action_Button__r.FEC_Code__c,
               FEC_Active__c, FEC_IsReverted__c, FEC_Next_Stage__c
        FROM FEC_Stage_Change__c
        WHERE FEC_Previous_Stage__c = :stages[0].Id
          AND FEC_Active__c = TRUE AND FEC_IsReverted__c = false
      ];
      System.debug('Stage Changes from default stage: ' + changes.size());
      for (FEC_Stage_Change__c sc : changes) {
        System.debug('  SC: btn=' + sc.FEC_Action_Button__c + ' code=' + sc.FEC_Action_Button__r.FEC_Code__c);
      }
    }
  }
}
