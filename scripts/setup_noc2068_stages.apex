// Setup Stage 1 và Stage 2 cho NOC-2068 (COF - CC01.01)
// Dùng NOC-1502 làm mẫu (cùng UserGroup CC;SP)

FEC_Nature_of_Case__c noc2068 = [SELECT Id, Name FROM FEC_Nature_of_Case__c WHERE Name = 'NOC-2068' LIMIT 1];
System.debug('NOC-2068 Id=' + noc2068.Id);

// Check NOC-1502 stages để làm mẫu
FEC_Nature_of_Case__c noc1502 = [SELECT Id, Name FROM FEC_Nature_of_Case__c WHERE Name = 'NOC-1502' LIMIT 1];
List<FEC_Case_Stage__c> templateStages = [
    SELECT Id, Name, FEC_Default_Stage__c, FEC_Active__c, FEC_Code__c
    FROM FEC_Case_Stage__c WHERE FEC_Nature_of_Cases__c = :noc1502.Id
    ORDER BY Name ASC
];
System.debug('Template stages from NOC-1502:');
for (FEC_Case_Stage__c s : templateStages) {
    System.debug('  Stage=' + s.Name + ' Code=' + s.FEC_Code__c + ' Default=' + s.FEC_Default_Stage__c);
}

// Check Stage Changes của NOC-1502
List<FEC_Stage_Change__c> templateChanges = [
    SELECT Id, FEC_Previous_Stage__r.Name, FEC_Next_Stage__r.Name, FEC_Team_User_Group__c,
           FEC_Action_Button__c, FEC_Action_Button__r.FEC_Code__c, FEC_Active__c, FEC_Next_Queue__c
    FROM FEC_Stage_Change__c
    WHERE FEC_Previous_Stage__c IN (SELECT Id FROM FEC_Case_Stage__c WHERE FEC_Nature_of_Cases__c = :noc1502.Id)
    ORDER BY FEC_Previous_Stage__r.Name ASC
];
System.debug('Template Stage Changes:');
for (FEC_Stage_Change__c sc : templateChanges) {
    System.debug('  SC ' + sc.FEC_Previous_Stage__r?.Name + ' → ' + sc.FEC_Next_Stage__r?.Name + ' Team=' + sc.FEC_Team_User_Group__c + ' Action=' + sc.FEC_Action_Button__r?.FEC_Code__c + ' Queue=' + sc.FEC_Next_Queue__c);
}

// Check FEC_Stage_Screen__c của NOC-1502 Stage 1
if (!templateStages.isEmpty()) {
    FEC_Case_Stage__c stage1 = null;
    for (FEC_Case_Stage__c s : templateStages) {
        if (s.FEC_Default_Stage__c) { stage1 = s; break; }
    }
    if (stage1 != null) {
        List<FEC_Stage_Screen__c> screens = [
            SELECT Id, FEC_Action_Button__r.FEC_Code__c, FEC_Action_Button__r.Name, FEC_User_Group__c, FEC_Field_Type__c
            FROM FEC_Stage_Screen__c WHERE FEC_Case_Stage__c = :stage1.Id AND FEC_Action_Button__c != null
        ];
        System.debug('Stage Screen buttons for Stage 1:');
        for (FEC_Stage_Screen__c ss : screens) {
            System.debug('  Button=' + ss.FEC_Action_Button__r?.FEC_Code__c + ' UserGroup=' + ss.FEC_User_Group__c + ' FieldType=' + ss.FEC_Field_Type__c);
        }
    }
}
