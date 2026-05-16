// Đổi profile current user sang Relevant Depts để test
// LƯU Ý: Không thể đổi profile của chính mình qua Apex
// Cần dùng một user khác để chạy script này, hoặc đổi qua UI

// Check profile hiện tại
User u = [SELECT Id, Name, Email, Profile.Name FROM User WHERE Id = :UserInfo.getUserId()];
System.debug('Current user: ' + u.Name + ' | Profile: ' + u.Profile.Name);

// Tìm profile Relevant Depts
Profile p = [SELECT Id, Name FROM Profile WHERE Name = 'Relevant Depts' LIMIT 1];
System.debug('Relevant Depts Profile Id: ' + p.Id);

// NOTE: Không thể update profile của chính mình trong Apex
// Cần dùng UI: Setup > Users > Edit > Profile = Relevant Depts
System.debug('Vui lòng đổi profile qua UI: Setup > Users > ' + u.Name + ' > Edit > Profile = Relevant Depts');
