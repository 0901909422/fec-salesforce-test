// Rollback role tungnm37 về null
List<User> me = [SELECT Id, UserRoleId, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
System.debug('Current role: ' + me[0].UserRole?.Name);
update new User(Id = me[0].Id, UserRoleId = null);
System.debug('Role cleared');
