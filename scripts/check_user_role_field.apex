User u = [SELECT Id, FEC_User_Group__c, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
System.debug('UserGroup=' + u.FEC_User_Group__c + ' UserRole=' + u.UserRole?.Name);
// Check if FEC_User_Role__c exists
try {
    Map<String, Schema.SObjectField> fields = Schema.SObjectType.User.fields.getMap();
    System.debug('Has FEC_User_Role__c=' + fields.containsKey('FEC_User_Role__c'));
} catch(Exception e) {
    System.debug('Error: ' + e.getMessage());
}
