// Check Case vừa được route từ UI - xem OwnerId hiện tại
List<Case> cases = [
    SELECT Id, FEC_ID_Search__c, OwnerId, Owner.Name, Owner.Type, LastModifiedDate
    FROM Case
    WHERE Owner.Type = 'Queue'
    ORDER BY LastModifiedDate DESC
    LIMIT 3
];
for (Case c : cases) {
    System.debug('Case: ' + c.FEC_ID_Search__c + ' | Owner: ' + c.Owner.Name + ' | Type: ' + c.Owner.Type + ' | Modified: ' + c.LastModifiedDate);
}
