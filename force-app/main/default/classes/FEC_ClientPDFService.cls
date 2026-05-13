/**
 * FEC_ClientPDFService
 * Service class nhận PDF base64 từ client (LWC pdfmake) và lưu vào Salesforce.
 * Phương án Client-side Rendering: LWC tạo PDF bằng pdfmake → gửi base64 về Apex → lưu ContentVersion + link.
 * 
 * @created    : 2026/04/13 long.nguyen.50
 * @modified   : 
 */
public with sharing class FEC_ClientPDFService {
    /**
     * getTemplateData
     * Lấy HTML template + metadata để LWC parse và build pdfmake docDefinition.
     * 
     * @param strTemplateCode : Mã template trong FEC_PDFTemplate__mdt
     * @return Map<String, String> : Chứa htmlBody, fileName, category
     * @created : 2026/04/13 long.nguyen.50
     * @modified : 
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getTemplateData(String strTemplateCode) {
        try {
            FEC_PDFTemplate__mdt objTemplate = FEC_PDFTemplateSelector.getByCode(strTemplateCode);
            if (objTemplate == null) {
                throw new AuraHandledException(String.format(Label.FEC_PDF_Error_TemplateNotFound, new List<String>{strTemplateCode}));
            }

            Map<String, String> mapResult = new Map<String, String>();
            mapResult.put('htmlBody', objTemplate.FEC_HTMLBody__c);
            mapResult.put('fileName', objTemplate.FEC_FileName__c);
            mapResult.put('category', objTemplate.FEC_Category__c);
            mapResult.put('templateCode', objTemplate.FEC_TemplateCode__c);
            return mapResult;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}