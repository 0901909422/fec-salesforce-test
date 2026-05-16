// Update FEC_Email__c trên FEC_Customer_History__c theo Account Number
List<FEC_Customer_History__c> recs = [
    SELECT Id, FEC_Account_Number__c, FEC_Email__c
    FROM FEC_Customer_History__c
    WHERE FEC_Account_Number__c IN ('0001500010000000261', '0001500010000009734')
];

System.debug('Found: ' + recs.size());

List<FEC_Customer_History__c> toUpdate = new List<FEC_Customer_History__c>();
for (FEC_Customer_History__c r : recs) {
    System.debug('id=' + r.Id + ' num=' + r.FEC_Account_Number__c + ' currentEmail=' + r.FEC_Email__c);
    if ('0001500010000000261'.equals(r.FEC_Account_Number__c)) {
        r.FEC_Email__c = 'huyen.nguyen.7@fecredit.com.vn';
        toUpdate.add(r);
    } else if ('0001500010000009734'.equals(r.FEC_Account_Number__c)) {
        r.FEC_Email__c = 'thanh.vu.5@fecredit.com.vn';
        toUpdate.add(r);
    }
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Updated ' + toUpdate.size() + ' records');
    for (FEC_Customer_History__c r : toUpdate) {
        System.debug('Done: ' + r.FEC_Account_Number__c + ' -> ' + r.FEC_Email__c);
    }
} else {
    System.debug('No records found');
}
