// Check FeedItem cho Case Email mới nhất
List<Case> cases = [SELECT Id FROM Case WHERE FEC_Channel__c = 'Email' ORDER BY CreatedDate DESC LIMIT 1];
if (!cases.isEmpty()) {
    List<FeedItem> items = [
        SELECT Id, Type, Body, CreatedDate, CreatedBy.Name
        FROM FeedItem WHERE ParentId = :cases[0].Id
        ORDER BY CreatedDate DESC LIMIT 5
    ];
    System.debug('Case: ' + cases[0].Id + ' | FeedItems: ' + items.size());
    for (FeedItem f : items) {
        System.debug('  Type: ' + f.Type + ' | By: ' + f.CreatedBy.Name + ' | ' + f.CreatedDate);
    }
}
