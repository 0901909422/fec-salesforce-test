/** * FEC_AttachmentController
* Controller to handle operations related to selecting and attaching files 
* from Interaction Case to a Service Case (Story 5).
* @created    : 2025/12/03 long.nguyen.50
* @modified   : 
*/ 
public with sharing class FEC_AttachmentController {
    
    public class FileAttachmentInfo {
        @AuraEnabled public String id;           // ContentVersion Ids
        @AuraEnabled public String fileName;     // Tên file
        @AuraEnabled public Datetime createdDate;// Ngày tạo
        @AuraEnabled public String createdBy;    // Người tạo
        @AuraEnabled public Boolean isAttached;  // Đã được gắn vào Service Case chưa
        @AuraEnabled public Boolean isReadOnly;  // Read-only (đã gắn trước đó)
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

        // 1. Lấy danh sách Content Document IDs từ Interaction Case
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

        // 2. Lấy thông tin Content Version và kiểm tra file đã gắn vào Target Service Case chưa
        Set<Id> setAttachedCDL = new Set<Id>();
        // Comment: Kiểm tra các file đã gắn vào Service Case hiện tại để đánh dấu Read-Only.
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :strTargetServiceCaseId 
            AND ContentDocumentId IN :setContentDocumentIds
        ]) {
            setAttachedCDL.add(cdl.ContentDocumentId);
        }

        // 3. Lấy ContentVersion (tên file, ngày tạo, người tạo)
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
            
            // Logic Story 5: Đánh dấu file đã gắn trước đó là read-only (không thể chọn lại)
            info.isAttached = setAttachedCDL.contains(cv.ContentDocumentId);
            info.isReadOnly = info.isAttached;
            
            listFileAttachments.add(info);
        }

        return listFileAttachments;
    }
    
    /** * attachFilesToServiceCase
    * Links selected Content Documents to the target Service Case.
    * @param strTargetServiceCaseId: ID của Service Case (target).
    * @param listSelectedContentDocumentIds: List các ContentDocumentId được chọn.
    * @return isSuccess: Boolean indicating successful attachment.
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 
    */ 
    @AuraEnabled
    public static Boolean attachFilesToServiceCase(String strTargetServiceCaseId, List<String> listSelectedContentDocumentIds) {
        List<ContentDocumentLink> listCDLToInsert = new List<ContentDocumentLink>();

        // Comment: Tạo ContentDocumentLink cho từng file được chọn và Case đích.
        for (String strContentDocId : listSelectedContentDocumentIds) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = strContentDocId;
            cdl.LinkedEntityId = strTargetServiceCaseId;
            cdl.ShareType = 'V'; // Viewer permission (đảm bảo quyền truy cập)
            listCDLToInsert.add(cdl);
        }
        
        // Comment: Thực hiện DML insert ContentDocumentLink list (Không DML trong Loop)
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
    public static void attachFileToInteractionCase(String interactionCaseId, String base64File, String fileName){
        try {
            System.debug('vào attachFileToInteractionCase');
            Blob fileBody = EncodingUtil.base64Decode(base64File);
            System.debug('fileBody Blob: ' + fileBody);
            System.debug('fileName: ' + fileName);
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;          
            cv.PathOnClient = fileName;     
            cv.VersionData = fileBody;
            cv.FirstPublishLocationId = interactionCaseId;
            System.debug('ContentVersion to insert: ' + cv);
            insert cv;
            System.debug('Inserted ContentVersion Id: ' + cv.Id);
            // Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
            // System.debug('ContentDocument Id: ' + conDocId);
            // ContentDocumentLink cdl = new ContentDocumentLink();
            // cdl.ContentDocumentId = conDocId;
            // cdl.LinkedEntityId = interactionCaseId;
            // cdl.ShareType = 'V';
            // System.debug('ContentDocumentLink to insert: ' + cdl);
            // insert cdl;
            System.debug('Thành công! File đã được lưu vào Case.');
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** * downloadAndSaveBase64
    * Downloads file from S3 URL, converts to Base64, and saves to Interaction Case.
    * This method consolidates the JavaScript function handleDownloadAndSaveBase64 and callAttachFileToInteractionCase.
    * @param s3Url: URL of the file on S3.
    * @param interactionCaseId: ID of the Interaction Case (target for file upload).
    * @param fileName: Name of the file to be uploaded.
    * @created:
    * @modified: 
    */ 
    @AuraEnabled
    public static void downloadAndSaveBase64(String s3Url, String interactionCaseId, String fileName){
        System.debug('vào downloadAndSaveBase64');
        System.debug('S3 URL: ' + s3Url);
        System.debug('Interaction Case ID: ' + interactionCaseId);
        System.debug('File Name: ' + fileName);
        try {
            // 1. Fetch file từ S3 bằng HttpRequest
            HttpRequest request = new HttpRequest();
            request.setEndpoint(s3Url);
            request.setMethod('GET');
            request.setTimeout(60000); // 60 seconds timeout
            
            Http http = new Http();
            HttpResponse response = http.send(request);
            System.debug('HTTP Response Status: ' + response.getStatusCode());
            // System.debug('HTTP Response Body: ' + response.getBody());
            if (response.getStatusCode() != 200) {
                throw new AuraHandledException('Lỗi tải file từ S3: HTTP ' + response.getStatusCode());
            }
            
            // 2. Lấy Blob từ response và convert sang Base64
            Blob fileBlob = response.getBodyAsBlob();
            System.debug('File Blob: ' + fileBlob);
            String base64String = EncodingUtil.base64Encode(fileBlob);
            System.debug('Base64 String length: ' + base64String);
            // 3. Gọi phương thức attachFileToInteractionCase để lưu file
            attachFileToInteractionCase(interactionCaseId, base64String, fileName);
            
            System.debug('downloadAndSaveBase64: Thành công! File từ S3 đã được lưu vào Case.');
        } catch (Exception e) {
            System.debug('downloadAndSaveBase64 Error: ' + e.getMessage());
            throw new AuraHandledException('Lỗi xử lý file: ' + e.getMessage());
        }
    }

}