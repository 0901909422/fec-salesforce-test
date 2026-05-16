// Check user role của user đang login
User u = [SELECT Id, Name, Email, UserRole.Name, UserRoleId, FEC_User_Group__c, Profile.Name
          FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
System.debug('User Name=' + u.Name + ' Email=' + u.Email);
System.debug('UserRoleId=' + u.UserRoleId + ' UserRole.Name=' + u.UserRole?.Name);
System.debug('FEC_User_Group__c=' + u.FEC_User_Group__c);
System.debug('Profile.Name=' + u.Profile?.Name);

// Check user phamTung (người submit)
List<User> phamTung = [SELECT Id, Name, Email, UserRole.Name, UserRoleId, FEC_User_Group__c
                       FROM User WHERE Name LIKE '%Tung%' OR Email LIKE '%tungnm%' LIMIT 5];
for (User pu : phamTung) {
    System.debug('User=' + pu.Name + ' Email=' + pu.Email + ' RoleId=' + pu.UserRoleId + ' Role=' + pu.UserRole?.Name + ' Group=' + pu.FEC_User_Group__c);
}
