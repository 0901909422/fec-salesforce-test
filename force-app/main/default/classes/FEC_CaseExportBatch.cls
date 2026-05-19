public class FEC_CaseExportBatch
        implements Database.Batchable<SObject>,
                   Database.AllowsCallouts,
                   Database.Stateful {

    // ── Batch config ─────────────────────────────────────────────────────────
    public static final Integer DEFAULT_BATCH_SIZE     = 100;
    private static final Integer CLOSED_DAYS_THRESHOLD = 90;

    // ── Stateful counters ────────────────────────────────────────────────────
    private Integer totalCases   = 0;
    private Integer successCount = 0;
    private Integer failCount    = 0;
    private List<String> failedInfo = new List<String>();

    // ── Stateful data accumulator — gom toàn bộ data qua các batch ────────
    private List<Map<String, Object>> allCaseData = new List<Map<String, Object>>();

    // ── start() ──────────────────────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime threshold = System.now().addDays(-CLOSED_DAYS_THRESHOLD);
        System.debug('[FEC_TempClass3d] start() — jobId: ' + bc.getJobId()
            + ', threshold: ' + threshold);
        return Database.getQueryLocator([
            SELECT Id, CaseNumber, FEC_ID_Search__c 
            FROM Case
            WHERE Status = 'Closed'
            AND ClosedDate <= :threshold
            ORDER BY ClosedDate ASC
        ]);
    }

    // ── execute() ────────────────────────────────────────────────────────────
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        Set<Id> caseIds = new Set<Id>();
        for (SObject s : scope) {
            caseIds.add(s.Id);
        }
        totalCases += caseIds.size();

        try {
            // 1. Query tất cả Cases trong batch — 1 SOQL
            Map<Id, Case> casesById = queryCasesBatch(caseIds);

            // 2. Query tất cả child custom objects — 1 SOQL/child type
            Map<String, Map<Id, List<SObject>>> childDataByType = queryChildObjectsBatch(caseIds);

            // 3. Query tất cả lookup objects — 1 SOQL/lookup type
            Map<String, Map<Id, SObject>> lookupDataByType = queryLookupObjectsBatch(casesById);

            // 4. Assemble JSON payload — gom lại theo từng case
            List<Map<String, Object>> batchPayload = new List<Map<String, Object>>();
            for (Id caseId : caseIds) {
                Case theCase = casesById.get(caseId);
                if (theCase == null) continue;

                Map<String, Object> caseResult = new Map<String, Object>();
                caseResult.put('Case', theCase);

                // Child relationships — cùng cấp với Case
                for (String childObjName : childDataByType.keySet()) {
                    Map<Id, List<SObject>> byCaseId = childDataByType.get(childObjName);
                    List<SObject> records = byCaseId.get(caseId);
                    caseResult.put(childObjName, (records != null && !records.isEmpty()) ? records : null);
                }

                // Lookup objects — cùng cấp với Case
                Map<String, Object> lookupMap = assembleLookupForCase(theCase, lookupDataByType);
                caseResult.putAll(lookupMap);

                batchPayload.add(caseResult);
            }

            if (batchPayload.isEmpty()) {
                return;
            }

            // Tích lũy data cho JSON report cuối cùng
            allCaseData.addAll(batchPayload);

            // 5. Lưu JSON file
            String jsonPayload = JSON.serializePretty(batchPayload);
            
            // 6. Gọi API
            FEC_CaseExportHttpService.postCases(jsonPayload);
            successCount += batchPayload.size();
            // 7. Update archive status
            markCasesAsProcessing(caseIds);

            System.debug('[FEC_TempClass3d] Batch OK — ' + batchPayload.size() + ' cases');
            System.debug('caseid: '+ caseIds);
        } catch (Exception ex) {
            failCount += caseIds.size();
            failedInfo.add(caseIds.size() + ' cases: ' + ex.getMessage());
            System.debug(LoggingLevel.ERROR,
                '[FEC_TempClass3d] Batch FAILED: ' + ex.getMessage());
        }
    }

    // ── finish() ─────────────────────────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        System.debug('[CaseExportBatch] ═══ KẾT QUẢ ═══');
        System.debug('  Tổng số cases : ' + totalCases);
        System.debug('  Batch OK      : ' + successCount);
        System.debug('  Batch FAILED  : ' + failCount);
        if (!failedInfo.isEmpty()) {
            for (String info : failedInfo) {
                System.debug('  ✗ ' + info);
            }
        }

        // Render JSON report và lưu vào Salesforce dưới dạng ContentVersion
        // saveJsonReport(bc.getJobId());
    }

    /**
     * Tạo JSON file chứa toàn bộ data đã query và lưu vào Salesforce (ContentVersion).
     */
    private void saveJsonReport(Id jobId) {
        try {
            String jsonContent = JSON.serializePretty(allCaseData);
            String fileName = 'CaseExportBatch_'
                + System.now().format('yyyyMMdd_HHmmss') + '.json';

            ContentVersion cv = new ContentVersion();
            cv.Title          = fileName;
            cv.PathOnClient   = fileName;
            cv.VersionData    = Blob.valueOf(jsonContent);
            cv.Description    = 'FEC Case Export Batch Data - Job: ' + jobId;
            insert cv;

            System.debug('[CaseExportBatch] JSON report saved: ' + fileName
                + ' (ContentVersion Id: ' + cv.Id + ')');
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR,
                '[CaseExportBatch] Failed to save JSON report: ' + ex.getMessage());
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BATCH-LEVEL QUERIES — 1 SOQL per object type cho toàn bộ batch
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Query tất cả Cases trong batch với all accessible fields — 1 SOQL.
     */
    private static Map<Id, Case> queryCasesBatch(Set<Id> caseIds) {
        String q = buildAllFieldsQuery('Case') + ' WHERE Id IN :caseIds';
        List<Case> cases = Database.query(q);
        Map<Id, Case> result = new Map<Id, Case>();
        for (Case c : cases) {
            result.put(c.Id, c);
        }
        return result;
    }

    /**
     * Query tất cả child custom objects cho batch caseIds.
     * Mỗi child object type = 1 SOQL, kết quả group theo CaseId.
     *
     * Return: Map<ChildObjectName, Map<CaseId, List<SObject>>>
     */
    private static Map<String, Map<Id, List<SObject>>> queryChildObjectsBatch(Set<Id> caseIds) {
        Map<String, Map<Id, List<SObject>>> result = new Map<String, Map<Id, List<SObject>>>();

        List<Schema.ChildRelationship> childRels = Schema.SObjectType.Case.getChildRelationships();

        for (Schema.ChildRelationship childRel : childRels) {
            Schema.SObjectType childType = childRel.getChildSObject();
            String childObjectName = childType.getDescribe().getName();
            String childFieldName = childRel.getField().getDescribe().getName();

            if (!childObjectName.endsWith('__c')) {
                continue;
            }

            Map<Id, List<SObject>> byCaseId = new Map<Id, List<SObject>>();
            // Khởi tạo empty list cho mỗi caseId
            for (Id cId : caseIds) {
                byCaseId.put(cId, new List<SObject>());
            }

            try {
                // 1 SOQL cho tất cả cases trong batch
                String q = buildAllFieldsQuery(childObjectName)
                    + ' WHERE ' + childFieldName + ' IN :caseIds'
                    + ' LIMIT 50000';
                List<SObject> records = Database.query(q);

                // Group theo CaseId
                for (SObject rec : records) {
                    Id parentCaseId = (Id) rec.get(childFieldName);
                    if (byCaseId.containsKey(parentCaseId)) {
                        byCaseId.get(parentCaseId).add(rec);
                    }
                }
                System.debug('[FEC_TempClass3d] Child ' + childObjectName
                    + ': ' + records.size() + ' records total');
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN,
                    '[FEC_TempClass3d] Cannot query child ' + childObjectName
                    + ': ' + ex.getMessage());
            }

            result.put(childObjectName, byCaseId);
        }

        return result;
    }

    /**
     * Query tất cả lookup objects cho batch.
     * Gom tất cả lookup IDs từ tất cả cases, group theo object type, 1 SOQL/type.
     *
     * Return: Map<ObjectTypeName, Map<RecordId, SObject>>
     */
    private static Map<String, Map<Id, SObject>> queryLookupObjectsBatch(Map<Id, Case> casesById) {
        Map<String, Schema.SObjectField> caseFields = Schema.SObjectType.Case.fields.getMap();

        // Bước 1: Gom tất cả lookup IDs từ tất cả cases theo object type
        Map<String, Set<Id>> idsByObjectType = new Map<String, Set<Id>>();

        for (Case theCase : casesById.values()) {
            for (String fieldName : caseFields.keySet()) {
                Schema.DescribeFieldResult fieldDesc = caseFields.get(fieldName).getDescribe();

                if (fieldDesc.getType() != Schema.DisplayType.REFERENCE) {
                    continue;
                }

                List<Schema.SObjectType> referenceTo = fieldDesc.getReferenceTo();
                if (referenceTo == null || referenceTo.isEmpty()) {
                    continue;
                }

                Object refIdValue = theCase.get(fieldDesc.getName());
                if (refIdValue == null) {
                    continue;
                }

                Id refId = (Id) refIdValue;
                for (Schema.SObjectType refType : referenceTo) {
                    String objectName = refType.getDescribe().getName();
                    if (objectName == 'Case') {
                        continue;
                    }
                    if (!idsByObjectType.containsKey(objectName)) {
                        idsByObjectType.put(objectName, new Set<Id>());
                    }
                    idsByObjectType.get(objectName).add(refId);
                }
            }
        }

        // Bước 2: Query 1 lần cho mỗi object type
        Map<String, Map<Id, SObject>> result = new Map<String, Map<Id, SObject>>();

        for (String objectName : idsByObjectType.keySet()) {
            Set<Id> ids = idsByObjectType.get(objectName);
            Map<Id, SObject> recordsById = new Map<Id, SObject>();

            try {
                String q = buildAllFieldsQuery(objectName) + ' WHERE Id IN :ids';
                List<SObject> records = Database.query(q);
                for (SObject rec : records) {
                    recordsById.put(rec.Id, rec);
                }
                System.debug('[FEC_TempClass3d] Lookup ' + objectName
                    + ': ' + records.size() + ' records');
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN,
                    '[FEC_TempClass3d] Cannot query lookup ' + objectName
                    + ': ' + ex.getMessage());
            }

            result.put(objectName, recordsById);
        }

        return result;
    }

    /**
     * Assemble lookup data cho 1 case cụ thể từ batch lookup results.
     * Duyệt qua tất cả reference fields trên Case, lấy record tương ứng từ lookupDataByType.
     */
    private static Map<String, Object> assembleLookupForCase(
        Case theCase,
        Map<String, Map<Id, SObject>> lookupDataByType
    ) {
        Map<String, Schema.SObjectField> caseFields = Schema.SObjectType.Case.fields.getMap();
        Map<String, Object> lookupMap = new Map<String, Object>();

        // Gom records theo object type cho case này
        Map<String, List<SObject>> recordsByType = new Map<String, List<SObject>>();

        for (String fieldName : caseFields.keySet()) {
            Schema.DescribeFieldResult fieldDesc = caseFields.get(fieldName).getDescribe();

            if (fieldDesc.getType() != Schema.DisplayType.REFERENCE) {
                continue;
            }

            List<Schema.SObjectType> referenceTo = fieldDesc.getReferenceTo();
            if (referenceTo == null || referenceTo.isEmpty()) {
                continue;
            }

            Object refIdValue = theCase.get(fieldDesc.getName());

            for (Schema.SObjectType refType : referenceTo) {
                String objectName = refType.getDescribe().getName();
                if (objectName == 'Case') {
                    continue;
                }

                if (refIdValue != null && lookupDataByType.containsKey(objectName)) {
                    Id refId = (Id) refIdValue;
                    SObject rec = lookupDataByType.get(objectName).get(refId);
                    if (rec != null) {
                        if (!recordsByType.containsKey(objectName)) {
                            recordsByType.put(objectName, new List<SObject>());
                        }
                        // Tránh duplicate
                        Boolean exists = false;
                        for (SObject existing : recordsByType.get(objectName)) {
                            if (existing.Id == rec.Id) {
                                exists = true;
                                break;
                            }
                        }
                        if (!exists) {
                            recordsByType.get(objectName).add(rec);
                        }
                    }
                }
            }
        }

        // Build output
        for (String objectName : recordsByType.keySet()) {
            List<SObject> records = recordsByType.get(objectName);
            if (objectName == 'FEC_Customer_History__c') {
                // Luôn trả về array cho FEC_Customer_History__c
                lookupMap.put(objectName, records);
            } else if (records.size() == 1) {
                lookupMap.put(objectName, records[0]);
            } else {
                lookupMap.put(objectName, records);
            }
        }

        // Object types không có reference → null
        Set<String> allReferencedTypes = new Set<String>();
        for (String fieldName : caseFields.keySet()) {
            Schema.DescribeFieldResult fieldDesc = caseFields.get(fieldName).getDescribe();
            if (fieldDesc.getType() != Schema.DisplayType.REFERENCE) {
                continue;
            }
            List<Schema.SObjectType> referenceTo = fieldDesc.getReferenceTo();
            if (referenceTo == null || referenceTo.isEmpty()) {
                continue;
            }
            for (Schema.SObjectType refType : referenceTo) {
                String objName = refType.getDescribe().getName();
                if (objName != 'Case') {
                    allReferencedTypes.add(objName);
                }
            }
        }
        for (String objName : allReferencedTypes) {
            if (!lookupMap.containsKey(objName)) {
                lookupMap.put(objName, null);
            }
        }

        return lookupMap;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // UTILITIES
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Build SOQL SELECT với tất cả accessible fields.
     */
    private static String buildAllFieldsQuery(String objectName) {
        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectName);
        Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();
        List<String> fieldNames = new List<String>();

        for (String fName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fDesc = fieldMap.get(fName).getDescribe();
            if (fDesc.isAccessible()) {
                fieldNames.add(fDesc.getName());
            }
        }

        return 'SELECT ' + String.join(fieldNames, ', ') + ' FROM ' + objectName;
    }

    /**
     * Update FEC_Archive_Status__c = 'Processing' sau khi gửi thành công.
     */
    private static void markCasesAsProcessing(Set<Id> caseIds) {
        List<Case> toUpdate = new List<Case>();
        Datetime now = System.now();
        for (Id cId : caseIds) {
            toUpdate.add(new Case(
                Id                      = cId,
                FEC_Archive_Status__c   = 'Processing',
                FEC_Archive_Sent_At__c  = now,
                FEC_Attachment_Status__c = null
            ));
        }
        List<Database.SaveResult> results = Database.update(toUpdate, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                System.debug(LoggingLevel.WARN,
                    '[FEC_TempClass3d] Cannot update archive flag for '
                    + toUpdate[i].Id + ': '
                    + results[i].getErrors()[0].getMessage());
            }
        }
    }

    // ── Static helpers ───────────────────────────────────────────────────────
    public static void run() {
        Database.executeBatch(new FEC_CaseExportBatch(), DEFAULT_BATCH_SIZE);
    }

    public static void run(Integer batchSize) {
        Database.executeBatch(new FEC_CaseExportBatch(), batchSize);
    }
}