List<Case> cases = [
    SELECT Id, FEC_Interaction_Email__c, Subject,
           FEC_EmailFrom__c
    FROM Case
    WHERE FEC_Channel__c = 'Email'
    ORDER BY CreatedDate DESC
    LIMIT 3
];
for (Case c : cases) {
    System.debug('Subject: ' + c.Subject);
    System.debug('FEC_Interaction_Email__c: ' + c.FEC_Interaction_Email__c);
    try { System.debug('FEC_EmailFrom__c: ' + c.get('FEC_EmailFrom__c')); } catch(Exception e) { System.debug('No FEC_EmailFrom__c field'); }
}
