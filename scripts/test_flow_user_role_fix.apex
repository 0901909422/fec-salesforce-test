// Test fix Flow: set role cho tungnm37, tạo assignment, verify, rollback role

// 1. Lấy role của tuyetlm
List<User> tuyetlm = [SELECT UserRoleId FROM User WHERE Email = 'tuyetlm@fpt.com' LIMIT 1];
if (tuyetlm.isEmpty()) { System.debug('tuyetlm not found'); return; }
Id roleId = tuyetlm[0].UserRoleId;
System.debug('Role to assign: ' + roleId);

// 2. Lấy tungnm37 và lưu role cũ
List<User> me = [SELECT Id, Email, UserRoleId, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
if (me.isEmpty()) { System.debug('Current user not found'); return; }
Id oldRoleId = me[0].UserRoleId;
System.debug('tungnm37 current role: ' + me[0].UserRole?.Name + ' (' + oldRoleId + ')');

// 3. Set role cho tungnm37
update new User(Id = me[0].Id, UserRoleId = roleId);
System.debug('Role set to tuyetlm role');

// 4. Re-query để confirm
User meAfter = [SELECT Id, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
System.debug('tungnm37 new role: ' + meAfter.UserRole?.Name);

// 5. Tạo Assignment với FEC_User_Role__c set từ Apex
String caseId = '5008500000HvjJbAAJ';
FEC_Assignment__c a = new FEC_Assignment__c(
    FEC_Case__c = caseId,
    FEC_Assignment_Type__c = 'Routing',
    FEC_Assignment_Status__c = 'Open',
    FEC_Assignment_Name__c = 'Routing',
    FEC_OwnerID__c = 'DQ - CS Support',
    FEC_User_Role__c = meAfter.UserRole?.Name,
    FEC_Manual__c = false
);
insert a;

// 6. Verify
FEC_Assignment__c result = [
    SELECT Id, Name, FEC_User_Role__c, CreatedBy.UserRole.Name
    FROM FEC_Assignment__c WHERE Id = :a.Id LIMIT 1
];
System.debug('=== RESULT ===');
System.debug('FEC_User_Role__c = ' + result.FEC_User_Role__c);
System.debug('CreatedBy.UserRole.Name = ' + result.CreatedBy?.UserRole?.Name);
Boolean pass = result.FEC_User_Role__c == meAfter.UserRole?.Name;
System.debug(pass ? '✓ PASS - UserRole preserved: ' + result.FEC_User_Role__c : '✗ FAIL - overridden to: ' + result.FEC_User_Role__c);

// 7. Rollback role
update new User(Id = me[0].Id, UserRoleId = oldRoleId);
System.debug('Role rolled back to: ' + oldRoleId);
