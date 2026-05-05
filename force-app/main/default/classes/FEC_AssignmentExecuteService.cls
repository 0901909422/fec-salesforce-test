public with sharing class FEC_AssignmentExecuteService {
    
    
    @AuraEnabled(cacheable=true)
    public static Boolean canExecuteAssignment(Id caseId) {
        Id userId = UserInfo.getUserId();
        
        List<FEC_Assignment__c> assignments = [
            SELECT Id, FEC_Assignment_Owner__c , FEC_Assignment_Status__c 
            FROM FEC_Assignment__c
            WHERE FEC_Case__c = :caseId
        ];
        
        if (assignments.isEmpty()) return false;
        
        for (FEC_Assignment__c a : assignments) {
            if (
                a.FEC_Assignment_Owner__c == userId &&
                !(
                a.FEC_Assignment_Status__c == 'Completed' ||
                a.FEC_Assignment_Status__c == 'Resolved-Completed' ||
                a.FEC_Assignment_Status__c == 'Resolved-Rejected' ||
                a.FEC_Assignment_Status__c == 'Resolved-Cancelled' ||
                a.FEC_Assignment_Status__c == 'AutoRecalled' ||
                a.FEC_Assignment_Status__c == 'AutoCompleted'
                )
            ) {
                return true;
            }
        }
        
        return false;
    }
    
}