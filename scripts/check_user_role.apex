User u = [SELECT Id, Email, UserRole.Name, UserRoleId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
System.debug('Email: ' + u.Email);
System.debug('UserRoleId: ' + u.UserRoleId);
System.debug('UserRole.Name: ' + u.UserRole?.Name);
