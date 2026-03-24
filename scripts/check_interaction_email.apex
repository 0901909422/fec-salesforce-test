// Check case mới nhất có FEC_Interaction_Email__c không
List<Case> cases = [
    SELECT Id, Subject, Status, FEC_Interaction_Email__c, FEC_Case_Channel__c
    FROM Case
    ORDER BY CreatedDate DESC LIMIT 5
];
for (Case c : cases) {
    System.debug('Case: ' + c.Subject + ' | Channel: ' + c.FEC_Case_Channel__c
        + ' | InteractionEmail: ' + c.FEC_Interaction_Email__c + ' | Status: ' + c.Status);
}

// Check EmailMessage incoming để lấy ToAddress (fromEmail trong UI)
Case latest = cases[0];
List<EmailMessage> msgs = [
    SELECT ToAddress, FromAddress, Incoming FROM EmailMessage
    WHERE ParentId = :latest.Id ORDER BY MessageDate ASC LIMIT 3
];
System.debug('EmailMessages for case ' + latest.Id + ':');
for (EmailMessage m : msgs) {
    System.debug('  Incoming: ' + m.Incoming + ' | From: ' + m.FromAddress + ' | To: ' + m.ToAddress);
}
