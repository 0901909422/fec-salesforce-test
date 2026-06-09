/**
 * FEC_CampaignBatchLogger
 * Centralized logging for Campaign batch operations into FEC_Batch_Log__c.
 * Replaces System.debug-based logging with persistent custom object records.
 * 
 * IMPORTANT: This logger swallows its own exceptions — all DML is wrapped
 * in try/catch so logging failures never cause the calling batch to fail.
 */
public with sharing class FEC_CampaignBatchLogger {

    /**
     * Creates a log record when a batch job starts.
     * @param batchName  Name of the batch class being executed
     * @param totalRecords  Total number of records to process
     * @return Id of the created FEC_Batch_Log__c record, or null on failure
     */
    public static Id logStart(String batchName, Integer totalRecords) {
        try {
            FEC_Batch_Log__c logRecord = new FEC_Batch_Log__c(
                FEC_Batch_Name__c = batchName,
                FEC_Status__c = FEC_Constants.BATCH_LOG_IN_PROGRESS,
                FEC_Total_Job_Items__c = totalRecords,
                FEC_Processed_Items__c = 0,
                FEC_Error_Count__c = 0
            );
            insert logRecord;
            return logRecord.Id;
        } catch (Exception ex) {
            return null;
        }
    }

    /**
     * Updates the log record when a batch job finishes.
     * Sets status to Completed when errorCount is 0, Failed otherwise.
     * @param logId  Id of the FEC_Batch_Log__c record created by logStart
     * @param jobId  AsyncApexJob Id from BatchableContext
     * @param processedCount  Number of records successfully processed
     * @param errorCount  Number of records that encountered errors
     * @param errorDetails  Accumulated error detail text (may be null)
     */
    public static void logFinish(
        Id logId, String jobId, Integer processedCount,
        Integer errorCount, String errorDetails
    ) {
        if (logId == null) {
            return;
        }
        try {
            FEC_Batch_Log__c logRecord = new FEC_Batch_Log__c(
                Id = logId,
                FEC_Job_ID__c = jobId,
                FEC_Status__c = (errorCount > 0)
                    ? FEC_Constants.BATCH_LOG_FAILED
                    : FEC_Constants.BATCH_LOG_COMPLETED,
                FEC_Processed_Items__c = processedCount,
                FEC_Error_Count__c = errorCount,
                FEC_Error_Details__c = errorDetails
            );
            update logRecord;
        } catch (Exception ex) {
            // Swallow — logger must never cause batch failure
        }
    }

    /**
     * Appends callout error information to the log record.
     * @param logId  Id of the FEC_Batch_Log__c record
     * @param batchName  Name of the batch class
     * @param statusCode  HTTP status code returned by the callout
     * @param responseBody  Response body from the failed callout
     * @param affectedRecords  Number of records affected by this error
     */
    public static void logCalloutError(
        Id logId, String batchName, Integer statusCode,
        String responseBody, Integer affectedRecords
    ) {
        if (logId == null) {
            return;
        }
        try {
            String errorEntry = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT_LOG)
                + ' | ' + batchName
                + ' | HTTP ' + statusCode
                + ' | Records: ' + affectedRecords
                + ' | Body: ' + truncateBody(responseBody)
                + '\n';

            appendErrorDetails(logId, errorEntry);
        } catch (Exception ex) {
            // Swallow — logger must never cause batch failure
        }
    }

    /**
     * Appends exception information (message + stack trace) to the log record.
     * @param logId  Id of the FEC_Batch_Log__c record
     * @param batchName  Name of the batch class
     * @param ex  The caught exception
     * @param affectedRecords  Number of records affected by this error
     */
    public static void logException(
        Id logId, String batchName, Exception ex,
        Integer affectedRecords
    ) {
        if (logId == null) {
            return;
        }
        try {
            String errorEntry = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT_LOG)
                + ' | ' + batchName
                + ' | Exception: ' + ex.getMessage()
                + ' | StackTrace: ' + ex.getStackTraceString()
                + ' | Records: ' + affectedRecords
                + '\n';

            appendErrorDetails(logId, errorEntry);
        } catch (Exception innerEx) {
            // Swallow — logger must never cause batch failure
        }
    }

    // ─── Private Helpers ───────────────────────────────────────────

    /**
     * Appends error text to the existing FEC_Error_Details__c field.
     * Reads current value first to preserve previously logged errors.
     */
    private static void appendErrorDetails(Id logId, String newEntry) {
        FEC_Batch_Log__c logRecord = [
            SELECT Id, FEC_Error_Details__c
            FROM FEC_Batch_Log__c
            WHERE Id = :logId
            LIMIT 1
        ];
        String existing = logRecord.FEC_Error_Details__c;
        logRecord.FEC_Error_Details__c = String.isBlank(existing)
            ? newEntry
            : existing + newEntry;
        update logRecord;
    }

    /**
     * Truncates response body to avoid exceeding LongTextArea limits.
     * FEC_Error_Details__c is 131072 chars; keep individual entries reasonable.
     */
    private static String truncateBody(String body) {
        if (String.isBlank(body)) {
            return '';
        }
        return body.length() > 500 ? body.substring(0, 500) + '...' : body;
    }
}
