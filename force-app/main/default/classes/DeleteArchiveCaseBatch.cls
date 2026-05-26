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
    List<String> listObjToDelArchiveCase = label.TECH_LIST_OBJ_DEL_ARCHIVE_CASE.split(',');

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
        
        String sObjectName = listObjToDelArchiveCase[currentObjectIndex];
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
        if (currentObjectIndex < listObjToDelArchiveCase.size()) {
            Database.executeBatch(this, 200);
        } else {
            System.debug('ArchiveCaseDeletionBatch: Completed cleanup of all archive temp records.');
        }
    }
}