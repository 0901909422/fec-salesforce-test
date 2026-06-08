List<Case> testCases = new List<Case>();
for (Integer i = 0; i < 2; i++) {
    testCases.add(new Case(Status='Closed', Subject='Diag '+i));
}
insert testCases;

System.debug('== isSystemUpdate before: ' + FEC_CaseTriggerHandler.isSystemUpdate);

List<Case> toUpdate = new List<Case>();
Datetime now = System.now();
for (Case c : testCases) {
    toUpdate.add(new Case(
        Id = c.Id,
        FEC_Archive_Status__c = 'Processing',
        FEC_Archive_Sent_At__c = now,
        FEC_Attachment_Status__c = null
    ));
}

FEC_CaseTriggerHandler.isSystemUpdate = true;
try {
    update toUpdate;
    System.debug('== UPDATE OK');
} catch (Exception e) {
    System.debug('== UPDATE FAILED: ' + e.getTypeName() + ' / ' + e.getMessage());
} finally {
    FEC_CaseTriggerHandler.isSystemUpdate = false;
}

List<Case> aft = [SELECT Id, FEC_Archive_Status__c, FEC_Archive_Sent_At__c FROM Case WHERE Id IN :testCases];
for (Case c : aft) {
    System.debug('== After: id=' + c.Id + ' status=' + c.FEC_Archive_Status__c + ' sentAt=' + c.FEC_Archive_Sent_At__c);
}
delete testCases;
