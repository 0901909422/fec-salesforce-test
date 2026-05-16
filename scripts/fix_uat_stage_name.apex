// Fix FEC_Case_Stage__c records có Name = Id (bị set sai)
// Tìm tất cả stages có Name trông như Salesforce Id (15 hoặc 18 chars, bắt đầu bằng a0D)
List<FEC_Case_Stage__c> badStages = [
    SELECT Id, Name, FEC_Code__c
    FROM FEC_Case_Stage__c
    WHERE Name LIKE 'a0D%'
    LIMIT 200
];
System.debug('Bad stages found: ' + badStages.size());

List<FEC_Case_Stage__c> toUpdate = new List<FEC_Case_Stage__c>();
for (FEC_Case_Stage__c s : badStages) {
    System.debug('  Id=' + s.Id + ' | Name=' + s.Name + ' | Code=' + s.FEC_Code__c);
    if (String.isNotBlank(s.FEC_Code__c)) {
        toUpdate.add(new FEC_Case_Stage__c(Id = s.Id, Name = s.FEC_Code__c));
    }
}

if (!toUpdate.isEmpty()) {
    System.debug('Updating ' + toUpdate.size() + ' stages...');
    update toUpdate;
    System.debug('Done');
} else {
    System.debug('Nothing to update');
}
