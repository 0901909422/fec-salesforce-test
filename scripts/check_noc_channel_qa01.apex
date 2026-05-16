// Check NOC-2079 và NOC-1425 trên qa01
// Chạy: sf apex run --file scripts/check_noc_channel_qa01.apex --target-org fptqa01

List<FEC_Nature_of_Case__c> nocs = [
    SELECT Id, Name, FEC_Channel__c,
           FEC_Business_Process__c, FEC_Business_Process__r.Name,
           FEC_Category__c, FEC_Category__r.Name,
           FEC_Sub_Category__c, FEC_Sub_Category__r.Name,
           FEC_Sub_Code__c, FEC_Sub_Code__r.Name
    FROM FEC_Nature_of_Case__c
    WHERE Name IN ('NOC-2079', 'NOC-1425')
    ORDER BY Name
];
for (FEC_Nature_of_Case__c n : nocs) {
    System.debug('NOC=' + n.Name
        + ' Channel=[' + n.FEC_Channel__c + ']'
        + ' BP=' + n.FEC_Business_Process__r?.Name
        + ' Cat=' + n.FEC_Category__r?.Name
        + ' SubCat=' + n.FEC_Sub_Category__r?.Name
        + ' SubCode=' + n.FEC_Sub_Code__r?.Name);
}

// Check trigger có active không
List<ApexTrigger> triggers = [
    SELECT Id, Name, Status FROM ApexTrigger WHERE Name = 'FEC_NatureOfCaseTrigger'
];
System.debug('Trigger: ' + (triggers.isEmpty() ? 'NOT FOUND' : triggers[0].Name + ' Status=' + triggers[0].Status));

// Check handler class có tồn tại không
List<ApexClass> classes = [
    SELECT Id, Name FROM ApexClass WHERE Name = 'FEC_NatureOfCaseTriggerHandler'
];
System.debug('Handler class: ' + (classes.isEmpty() ? 'NOT FOUND' : 'EXISTS'));
