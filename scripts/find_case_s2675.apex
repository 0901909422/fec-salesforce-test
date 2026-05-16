// tungnm37: tìm case S-2675 với nhiều format
List<Case> cases = [
    SELECT Id, CaseNumber, Subject, Status, FEC_Stage_Name__c
    FROM Case 
    WHERE CaseNumber LIKE '%2675%'
    LIMIT 5
];
System.debug('Found: ' + cases.size());
for (Case c : cases) {
    System.debug('Id: ' + c.Id + ' | CaseNumber: ' + c.CaseNumber + ' | Subject: ' + c.Subject + ' | Status: ' + c.Status);
}
