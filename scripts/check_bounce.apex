// Check xem tungnm.mpc@gmail.com có bị bounce không
List<EmailBounce> bounces = [
    SELECT Id, BounceDate, BounceMessage, BounceType, ToAddress
    FROM EmailBounce
    WHERE ToAddress = 'tungnm.mpc@gmail.com'
    LIMIT 5
];
System.debug('Bounces found: ' + bounces.size());
for (EmailBounce b : bounces) {
    System.debug('Bounce: ' + b.ToAddress + ' | Type: ' + b.BounceType + ' | Date: ' + b.BounceDate + ' | Msg: ' + b.BounceMessage);
}
