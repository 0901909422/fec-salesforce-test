// Check case S-0236 status history
List<Case> cases = [SELECT Id, CaseNumber, Status, OwnerId, Owner.Name FROM Case WHERE FEC_ID_Search__c = 'S-0236' LIMIT 1];
if (cases.isEmpty()) { System.debug('Not found'); return; }
Case c = cases[0];
System.debug('Case: ' + c.CaseNumber + ' | Status: ' + c.Status + ' | Owner: ' + c.Owner.Name);

// Check case history
List<CaseHistory> history = [
    SELECT Field, OldValue, NewValue, CreatedDate, CreatedBy.Name
    FROM CaseHistory
    WHERE CaseId = :c.Id AND Field IN ('Status', 'Owner')
    ORDER BY CreatedDate DESC LIMIT 10
];
for (CaseHistory h : history) {
    System.debug(h.Field + ': ' + h.OldValue + ' → ' + h.NewValue + ' | by: ' + h.CreatedBy.Name + ' | ' + h.CreatedDate);
}
