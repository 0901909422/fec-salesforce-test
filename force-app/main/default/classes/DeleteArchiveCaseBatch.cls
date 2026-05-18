/*------------------------------------------------------------
Author:        Thanh Van
Company:       Amaris
Description:   Delete Archive Case by Batch job
Test Class:    DeleteArchiveCaseBatch_Test
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/04/01     Thanh Van          Init
------------------------------------------------------------*/
global class DeleteArchiveCaseBatch implements Database.Batchable<sObject>, Database.Stateful, Schedulable {

    // All other objects use IsArchiveTemp__c = true.
    // Deletion order: Case first (they reference lookup objects), then lookup objects.
    private static final List<String> DELETION_ORDER = new List<String>{
        'Case',
        'FEC_Actual_Nature_of_Case__c',
        'FEC_Customer_History__c',
        'FEC_Product_Type__c',
        'FEC_Category__c',
        'FEC_Sub_Category__c',
        'FEC_Sub_Code__c',
        'FEC_Business_Process__c',
        'FEC_IPP__c',
        'FEC_Card_Payment__c',
        'FEC_Process_Action__c',
        'FEC_Integration_Case__c'
    };

    private Integer currentObjectIndex = 0;

    public List<string> listIdArchiveCaseToDeleted = new List<string>();

    global DeleteArchiveCaseBatch() {}

    global DeleteArchiveCaseBatch(List<String> listIdArchiveCaseToDeletedTemp) {
        this.listIdArchiveCaseToDeleted = listIdArchiveCaseToDeletedTemp;
    }

    global void execute(SchedulableContext sc){
        DeleteArchiveCaseBatch batch = new DeleteArchiveCaseBatch();
        Database.executeBatch(batch);
    }

    global Database.QueryLocator start(Database.BatchableContext context) {
        
        String sObjectName = DELETION_ORDER[currentObjectIndex];
        String query;
        if (sObjectName == 'Case') {
            query = 'SELECT Id FROM Case WHERE ArchiveExternalId__c != NULL AND ArchiveExternalId__c != ' 
                        + '\'' + '\'';
            if (listIdArchiveCaseToDeleted.size() > 0) {
                String idsWithSingleQuote = '(' + '\'' + String.join(listIdArchiveCaseToDeleted, '\',\'') + '\'' + ')';
                query += ' AND Id IN ' + idsWithSingleQuote;
            }
        } else {
            query = 'SELECT Id FROM ' + sObjectName + ' WHERE IsArchiveTemp__c = true';
        }

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (!scope.isEmpty()) {
            delete scope;
        }
    }

    public void finish(Database.BatchableContext bc) {
        currentObjectIndex++;
        if (currentObjectIndex < DELETION_ORDER.size()) {
            Database.executeBatch(this, 200);
        } else {
            System.debug('ArchiveCaseDeletionBatch: Completed cleanup of all archive temp records.');
        }
    }
}