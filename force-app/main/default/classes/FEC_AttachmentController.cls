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
}