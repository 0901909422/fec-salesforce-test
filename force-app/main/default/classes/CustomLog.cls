/*------------------------------------------------------------
Author:        Thanh Van
Company:       Amaris
Description:   Custom Log object to store the logs
Test Class:    
History
<Date>         <Authors Name>     <Brief Description of Change>
2025/03/25     Thanh Van          Init
------------------------------------------------------------*/
public with sharing class CustomLog {

    public static Boolean isTestWithError = false;

    public String TargetObjectId {get;set;}
    public String ApexClass {get;set;}
    public String ApexMethod {get;set;}
    public String ActionName {get;set;}
    public String Message {get;set;}
    public String Response {get;set;}
    public Boolean Success {get;set;}
    
    public CustomLog() {
        this.TargetObjectId = '';
        this.ApexClass = '';
        this.ApexMethod = '';
        this.ActionName = '';
        this.Message = '';
        this.Response = '';
        this.Success = false;
    }
    public class HistoryLog {
        @AuraEnabled public Id Id;                 // Use capital I to align with lightning-datatable key-field="Id"
        @AuraEnabled public String createdByEmail;
        @AuraEnabled public Datetime createdDate;  // Datetime to match assignment from sObject.CreatedDate
        @AuraEnabled public String logActionName;
        @AuraEnabled public String logMessage;
        @AuraEnabled public String logResponse;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Method to build each CustomLog Old - New value
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2025/03/25     Thanh Van          Init
    ------------------------------------------------------------*/
    public static CustomLog buildLogOldNew(String TargetObjectId, String className, 
                                        String methodName, String actionName, 
                                        String oldValue, String newValue) {

        CustomLog customlogIns = new CustomLog();
        customlogIns.TargetObjectId = TargetObjectId;
        customlogIns.ApexClass = className;
        customlogIns.ApexMethod = methodName;
        customlogIns.ActionName = actionName;
        customlogIns.Message = oldValue;
        customlogIns.Response = newValue;
        customlogIns.Success = true;

        return customlogIns;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Method to save log Old - New value
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2025/03/25     Thanh Van          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static void logOldNew(String TargetObjectId, String className, 
                                String methodName, String actionName, 
                                String oldValue, String newValue) {

        List<CustomLog> logEntries = new List<CustomLog>();
        CustomLog customlogIns = buildLogOldNew(TargetObjectId, className, methodName, 
                                                actionName, oldValue, newValue);
        logEntries.add(customlogIns);
        insertCustomLogs(logEntries);
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Method to build each Internal Error log
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2025/03/25     Thanh Van          Init
    ------------------------------------------------------------*/
    public static CustomLog buildLogInternalError(String className, String methodName, String errorMess) {

        CustomLog customlogIns = new CustomLog();
        customlogIns.ApexClass = className;
        customlogIns.ApexMethod = methodName;
        customlogIns.Message = errorMess;
        
        return customlogIns;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Method to save Internal Error log
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2025/03/25     Thanh Van          Init
    ------------------------------------------------------------*/
    public static void logInternalError(String className, String methodName, String errorMess) {

        List<CustomLog> logEntries = new List<CustomLog>();
        CustomLog customlogIns = buildLogInternalError(className, methodName, errorMess);
        logEntries.add(customlogIns);
        insertCustomLogs(logEntries);
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Method to save Custom logs
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2025/03/25     Thanh Van          Init
    ------------------------------------------------------------*/
    public static void insertCustomLogs(List<CustomLog> logEntries) {
        if (logEntries == null || logEntries.isEmpty()) return;

        try {
            if (isTestWithError) throw new NullPointerException();

            List<CustomLog__c> listLog = new List<CustomLog__c>();
            for (CustomLog logIns : logEntries) {
                CustomLog__c customlogIns = new CustomLog__c();
                customlogIns.TargetObjectId__c = logIns.TargetObjectId;
                customlogIns.ApexClass__c = logIns.ApexClass;
                customlogIns.ApexMethod__c = logIns.ApexMethod;
                customlogIns.Message__c = logIns.Message;
                customlogIns.ActionName__c = logIns.ActionName;
                customlogIns.Response__c = logIns.Response;
                customlogIns.Success__c = logIns.Success;

                listLog.add(customlogIns);
            }

            if (listLog.size() > 0) {
                Database.insert(listLog, false);
            }
        } catch (Exception ex) {
            System.debug('Error inserting CustomLog__c: ' + ex.getMessage());
            System.debug('The Governor Limits have already been exhausted and hence failed to create a Log!');
        }
    }

    /*------------------------------------------------------------
    Author:        Ha Linh
    Company:       Amaris
    Description:   Custom history log by targetId
    @targetId TargetId
    retrun List HistoryLog
    Test Class:    
    History
    <Date>         <Authors Name>     <Brief Description of Change>
    2026/03/31      Ha Linh          Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static List<HistoryLog> getCustomHistoryLog(Id targetId) {
        // Validate input
        if (targetId == null) {
            return new List<HistoryLog>();
        }

        // SOQL per request
        List<CustomLog__c> logs = [
            SELECT Id,
                   CreatedDate,
                   CreatedBy.Email,
                   ActionName__c,
                   Message__c,
                   Response__c
              FROM CustomLog__c
             WHERE TargetObjectId__c = :targetId AND ActionName__c != null
             ORDER BY CreatedDate DESC
             LIMIT 500
        ];

        // Map sObjects to DTO for LWC
        List<HistoryLog> historyLogs = new List<HistoryLog>();
        for (CustomLog__c log : logs) {
            HistoryLog row = new HistoryLog();
            row.Id = log.Id;
            row.createdDate = log.CreatedDate;
            row.createdByEmail = (log.CreatedBy != null) ? log.CreatedBy.Email : null;
            row.logActionName = log.ActionName__c;
            row.logMessage = log.Message__c;
            row.logResponse = log.Response__c;
            historyLogs.add(row);
        }
        return historyLogs;
    }
}