/** * FEC_AttachmentController
* Controller to handle operations related to selecting and attaching files 
* from Interaction Case to a Service Case (Story 5).
* @created    : 2025/12/03 long.nguyen.50
* @modified   : 
*/ 
public with sharing class FEC_AttachmentController {
    
    public class FileAttachmentInfo {
        @AuraEnabled public String id;           // ContentVersion Id
        @AuraEnabled public String fileName;     // File name
        @AuraEnabled public Datetime createdDate;// Creation date
        @AuraEnabled public String createdBy;    // Created by user
        @AuraEnabled public Boolean isAttached;  // Indicates if attached to Service Case
        @AuraEnabled public Boolean isReadOnly;  // Read-only flag (already attached previously)
    }

    /** * getAttachmentsFromInteraction
    * Retrieves list of all attachments linked to the Interaction Case (Source Case).
    * @param strInteractionCaseId: ID of the Interaction Case (source of attachments).
    * @param strTargetServiceCaseId: ID of the Service Case (target for attachment check).
    * @return listFileAttachments: List of FileAttachmentInfo records.
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 
    */ 
    @AuraEnabled
    public static List<FileAttachmentInfo> getAttachmentsFromInteraction(String strInteractionCaseId, String strTargetServiceCaseId) {
        List<FileAttachmentInfo> listFileAttachments = new List<FileAttachmentInfo>();

        // 1. Retrieve Content Document IDs from Interaction Case
        Set<Id> setContentDocumentIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :strInteractionCaseId
        ]) {
            setContentDocumentIds.add(cdl.ContentDocumentId);
        }

        if (setContentDocumentIds.isEmpty()) {
            return listFileAttachments;
        }

        // 2. Retrieve Content Version info and check if files are already attached to Target Service Case
        Set<Id> setAttachedCDL = new Set<Id>();
        // Comment: Check files already attached to current Service Case to mark as Read-Only.
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :strTargetServiceCaseId 
            AND ContentDocumentId IN :setContentDocumentIds
        ]) {
            setAttachedCDL.add(cdl.ContentDocumentId);
        }

        // 3. Retrieve ContentVersion (file name, creation date, created by user)
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId, Title, CreatedDate, CreatedBy.Name 
            FROM ContentVersion 
            WHERE ContentDocumentId IN :setContentDocumentIds AND IsLatest = TRUE
            ORDER BY CreatedDate DESC
        ]) {
            FileAttachmentInfo info = new FileAttachmentInfo();
            info.id = cv.Id;
            info.fileName = cv.Title;
            info.createdDate = cv.CreatedDate;
            info.createdBy = cv.CreatedBy.Name;
            
            // Logic Story 5: Mark previously attached files as read-only (cannot select again)
            info.isAttached = setAttachedCDL.contains(cv.ContentDocumentId);
            info.isReadOnly = info.isAttached;
            
            listFileAttachments.add(info);
        }

        return listFileAttachments;
    }
    
    /** * attachFilesToServiceCase
    * Links selected Content Documents to the target Service Case.
    * @param strTargetServiceCaseId: ID of the target Service Case.
    * @param listSelectedContentDocumentIds: List of selected ContentDocumentIds.
    * @return isSuccess: Boolean indicating successful attachment.
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 
    */ 
    @AuraEnabled
    public static Boolean attachFilesToServiceCase(String strTargetServiceCaseId, List<String> listSelectedContentDocumentIds) {
        List<ContentDocumentLink> listCDLToInsert = new List<ContentDocumentLink>();

        // Comment: Create ContentDocumentLink for each selected file and target Case.
        for (String strContentDocId : listSelectedContentDocumentIds) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = strContentDocId;
            cdl.LinkedEntityId = strTargetServiceCaseId;
            cdl.ShareType = 'V'; // Viewer permission (ensures access rights)
            listCDLToInsert.add(cdl);
        }
        
        // Comment: Execute DML insert of ContentDocumentLink list (no DML within Loop)
        if (!listCDLToInsert.isEmpty()) {
            insert listCDLToInsert;
            return true;
        }
        return false;
    }

    /** * attachFileToInteractionCase
    * Uploads a file to the Interaction Case and links it as a Content Document.
    * @param interactionCaseId: ID of the Interaction Case (target for file upload).
    * @param base64File: Base64 encoded file content.
    * @param fileName: Name of the file to be uploaded.
    * @created: nam.vo.3@fecredit.com.vn
    * @modified: 
    */ 
    // @future(callout=true)
    @AuraEnabled
    public static void attachFileToInteractionCase(String interactionCaseId, String base64File, String fileName, String uniqueMessageId){
        try {
            if(uniqueMessageId != null) {
                // FOR UPDATE lock ensures concurrent queries are queued and processed sequentially
                List<Case> lockCase = [SELECT Id FROM Case WHERE Id = :interactionCaseId FOR UPDATE];
                List<ContentVersion> existingFiles = [
                    SELECT Id FROM ContentVersion 
                    WHERE FirstPublishLocationId = :interactionCaseId 
                    AND Description = :uniqueMessageId
                    LIMIT 1
                ];
                if (!existingFiles.isEmpty()) {
                    return; 
                }
            }
            Blob fileBody = EncodingUtil.base64Decode(base64File);
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;          
            cv.PathOnClient = fileName;     
            cv.VersionData = fileBody;
            cv.FirstPublishLocationId = interactionCaseId;
            cv.Description = uniqueMessageId ?? ''; // Use Description field to store uniqueMessageId for duplicate checking
            insert cv;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** * downloadAndSaveBase64
    * Downloads file from S3 URL, converts to Base64, and saves to Interaction Case.
    * This method consolidates the JavaScript function handleDownloadAndSaveBase64 and callAttachFileToInteractionCase.
    * @param s3Url: URL of the file on S3.
    * @param interactionCaseId: ID of the Interaction Case (target for file upload).
    * @param fileName: Name of the file to be uploaded.
    * @param uniqueMessageId: Unique message identifier for duplicate detection.
    * @return void
    */ 
    @AuraEnabled
    public static void downloadAndSaveBase64(String s3Url, String interactionCaseId, String fileName, String uniqueMessageId){
        try {
            Blob fileBlob = FEC_Utils.downloadFileAsBlob(s3Url);
            String base64String = EncodingUtil.base64Encode(fileBlob);
            attachFileToInteractionCase(interactionCaseId, base64String, fileName, uniqueMessageId);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error processing file: ' + e.getMessage());
        }
    }

}