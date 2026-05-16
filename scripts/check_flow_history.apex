try {
    List<SObject> recs = Database.query('SELECT Id FROM FEC_Case_Flow_History__c LIMIT 1');
    System.debug('FEC_Case_Flow_History__c exists, count=' + recs.size());
} catch (Exception e) {
    System.debug('FEC_Case_Flow_History__c NOT found: ' + e.getMessage());
}
