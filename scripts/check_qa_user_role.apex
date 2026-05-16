// Check user tuyetlm trên QA
List<User> users = [
    SELECT Id, Email, UserRole.Name, UserRoleId, IsActive
    FROM User
    WHERE Email LIKE 'tuyetlm%'
    LIMIT 5
];
System.debug('=== Users matching tuyetlm ===');
for (User u : users) {
    System.debug('Email=' + u.Email + ' | UserRoleId=' + u.UserRoleId + ' | UserRole.Name=' + u.UserRole?.Name + ' | Active=' + u.IsActive);
}

// Check khi nào Assignment A-000263 được tạo và user lúc đó
List<FEC_Assignment__c> a = [
    SELECT Id, Name, CreatedById, CreatedBy.Email, CreatedBy.UserRole.Name,
           FEC_User_Role__c, CreatedDate
    FROM FEC_Assignment__c
    WHERE Name = 'A-000263'
    LIMIT 1
];
if (!a.isEmpty()) {
    System.debug('A-000263 CreatedBy=' + a[0].CreatedBy?.Email + ' | CreatedBy.UserRole=' + a[0].CreatedBy?.UserRole?.Name + ' | FEC_User_Role__c=' + a[0].FEC_User_Role__c);
}
