// Check stages có Code CC01.01
List<FEC_Case_Stage__c> stages = [
    SELECT Id, Name, FEC_Code__c, FEC_Nature_of_Cases__c, FEC_Nature_of_Cases__r.Name,
           FEC_Default_Stage__c, FEC_Active__c
    FROM FEC_Case_Stage__c
    WHERE FEC_Code__c LIKE '%CC01.01%'
    ORDER BY Name ASC
];
System.debug('Stages with CC01.01 = ' + stages.size());
for (FEC_Case_Stage__c s : stages) {
    System.debug('  Stage=' + s.Name + ' NOC=' + s.FEC_Nature_of_Cases__r?.Name + ' Default=' + s.FEC_Default_Stage__c + ' Active=' + s.FEC_Active__c);
    
    // Check Stage Change
    List<FEC_Stage_Change__c> changes = [
        SELECT Id, FEC_Previous_Stage__r.Name, FEC_Next_Stage__r.Name, FEC_Team_User_Group__c, FEC_Active__c
        FROM FEC_Stage_Change__c WHERE FEC_Previous_Stage__c = :s.Id
    ];
    System.debug('    Stage Changes=' + changes.size());
    for (FEC_Stage_Change__c sc : changes) {
        System.debug('    → ' + sc.FEC_Next_Stage__r?.Name + ' Team=' + sc.FEC_Team_User_Group__c + ' Active=' + sc.FEC_Active__c);
    }
    
    // Check Stage Screen
    List<FEC_Stage_Screen__c> screens = [
        SELECT Id, FEC_Action_Button__r.FEC_Code__c, FEC_User_Group__c, FEC_Active__c
        FROM FEC_Stage_Screen__c WHERE FEC_Case_Stage__c = :s.Id AND FEC_Action_Button__c != null
    ];
    System.debug('    Stage Screens=' + screens.size());
    for (FEC_Stage_Screen__c ss : screens) {
        System.debug('    Button=' + ss.FEC_Action_Button__r?.FEC_Code__c + ' UserGroup=' + ss.FEC_User_Group__c + ' Active=' + ss.FEC_Active__c);
    }
}
