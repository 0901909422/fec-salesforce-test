// tungnm37: check tất cả FEC_Business_Process__c để biết FEC_Code__c thực tế
List<FEC_Business_Process__c> bpList = [
    SELECT Id, Name, FEC_Code__c, FEC_Active__c
    FROM FEC_Business_Process__c
    ORDER BY Name
    LIMIT 50
];
for (FEC_Business_Process__c bp : bpList) {
    System.debug('BP Name: ' + bp.Name + ' | Code: ' + bp.FEC_Code__c + ' | Active: ' + bp.FEC_Active__c);
}
System.debug('Total: ' + bpList.size());
