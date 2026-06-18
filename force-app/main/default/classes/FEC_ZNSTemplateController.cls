/**
 * FEC_ZNSTemplateController
 */
public with sharing class FEC_ZNSTemplateController {

    public static final String ZNS = 'ZNS';

    // =========================================================================
    // Result trả về LWC
    // =========================================================================
    public class UpdateResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  message;
        @AuraEnabled public Integer templateCount;
        @AuraEnabled public Integer paramCount;

        public UpdateResult(Boolean success, String message, Integer templateCount, Integer paramCount) {
            this.success       = success;
            this.message       = message;
            this.templateCount = templateCount;
            this.paramCount    = paramCount;
        }
    }

    // =========================================================================
    // AuraEnabled method – LWC gọi khi nhấn nút Update
    // =========================================================================
    @AuraEnabled
    public static UpdateResult updateZNSTemplates() {
        try {
            // ── Bước 1: Callout + mapping ─────────────────────────────────────
            FEC_ZNSTemplateCallout.CalloutResult calloutResult =
                new FEC_ZNSTemplateCallout().fetchAndMap();

            if (calloutResult.isEmpty()) {
                return new UpdateResult(false, 'Không có dữ liệu trả về từ API.', 0, 0);
            }

            // ── Bước 2: Chỉ xóa template ZNS cũ, không xóa param mapping ─────
            deleteExistingZNSTemplates();

            // ── Bước 3: Insert FEC_Template__c mới ───────────────────────────
            FEC_Folder__c folder = getOrCreateZNSFolder();
            for (FEC_Template__c template : calloutResult.templates) {
                template.FEC_Folder__c = folder.Id;
            }

            if (!calloutResult.templates.isEmpty()) {
                insert calloutResult.templates;
            }

            // ── Bước 4: Chỉ insert param mapping chưa tồn tại ────────────────
            Integer insertedParamCount = insertMissingParamMappings(calloutResult.paramMaps);

            return new UpdateResult(
                true,
                'Cập nhật thành công.',
                calloutResult.templates.size(),
                insertedParamCount
            );

        } catch (CalloutException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (DmlException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    // =========================================================================
    // Private
    // =========================================================================

    private static void deleteExistingZNSTemplates() {
        List<FEC_Template__c> oldTemplates = [
            SELECT Id
            FROM FEC_Template__c
            WHERE FEC_Is_ZNS_Template__c = TRUE
            WITH SECURITY_ENFORCED
            LIMIT 10000
        ];

        if (!oldTemplates.isEmpty()) {
            delete oldTemplates;
        }
    }

    private static Integer insertMissingParamMappings(List<FEC_Notification_ZNS_Param_Mapping__c> newParamMaps) {
        if (newParamMaps == null || newParamMaps.isEmpty()) {
            return 0;
        }

        Set<String> templateIds = new Set<String>();

        for (FEC_Notification_ZNS_Param_Mapping__c paramMap : newParamMaps) {
            if (String.isNotBlank(paramMap.Template_ID__c)) {
                templateIds.add(paramMap.Template_ID__c);
            }
        }

        Set<String> existingKeys = new Set<String>();

        if (!templateIds.isEmpty()) {
            List<FEC_Notification_ZNS_Param_Mapping__c> existingParamMaps = [
                SELECT Id,
                    Name,
                    Template_ID__c
                FROM FEC_Notification_ZNS_Param_Mapping__c
                WHERE Template_ID__c IN :templateIds
                WITH SECURITY_ENFORCED
                LIMIT 10000
            ];

            for (FEC_Notification_ZNS_Param_Mapping__c existingParamMap : existingParamMaps) {
                existingKeys.add(buildParamMappingKey(existingParamMap));
            }
        }

        List<FEC_Notification_ZNS_Param_Mapping__c> paramsToInsert =
            new List<FEC_Notification_ZNS_Param_Mapping__c>();

        Set<String> newKeys = new Set<String>();

        for (FEC_Notification_ZNS_Param_Mapping__c paramMap : newParamMaps) {
            String key = buildParamMappingKey(paramMap);

            if (String.isBlank(key)) {
                continue;
            }

            if (existingKeys.contains(key) || newKeys.contains(key)) {
                continue;
            }

            paramsToInsert.add(paramMap);
            newKeys.add(key);
        }

        if (!paramsToInsert.isEmpty()) {
            insert paramsToInsert;
        }

        return paramsToInsert.size();
    }

    private static String buildParamMappingKey(FEC_Notification_ZNS_Param_Mapping__c paramMap) {
        if (paramMap == null) {
            return null;
        }

        if (String.isBlank(paramMap.Template_ID__c) || String.isBlank(paramMap.Name)) {
            return null;
        }

        return normalizeKeyPart(paramMap.Template_ID__c)
            + '|'
            + normalizeKeyPart(paramMap.Name);
    }

    private static String normalizeKeyPart(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
    }

    private static FEC_Folder__c getZNSFolder() {
        List<FEC_Folder__c> folders = [
            SELECT Id,
                Name,
                FEC_Folder_Label__c,
                FEC_Folder_Unique_Name__c,
                FEC_Parent_Folder__c
            FROM FEC_Folder__c
            WHERE Name = :ZNS
            AND FEC_Folder_Label__c = :ZNS
            AND FEC_Folder_Unique_Name__c = :ZNS
            LIMIT 1
        ];

        return folders.isEmpty() ? null : folders[0];
    }

    private static FEC_Folder__c getOrCreateZNSFolder() {
        FEC_Folder__c folder = getZNSFolder();

        if (folder != null) {
            return folder;
        }

        // Create if not exists
        FEC_Folder__c newFolder = new FEC_Folder__c(
            Name = ZNS,
            FEC_Folder_Label__c = ZNS,
            FEC_Folder_Unique_Name__c = ZNS
        );

        insert newFolder;

        return newFolder;
    }
}