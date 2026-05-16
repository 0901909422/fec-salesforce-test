// Chạy script này bằng Admin user khác để đổi profile của pham Tung
Id targetUserId = [SELECT Id FROM User WHERE Email = 'minhtung2108@gmail.com' LIMIT 1].Id;
Id relevantDeptsProfileId = [SELECT Id FROM Profile WHERE Name = 'Relevant Depts' LIMIT 1].Id;
update new User(Id = targetUserId, ProfileId = relevantDeptsProfileId);
System.debug('Done - profile changed to Relevant Depts for user: ' + targetUserId);
