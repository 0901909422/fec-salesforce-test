public with sharing class FEC_BixIngestService {

    // Constants
    public static final String TABLE_NAME = 'BIX_FECS_CUST_ADDINFO';
    public static final String PK_COLUMN = 'PXEXTRACTDATETIME';
    public static final String OBJECT_API_NAME = 'FEC_CustomerAdditionalInfo__c';
    public static final String FUNCTION_NAME = 'FEC_BixIngestQueueable';
    @TestVisible
    private static final Integer MAX_PAYLOAD_SIZE = 6000000;

    // Inner class for BIX record structure
    public class BixRecord {
        public String KEYIDENTIFIER;
        public String KEYIDVALUE;
        public String FIELDID;
        public String FIELDVALUE;
        public String ISACTIVE;
        public String PZINSKEY;
        public String PXEXTRACTDATETIME;
        public String PXSAVEDATETIME;
        public String PXEXTRACTIDENTIFIER;
        public String PXINSNAME;
        public String PXCREATEDATETIME;
        public String PXCREATEOPERATOR;
        public String PXUPDATEDATETIME;
        public String PXUPDATEOPERATOR;
    }

    // Inner class for request body
    public class BixIngestRequest {
        public String tableName;
        public String pkColumn;
        public List<BixRecord> records;
    }

    /**
     * Build composite key: KeyIDValue!KeyIdentifier!FieldID
     * @param record FEC_CustomerAdditionalInfo__c record
     * @return composite key string
     */
    public static String buildCompositeKey(FEC_CustomerAdditionalInfo__c record) {
        String delimiter = FEC_ConstantCommon.COMPOSITE_KEY_DELIMITER;
        return safe(record.FEC_KeyIDValue__c)
            + delimiter
            + safe(record.FEC_KeyIdentifier__c)
            + delimiter
            + safe(record.FEC_FieldID__c);
    }

    /**
     * Map a single Detail_Record to BixRecord.
     * @param record source record
     * @param isoTimestamp current UTC datetime in ISO 8601
     * @return mapped BixRecord
     */
    public static BixRecord mapToBixRecord(FEC_CustomerAdditionalInfo__c record, String isoTimestamp) {
        String compositeKey = buildCompositeKey(record);
        String delimiter = FEC_ConstantCommon.COMPOSITE_KEY_DELIMITER;

        BixRecord bix = new BixRecord();
        bix.KEYIDENTIFIER = safe(record.FEC_KeyIdentifier__c);
        bix.KEYIDVALUE = safe(record.FEC_KeyIDValue__c);
        bix.FIELDID = safe(record.FEC_FieldID__c);
        bix.FIELDVALUE = safe(record.FEC_FieldValue__c);
        bix.ISACTIVE = (record.FEC_IsActive__c == true) ? '1' : '0';
        bix.PZINSKEY = OBJECT_API_NAME + delimiter + compositeKey;
        bix.PXEXTRACTDATETIME = isoTimestamp;
        bix.PXSAVEDATETIME = isoTimestamp;
        bix.PXEXTRACTIDENTIFIER = OBJECT_API_NAME + delimiter + FUNCTION_NAME + delimiter + isoTimestamp;
        bix.PXINSNAME = compositeKey;
        bix.PXCREATEDATETIME = record.CreatedDate != null ? record.CreatedDate.formatGmt(FEC_ConstantCommon.STR_DATETIME_FORMAT_Z) : null;
        bix.PXCREATEOPERATOR = record.CreatedById != null ? String.valueOf(record.CreatedById) : null;
        bix.PXUPDATEDATETIME = record.LastModifiedDate != null ? record.LastModifiedDate.formatGmt(FEC_ConstantCommon.STR_DATETIME_FORMAT_Z) : null;
        bix.PXUPDATEOPERATOR = record.LastModifiedById != null ? String.valueOf(record.LastModifiedById) : null;
        return bix;
    }

    /**
     * Build complete request body from list of Detail_Records.
     * @param records list of FEC_CustomerAdditionalInfo__c
     * @return serialized JSON string
     */
    public static String buildRequestBody(List<FEC_CustomerAdditionalInfo__c> records) {
        String isoTimestamp = Datetime.now().formatGmt(FEC_ConstantCommon.STR_DATETIME_FORMAT_Z);

        BixIngestRequest request = new BixIngestRequest();
        request.tableName = TABLE_NAME;
        request.pkColumn = PK_COLUMN;
        request.records = new List<BixRecord>();

        for (Integer i = 0; i < records.size(); i++) {
            request.records.add(mapToBixRecord(records[i], isoTimestamp));
        }

        return JSON.serialize(request);
    }

    /**
     * Split records into batches that fit within heap size limit.
     * @param records full list of records
     * @return List of record batches
     */
    public static List<List<FEC_CustomerAdditionalInfo__c>> splitIntoBatches(List<FEC_CustomerAdditionalInfo__c> records) {
        List<List<FEC_CustomerAdditionalInfo__c>> batches = new List<List<FEC_CustomerAdditionalInfo__c>>();
        List<FEC_CustomerAdditionalInfo__c> currentBatch = new List<FEC_CustomerAdditionalInfo__c>();
        Integer currentSize = 0;

        for (FEC_CustomerAdditionalInfo__c record : records) {
            String serialized = JSON.serialize(mapToBixRecord(record, ''));
            Integer recordSize = serialized.length() * 2; // UTF-16 estimate

            if (currentSize + recordSize > MAX_PAYLOAD_SIZE && !currentBatch.isEmpty()) {
                batches.add(currentBatch);
                currentBatch = new List<FEC_CustomerAdditionalInfo__c>();
                currentSize = 0;
            }

            currentBatch.add(record);
            currentSize += recordSize;
        }

        if (!currentBatch.isEmpty()) {
            batches.add(currentBatch);
        }

        return batches;
    }

    private static String safe(String val) {
        return String.isNotBlank(val) ? val : '';
    }
}
