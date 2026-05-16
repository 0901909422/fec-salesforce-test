// Chạy script này để đổi lại profile về System Administrator
Id targetUserId = [SELECT Id FROM User WHERE Email = 'minhtung2108@gmail.com' LIMIT 1].Id;
Id sysAdminProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id;
update new User(Id = targetUserId, ProfileId = sysAdminProfileId);
System.debug('Done - profile restored to System Administrator for user: ' + targetUserId);
