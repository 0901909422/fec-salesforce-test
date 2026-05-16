// Test: clear channel NOC-1003 rồi set lại để trigger propagate
FEC_Nature_of_Case__c noc1003 = [SELECT Id, FEC_Channel__c FROM FEC_Nature_of_Case__c WHERE Name = 'NOC-1003' LIMIT 1];
String originalChannel = noc1003.FEC_Channel__c;
System.debug('Original channel: ' + originalChannel);

// Step 1: Clear channel
Database.update(new FEC_Nature_of_Case__c(Id = noc1003.Id, FEC_Channel__c = null));
System.debug('Cleared channel');

// Step 2: Set lại channel → trigger sẽ propagate
Database.update(new FEC_Nature_of_Case__c(Id = noc1003.Id, FEC_Channel__c = originalChannel));
System.debug('Set channel back: ' + originalChannel);

// Check kết quả
List<FEC_Nature_of_Case__c> siblings = [
    SELECT Name, FEC_Channel__c FROM FEC_Nature_of_Case__c
    WHERE Name IN ('NOC-1004', 'NOC-1005', 'NOC-1006', 'NOC-1007')
    ORDER BY Name
];
for (FEC_Nature_of_Case__c n : siblings) {
    System.debug(n.Name + ' | Channel: ' + n.FEC_Channel__c);
}
