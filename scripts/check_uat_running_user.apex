// Check user đang chạy và UserRole
List<User> userlst = [SELECT Id, Email, UserRole.Name, UserRoleId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
if (!userlst.isEmpty()) {
    System.debug('Running user: ' + userlst[0].Email + ' | UserRoleId=' + userlst[0].UserRoleId + ' | UserRole.Name=' + userlst[0].UserRole?.Name);
}

// Check tuyetlm
List<User> tuyetlm = [SELECT Id, Email, UserRole.Name, UserRoleId FROM User WHERE Email = 'tuyetlm@fpt.com' LIMIT 1];
if (!tuyetlm.isEmpty()) {
    System.debug('tuyetlm: UserRole=' + tuyetlm[0].UserRole?.Name + ' | UserRoleId=' + tuyetlm[0].UserRoleId);
}
