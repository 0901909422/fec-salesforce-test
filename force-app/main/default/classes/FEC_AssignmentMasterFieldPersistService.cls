/**
 * Persist master-data Assignment fields when user submits Assignment (N5).
 */
public without sharing class FEC_AssignmentMasterFieldPersistService {
    private static final String TYPE_ASSIGNMENT = 'Assignment';

    public class FieldValueInput {
        @AuraEnabled
        public String objectApiName;
        @AuraEnabled
        public String fieldApiName;
        @AuraEnabled
        public String value;
    }

    public class AllowlistField {
        public String objectApiName;
        public String fieldApiName;
        public String label;
        public Boolean mandatory;
    }

    @AuraEnabled
    public static void persistOnAssignmentSubmit(Id caseId, String fieldValuesJson) {
        if (caseId == null || String.isBlank(fieldValuesJson)) {
            return;
        }

        List<FieldValueInput> inputs;
        try {
            inputs = (List<FieldValueInput>) JSON.deserialize(
                fieldValuesJson,
                List<FieldValueInput>.class
            );
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_ERR_INVALID_INPUT);
        }
        if (inputs == null || inputs.isEmpty()) {
            validateMandatoryFields(caseId, new Map<String, String>());
            return;
        }

        Map<String, String> payloadByKey = new Map<String, String>();
        for (FieldValueInput input : inputs) {
            if (
                input == null ||
                String.isBlank(input.objectApiName) ||
                String.isBlank(input.fieldApiName)
            ) {
                continue;
            }
            String key = buildKey(input.objectApiName, input.fieldApiName);
            payloadByKey.put(key, input.value);
        }

        validateMandatoryFields(caseId, payloadByKey);
        applyPersist(caseId, payloadByKey);
    }

    private static void validateMandatoryFields(
        Id caseId,
        Map<String, String> payloadByKey
    ) {
        Map<String, AllowlistField> allowlist = loadAllowlist(caseId);
        List<String> missingLabels = new List<String>();
        for (AllowlistField allowed : allowlist.values()) {
            if (allowed.mandatory != true) {
                continue;
            }
            String key = buildKey(allowed.objectApiName, allowed.fieldApiName);
            String val = payloadByKey.get(key);
            if (String.isBlank(val)) {
                missingLabels.add(
                    String.isNotBlank(allowed.label)
                        ? allowed.label
                        : allowed.fieldApiName
                );
            }
        }
        if (!missingLabels.isEmpty()) {
            throw new AuraHandledException(
                String.format(
                    System.Label.FEC_MSG_Invalid,
                    new List<String>{
                        String.join(missingLabels, ', ')
                    }
                )
            );
        }
    }

    private static void applyPersist(Id caseId, Map<String, String> payloadByKey) {
        Map<String, AllowlistField> allowlist = loadAllowlist(caseId);
        if (allowlist.isEmpty()) {
            return;
        }

        CaseContext ctx = loadCaseContext(caseId);
        Map<String, SObject> recordsByObject = resolveTargetRecords(ctx, allowlist.values());

        Map<String, Map<String, String>> updatesByObject = new Map<String, Map<String, String>>();
        for (String key : payloadByKey.keySet()) {
            if (!allowlist.containsKey(key)) {
                continue;
            }
            AllowlistField allowed = allowlist.get(key);
            if (!recordsByObject.containsKey(allowed.objectApiName)) {
                continue;
            }
            if (!updatesByObject.containsKey(allowed.objectApiName)) {
                updatesByObject.put(
                    allowed.objectApiName,
                    new Map<String, String>()
                );
            }
            updatesByObject.get(allowed.objectApiName)
                .put(allowed.fieldApiName, payloadByKey.get(key));
        }

        List<SObject> toUpdate = new List<SObject>();
        for (String objName : updatesByObject.keySet()) {
            SObject rec = recordsByObject.get(objName);
            if (rec == null || rec.Id == null) {
                continue;
            }
            Map<String, String> fieldMap = updatesByObject.get(objName);
            for (String fieldApi : fieldMap.keySet()) {
                setFieldFromString(rec, fieldApi, fieldMap.get(fieldApi));
            }
            toUpdate.add(rec);
        }

        if (toUpdate.isEmpty()) {
            return;
        }

        FEC_CaseTriggerHandler.isSystemUpdate = true;
        try {
            Database.update(toUpdate, AccessLevel.SYSTEM_MODE);
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = false;
        }
    }

    private static Map<String, AllowlistField> loadAllowlist(Id caseId) {
        Map<String, AllowlistField> result = new Map<String, AllowlistField>();
        CaseContext ctx = loadCaseContext(caseId);
        if (ctx == null || ctx.stageId == null || ctx.natureOfCaseId == null) {
            return result;
        }
        if (ctx.assignmentCount == null || ctx.assignmentCount <= 0) {
            return result;
        }

        String masterDataSettingObj = ctx.useActualMasterData
            ? 'FEC_Actual_Master_Data_Setting__c'
            : 'FEC_Master_Data_Setting__c';
        String natureField = ctx.useActualMasterData
            ? 'FEC_Actual_Nature_of_Case__c'
            : 'FEC_Nature_of_Case__c';

        String soql =
            'SELECT FEC_Field_API_Name__c, FEC_Field_Object_Name__c, ' +
            'FEC_Field_Mandatory__c, FEC_Field_Editable__c, FEC_Field_Label_Name__c, ' +
            'FEC_Editable_User_Group__c, FEC_Hidden__c, FEC_Field_Reverted__c, FEC_Type__c ' +
            'FROM ' +
            masterDataSettingObj +
            ' WHERE ' +
            natureField +
            ' = :natureOfCaseId AND FEC_Stage_Name__c = :stageId ' +
            'AND FEC_Field_Status__c = TRUE AND FEC_Type__c = :assignmentType';

        List<SObject> masterDatalst = Database.queryWithBinds(
            soql,
            new Map<String, Object>{
                'natureOfCaseId' => ctx.natureOfCaseId,
                'stageId' => ctx.stageId,
                'assignmentType' => TYPE_ASSIGNMENT
            },
            AccessLevel.USER_MODE
        );

        masterDatalst = FEC_CaseMasterDataHelper.filterRevertedAssignmentRowsByStageContext(
            masterDatalst,
            ctx.isRevertContext,
            ctx.revertConfirmAssessmentSourceStage
        );
        masterDatalst = FEC_CaseMasterDataHelper.filterAssignmentRowsByCurrentUserGroup(
            masterDatalst,
            ctx.userGroup
        );
        masterDatalst = FEC_CaseMasterDataHelper.removeMasterDataRowsByHiddenAssignmentFieldApis(
            masterDatalst,
            true,
            ctx.userGroup
        );

        for (SObject row : masterDatalst) {
            if (!TYPE_ASSIGNMENT.equals((String) row.get('FEC_Type__c'))) {
                continue;
            }
            Boolean fieldEditable = (Boolean) row.get('FEC_Field_Editable__c');
            String editableGr = (String) row.get('FEC_Editable_User_Group__c');
            if (
                !FEC_CaseMasterDataHelper.isAssignmentFieldEditable(
                    fieldEditable,
                    editableGr,
                    ctx.userGroup
                )
            ) {
                continue;
            }
            String objName = (String) row.get('FEC_Field_Object_Name__c');
            String fieldApi = (String) row.get('FEC_Field_API_Name__c');
            if (String.isBlank(objName) || String.isBlank(fieldApi)) {
                continue;
            }
            AllowlistField allowed = new AllowlistField();
            allowed.objectApiName = objName;
            allowed.fieldApiName = fieldApi;
            allowed.label = (String) row.get('FEC_Field_Label_Name__c');
            allowed.mandatory = (Boolean) row.get('FEC_Field_Mandatory__c') == true;
            result.put(buildKey(objName, fieldApi), allowed);
        }
        return result;
    }

    private static Map<String, SObject> resolveTargetRecords(
        CaseContext ctx,
        Iterable<AllowlistField> allowlistFields
    ) {
        Map<String, SObject> result = new Map<String, SObject>();
        Set<String> objectNames = new Set<String>();
        for (AllowlistField f : allowlistFields) {
            objectNames.add(f.objectApiName);
        }

        for (String objName : objectNames) {
            SObject rec = queryRecordForObject(ctx, objName);
            if (rec != null) {
                result.put(objName, rec);
            }
        }
        return result;
    }

    private static SObject queryRecordForObject(CaseContext ctx, String objName) {
        if (ctx == null || ctx.caseId == null) {
            return null;
        }
        if ('Case'.equalsIgnoreCase(objName)) {
            return new Case(Id = ctx.caseId);
        }
        if ('FEC_Customer_History__c'.equalsIgnoreCase(objName)) {
            if (String.isBlank(ctx.customerHistoryId)) {
                return null;
            }
            List<SObject> rows = Database.queryWithBinds(
                'SELECT Id FROM FEC_Customer_History__c WHERE Id = :hid LIMIT 1',
                new Map<String, Object>{ 'hid' => ctx.customerHistoryId },
                AccessLevel.USER_MODE
            );
            return rows.isEmpty() ? null : rows[0];
        }
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objName);
        if (objType == null) {
            return null;
        }
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe()
            .fields.getMap();
        if (!fieldMap.containsKey('FEC_Case__c')) {
            return null;
        }
        String soql =
            'SELECT Id FROM ' +
            String.escapeSingleQuotes(objName) +
            ' WHERE FEC_Case__c = :caseId LIMIT 1';
        List<SObject> rows = Database.queryWithBinds(
            soql,
            new Map<String, Object>{ 'caseId' => ctx.caseId },
            AccessLevel.USER_MODE
        );
        return rows.isEmpty() ? null : rows[0];
    }

    private static void setFieldFromString(
        SObject rec,
        String fieldApi,
        String stringValue
    ) {
        Schema.SObjectField token = rec.getSObjectType()
            .getDescribe()
            .fields.getMap()
            .get(fieldApi);
        if (token == null) {
            return;
        }
        Schema.DescribeFieldResult dfr = token.getDescribe();
        if (!dfr.isUpdateable()) {
            return;
        }
        if (String.isBlank(stringValue)) {
            rec.put(fieldApi, null);
            return;
        }
        Schema.DisplayType dt = dfr.getType();
        if (dt == Schema.DisplayType.Boolean) {
            rec.put(fieldApi, Boolean.valueOf(stringValue));
        } else if (dt == Schema.DisplayType.Date) {
            rec.put(fieldApi, Date.valueOf(stringValue));
        } else if (dt == Schema.DisplayType.DateTime) {
            rec.put(fieldApi, DateTime.valueOf(stringValue));
        } else if (
            dt == Schema.DisplayType.Double ||
            dt == Schema.DisplayType.Currency ||
            dt == Schema.DisplayType.Percent
        ) {
            rec.put(fieldApi, Decimal.valueOf(stringValue));
        } else if (dt == Schema.DisplayType.Integer) {
            rec.put(fieldApi, Integer.valueOf(stringValue));
        } else {
            rec.put(fieldApi, stringValue);
        }
    }

    private static String buildKey(String objectApiName, String fieldApiName) {
        return objectApiName + '::' + fieldApiName;
    }

    private class CaseContext {
        public Id caseId;
        public Id natureOfCaseId;
        public Id stageId;
        public String stageName;
        public String userGroup;
        public String customerHistoryId;
        public Decimal assignmentCount;
        public Boolean useActualMasterData;
        public Boolean isRevertContext;
        public Integer revertConfirmAssessmentSourceStage;
    }

    private static CaseContext loadCaseContext(Id caseId) {
        List<Case> caselst = [
            SELECT
                Id,
                FEC_Actual_Nature_of_Case__c,
                FEC_Current_Case_Stage__c,
                FEC_Current_Case_Stage__r.Name,
                FEC_Assignment_Count__c,
                FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (caselst.isEmpty()) {
            return null;
        }
        Case c = caselst[0];
        User u = [
            SELECT FEC_User_Group__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        CaseContext ctx = new CaseContext();
        ctx.caseId = c.Id;
        ctx.stageId = c.FEC_Current_Case_Stage__c;
        ctx.stageName = c.FEC_Current_Case_Stage__r?.Name;
        ctx.customerHistoryId = c.FEC_Account_or_Contract__c;
        ctx.assignmentCount = c.FEC_Assignment_Count__c == null
            ? 0
            : c.FEC_Assignment_Count__c;
        ctx.userGroup = u.FEC_User_Group__c;
        ctx.useActualMasterData = String.isNotBlank(c.FEC_Actual_Nature_of_Case__c);
        ctx.natureOfCaseId = ctx.useActualMasterData
            ? (Id) c.FEC_Actual_Nature_of_Case__c
            : null;
        if (ctx.natureOfCaseId == null) {
            return ctx;
        }
        ctx.isRevertContext = isLatestRevertToCurrentStage(
            c.Id,
            ctx.stageId,
            ctx.stageName
        );
        ctx.revertConfirmAssessmentSourceStage = FEC_CaseMasterDataHelper.resolveRevertConfirmAssessmentSourceStage(
            c.Id,
            ctx.stageId,
            ctx.stageName,
            false
        );
        return ctx;
    }

    private static Boolean isLatestRevertToCurrentStage(
        Id caseId,
        Id currentStageId,
        String currentStageName
    ) {
        if (caseId == null || currentStageId == null) {
            return false;
        }
        List<FEC_Routing_Action_History__c> latestRevertHist = [
            SELECT Id
            FROM FEC_Routing_Action_History__c
            WHERE
                FEC_Case__c = :caseId
                AND FEC_Next_Stage__c = :currentStageId
                AND FEC_Next_Stage__c != NULL
                AND FEC_IsReverted__c = TRUE
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return !latestRevertHist.isEmpty();
    }
}
