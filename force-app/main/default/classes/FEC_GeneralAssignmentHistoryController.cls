public with sharing class FEC_GeneralAssignmentHistoryController {
    
    @AuraEnabled(cacheable=true)
    public static List<HistoryWrapper> getHistory(Id recordId) {
        List<HistoryWrapper> historyList = new List<HistoryWrapper>();
        
        try {
            List<FEC_General_Assignment__History> histories = [
                SELECT Id, Field, OldValue, NewValue, CreatedDate, CreatedBy.Name
                FROM FEC_General_Assignment__History
                WHERE ParentId = :recordId
                ORDER BY CreatedDate DESC
                LIMIT 100
            ];
            
            for (FEC_General_Assignment__History h : histories) {
                HistoryWrapper wrapper = new HistoryWrapper();
                wrapper.Id = h.Id;
                wrapper.CreatedDate = h.CreatedDate;
                wrapper.User = h.CreatedBy.Name;
                wrapper.Field = getFieldLabel(h.Field);
                wrapper.OldValue = String.valueOf(h.OldValue);
                wrapper.NewValue = String.valueOf(h.NewValue);
                historyList.add(wrapper);
            }
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
        }
        
        return historyList;
    }
    
    private static String getFieldLabel(String fieldName) {
        Map<String, String> fieldLabels = new Map<String, String>{
            'FEC_General_Assignment_Name__c' => 'General Assignment Name',
            'FEC_General_Assignment_Code__c' => 'General Assignment Code',
            'FEC_Customer_Type__c' => 'Customer Type',
            'FEC_Channel__c' => 'Channel',
            'FEC_Active__c' => 'Active',
            'created' => 'Created'
        };
        return fieldLabels.containsKey(fieldName) ? fieldLabels.get(fieldName) : fieldName;
    }
    
    public class HistoryWrapper {
        @AuraEnabled public String Id;
        @AuraEnabled public DateTime CreatedDate;
        @AuraEnabled public String User;
        @AuraEnabled public String Field;
        @AuraEnabled public String OldValue;
        @AuraEnabled public String NewValue;
    }
}

