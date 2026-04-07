/*------------------------------------------------------------
Author:        Thanh Van
Company:       Amaris
Description:   Queueable chain to download each archive attachment from S3
               and insert as Salesforce Attachment linked to the Case.
               Each job handles one file (one callout) then chains to the next.
               Attachment Name is prefixed with 'Archive_' for cleanup detection.
Test Class:    ArchiveCaseAttachmentQueueable_Test
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/04/07     Thanh Van          Init
------------------------------------------------------------*/
public class ArchiveCaseAttachmentQueueable implements Queueable, Database.AllowsCallouts {

    public static final String ARCHIVE_PREFIX = label.TECH_ATTACHMENT_ARCHIVE_PREFIX;
    @TestVisible private static Boolean disableChaining = false;

    private Id caseId;
    private List<Map<String, Object>> attachments;
    private Integer currentIndex;

    public ArchiveCaseAttachmentQueueable(Id caseId, List<Map<String, Object>> attachments, Integer currentIndex) {
        this.caseId = caseId;
        this.attachments = attachments;
        this.currentIndex = currentIndex;
    }

    public void execute(QueueableContext ctx) {
        if (currentIndex >= attachments.size()) return;

        Map<String, Object> att = attachments.get(currentIndex);
        String s3Key       = (String) att.get('s3Key');
        String filename    = (String) att.get('filename');
        String contentType = (String) att.get('contentType');

        if (String.isNotBlank(s3Key) && String.isNotBlank(filename)) {
            try {
                Blob fileBody = downloadFromS3(s3Key);
                if (fileBody != null) {
                    Attachment attachment = new Attachment();
                    attachment.ParentId    = caseId;
                    attachment.Name        = ARCHIVE_PREFIX + filename;
                    attachment.Body        = fileBody;
                    attachment.ContentType = String.isNotBlank(contentType) ? contentType : 'application/octet-stream';
                    insert attachment;
                }
            } catch (Exception ex) {
                System.debug('ArchiveCaseAttachmentQueueable: failed for s3Key=' + s3Key + ' | ' + ex.getMessage());
            }
        }

        // Chain to next file
        Integer nextIndex = currentIndex + 1;
        if (nextIndex < attachments.size() && !disableChaining) {
            System.enqueueJob(new ArchiveCaseAttachmentQueueable(caseId, attachments, nextIndex));
        }
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
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(label.TECH_API_GET_ARCHIVE_ATTACHMENT);

        String endpoint = FEC_MockupEndpoint.GET_CASE_ARCHIVE_ENDPOINT_MOCKUP;
        if (apiConfig != null) {
            endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_CASE_ARCHIVE_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c + '/' + EncodingUtil.urlEncode(s3Key, 'UTF-8'));
        }

        Map<String, String> headers = new Map<String, String>{
            'X-API-KEY' => 'RkVDX1NBTEVTRk9SQ0U='
        };

        HttpResponse resp = FEC_CommonUltils.calloutApiWithHeaders(endpoint, FEC_ConstantCommon.API_METHOD_GET, headers, null);
        FEC_CommonUltils.logApi(label.TECH_API_GET_ARCHIVE_ATTACHMENT, endpoint, FEC_ConstantCommon.API_METHOD_GET, null, resp, null);

        if (resp.getStatusCode() == 200) {
            return resp.getBodyAsBlob();
        }

        System.debug('downloadFromS3 failed: status=' + resp.getStatusCode() + ' s3Key=' + s3Key);
        return null;
    }
}