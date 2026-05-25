public with sharing class FEC_CaseAssignmentLogController {
    public class LogRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal numberOfCase;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdDateLabel;
    }

    public class LogDetailRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal numberOfCase;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdDateLabel;
    }

    @AuraEnabled(cacheable=true)
    public static List<LogRow> getAssignmentLogs(Id assignmentId) {
        List<LogRow> rows = new List<LogRow>();
        if (assignmentId == null) {
            return rows;
        }
        for (FEC_Case_Assignment_Logs__c logRow : [
            SELECT Id, Name, FEC_Number_of_Case__c, CreatedDate
            FROM FEC_Case_Assignment_Logs__c
            WHERE FEC_Case_Assignment_Name__c = :assignmentId
            ORDER BY CreatedDate DESC, Name DESC
        ]) {
            LogRow row = new LogRow();
            row.id = logRow.Id;
            row.name = logRow.Name;
            row.numberOfCase = logRow.FEC_Number_of_Case__c;
            row.createdDate = logRow.CreatedDate;
            row.createdDateLabel = formatRunDateTime(logRow.CreatedDate);
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<LogDetailRow> getAssignmentLogDetails(Id logId) {
        List<LogDetailRow> rows = new List<LogDetailRow>();
        if (logId == null) {
            return rows;
        }
        for (FEC_Case_Assignment_Log_Detail__c detailRow : [
            SELECT Id, Name, FEC_Number_of_Case__c, CreatedDate
            FROM FEC_Case_Assignment_Log_Detail__c
            WHERE FEC_Case_Assignment_log_Name__c = :logId
            ORDER BY CreatedDate ASC, Name ASC
        ]) {
            LogDetailRow row = new LogDetailRow();
            row.id = detailRow.Id;
            row.name = detailRow.Name;
            row.numberOfCase = detailRow.FEC_Number_of_Case__c;
            row.createdDate = detailRow.CreatedDate;
            row.createdDateLabel = formatRunDateTime(detailRow.CreatedDate);
            rows.add(row);
        }
        return rows;
    }

    private static String formatRunDateTime(Datetime value) {
        if (value == null) {
            return '';
        }
        return value.format('dd/MM/yyyy HH:mm:ss', UserInfo.getTimeZone().getID());
    }
}
