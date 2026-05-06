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
                a.FEC_Assignment_Status__c == FEC_ConstantCommon.STATUS_COMPLETED ||
                a.FEC_Assignment_Status__c == FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED ||
                a.FEC_Assignment_Status__c == FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED ||
                a.FEC_Assignment_Status__c == FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED ||
                a.FEC_Assignment_Status__c == FEC_ConstantCommon.ASSIGNMENT_AUTORECALLED_STATUS ||
                a.FEC_Assignment_Status__c == FEC_ConstantCommon.ASSIGNMENT_AUTOCOMPLETE_STATUS
                )
            ) {
                return true;
            }
        }
        
        return false;
    }
    
}