// Debug case queue và interaction email data
// Lấy case đang test - case "Khiếu nại về lãi suất tháng 3/2026"
List<Case> cases = [
    SELECT Id, CaseNumber, Subject, Status, OwnerId, Owner.Name, Owner.Type
    FROM Case
    WHERE Subject LIKE '%lãi suất%'
    ORDER BY CreatedDate DESC
    LIMIT 3
];
for (Case c : cases) {
    System.debug('Case: #' + c.CaseNumber + ' | ' + c.Subject);
    System.debug('  OwnerId: ' + c.OwnerId + ' | Owner: ' + c.Owner.Name + ' | Type: ' + c.Owner.Type);
    
    // Nếu là Queue
    if (c.Owner.Type == 'Queue') {
        Group q = [SELECT Id, Name, Email FROM Group WHERE Id = :c.OwnerId LIMIT 1];
        System.debug('  Queue Email: ' + q.Email);
    }
    
    // Xem EmailMessage liên quan
    List<EmailMessage> emails = [
        SELECT Id, FromAddress, ToAddress, Subject, MessageDate
        FROM EmailMessage WHERE ParentId = :c.Id
        ORDER BY MessageDate DESC LIMIT 3
    ];
    System.debug('  EmailMessages: ' + emails.size());
    for (EmailMessage em : emails) {
        System.debug('    From: ' + em.FromAddress + ' | To: ' + em.ToAddress);
    }
    
    // Xem FEC_InteractionEmailController.getInteractionEmail
    Map<String, String> interactionData = FEC_InteractionEmailController.getInteractionEmail(c.Id);
    System.debug('  InteractionEmail data: ' + interactionData);
}
