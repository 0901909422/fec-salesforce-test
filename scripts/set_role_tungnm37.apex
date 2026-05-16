// Set role của tuyetlm cho tungnm37
List<User> tuyetlm = [SELECT UserRoleId, UserRole.Name FROM User WHERE Email = 'tuyetlm@fpt.com' LIMIT 1];
List<User> me = [SELECT Id, UserRoleId, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
System.debug('tuyetlm role: ' + tuyetlm[0].UserRole?.Name + ' (' + tuyetlm[0].UserRoleId + ')');
System.debug('tungnm37 current role: ' + me[0].UserRole?.Name + ' (' + me[0].UserRoleId + ')');
update new User(Id = me[0].Id, UserRoleId = tuyetlm[0].UserRoleId);
System.debug('Done - tungnm37 now has role: ' + tuyetlm[0].UserRole?.Name);
