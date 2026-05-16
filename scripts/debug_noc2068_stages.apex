// Check NOC-2068 stages và routing assignments
FEC_Nature_of_Case__c noc = [
    SELECT Id, Name, FEC_Business_Process__c, FEC_Business_Process__r.FEC_Code__c,
           FEC_Active__c, FEC_User_Group__c
    FROM FEC_Nature_of_Case__c WHERE Name = 'NOC-2068' LIMIT 1
];
System.debug('NOC-2068 Id=' + noc.Id + ' BP=' + noc.FEC_Business_Process__r?.FEC_Code__c + ' Active=' + noc.FEC_Active__c + ' UserGroup=' + noc.FEC_User_Group__c);

// Check stages
List<FEC_Case_Stage__c> stages = [
    SELECT Id, Name, FEC_Default_Stage__c, FEC_Active__c
    FROM FEC_Case_Stage__c WHERE FEC_Nature_of_Cases__c = :noc.Id
    ORDER BY Name ASC
];
System.debug('Stages count=' + stages.size());
for (FEC_Case_Stage__c s : stages) {
    System.debug('  Stage Id=' + s.Id + ' Name=' + s.Name + ' Default=' + s.FEC_Default_Stage__c + ' Active=' + s.FEC_Active__c);
}

// Check routing assignments
List<FEC_Routing_Assignment__c> ras = [
    SELECT Id, FEC_Team__c, FEC_Queue__c FROM FEC_Routing_Assignment__c
    WHERE FEC_Nature_of_Cases__c = :noc.Id
];
System.debug('Routing Assignments count=' + ras.size());
for (FEC_Routing_Assignment__c ra : ras) {
    System.debug('  RA Team=' + ra.FEC_Team__c + ' Queue=' + ra.FEC_Queue__c);
}

// Check FEC_Stage_Change__c cho NOC-2068
List<FEC_Stage_Change__c> changes = [
    SELECT Id, FEC_Previous_Stage__r.Name, FEC_Next_Stage__r.Name, FEC_Team_User_Group__c,
           FEC_Action_Button__r.FEC_Code__c, FEC_Active__c
    FROM FEC_Stage_Change__c
    WHERE FEC_Previous_Stage__c IN (SELECT Id FROM FEC_Case_Stage__c WHERE FEC_Nature_of_Cases__c = :noc.Id)
    ORDER BY FEC_Previous_Stage__r.Name ASC
];
System.debug('Stage Changes count=' + changes.size());
for (FEC_Stage_Change__c sc : changes) {
    System.debug('  SC ' + sc.FEC_Previous_Stage__r?.Name + ' → ' + sc.FEC_Next_Stage__r?.Name + ' Team=' + sc.FEC_Team_User_Group__c + ' Action=' + sc.FEC_Action_Button__r?.FEC_Code__c + ' Active=' + sc.FEC_Active__c);
}
