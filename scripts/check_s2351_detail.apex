List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, FEC_Stage_Name__c, FEC_Current_Case_Stage__c,
           FEC_Is_Submited__c, OwnerId, Owner.Name
    FROM Case WHERE FEC_ID_Search__c = 'S-2351' LIMIT 1
];
if (cases.isEmpty()) { System.debug('Not found'); return; }
Case c = cases[0];
System.debug('StageName=[' + c.FEC_Stage_Name__c + ']');

// Check FEC_Assignment__c của case này
List<FEC_Assignment__c> assignments = [
    SELECT Id, FEC_Assignment_Routing_Action__c, FEC_Manual__c, FEC_OwnerID__c, CreatedDate
    FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id ORDER BY CreatedDate ASC
];
for (FEC_Assignment__c a : assignments) {
    System.debug('Assignment stageName=[' + a.FEC_Assignment_Routing_Action__c + '] Manual=' + a.FEC_Manual__c + ' Owner=' + a.FEC_OwnerID__c);
}

// Test pattern
String sn = 'COF - General Flow - CC01.01-Nhân viên yêu cầu tiền phí - Stage 1';
System.debug('Pattern match=[' + Pattern.matches('(?i).*stage\\s*1.*', sn) + ']');
