// tungnm37: check FEC_Business_Process__c có FEC_Code__c = COF/GSR không
List<FEC_Business_Process__c> bpList = [
    SELECT Id, Name, FEC_Code__c, FEC_Active__c
    FROM FEC_Business_Process__c
    WHERE FEC_Code__c IN ('COF', 'GSR')
    LIMIT 20
];
System.debug('=== Business Process COF/GSR ===');
for (FEC_Business_Process__c bp : bpList) {
    System.debug('Name: ' + bp.Name + ' | Code: ' + bp.FEC_Code__c + ' | Active: ' + bp.FEC_Active__c);
}

// Check thêm: Stage Name có chứa COF/GSR không
List<FEC_Case_Stage__c> stageList = [
    SELECT Id, Name, FEC_Nature_of_Cases__c, FEC_Nature_of_Cases__r.FEC_Business_Process__r.FEC_Code__c
    FROM FEC_Case_Stage__c
    WHERE Name LIKE '%COF%' OR Name LIKE '%GSR%'
    LIMIT 10
];
System.debug('=== Case Stage COF/GSR ===');
for (FEC_Case_Stage__c s : stageList) {
    System.debug('Stage: ' + s.Name + ' | BP Code: ' + s.FEC_Nature_of_Cases__r?.FEC_Business_Process__r?.FEC_Code__c);
}
