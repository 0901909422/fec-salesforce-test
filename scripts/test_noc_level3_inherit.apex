// Test kế thừa từ NOC level 3 (BP+Cat+SubCat, không có SubCode)
// Tìm NOC level 3 có con
List<FEC_Nature_of_Case__c> level3Nocs = [
    SELECT Id, Name, FEC_Business_Process__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Channel__c
    FROM FEC_Nature_of_Case__c
    WHERE FEC_Sub_Code__c = null AND FEC_Sub_Category__c != null
      AND FEC_Business_Process__c != null AND FEC_Category__c != null
    LIMIT 10
];

FEC_Nature_of_Case__c parentNoc = null;
List<FEC_Nature_of_Case__c> childNocs = new List<FEC_Nature_of_Case__c>();

for (FEC_Nature_of_Case__c n : level3Nocs) {
    List<FEC_Nature_of_Case__c> kids = [
        SELECT Id, Name, FEC_Channel__c FROM FEC_Nature_of_Case__c
        WHERE FEC_Business_Process__c = :n.FEC_Business_Process__c
          AND FEC_Category__c = :n.FEC_Category__c
          AND FEC_Sub_Category__c = :n.FEC_Sub_Category__c
          AND FEC_Sub_Code__c != null LIMIT 3
    ];
    if (!kids.isEmpty()) {
        parentNoc = n;
        childNocs = kids;
        break;
    }
}

if (parentNoc == null) { System.debug('No level 3 parent with children found'); return; }
System.debug('Parent: ' + parentNoc.Name + ' | Channel: ' + parentNoc.FEC_Channel__c);
for (FEC_Nature_of_Case__c c : childNocs) {
    System.debug('  Child: ' + c.Name + ' | Channel: ' + c.FEC_Channel__c);
}

// Lấy channel để test
List<FEC_Channel__c> channels = [SELECT Id FROM FEC_Channel__c WHERE FEC_Channel_Status__c = true LIMIT 1];
if (channels.isEmpty()) { System.debug('No active channel'); return; }

// Set channel cho parent → trigger propagate
String testChannel = channels[0].Id;
Database.update(new FEC_Nature_of_Case__c(Id = parentNoc.Id, FEC_Channel__c = testChannel));
System.debug('Set parent channel: ' + testChannel);

// Check children
List<FEC_Nature_of_Case__c> childrenAfter = [
    SELECT Name, FEC_Channel__c FROM FEC_Nature_of_Case__c
    WHERE Id IN :childNocs ORDER BY Name
];
for (FEC_Nature_of_Case__c c : childrenAfter) {
    System.debug('After - ' + c.Name + ' | Channel: ' + c.FEC_Channel__c);
}

// Cleanup
Database.update(new FEC_Nature_of_Case__c(Id = parentNoc.Id, FEC_Channel__c = null));
