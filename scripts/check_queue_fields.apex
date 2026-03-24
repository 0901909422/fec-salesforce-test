// Kiểm tra Case owner (Queue) và EmailRoutingAddress
String caseId = '500Az00000MwdfTIAR';

// 1. Case owner info
Case c = [SELECT Id, OwnerId, Owner.Name, Owner.Type FROM Case WHERE Id = :caseId LIMIT 1];
System.debug('Case OwnerId: ' + c.OwnerId + ' | Name: ' + c.Owner.Name + ' | Type: ' + c.Owner.Type);

// 2. Nếu owner là Queue thì lấy Queue detail
if (c.Owner.Type == 'Queue') {
    Group q = [SELECT Id, Name, Email FROM Group WHERE Id = :c.OwnerId LIMIT 1];
    System.debug('Queue Name: ' + q.Name + ' | Queue Email: ' + q.Email);
}

// 3. Xem tất cả Queue có email
List<Group> queues = [SELECT Id, Name, Email FROM Group WHERE Type = 'Queue' AND Email != null ORDER BY Name ASC LIMIT 20];
System.debug('Queues with email: ' + queues.size());
for (Group g : queues) {
    System.debug('  Queue: ' + g.Name + ' | Email: ' + g.Email);
}

// 4. EmailRoutingAddress - xem có field nào liên quan Queue không
Map<String, Schema.SObjectField> fields = Schema.SObjectType.EmailRoutingAddress.fields.getMap();
System.debug('EmailRoutingAddress all fields:');
for (String f : new List<String>(fields.keySet())) {
    System.debug('  ' + f);
}
