/**
 * FEC_PDFTemplateSelector
 * Selector class chuyên query FEC_PDFTemplate__mdt theo các điều kiện.
 * Tách riêng logic query để dễ maintain và mock trong test.
 * 
 * @created    : 2025/12/10 long.nguyen.50
 * @modified   : 
 */
public with sharing class FEC_PDFTemplateSelector {

    /**
     * getByCode
     * Lấy 1 template active theo Template Code (unique).
     * 
     * @param strTemplateCode : Mã template (VD: 'XNTL_HDTD')
     * @return FEC_PDFTemplate__mdt : Template record, null nếu không tìm thấy
     * @created : 2025/12/10 long.nguyen.50
     * @modified : 
     */
    public static FEC_PDFTemplate__mdt getByCode(String strTemplateCode) {
        if (String.isBlank(strTemplateCode)) {
            return null;
        }

        List<FEC_PDFTemplate__mdt> listTemplates = [
            SELECT DeveloperName, MasterLabel,
                   FEC_TemplateCode__c, FEC_Category__c, FEC_Description__c,
                   FEC_HTMLBody__c, FEC_FileName__c, FEC_IsActive__c
            FROM FEC_PDFTemplate__mdt
            WHERE FEC_TemplateCode__c = :strTemplateCode
                AND FEC_IsActive__c = true
            LIMIT 1
        ];

        return listTemplates.isEmpty() ? null : listTemplates[0];
    }

    /**
     * getByCategory
     * Lấy danh sách template active theo Category.
     * 
     * @param strCategory : Tên category (VD: 'Thanh Lý', 'Xác Nhận')
     * @return List<FEC_PDFTemplate__mdt> : Danh sách template
     * @created : 2025/12/10 long.nguyen.50
     * @modified : 
     */
    public static List<FEC_PDFTemplate__mdt> getByCategory(String strCategory) {
        if (String.isBlank(strCategory)) {
            return new List<FEC_PDFTemplate__mdt>();
        }

        return [
            SELECT DeveloperName, MasterLabel,
                   FEC_TemplateCode__c, FEC_Category__c, FEC_Description__c,
                   FEC_HTMLBody__c, FEC_FileName__c, FEC_IsActive__c
            FROM FEC_PDFTemplate__mdt
            WHERE FEC_Category__c = :strCategory
                AND FEC_IsActive__c = true
            ORDER BY MasterLabel ASC
            LIMIT 200
        ];
    }

    /**
     * getAllActive
     * Lấy tất cả template đang active.
     * 
     * @return List<FEC_PDFTemplate__mdt> : Danh sách template active
     * @created : 2025/12/10 long.nguyen.50
     * @modified : 
     */
    public static List<FEC_PDFTemplate__mdt> getAllActive() {
        return [
            SELECT DeveloperName, MasterLabel,
                   FEC_TemplateCode__c, FEC_Category__c, FEC_Description__c,
                   FEC_FileName__c, FEC_IsActive__c
            FROM FEC_PDFTemplate__mdt
            WHERE FEC_IsActive__c = true
            ORDER BY FEC_Category__c ASC, MasterLabel ASC
            LIMIT 200
        ];
    }

    /**
     * getTemplateOptions
     * Lấy danh sách template dạng lightweight (không kèm HTMLBody) cho picklist/combobox.
     * 
     * @return List<TemplateOption> : Danh sách option cho UI
     * @created : 2025/12/10 long.nguyen.50
     * @modified : 
     */
    @AuraEnabled(cacheable=true)
    public static List<TemplateOption> getTemplateOptions() {
        List<TemplateOption> listOptions = new List<TemplateOption>();

        for (FEC_PDFTemplate__mdt objTemplate : getAllActive()) {
            TemplateOption objOption = new TemplateOption();
            objOption.label = objTemplate.MasterLabel;
            objOption.value = objTemplate.FEC_TemplateCode__c;
            objOption.category = objTemplate.FEC_Category__c;
            objOption.description = objTemplate.FEC_Description__c;
            listOptions.add(objOption);
        }

        return listOptions;
    }

    /**
     * TemplateOption
     * Lightweight wrapper cho UI combobox/picklist.
     */
    public class TemplateOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String category;
        @AuraEnabled public String description;
    }
}