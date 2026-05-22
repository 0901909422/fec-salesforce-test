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

            // ── Bước 2: Xóa record cũ của cả 2 object ────────────────────────
            deleteExistingRecords();

            // ── Bước 3: Insert FEC_Template__c ───────────────────────────────
            FEC_Folder__c folder = getOrCreateZNSFolder();
            for (FEC_Template__c template : calloutResult.templates) {
                template.FEC_Folder__c = folder.Id;
            }
            insert calloutResult.templates;

            // ── Bước 4: Insert FEC_Notification_ZNS_Param_Mapping__c ─────────
            insert calloutResult.paramMaps;

            return new UpdateResult(
                true,
                'Cập nhật thành công.',
                calloutResult.templates.size(),
                calloutResult.paramMaps.size()
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
    private static void deleteExistingRecords() {
        List<FEC_Template__c> oldTemplates = [
            SELECT Id FROM FEC_Template__c
            WHERE FEC_Is_ZNS_Template__c = TRUE
            WITH SECURITY_ENFORCED
            LIMIT 10000
        ];
        if (!oldTemplates.isEmpty()) {
            delete oldTemplates;
        }

        List<FEC_Notification_ZNS_Param_Mapping__c> oldParams = [
            SELECT Id FROM FEC_Notification_ZNS_Param_Mapping__c
            WITH SECURITY_ENFORCED
            LIMIT 10000
        ];
        if (!oldParams.isEmpty()) {
            delete oldParams;
        }

        FEC_Folder__c folder = getZNSFolder();
        if (folder != null) {
            delete folder;
        }
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