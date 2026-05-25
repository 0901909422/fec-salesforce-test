/*------------------------------------------------------------
Author:        Thanh Van
Company:       Amaris
Description:   Controller for fec_ArchiveAttachments LWC.
               - getAttachments: returns attachment metadata stored on Case
               - downloadFile: callout to S3 and returns base64 file content
Test Class:    ArchiveCaseAttachmentController_Test
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/04/28     Thanh Van          Init
------------------------------------------------------------*/
public without sharing class ArchiveCaseAttachmentController {

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Get Attachment List
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/04/07      Thanh Van           Init
    ------------------------------------------------------------*/
    @AuraEnabled(cacheable=true)
    public static List<AttachmentInfo> getAttachments(Id caseId) {
        List<AttachmentInfo> result = new List<AttachmentInfo>();
        if (caseId == null) return result;

        List<Case> cases = [SELECT ArchiveAttachment__c FROM Case WHERE Id = :caseId LIMIT 1];
        if (cases.size() > 0) {
            Case caseIns = cases[0];
            if (String.isBlank(caseIns.ArchiveAttachment__c)) return result;

            // [{"filename":"Screenshot 2026-05-06 at 11.06.33.png",
            // "contentType":"image/png",
            // "s3Path":"case-files/S-79587/7df289ce95651df0_Screenshot_2026-05-06_at_11.06.33.png",
            // "uploadedAt":"2026-05-06T14:41:00.823164Z"}]
            List<Object> rawList = (List<Object>) JSON.deserializeUntyped(caseIns.ArchiveAttachment__c);
            for (Object item : rawList) {
                Map<String, Object> mapItem = (Map<String, Object>) item;
                AttachmentInfo info = new AttachmentInfo();
                info.s3Key       = (String) mapItem.get('s3Path');
                info.filename    = (String) mapItem.get('filename');
                info.contentType = (String) mapItem.get('contentType');
                info.uploadedAt  = (String) mapItem.get('uploadedAt');
                info.uploadedBy  = (String) mapItem.get('uploadedBy');
                result.add(info);
            }
        }

        return result;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Download File
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/04/07      Thanh Van           Init
    ------------------------------------------------------------*/
    @AuraEnabled
    public static DownloadResult downloadFile(String s3Key, String filename, 
                                                String contentType, String caseId) {
        DownloadResult res = new DownloadResult();
        res.success = false;

        if (String.isBlank(s3Key)) {
            res.errorMessage = 's3Key is required';
            return res;
        }

        System.debug('caseId ' + caseId);
        try {
            List<Case> cases = [SELECT Id, ArchiveMigrationSource__c 
                                FROM Case WHERE Id = :caseId LIMIT 1];
            if (cases.size() > 0) {
                Case caseIns = cases[0];

                Blob fileBody = downloadFromS3(s3Key, caseIns);
                if (fileBody == null) {
                    res.errorMessage = 'Failed to download file from archive';
                    return res;
                }

                res.success     = true;
                res.base64Data  = EncodingUtil.base64Encode(fileBody);
                res.filename    = filename;
                res.contentType = String.isNotBlank(contentType) ? contentType : 'application/octet-stream';
            }
        } catch (Exception ex) {
            res.errorMessage = ex.getMessage();
            System.debug('ArchiveCaseAttachmentController.downloadFile error: ' + ex.getMessage());
        }
        return res;
    }

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Call the configured API endpoint to download file bytes from S3.
                   Endpoint base is read from FEC_API_Config__mdt + FEC_API_Setting__c,
                   s3Key is appended as path param.
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/04/07      Thanh Van           Init
    ------------------------------------------------------------*/
    public static Blob downloadFromS3(String s3Key, Case caseIns) {
        Integer statusCode;
        String serviceName = label.TECH_API_GET_ARCHIVE_ATTACHMENT;
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(serviceName);
        String migrationSource = caseIns.ArchiveMigrationSource__c;

        String endpoint = FEC_MockupEndpoint.GET_CASE_ARCHIVE_ATTACHMENT_ENDPOINT_MOCKUP 
                            + s3Key + '&source=' + migrationSource;
        if (apiConfig != null && String.isNotBlank(apiConfig.FEC_Endpoint__c)) {
            endpoint = apiSetting?.FEC_Call_Mock__c ? endpoint 
                        : (apiSetting?.FEC_Endpoint__c + apiConfig.FEC_Endpoint__c) 
                            + s3Key + '&source=' + migrationSource;
        }

        Map<String, String> headers = new Map<String, String>{
            'X-API-KEY' => 'RkVDX1NBTEVTRk9SQ0U='
        };

        HttpResponse resp = FEC_CommonUltils.calloutApiWithHeaders(endpoint, FEC_ConstantCommon.API_METHOD_GET, headers, null);
        statusCode = resp.getStatusCode();
        String resStatusCode = String.valueOf(statusCode);
        // Log
        FEC_IntegrationFraudCaseUtil.logIntegrationService(serviceName, '', '', '', endpoint, 
                                                            '', resStatusCode, '', '');

        if (statusCode == 200) return resp.getBodyAsBlob();

        System.debug('downloadFromS3 failed: status=' + statusCode + ' s3Key=' + s3Key);
        return null;
    }

    public class AttachmentInfo {
        @AuraEnabled public String s3Key;
        @AuraEnabled public String filename;
        @AuraEnabled public String contentType;
        @AuraEnabled public String uploadedAt;
        @AuraEnabled public String uploadedBy;
    }

    public class DownloadResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String base64Data;
        @AuraEnabled public String filename;
        @AuraEnabled public String contentType;
        @AuraEnabled public String errorMessage;
    }
}
