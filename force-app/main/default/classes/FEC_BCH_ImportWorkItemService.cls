public without sharing class FEC_BCH_ImportWorkItemService {

    public static final String WORK_OBJECT_API_NAME = 'FEC_BCH_Import_Work_Item__c';
    private static final Integer DML_CHUNK_SIZE = 200;
    private static final String STATUS_PENDING = 'Pending';
    private static final String STATUS_PROCESSING = 'Processing';
    private static final String STATUS_SUCCESS = 'Success';
    private static final String STATUS_FAILED = 'Failed';
    private static final Integer DEFAULT_LOAD_CHUNK_SIZE = 5000;

    public class WorkItemChunkResult {
        public List<FEC_BatchCaseHandlingImportRow> rows;
        public Integer lastRowIndex;
        public Boolean hasMore;
    }

    public static Boolean isWorkItemObjectAvailable() {
        return Schema.getGlobalDescribe().containsKey(WORK_OBJECT_API_NAME);
    }

    public static void stageRows(Id batchRecordId, List<FEC_BatchCaseHandlingImportRow> rows) {
        if (batchRecordId == null || rows == null || rows.isEmpty()) {
            return;
        }
        List<FEC_BCH_Import_Work_Item__c> chunk = new List<FEC_BCH_Import_Work_Item__c>();
        Integer rowIndex = 0;
        for (FEC_BatchCaseHandlingImportRow row : rows) {
            FEC_BCH_Import_Work_Item__c item = new FEC_BCH_Import_Work_Item__c();
            item.FEC_Batch_Case_Handling__c = batchRecordId;
            item.FEC_Row_Index__c = rowIndex;
            item.FEC_Row_Payload__c = JSON.serialize(row);
            item.FEC_Row_Status__c = STATUS_PENDING;
            item.FEC_Record_Id__c = row == null ? null : row.recordId;
            chunk.add(item);
            rowIndex++;
            if (chunk.size() >= DML_CHUNK_SIZE) {
                insert chunk;
                chunk.clear();
            }
        }
        if (!chunk.isEmpty()) {
            insert chunk;
        }
    }

    public static List<FEC_BatchCaseHandlingImportRow> deserializeRows(
        List<FEC_BCH_Import_Work_Item__c> workItems
    ) {
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>();
        if (workItems == null || workItems.isEmpty()) {
            return rows;
        }
        for (FEC_BCH_Import_Work_Item__c item : workItems) {
            rows.add(deserializeRowPayload(item == null ? null : item.FEC_Row_Payload__c));
        }
        return rows;
    }

    public static void saveScopeOutcomes(
        List<FEC_BCH_Import_Work_Item__c> workItems,
        List<FEC_BatchCaseHandlingImportRow> rows
    ) {
        if (workItems == null || workItems.isEmpty()) {
            return;
        }
        Integer max = workItems.size();
        for (Integer idx = 0; idx < max; idx++) {
            FEC_BCH_Import_Work_Item__c item = workItems[idx];
            FEC_BatchCaseHandlingImportRow row = idx < rows.size() ? rows[idx] : null;
            if (item == null || row == null) {
                continue;
            }
            item.FEC_Row_Payload__c = JSON.serialize(row);
            item.FEC_Row_Status__c = toWorkStatus(row.status);
            item.FEC_Row_Error__c = row.errors;
            item.FEC_Record_Id__c = row.recordId;
        }
        update workItems;
    }

    public static void markScopeFailed(
        List<FEC_BCH_Import_Work_Item__c> workItems,
        List<FEC_BatchCaseHandlingImportRow> rows,
        String failureMessage
    ) {
        if (workItems == null || workItems.isEmpty()) {
            return;
        }
        String err = String.isBlank(failureMessage)
            ? FEC_BatchCaseHandlingImportService.resolveImportQueueLimitExceededReason()
            : failureMessage;
        Integer max = workItems.size();
        for (Integer idx = 0; idx < max; idx++) {
            FEC_BCH_Import_Work_Item__c item = workItems[idx];
            FEC_BatchCaseHandlingImportRow row = idx < rows.size() ? rows[idx] : null;
            if (item == null) {
                continue;
            }
            if (row == null) {
                row = new FEC_BatchCaseHandlingImportRow();
                rows.add(row);
            }
            row.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
            row.errors = appendError(row.errors, err);
            item.FEC_Row_Payload__c = JSON.serialize(row);
            item.FEC_Row_Status__c = STATUS_FAILED;
            item.FEC_Row_Error__c = row.errors;
            item.FEC_Record_Id__c = row.recordId;
        }
        update workItems;
    }

    public static List<FEC_BatchCaseHandlingImportRow> loadRowsByBatch(Id batchRecordId) {
        List<FEC_BatchCaseHandlingImportRow> out = new List<FEC_BatchCaseHandlingImportRow>();
        if (batchRecordId == null) {
            return out;
        }
        for (FEC_BCH_Import_Work_Item__c item : [
            SELECT FEC_Row_Payload__c
            FROM FEC_BCH_Import_Work_Item__c
            WHERE FEC_Batch_Case_Handling__c = :batchRecordId
            ORDER BY FEC_Row_Index__c ASC
            LIMIT 50000
        ]) {
            out.add(deserializeRowPayload(item.FEC_Row_Payload__c));
        }
        return out;
    }

    public static WorkItemChunkResult loadRowsByBatchChunk(
        Id batchRecordId,
        Integer afterRowIndex,
        Integer chunkSize
    ) {
        WorkItemChunkResult out = new WorkItemChunkResult();
        out.rows = new List<FEC_BatchCaseHandlingImportRow>();
        out.lastRowIndex = afterRowIndex == null ? -1 : afterRowIndex;
        out.hasMore = false;
        if (batchRecordId == null) {
            return out;
        }
        Integer safeChunkSize = chunkSize == null || chunkSize < 1
            ? DEFAULT_LOAD_CHUNK_SIZE
            : Math.min(chunkSize, DEFAULT_LOAD_CHUNK_SIZE);
        Integer startRowIndex = afterRowIndex == null ? -1 : afterRowIndex;
        List<FEC_BCH_Import_Work_Item__c> rows = [
            SELECT FEC_Row_Index__c, FEC_Row_Payload__c
            FROM FEC_BCH_Import_Work_Item__c
            WHERE FEC_Batch_Case_Handling__c = :batchRecordId
            AND FEC_Row_Index__c > :startRowIndex
            ORDER BY FEC_Row_Index__c ASC
            LIMIT :safeChunkSize
        ];
        for (FEC_BCH_Import_Work_Item__c item : rows) {
            out.rows.add(deserializeRowPayload(item.FEC_Row_Payload__c));
            if (item.FEC_Row_Index__c != null) {
                out.lastRowIndex = item.FEC_Row_Index__c.intValue();
            }
        }
        if (!rows.isEmpty()) {
            Integer nextStart = out.lastRowIndex == null ? -1 : out.lastRowIndex;
            Integer remainCount = [
                SELECT COUNT()
                FROM FEC_BCH_Import_Work_Item__c
                WHERE FEC_Batch_Case_Handling__c = :batchRecordId
                AND FEC_Row_Index__c > :nextStart
            ];
            out.hasMore = remainCount > 0;
        }
        return out;
    }

    public static Integer countRowsByBatch(Id batchRecordId) {
        if (batchRecordId == null) {
            return 0;
        }
        return [
            SELECT COUNT()
            FROM FEC_BCH_Import_Work_Item__c
            WHERE FEC_Batch_Case_Handling__c = :batchRecordId
        ];
    }

    public static Integer countRowsByStatus(Id batchRecordId, String workStatus) {
        if (batchRecordId == null || String.isBlank(workStatus)) {
            return 0;
        }
        return [
            SELECT COUNT()
            FROM FEC_BCH_Import_Work_Item__c
            WHERE FEC_Batch_Case_Handling__c = :batchRecordId
            AND FEC_Row_Status__c = :workStatus
        ];
    }

    public static String findFirstFailureReason(Id batchRecordId) {
        if (batchRecordId == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        List<FEC_BCH_Import_Work_Item__c> rows = [
            SELECT FEC_Row_Error__c
            FROM FEC_BCH_Import_Work_Item__c
            WHERE FEC_Batch_Case_Handling__c = :batchRecordId
            AND FEC_Row_Status__c = :STATUS_FAILED
            ORDER BY FEC_Row_Index__c ASC
            LIMIT 1
        ];
        if (rows.isEmpty() || String.isBlank(rows[0].FEC_Row_Error__c)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return rows[0].FEC_Row_Error__c;
    }

    private static FEC_BatchCaseHandlingImportRow deserializeRowPayload(String rowPayload) {
        if (String.isBlank(rowPayload)) {
            return new FEC_BatchCaseHandlingImportRow();
        }
        try {
            return (FEC_BatchCaseHandlingImportRow) JSON.deserialize(
                rowPayload,
                FEC_BatchCaseHandlingImportRow.class
            );
        } catch (Exception ex) {
            FEC_BatchCaseHandlingImportRow fallback = new FEC_BatchCaseHandlingImportRow();
            fallback.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
            fallback.errors = ex.getMessage();
            return fallback;
        }
    }

    private static String toWorkStatus(String rowStatus) {
        if (rowStatus == System.Label.FEC_Batch_Case_Handling_Success) {
            return STATUS_SUCCESS;
        }
        if (rowStatus == System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed) {
            return STATUS_FAILED;
        }
        if (String.isBlank(rowStatus)) {
            return STATUS_PENDING;
        }
        return STATUS_PROCESSING;
    }

    private static String appendError(String current, String incoming) {
        if (String.isBlank(incoming)) {
            return current;
        }
        if (String.isBlank(current)) {
            return incoming;
        }
        if (current.contains(incoming)) {
            return current;
        }
        return current + ',\n' + incoming;
    }
}
