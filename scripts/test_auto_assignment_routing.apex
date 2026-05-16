// Test insert Routing Action History trực tiếp để xem trigger lỗi gì
String caseId = '500Az00000NvWHFIA3';
User u = [SELECT Id, Email, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
Case c = [SELECT Id, OwnerId, FEC_Final_Status__c FROM Case WHERE Id = :caseId LIMIT 1];

try {
    FEC_Routing_Action_History__c h = new FEC_Routing_Action_History__c(
        FEC_Routing_Action__c = 'Route to',
        FEC_Case__c = caseId,
        FEC_Perform_User__c = u.Id,
        FEC_User__c = 'tungnm37',
        FEC_Stage_Name__c = 'Test Stage',
        FEC_Original_User_Queue__c = 'Test Original',
        FEC_Updated_User_Queue__c = 'DQ - Card Operations',
        FEC_Updated_User_Queue_ID__c = '00GAz0000005JuCAMA0',
        FEC_Current_Status__c = c.FEC_Final_Status__c,
        FEC_Submitted_On__c = DateTime.now()
    );
    Database.SaveResult sr = Database.insert(h, false);
    if (sr.isSuccess()) {
        System.debug('Insert SUCCESS: ' + sr.getId());
    } else {
        for (Database.Error e : sr.getErrors()) {
            System.debug('Insert ERROR: ' + e.getStatusCode() + ' | ' + e.getMessage());
        }
    }
} catch (Exception e) {
    System.debug('Exception: ' + e.getMessage() + ' | ' + e.getStackTraceString());
}
