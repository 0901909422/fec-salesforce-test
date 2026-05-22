/**
 * FEC_ZNSTemplateParamMappingController
 * Apex controller cho LWC znsParamMapping.
 *
 * Object liên quan:
 *   FEC_Notification_ZNS_Param_Mapping__c  – param mapping (đọc + ghi)
 *   FEC_Template__c                         – lấy previewUrl
 *   Field History Tracking trên FEC_Notification_ZNS_Param_Mapping__c – lịch sử tự động
 */
public without sharing class FEC_ZNSTemplateParamMappingController {

    // =========================================================================
    // Inner wrappers
    // =========================================================================

    public class ParamMappingRow {
        @AuraEnabled public String recordId;
        @AuraEnabled public String paramName;      // Param_Name__c
        @AuraEnabled public String paramType;      // Param_Type__c
        @AuraEnabled public String pageContext;    // Page_Context__c  (editable)
        @AuraEnabled public String fieldName;      // Field_Name__c    (editable)
        @AuraEnabled public String functionValue;  // Function__c      (editable)
    }

    public class ParamMappingInput {
        @AuraEnabled public String recordId;
        @AuraEnabled public String pageContext;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String functionValue;
    }

    public class HistoryRow {
        @AuraEnabled public String recordId;
        @AuraEnabled public String templateId;
        @AuraEnabled public String modifiedOn;
        @AuraEnabled public String modifiedBy;
        @AuraEnabled public String fieldChanged;
        @AuraEnabled public String oldValue;
        @AuraEnabled public String newValue;
    }

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public Option(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    // =========================================================================
    // Lấy danh sách param mapping theo templateId
    // =========================================================================
    @AuraEnabled
    public static List<ParamMappingRow> getParamMappings(String templateId) {
        List<ParamMappingRow> rows = new List<ParamMappingRow>();
        for (FEC_Notification_ZNS_Param_Mapping__c rec : [
            SELECT Id, Name, Param_Type__c,
                   Page_Context__c, Field_Name__c, Format_Function__c
            FROM   FEC_Notification_ZNS_Param_Mapping__c
            WHERE  Template_ID__c = :templateId
            WITH   SECURITY_ENFORCED
            ORDER  BY Name ASC
        ]) {
            ParamMappingRow row = new ParamMappingRow();
            row.recordId      = rec.Id;
            row.paramName     = rec.Name;
            row.paramType     = rec.Param_Type__c;
            row.pageContext   = rec.Page_Context__c;
            row.fieldName     = rec.Field_Name__c;
            row.functionValue = rec.Format_Function__c;
            rows.add(row);
        }
        return rows;
    }

    // =========================================================================
    // Dropdown options
    // Extensible: thêm/bớt phần tử trong từng hàm này khi cần mở rộng
    // =========================================================================

    /**
     * Danh sách Salesforce Object cho cột "Page Context".
     * Mở rộng: thêm Option mới vào list bên dưới.
     */
    @AuraEnabled(cacheable=true)
    public static List<Option> getPageContextOptions() {
        return new List<Option>{
            new Option('Case',        'Case')
        };
    }

    /**
     * Lấy toàn bộ field của một Salesforce Object.
     * Dùng cho cột "Tên trường dữ liệu" — thay đổi theo Page Context.
     */
    @AuraEnabled(cacheable=true)
    public static List<Option> getFieldOptions(String objectApiName) {
        List<Option> opts = new List<Option>();
        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectApiName);
            if (sot == null) return opts;
            for (Schema.SObjectField field : sot.getDescribe().fields.getMap().values()) {
                Schema.DescribeFieldResult f = field.getDescribe();
                opts.add(new Option(f.getLabel() + ' (' + f.getName() + ')', f.getName()));
            }
        } catch (Exception ex) {
            System.debug('[ZNSParamMappingController] getFieldOptions error: ' + ex.getMessage());
        }
        return opts;
    }

    /**
     * Danh sách Function cho cột "Function".
     * Mở rộng: thêm Option mới vào list bên dưới.
     */
    @AuraEnabled(cacheable=true)
    public static List<Option> getFunctionOptions() {
        return new List<Option>{
            new Option('Không',                          ''),
            new Option('Get Day of Date',                'GET_DAY_OF_DATE'),
            new Option('Get Last 4 Digit Of Card Number','GET_LAST_4_DIGIT_CARD')
        };
    }

    // =========================================================================
    // Lưu thay đổi
    // =========================================================================
    @AuraEnabled
    public static void saveParamMappings(String inputsJson, String templateId) {
        List<ParamMappingInput> inputs = (List<ParamMappingInput>)JSON.deserialize(inputsJson, List<ParamMappingInput>.class);
        List<FEC_Notification_ZNS_Param_Mapping__c> toUpdate =
            new List<FEC_Notification_ZNS_Param_Mapping__c>();

        for (ParamMappingInput inp : inputs) {
            if (String.isBlank(inp.recordId)) continue;
            toUpdate.add(new FEC_Notification_ZNS_Param_Mapping__c(
                Id              = inp.recordId,
                Page_Context__c = inp.pageContext,
                Field_Name__c   = inp.fieldName,
                Format_Function__c     = inp.functionValue
            ));
        }

        if (toUpdate.isEmpty()) return;
 
        try {
            update toUpdate;
        } catch (DmlException ex) {
            throw new AuraHandledException(ex.getDmlMessage(0));
        }
    }

    // =========================================================================
    // Lịch sử – dùng Field History Tracking của Salesforce
    // Yêu cầu: bật "Track Field History" cho các field cần theo dõi trong Setup
    //   → Object Manager → FEC_Notification_ZNS_Param_Mapping__c → Fields & Relationships
    //   → Set History Tracking → tick Page_Context__c, Field_Name__c, Function__c
    // =========================================================================
    @AuraEnabled(cacheable=false)
    public static List<HistoryRow> getHistory(String templateId) {

        // Lấy Id của các param record thuộc templateId
        Set<Id> parentIds = new Map<Id, FEC_Notification_ZNS_Param_Mapping__c>([
            SELECT Id
            FROM   FEC_Notification_ZNS_Param_Mapping__c
            WHERE  Template_ID__c = :templateId
            WITH   SECURITY_ENFORCED
        ]).keySet();

        if (parentIds.isEmpty()) return new List<HistoryRow>();

        // Query Field History Tracking – object __History được SF tự tạo
        List<HistoryRow> rows = new List<HistoryRow>();
        for (FEC_Notification_ZNS_Param_Mapping__History h : [
            SELECT Id,
                   ParentId,
                   Parent.Template_ID__c,
                   CreatedDate,
                   CreatedBy.Name,
                   Field,
                   OldValue,
                   NewValue
            FROM   FEC_Notification_ZNS_Param_Mapping__History
            WHERE  ParentId IN :parentIds
              AND  Field    IN ('Page_Context__c', 'Field_Name__c', 'Format_Function__c')
            ORDER BY CreatedDate DESC
            LIMIT  200
        ]) {
            HistoryRow row  = new HistoryRow();
            row.recordId    = h.Id;
            row.templateId  = h.Parent.Template_ID__c;
            row.modifiedOn  = String.valueOf(h.CreatedDate);
            row.modifiedBy  = h.CreatedBy.Name;
            row.fieldChanged = h.Field;
            row.oldValue    = h.OldValue != null ? String.valueOf(h.OldValue) : '';
            row.newValue    = h.NewValue != null ? String.valueOf(h.NewValue) : '';
            rows.add(row);
        }
        return rows;
    }
}