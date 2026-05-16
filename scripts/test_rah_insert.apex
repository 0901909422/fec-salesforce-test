// Debug trigger error chi tiết hơn
String caseId = '500Az00000NvWHFIA3';
User u = [SELECT Id, Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

FEC_Routing_Action_History__c h = new FEC_Routing_Action_History__c(
    FEC_Routing_Action__c = 'Route to',
    FEC_Case__c = caseId,
    FEC_Perform_User__c = u.Id,
    FEC_User__c = 'tungnm37',
    FEC_Stage_Name__c = 'Test Stage',
    FEC_Updated_User_Queue__c = 'DQ - Card Operations',
    FEC_Submitted_On__c = DateTime.now()
);

try {
    insert h;
    System.debug('SUCCESS: ' + h.Id);
} catch (DmlException e) {
    System.debug('DML Error: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}
