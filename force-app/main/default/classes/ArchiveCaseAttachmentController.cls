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
public with sharing class ArchiveCaseAttachmentController {

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

        Case c = [SELECT ArchiveAttachment__c FROM Case WHERE Id = :caseId LIMIT 1];
        if (String.isBlank(c.ArchiveAttachment__c)) return result;

        List<Object> rawList = (List<Object>) JSON.deserializeUntyped(c.ArchiveAttachment__c);
        for (Object item : rawList) {
            Map<String, Object> mapItem = (Map<String, Object>) item;
            AttachmentInfo info = new AttachmentInfo();
            info.s3Key       = (String) mapItem.get('s3Key');
            info.filename    = (String) mapItem.get('filename');
            info.contentType = (String) mapItem.get('contentType');
            info.fileSize    = mapItem.get('fileSize') != null ? Long.valueOf(String.valueOf(mapItem.get('fileSize'))) : 0;
            info.uploadedAt  = (String) mapItem.get('uploadedAt');
            info.uploadedBy  = (String) mapItem.get('uploadedBy');
            result.add(info);
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
    public static DownloadResult downloadFile(String s3Key, String filename, String contentType) {
        DownloadResult res = new DownloadResult();
        res.success = false;

        if (String.isBlank(s3Key)) {
            res.errorMessage = 's3Key is required';
            return res;
        }

        try {
            Blob fileBody = downloadFromS3(s3Key);
            if (fileBody == null) {
                res.errorMessage = 'Failed to download file from archive';
                return res;
            }

            res.success     = true;
            res.base64Data  = EncodingUtil.base64Encode(fileBody);
            res.filename    = filename;
            res.contentType = String.isNotBlank(contentType) ? contentType : 'application/octet-stream';
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
    public static Blob downloadFromS3(String s3Key) {
        Integer statusCode;
        String serviceName = label.TECH_API_GET_ARCHIVE_ATTACHMENT;
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(serviceName);

        String endpoint = FEC_MockupEndpoint.GET_CASE_ARCHIVE_ENDPOINT_MOCKUP;
        if (apiConfig != null) {
            endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_CASE_ARCHIVE_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c + '/' + EncodingUtil.urlEncode(s3Key, 'UTF-8'));
        
            Map<String, String> headers = new Map<String, String>{
                'X-API-KEY' => 'RkVDX1NBTEVTRk9SQ0U='
            };

            HttpResponse resp = FEC_CommonUltils.calloutApiWithHeaders(endpoint, FEC_ConstantCommon.API_METHOD_GET, headers, null);
            String resBody = resp.getBody();
            statusCode = resp.getStatusCode();
            String resStatusCode = String.valueOf(statusCode);
            // Log
            FEC_IntegrationFraudCaseUtil.logIntegrationService(serviceName, '', '', '', s3Key, 
                                                            resBody, resStatusCode, '', '');

            if (statusCode == 200) return resp.getBodyAsBlob();
        }

        System.debug('downloadFromS3 failed: status=' + statusCode + ' s3Key=' + s3Key);
        return null;
    }

    public class AttachmentInfo {
        @AuraEnabled public String s3Key;
        @AuraEnabled public String filename;
        @AuraEnabled public String contentType;
        @AuraEnabled public Long fileSize;
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
