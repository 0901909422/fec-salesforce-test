// Reset case 00004724 về Stage 2 để test lại
FEC_Case_Stage__c stage2 = [
    SELECT Id, Name FROM FEC_Case_Stage__c
    WHERE FEC_Code__c LIKE '%CC01.01%Stage 2%NOC2068%'
    LIMIT 1
];
System.debug('Stage 2 Id=' + stage2.Id);

update new Case(
    Id = '500Az00000OJ1XFIA1',
    FEC_Is_Submited__c = true,
    FEC_Current_Case_Stage__c = stage2.Id
);
System.debug('Case reset to Stage 2');
