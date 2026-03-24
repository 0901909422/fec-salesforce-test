// Check các Case Email gần nhất
List<Case> cases = [
    SELECT Id, Subject, FEC_Channel__c, FEC_Interaction_Email__c,
           FEC_Send_To__c, FEC_Interaction_View_Mode__c, CreatedDate
    FROM Case
    WHERE FEC_Channel__c = 'Email'
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('=== Email Cases ===');
for (Case c : cases) {
    System.debug('ID: ' + c.Id
        + ' | Subject: ' + c.Subject
        + ' | Email: ' + c.FEC_Interaction_Email__c
        + ' | ViewMode: ' + c.FEC_Interaction_View_Mode__c
        + ' | Created: ' + c.CreatedDate);
}

// Check EmailMessage linked
if (!cases.isEmpty()) {
    List<EmailMessage> msgs = [
        SELECT Id, Subject, FromAddress, ToAddress, Incoming, ParentId
        FROM EmailMessage
        WHERE ParentId = :cases[0].Id
        LIMIT 5
    ];
    System.debug('=== EmailMessages for latest case ===');
    for (EmailMessage m : msgs) {
        System.debug('  Subject: ' + m.Subject + ' | From: ' + m.FromAddress + ' | Incoming: ' + m.Incoming);
    }
}
