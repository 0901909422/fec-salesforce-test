// Check user tuyetlm@fpt.com và Assignment Remark user role
List<User> users = [
    SELECT Id, Email, UserRole.Name, UserRoleId
    FROM User
    WHERE Email = 'tuyetlm@fpt.com'
    LIMIT 1
];
if (!users.isEmpty()) {
    User u = users[0];
    System.debug('User: ' + u.Email + ' | UserRoleId=' + u.UserRoleId + ' | UserRole.Name=' + u.UserRole?.Name);
} else {
    System.debug('User not found');
}

// Check Assignment A-000090 remarks
List<FEC_Case_Remarks__c> remarks = [
    SELECT Id, FEC_Case_Remarks__c, FEC_Stage_Name__c, FEC_User__c,
           FEC_User_Role__c, FEC_Remark_Type__c, CreatedDate
    FROM FEC_Case_Remarks__c
    WHERE FEC_Assignment__r.Name = 'A-000090'
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('=== Assignment Remarks for A-000090 ===');
for (FEC_Case_Remarks__c r : remarks) {
    System.debug('Type=' + r.FEC_Remark_Type__c + ' | User=' + r.FEC_User__c + ' | UserRole=' + r.FEC_User_Role__c + ' | Stage=' + r.FEC_Stage_Name__c);
}
