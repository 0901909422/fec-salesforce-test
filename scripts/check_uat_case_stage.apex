// Check FEC_Case_Stage__c record a0D86000002ZEF3 ở UAT
List<FEC_Case_Stage__c> stages = [
    SELECT Id, Name, FEC_Code__c, FEC_Default_Stage__c, FEC_Active__c,
           FEC_Nature_of_Cases__r.Name
    FROM FEC_Case_Stage__c
    WHERE Id = 'a0D86000002ZEF3'
    LIMIT 1
];
if (!stages.isEmpty()) {
    FEC_Case_Stage__c s = stages[0];
    System.debug('Stage Id: ' + s.Id);
    System.debug('Stage Name: ' + s.Name);
    System.debug('Stage Code: ' + s.FEC_Code__c);
    System.debug('Default: ' + s.FEC_Default_Stage__c);
    System.debug('NOC: ' + s.FEC_Nature_of_Cases__r?.Name);
} else {
    System.debug('Stage not found');
}

// Check vài stages gần đây
List<FEC_Case_Stage__c> recentStages = [
    SELECT Id, Name, FEC_Code__c
    FROM FEC_Case_Stage__c
    ORDER BY CreatedDate DESC LIMIT 5
];
System.debug('=== Recent Stages ===');
for (FEC_Case_Stage__c s : recentStages) {
    System.debug('Id=' + s.Id + ' | Name=' + s.Name + ' | Code=' + s.FEC_Code__c);
}
