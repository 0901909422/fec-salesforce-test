// Check email deliverability setting của org
Organization org = [SELECT Id, Name, IsSandbox FROM Organization LIMIT 1];
System.debug('Org: ' + org.Name + ' | IsSandbox: ' + org.IsSandbox);

// Check deliverability - query DeliverabilitySettings nếu có
// Sandbox mặc định chỉ gửi được đến verified addresses
System.debug('Note: Sandbox mặc định chỉ gửi đến System email addresses.');
System.debug('Cần vào Setup > Deliverability > Access Level = "All email"');

// Check EmailMessage vừa tạo
List<EmailMessage> recent = [
    SELECT Id, Subject, ToAddress, Status, MessageDate
    FROM EmailMessage
    ORDER BY CreatedDate DESC LIMIT 3
];
for (EmailMessage em : recent) {
    System.debug('EmailMessage: ' + em.Subject + ' | To: ' + em.ToAddress + ' | Status: ' + em.Status);
}
