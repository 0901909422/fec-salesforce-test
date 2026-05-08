/**
 * LWC C360 — tab Additional Data: đọc FEC_CustomerAdditionalInfo__c (chỉ field trên object)
 * đã lọc theo Case; config FEC_CustomerAdditionalInfoConfig__c truy vấn riêng theo FEC_Config__c.
 * Khớp KeyIdentifier + KeyIDValue với FEC_Account_or_Contract__r; chỉ bản ghi chi tiết isActive, config isActive,
 * trong khoảng StartDate–EndDate của config.
 * Một Case chỉ dùng một điều kiện lookup (ưu tiên theo STT design: CIF_NUMBER → ID_CARD → PHONE_NUMBER →
 * APPLICATION_ID → ACCOUNT_NO/CONTRACT_NO); nếu nhiều bản ghi FEC_CustomerAdditionalInfo__c khớp thì chỉ trả 1 bản (CreatedDate mới nhất).
 */
public with sharing class FEC_CustomerAdditionalDataController {

    public class RowDTO {
        @AuraEnabled public String recordName { get; set; }
        @AuraEnabled public String fieldLabel { get; set; }
        @AuraEnabled public String fieldValue { get; set; }
        @AuraEnabled public String sourceFileName { get; set; }
    }

    private static final String KEY_CIF_NUMBER = 'CIF_NUMBER';
    private static final String KEY_ID_CARD = 'ID_CARD';
    private static final String KEY_PHONE_NUMBER = 'PHONE_NUMBER';
    private static final String KEY_APPLICATION_ID = 'APPLICATION_ID';
    private static final String KEY_ACCOUNT_NO = 'ACCOUNT_NO';
    private static final String KEY_CONTRACT_NO = 'CONTRACT_NO';

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
        if (c.RecordType == null || c.RecordType.DeveloperName != FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME) {
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
            SELECT Id, CreatedDate, Name, FEC_FieldID__c, FEC_FieldValue__c, FEC_KeyIdentifier__c, FEC_KeyIDValue__c,
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

        FEC_CustomerAdditionalInfo__c bestRow;
        FEC_CustomerAdditionalInfoConfig__c bestCfg;
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
            if (bestRow == null || row.CreatedDate > bestRow.CreatedDate
                    || (row.CreatedDate == bestRow.CreatedDate && row.Id > bestRow.Id)) {
                bestRow = row;
                bestCfg = cfgRow;
            }
        }
        if (bestRow != null && bestCfg != null) {
            RowDTO dto = new RowDTO();
            dto.recordName = bestRow.Name;
            dto.fieldLabel = String.isNotBlank(bestCfg.FEC_FieldName__c)
                ? bestCfg.FEC_FieldName__c
                : bestRow.FEC_FieldID__c;
            dto.fieldValue = bestRow.FEC_FieldValue__c;
            dto.sourceFileName = bestRow.FEC_LinkedFilename__c;
            result.add(dto);
        }
        return result;
    }

    private static Case queryCase(Id caseId) {
        List<Case> cases = [
            SELECT RecordType.DeveloperName,
                   FEC_Account_or_Contract__c,
                   FEC_Account_or_Contract__r.FEC_CIF_Number__c,
                   FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c,
                   FEC_Account_or_Contract__r.FEC_Primary_Phone__c,
                   FEC_Account_or_Contract__r.FEC_Application_ID__c,
                   FEC_Account_or_Contract__r.FEC_Account_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        return cases.isEmpty() ? null : cases[0];
    }

    private static Map<String, Set<String>> buildKeyValueMap(Case c) {
        Map<String, Set<String>> m = new Map<String, Set<String>>();
        if (c.FEC_Account_or_Contract__c == null || c.FEC_Account_or_Contract__r == null) {
            return m;
        }
        FEC_Customer_History__c ac = c.FEC_Account_or_Contract__r;
        if (tryPutSingleLookupKey(m, KEY_CIF_NUMBER, ac.FEC_CIF_Number__c)) {
            return m;
        }
        if (tryPutSingleLookupKey(m, KEY_ID_CARD, ac.FEC_National_ID_Passport_ID__c)) {
            return m;
        }
        if (tryPutSingleLookupKey(m, KEY_PHONE_NUMBER, ac.FEC_Primary_Phone__c)) {
            return m;
        }
        if (tryPutSingleLookupKey(m, KEY_APPLICATION_ID, ac.FEC_Application_ID__c)) {
            return m;
        }
        if (ac.FEC_Account_Number__c != null) {
            String acctTrim = ac.FEC_Account_Number__c.trim();
            if (!String.isBlank(acctTrim)) {
                m.put(KEY_ACCOUNT_NO, new Set<String>{ acctTrim });
                m.put(KEY_CONTRACT_NO, new Set<String>{ acctTrim });
            }
        }
        return m;
    }

    private static Boolean tryPutSingleLookupKey(Map<String, Set<String>> m, String keyIdentifier, String rawValue) {
        if (rawValue == null) {
            return false;
        }
        String v = rawValue.trim();
        if (String.isBlank(v)) {
            return false;
        }
        m.put(keyIdentifier, new Set<String>{ v });
        return true;
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