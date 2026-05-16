// NOC-2068 không có Stage → cần tạo Stage tương tự NOC-1617 (cùng CC01.01)
// Lấy Stage 1 và Stage 2 của NOC-1617

FEC_Nature_of_Case__c noc2068 = [SELECT Id, Name FROM FEC_Nature_of_Case__c WHERE Name = 'NOC-2068' LIMIT 1];
FEC_Nature_of_Case__c noc1617 = [SELECT Id, Name FROM FEC_Nature_of_Case__c WHERE Name = 'NOC-1617' LIMIT 1];

List<FEC_Case_Stage__c> noc1617Stages = [
    SELECT Id, Name, FEC_Code__c, FEC_Default_Stage__c, FEC_Active__c
    FROM FEC_Case_Stage__c WHERE FEC_Nature_of_Cases__c = :noc1617.Id
    ORDER BY Name ASC
];
System.debug('NOC-1617 stages=' + noc1617Stages.size());

// Check NOC-2068 đã có stage chưa
List<FEC_Case_Stage__c> noc2068Stages = [SELECT Id FROM FEC_Case_Stage__c WHERE FEC_Nature_of_Cases__c = :noc2068.Id];
if (!noc2068Stages.isEmpty()) {
    System.debug('NOC-2068 already has stages, skipping');
    return;
}

// Tạo Stage cho NOC-2068 dựa trên NOC-1617
Map<Id, Id> oldToNewStageId = new Map<Id, Id>();
List<FEC_Case_Stage__c> newStages = new List<FEC_Case_Stage__c>();
for (FEC_Case_Stage__c s : noc1617Stages) {
    FEC_Case_Stage__c newStage = new FEC_Case_Stage__c(
        Name = s.Name,
        FEC_Code__c = s.FEC_Code__c + '-NOC2068',
        FEC_Nature_of_Cases__c = noc2068.Id,
        FEC_Default_Stage__c = s.FEC_Default_Stage__c,
        FEC_Active__c = s.FEC_Active__c
    );
    newStages.add(newStage);
}
insert newStages;
for (Integer i = 0; i < noc1617Stages.size(); i++) {
    oldToNewStageId.put(noc1617Stages[i].Id, newStages[i].Id);
    System.debug('Created Stage: ' + newStages[i].Name + ' Id=' + newStages[i].Id);
}

// Copy Stage Changes
List<FEC_Stage_Change__c> noc1617Changes = [
    SELECT Id, FEC_Previous_Stage__c, FEC_Next_Stage__c, FEC_Team_User_Group__c,
           FEC_Action_Button__c, FEC_Active__c, FEC_Next_Queue__c
    FROM FEC_Stage_Change__c
    WHERE FEC_Previous_Stage__c IN :oldToNewStageId.keySet()
];
List<FEC_Stage_Change__c> newChanges = new List<FEC_Stage_Change__c>();
for (FEC_Stage_Change__c sc : noc1617Changes) {
    if (oldToNewStageId.containsKey(sc.FEC_Previous_Stage__c) && oldToNewStageId.containsKey(sc.FEC_Next_Stage__c)) {
        newChanges.add(new FEC_Stage_Change__c(
            FEC_Previous_Stage__c = oldToNewStageId.get(sc.FEC_Previous_Stage__c),
            FEC_Next_Stage__c = oldToNewStageId.get(sc.FEC_Next_Stage__c),
            FEC_Team_User_Group__c = sc.FEC_Team_User_Group__c,
            FEC_Action_Button__c = sc.FEC_Action_Button__c,
            FEC_Active__c = sc.FEC_Active__c,
            FEC_Next_Queue__c = sc.FEC_Next_Queue__c
        ));
    }
}
if (!newChanges.isEmpty()) {
    insert newChanges;
    System.debug('Created ' + newChanges.size() + ' Stage Changes');
}

// Copy Stage Screens
List<FEC_Stage_Screen__c> noc1617Screens = [
    SELECT Id, FEC_Case_Stage__c, FEC_Action_Button__c, FEC_User_Group__c,
           FEC_Field_Type__c, FEC_Active__c, FEC_Custom_Action_Button_Label__c
    FROM FEC_Stage_Screen__c
    WHERE FEC_Case_Stage__c IN :oldToNewStageId.keySet()
      AND FEC_Action_Button__c != null
];
List<FEC_Stage_Screen__c> newScreens = new List<FEC_Stage_Screen__c>();
for (FEC_Stage_Screen__c ss : noc1617Screens) {
    if (oldToNewStageId.containsKey(ss.FEC_Case_Stage__c)) {
        newScreens.add(new FEC_Stage_Screen__c(
            FEC_Case_Stage__c = oldToNewStageId.get(ss.FEC_Case_Stage__c),
            FEC_Action_Button__c = ss.FEC_Action_Button__c,
            FEC_User_Group__c = ss.FEC_User_Group__c,
            FEC_Field_Type__c = ss.FEC_Field_Type__c,
            FEC_Active__c = ss.FEC_Active__c,
            FEC_Custom_Action_Button_Label__c = ss.FEC_Custom_Action_Button_Label__c
        ));
    }
}
if (!newScreens.isEmpty()) {
    insert newScreens;
    System.debug('Created ' + newScreens.size() + ' Stage Screens');
}

System.debug('=== Setup complete for NOC-2068 ===');
