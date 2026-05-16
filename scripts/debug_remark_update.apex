// Test update remark type
FEC_Case_Remarks__c r = [SELECT Id, Remark_Type__c, FEC_Assignment__c FROM FEC_Case_Remarks__c WHERE Remark_Type__c = 'Case' ORDER BY CreatedDate DESC LIMIT 1];
System.debug('Before: Type=' + r.Remark_Type__c + ' Assignment=' + r.FEC_Assignment__c);
try {
    r.Remark_Type__c = 'Assignment';
    update r;
    System.debug('Update SUCCESS');
} catch (Exception e) {
    System.debug('Update ERROR: ' + e.getMessage());
}

// Check FEC_Log__c errors
List<FEC_Log__c> logs = [SELECT FEC_Function_Name__c, FEC_Error_Message__c FROM FEC_Log__c ORDER BY CreatedDate DESC LIMIT 3];
for (FEC_Log__c l : logs) {
    System.debug('Log fn=' + l.FEC_Function_Name__c + ' err=' + l.FEC_Error_Message__c);
}
