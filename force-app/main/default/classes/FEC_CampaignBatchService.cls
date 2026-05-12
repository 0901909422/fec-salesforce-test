/**
 * FEC_CampaignBatchService
 * Central service class containing shared logic for all campaign batch jobs.
 * Replaces duplicated mapToModel(), chunking, evaluateCallStatus(), and
 * query-building logic previously scattered across individual batch classes.
 */
public with sharing class FEC_CampaignBatchService {

    /**
     * Maps an SObject record to the FEC_DataCampaign DTO.
     * Delegates to FEC_DataCampaign.fromSObject() when available (task 5).
     * For now, contains the mapping logic directly (copied from PushBatch).
     * @param record  The FEC_DataCampaign__c SObject to map
     * @return FEC_DataCampaign DTO with all fields populated
     * @throws IllegalArgumentException if record is null
     */
    public static FEC_DataCampaign mapToModel(FEC_DataCampaign__c record) {
        return FEC_DataCampaign.fromSObject(record);
    }

    /**
     * Splits a list of DTOs into chunks where each chunk's JSON serialization
     * does not exceed maxJsonSize bytes.
     * @param models  List of FEC_DataCampaign DTOs to chunk
     * @param maxJsonSize  Maximum JSON size in bytes per chunk
     * @return List of chunks, each chunk is a List of FEC_DataCampaign
     */
    public static List<List<FEC_DataCampaign>> chunkBySize(
        List<FEC_DataCampaign> models, Integer maxJsonSize
    ) {
        List<List<FEC_DataCampaign>> chunks = new List<List<FEC_DataCampaign>>();
        if (models == null || models.isEmpty()) {
            return chunks;
        }
        if (maxJsonSize == null || maxJsonSize <= 0) {
            throw new IllegalArgumentException(System.Label.FEC_Campaign_Error_MaxJsonSize);
        }

        List<FEC_DataCampaign> currentChunk = new List<FEC_DataCampaign>();
        for (FEC_DataCampaign model : models) {
            currentChunk.add(model);
            Integer currentSize = Blob.valueOf(JSON.serialize(currentChunk)).size();

            if (currentSize > maxJsonSize) {
                currentChunk.remove(currentChunk.size() - 1);
                if (!currentChunk.isEmpty()) {
                    chunks.add(currentChunk);
                }
                currentChunk = new List<FEC_DataCampaign>{ model };
            }
        }
        if (!currentChunk.isEmpty()) {
            chunks.add(currentChunk);
        }
        return chunks;
    }

    /**
     * Evaluates a call result code and returns the corresponding campaign status.
     * Uses FEC_Constants sets for mapping.
     * @param callResult  The call result code string
     * @return Campaign status string
     */
    public static String evaluateCallStatus(String callResult) {
        if (String.isBlank(callResult)) {
            return FEC_Constants.CAMPAIGN_STATUS_PENDING_RETRY;
        }
        if (FEC_Constants.CALL_RESULTS_COMPLETED.contains(callResult)) {
            return FEC_Constants.CAMPAIGN_STATUS_RESOLVED_COMPLETED;
        }
        if (FEC_Constants.CALL_RESULTS_CANCELLED.contains(callResult)) {
            return FEC_Constants.CAMPAIGN_STATUS_RESOLVED_CANCELLED;
        }
        if (FEC_Constants.CALL_RESULTS_CALLBACK.contains(callResult)) {
            return FEC_Constants.CAMPAIGN_STATUS_PENDING_CALLBACK;
        }
        return FEC_Constants.CAMPAIGN_STATUS_PENDING_RETRY;
    }

    /**
     * Builds the SOQL query for scheduled batch jobs (ScheduledPush and GetCallingListResult).
     * Adds Saturday/Sunday filter based on the dayOfWeek parameter.
     * @param selectFields  The SELECT clause fields
     * @param dayOfWeek  Day of week string (e.g. 'Saturday', 'Sunday', 'Monday')
     * @return Complete SOQL query string
     */
    public static String buildScheduledQuery(String selectFields, String dayOfWeek) {
        String query = 'SELECT ' + selectFields +
            ' FROM FEC_DataCampaign__c' +
            ' WHERE (NOT FEC_RecordStatus__c LIKE \'%Resolved%\')' +
            ' AND FEC_CS_Campaign__r.FEC_ScheduleCampaign__c = true' +
            ' AND FEC_IsWithinLifetime__c = true';

        if (dayOfWeek == 'Saturday') {
            query += ' AND FEC_CS_Campaign__r.FEC_SaturdaySchedule__c = true';
        } else if (dayOfWeek == 'Sunday') {
            query += ' AND FEC_CS_Campaign__r.FEC_SundaySchedule__c = true';
        }
        return query;
    }

    /**
     * Builds the SOQL query for instant push batch (FEC_PushCampaignDataBatch).
     * @return Complete SOQL query string for instant push
     */
    public static String buildInstantPushQuery() {
        return 'SELECT Id, FEC_AppId__c, FEC_AccountOrContractNumber__c, FEC_ProductLine__c, ' +
            'FEC_Number1__c, FEC_Number2__c, FEC_Number3__c, FEC_Number4__c, FEC_Number5__c, ' +
            'FEC_String1__c, FEC_String2__c, FEC_String3__c, FEC_String4__c, FEC_String5__c, ' +
            'FEC_DateTime1__c, FEC_DateTime2__c, FEC_DateTime3__c, ' +
            'FEC_RecordId__c, FEC_RecordStatus__c, FEC_RecordLifetime__c, FEC_RecordCurrentLifetime__c, ' +
            'FEC_MaxCallAttempt__c, FEC_CurrentCallAttempt__c, FEC_CampaignCallingList__c, FEC_SystemName__c, ' +
            'CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name, ' +
            'FEC_CS_Campaign__r.FEC_Campaign__r.FEC_CampaignId__c, ' +
            'FEC_CS_Campaign__r.FEC_PushInstant__c ' +
            'FROM FEC_DataCampaign__c ' +
            'WHERE CreatedDate >= :dtStart AND CreatedDate <= :dtEnd ' +
            'AND FEC_IsPushed__c = false ' +
            'AND FEC_SendToCommsDB__c = null ' +
            'AND FEC_SentInstantly__c = null ' +
            'AND (NOT FEC_RecordStatus__c LIKE \'Resolved-%\') ' +
            'AND FEC_RecordStatus__c != \'Pending-callback\' ' +
            'AND FEC_CS_Campaign__r.FEC_PushInstant__c = true ' +
            'AND (FEC_CallbackRequested__c != \'true\' OR FEC_CallbackRequested__c = null)';
    }

    /**
     * Builds the SOQL query for existing records push batch (FEC_PushExistingRecordsBatch).
     * Selects all DTO-mapping fields from buildInstantPushQuery() plus FEC_InsertionDate__c
     * and FEC_IsWithinLifetime__c.
     * Filters: created before today, not resolved, not pending-callback, within lifetime,
     * no callback requested, PushInstant enabled, InsertionDate null or before today.
     * @return Complete SOQL query string for existing records push
     */
    public static String buildExistingRecordsPushQuery() {
        return 'SELECT Id, FEC_AppId__c, FEC_AccountOrContractNumber__c, FEC_ProductLine__c, ' +
            'FEC_Number1__c, FEC_Number2__c, FEC_Number3__c, FEC_Number4__c, FEC_Number5__c, ' +
            'FEC_String1__c, FEC_String2__c, FEC_String3__c, FEC_String4__c, FEC_String5__c, ' +
            'FEC_DateTime1__c, FEC_DateTime2__c, FEC_DateTime3__c, ' +
            'FEC_RecordId__c, FEC_RecordStatus__c, FEC_RecordLifetime__c, FEC_RecordCurrentLifetime__c, ' +
            'FEC_MaxCallAttempt__c, FEC_CurrentCallAttempt__c, FEC_CampaignCallingList__c, FEC_SystemName__c, ' +
            'CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name, ' +
            'FEC_CS_Campaign__r.FEC_Campaign__r.FEC_CampaignId__c, ' +
            'FEC_CS_Campaign__r.FEC_PushInstant__c, ' +
            'FEC_InsertionDate__c, FEC_IsWithinLifetime__c ' +
            'FROM FEC_DataCampaign__c ' +
            'WHERE CreatedDate < :dtStart ' +
            'AND (NOT FEC_RecordStatus__c LIKE \'Resolved-%\') ' +
            'AND FEC_RecordStatus__c != \'Pending-callback\' ' +
            'AND FEC_IsWithinLifetime__c = true ' +
            'AND (FEC_CallbackRequested__c != \'true\' OR FEC_CallbackRequested__c = null) ' +
            'AND FEC_CS_Campaign__r.FEC_PushInstant__c = true ' +
            'AND (FEC_InsertionDate__c = null OR FEC_InsertionDate__c < :dtStart)';
    }

    /**
     * Builds the SOQL query for callback records push batch (FEC_PushCallbackRecordsBatch).
     * Selects all DTO-mapping fields from buildInstantPushQuery() plus FEC_InsertionDate__c,
     * FEC_CallbackRequested__c, FEC_RecordCurrentLifetime__c, and FEC_RecordLifetime__c.
     * Implements Pega filter (F2 OR F3) AND F4 AND F1 AND F6:
     * InsertionDate today, (status not Resolved-Completed/Cancelled OR CallbackRequested = true),
     * RecordCurrentLifetime <= RecordLifetime, PushInstant = true.
     * @return Complete SOQL query string for callback records push
     */
    public static String buildCallbackRecordsPushQuery() {
        return 'SELECT Id, FEC_AppId__c, FEC_AccountOrContractNumber__c, FEC_ProductLine__c, ' +
            'FEC_Number1__c, FEC_Number2__c, FEC_Number3__c, FEC_Number4__c, FEC_Number5__c, ' +
            'FEC_String1__c, FEC_String2__c, FEC_String3__c, FEC_String4__c, FEC_String5__c, ' +
            'FEC_DateTime1__c, FEC_DateTime2__c, FEC_DateTime3__c, ' +
            'FEC_RecordId__c, FEC_RecordStatus__c, FEC_RecordLifetime__c, FEC_RecordCurrentLifetime__c, ' +
            'FEC_MaxCallAttempt__c, FEC_CurrentCallAttempt__c, FEC_CampaignCallingList__c, FEC_SystemName__c, ' +
            'CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name, ' +
            'FEC_CS_Campaign__r.FEC_Campaign__r.FEC_CampaignId__c, ' +
            'FEC_CS_Campaign__r.FEC_PushInstant__c, ' +
            'FEC_InsertionDate__c, FEC_CallbackRequested__c ' +
            'FROM FEC_DataCampaign__c ' +
            'WHERE FEC_InsertionDate__c >= :dtStart AND FEC_InsertionDate__c <= :dtEnd ' +
            'AND (' +
                '(FEC_RecordStatus__c != \'Resolved-Completed\' ' +
                'AND FEC_RecordStatus__c != \'Resolved-Cancelled\') ' +
                'OR FEC_CallbackRequested__c = \'true\'' +
            ') ' +
            'AND FEC_RecordCurrentLifetime__c <= FEC_RecordLifetime__c ' +
            'AND FEC_CS_Campaign__r.FEC_PushInstant__c = true';
    }
}
