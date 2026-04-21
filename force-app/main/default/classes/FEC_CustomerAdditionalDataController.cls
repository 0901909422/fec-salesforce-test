/**
 * LWC C360 — tab Additional Data: đọc FEC_CustomerAdditionalInfo__c (chỉ field trên object)
 * đã lọc theo Case; config FEC_CustomerAdditionalInfoConfig__c truy vấn riêng theo FEC_Config__c.
 * Khớp KeyIdentifier + KeyIDValue với Case; chỉ bản ghi chi tiết isActive, config isActive,
 * trong khoảng StartDate–EndDate của config.
 */
public with sharing class FEC_CustomerAdditionalDataController {

    public class RowDTO {
        @AuraEnabled public String recordName { get; set; }
        @AuraEnabled public String fieldLabel { get; set; }
        @AuraEnabled public String fieldValue { get; set; }
        @AuraEnabled public String sourceFileName { get; set; }
    }

    private static final String KEY_CIF = 'CIF';
    private static final String KEY_ID_CARD = 'ID_CARD';
    private static final String KEY_PHONE = 'PHONE';
    private static final String KEY_PID = 'PID';
    private static final String KEY_APPLICATION_ID = 'APPLICATION_ID';
    private static final String KEY_ACCOUNT_NO = 'ACCOUNT_NO';
    private static final String KEY_CONTRACT_NO = 'CONTRACT_NO';
    private static final String KEY_USER_ID = 'USER_ID';

    @AuraEnabled(cacheable=true)
    public static List<RowDTO> getAdditionalDataRows(Id caseId) {
        return getRowsForCase(caseId);
    }

    private static List<RowDTO> getRowsForCase(Id caseId) {
        List<RowDTO> result = new List<RowDTO>();
        if (caseId == null) {
            return result;
        }
        Case c = queryCase(caseId);
        if (c == null) {
            return result;
        }
        Map<String, Set<String>> keyToValues = buildKeyValueMap(c);
        if (keyToValues.isEmpty()) {
            return result;
        }
        Set<String> keyIds = keyToValues.keySet();
        Set<String> allValues = new Set<String>();
        for (Set<String> vs : keyToValues.values()) {
            allValues.addAll(vs);
        }
        Date today = Date.today();
        List<FEC_CustomerAdditionalInfo__c> raw = [
            SELECT Name, FEC_FieldID__c, FEC_FieldValue__c, FEC_KeyIdentifier__c, FEC_KeyIDValue__c,
                   FEC_LinkedFilename__c, FEC_Config__c
            FROM FEC_CustomerAdditionalInfo__c
            WHERE FEC_IsActive__c = TRUE
            AND FEC_KeyIdentifier__c IN :keyIds
            AND FEC_KeyIDValue__c IN :allValues
        ];

        Set<Id> configIds = new Set<Id>();
        for (FEC_CustomerAdditionalInfo__c r : raw) {
            if (r.FEC_Config__c != null) {
                configIds.add(r.FEC_Config__c);
            }
        }
        Map<Id, FEC_CustomerAdditionalInfoConfig__c> cfgById = new Map<Id, FEC_CustomerAdditionalInfoConfig__c>();
        if (!configIds.isEmpty()) {
            List<FEC_CustomerAdditionalInfoConfig__c> cfgRows = [
                SELECT Id, FEC_StartDate__c, FEC_EndDate__c, FEC_IsActive__c, FEC_FieldName__c
                FROM FEC_CustomerAdditionalInfoConfig__c
                WHERE Id IN :configIds
            ];
            cfgById.putAll(cfgRows);
        }

        for (FEC_CustomerAdditionalInfo__c row : raw) {
            if (row.FEC_Config__c == null) {
                continue;
            }
            FEC_CustomerAdditionalInfoConfig__c cfgRow = cfgById.get(row.FEC_Config__c);
            if (cfgRow == null) {
                continue;
            }
            if (cfgRow.FEC_IsActive__c != true || !isInDateWindow(cfgRow, today)) {
                continue;
            }
            String kid = row.FEC_KeyIdentifier__c;
            String kv = row.FEC_KeyIDValue__c == null ? FEC_ConstantCommon.STR_EMPTY : row.FEC_KeyIDValue__c.trim();
            if (String.isBlank(kid) || String.isBlank(kv)) {
                continue;
            }
            Set<String> allowed = keyToValues.get(kid);
            if (allowed == null || !allowed.contains(kv)) {
                continue;
            }
            RowDTO dto = new RowDTO();
            dto.recordName = row.Name;
            dto.fieldLabel = String.isNotBlank(cfgRow.FEC_FieldName__c)
                ? cfgRow.FEC_FieldName__c
                : row.FEC_FieldID__c;
            dto.fieldValue = row.FEC_FieldValue__c;
            dto.sourceFileName = row.FEC_LinkedFilename__c;
            result.add(dto);
        }
        return result;
    }

    private static Case queryCase(Id caseId) {
        List<Case> cases = [
            SELECT FEC_CIF_Number__c, FEC_Search_National_ID__c, FEC_National_ID_Passport_ID__c,
                   FEC_Search_Phone_Number__c, FEC_Application_ID__c, FEC_Account_Number__c,
                   FEC_Contract_Number__c, FEC_Customer_Username__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        return cases.isEmpty() ? null : cases[0];
    }

    private static Map<String, Set<String>> buildKeyValueMap(Case c) {
        Map<String, Set<String>> m = new Map<String, Set<String>>();
        putKeyValue(m, KEY_CIF, c.FEC_CIF_Number__c);
        putKeyValue(m, KEY_ID_CARD, c.FEC_Search_National_ID__c);
        putKeyValue(m, KEY_ID_CARD, c.FEC_National_ID_Passport_ID__c);
        putKeyValue(m, KEY_PHONE, c.FEC_Search_Phone_Number__c);
        putKeyValue(m, KEY_PID, c.FEC_National_ID_Passport_ID__c);
        putKeyValue(m, KEY_APPLICATION_ID, c.FEC_Application_ID__c);
        putKeyValue(m, KEY_ACCOUNT_NO, c.FEC_Account_Number__c);
        putKeyValue(m, KEY_CONTRACT_NO, c.FEC_Contract_Number__c);
        putKeyValue(m, KEY_USER_ID, c.FEC_Customer_Username__c);
        return m;
    }

    private static void putKeyValue(Map<String, Set<String>> m, String keyIdentifier, String rawValue) {
        if (String.isBlank(keyIdentifier) || rawValue == null) {
            return;
        }
        String v = rawValue.trim();
        if (String.isBlank(v)) {
            return;
        }
        if (!m.containsKey(keyIdentifier)) {
            m.put(keyIdentifier, new Set<String>());
        }
        m.get(keyIdentifier).add(v);
    }

    private static Boolean isInDateWindow(FEC_CustomerAdditionalInfoConfig__c cfg, Date today) {
        if (cfg.FEC_StartDate__c != null && today < cfg.FEC_StartDate__c) {
            return false;
        }
        if (cfg.FEC_EndDate__c != null && today > cfg.FEC_EndDate__c) {
            return false;
        }
        return true;
    }
}