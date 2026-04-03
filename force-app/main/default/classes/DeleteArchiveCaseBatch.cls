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
        
        String query = 'SELECT Id FROM Case WHERE ArchiveExternalId__c != NULL AND ArchiveExternalId__c != ' 
                        + '\'' + '\'';
        if (listIdArchiveCaseToDeleted.size() > 0) {
            String idsWithSingleQuote = '(' + '\'' + String.join(listIdArchiveCaseToDeleted, '\',\'') + '\'' + ')';
            query += ' AND Id IN ' + idsWithSingleQuote;
        }

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext context, List<Case> listCase) {
        if (listCase == null || listCase.size() == 0) return;

        delete listCase;
    }

    global void finish(Database.BatchableContext context) {}
}