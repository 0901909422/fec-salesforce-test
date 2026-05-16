public with sharing class FEC_NocGeneralAssignmentController {
    
    @AuraEnabled(cacheable=true)
    public static List<GeneralAssignmentWrapper> getGeneralAssignments(Id nocId) {
        List<GeneralAssignmentWrapper> wrapperList = new List<GeneralAssignmentWrapper>();
        
        try {
            List<FEC_General_Assignment_Config__c> gaList = [
                SELECT Id, Name, FEC_Customer_Type__c, FEC_Channel__c, 
                       FEC_Case_Stage__c, FEC_Case_Stage__r.Name, 
                       FEC_General_Assignment_Name__c, FEC_Active__c
                FROM FEC_General_Assignment_Config__c
                WHERE FEC_Nature_of_Cases__c = :nocId
                ORDER BY CreatedDate DESC
            ];
            
            for (FEC_General_Assignment_Config__c ga : gaList) {
                GeneralAssignmentWrapper wrapper = new GeneralAssignmentWrapper();
                wrapper.Id = ga.Id;
                wrapper.Name = ga.Name;
                wrapper.recordUrl = '/' + ga.Id;
                wrapper.CustomerType = ga.FEC_Customer_Type__c;
                wrapper.Channel = ga.FEC_Channel__c;
                wrapper.Stage = ga.FEC_Case_Stage__r != null ? ga.FEC_Case_Stage__r.Name : '';
                wrapper.GeneralAssignmentName = ga.FEC_General_Assignment_Name__c;
                wrapper.Active = ga.FEC_Active__c;
                wrapperList.add(wrapper);
            }
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
        }
        
        return wrapperList;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<FEC_Channel__c> getChannelValues() {
        return [
            SELECT Id, Name, FEC_Channel_ID__c 
            FROM FEC_Channel__c 
            WHERE FEC_Channel_ID__c != null 
            ORDER BY FEC_Channel_ID__c
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<FEC_Case_Stage__c> getCaseStages() {
        return [SELECT Id, Name FROM FEC_Case_Stage__c ORDER BY Name];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<FEC_General_Assignment_Config__c> getGeneralAssignmentCodes() {
        return [
            SELECT Id, FEC_General_Assignment_Name__c 
            FROM FEC_General_Assignment_Config__c 
            WHERE FEC_General_Assignment_Name__c != null 
            ORDER BY FEC_General_Assignment_Name__c
        ];
    }
    
    @AuraEnabled
    public static void saveGeneralAssignment(Map<String, Object> gaData) {
        try {
            FEC_General_Assignment_Config__c ga = new FEC_General_Assignment_Config__c();
            ga.FEC_Nature_of_Cases__c = (Id)gaData.get('FEC_Nature_of_Cases__c');
            ga.FEC_Customer_Type__c = (String)gaData.get('FEC_Customer_Type__c');
            ga.FEC_Channel__c = (String)gaData.get('FEC_Channel__c');
            ga.FEC_Case_Stage__c = (Id)gaData.get('FEC_Case_Stage__c');
            ga.FEC_General_Assignment_Name__c = (String)gaData.get('FEC_General_Assignment_Name__c');
            ga.FEC_Active__c = (Boolean)gaData.get('FEC_Active__c');
            
            insert ga;
        } catch (Exception e) {
            throw new AuraHandledException('Lỗi khi lưu: ' + e.getMessage());
        }
    }
    
    public class GeneralAssignmentWrapper {
        @AuraEnabled public String Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String recordUrl;
        @AuraEnabled public String CustomerType;
        @AuraEnabled public String Channel;
        @AuraEnabled public String Stage;
        @AuraEnabled public String GeneralAssignmentName;
        @AuraEnabled public Boolean Active;
    }
}

