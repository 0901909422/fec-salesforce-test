// Kiểm tra email deliverability setting và org email config
System.debug('=== Email Deliverability Check ===');

// Kiểm tra OrgWideEmailAddress
List<OrgWideEmailAddress> orgEmails = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress LIMIT 10];
System.debug('OrgWideEmailAddresses: ' + orgEmails.size());
for (OrgWideEmailAddress oe : orgEmails) {
    System.debug('  → ' + oe.Address + ' (' + oe.DisplayName + ')');
}

// Kiểm tra label
System.debug('Label UBankCustomberServiceEmail: ' + System.Label.UBankCustomberServiceEmail);

// Kiểm tra current user email
User me = [SELECT Id, Email, Profile.Name FROM User WHERE Id = :UserInfo.getUserId()];
System.debug('Current user: ' + me.Email + ' | Profile: ' + me.Profile.Name);
