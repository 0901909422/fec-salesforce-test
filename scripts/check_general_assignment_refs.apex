// tungnm37: check Apex classes/triggers còn reference FEC_General_Assignment__c trên org
List<ApexClass> classes = [
    SELECT Id, Name
    FROM ApexClass
    WHERE Name LIKE '%GeneralAssignment%'
       OR Name LIKE '%General_Assignment%'
    LIMIT 50
];
System.debug('=== ApexClass with GeneralAssignment in name ===');
System.debug('Count: ' + classes.size());
for (ApexClass c : classes) {
    System.debug('Class: ' + c.Name);
}

List<ApexTrigger> triggers = [
    SELECT Id, Name
    FROM ApexTrigger
    WHERE Name LIKE '%GeneralAssignment%'
       OR Name LIKE '%General_Assignment%'
    LIMIT 20
];
System.debug('=== ApexTrigger with GeneralAssignment in name ===');
System.debug('Count: ' + triggers.size());
for (ApexTrigger t : triggers) {
    System.debug('Trigger: ' + t.Name);
}
