List<AggregateResult> results = [
    SELECT FEC_Assigned_to_Queue__c val, COUNT(Id) cnt
    FROM FEC_Notification__c
    GROUP BY FEC_Assigned_to_Queue__c
    ORDER BY COUNT(Id) DESC
];
for (AggregateResult r : results) {
    System.debug('Queue: [' + r.get('val') + '] | Count: ' + r.get('cnt'));
}
