// tungnm37: check FEC_User_Group__c của current user và Case S-1732
// Check current user
User me = [SELECT Id, Username, Name, FEC_User_Group__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
System.debug('CurrentUser: ' + me.Username + ' | Name: ' + me.Name + ' | FEC_User_Group__c: ' + me.FEC_User_Group__c);

// Check user duongrt217 (tìm rộng hơn)
List<User> users = [
    SELECT Id, Username, Name, FEC_User_Group__c
    FROM User
    WHERE Username LIKE '%duong%'
    AND IsActive = true
    LIMIT 10
];
for (User u : users) {
    System.debug('User: ' + u.Username + ' | FEC_User_Group__c: ' + u.FEC_User_Group__c);
}

// Check Case S-1732 (CaseNumber có thể có leading zeros)
List<Case> cases = [
    SELECT Id, CaseNumber, FEC_Is_Submited__c, FEC_Team__c, Status
    FROM Case
    WHERE CaseNumber LIKE '%1732%'
    LIMIT 5
];
for (Case c : cases) {
    System.debug('Case: ' + c.CaseNumber + ' | FEC_Is_Submited__c: ' + c.FEC_Is_Submited__c + ' | FEC_Team__c: ' + c.FEC_Team__c + ' | Status: ' + c.Status);
}
