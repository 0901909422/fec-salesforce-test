/** * FEC_ChatHubCaseController
* Controller to handle various events received from ChatHub, including Case creation, 
* new message processing, and saving chat history/attachments.
* @created    : 2025/12/03 long.nguyen.50
* @modified   : 
*/ 
public with sharing class FEC_ChatHubCaseController {
    
    // Quy ước đặt tên biến: String: strName, Datetime: dtStartDate, List: listAccounts
    
    /** * createCaseOnNewSession
    * Handles the incoming 'createCaseRequestEvent' to create a new Case record.
    * @param strJsonData: JSON string containing chat session and customer info.
    * @return strCaseID: ID of the newly created Case or null/error string.
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 
    */
    @AuraEnabled
    public static String createCaseOnNewSession(String strJsonData) {
        // Tương tự logic trong createCaseRequestEvent - xử lý data. [cite: 13, 14]
        Map<String, Object> mapData = (Map<String, Object>) JSON.deserializeUntyped(strJsonData);
        Map<String, Object> mapChatSession = (Map<String, Object>) mapData.get('chatSession');
        Map<String, Object> mapCustomerInfo = (Map<String, Object>) mapData.get('customerInfo');

        // Bỏ qua logic reassignment (quá phức tạp cho bước đầu, nên xử lý bằng Trigger/Batch/Flow)
        
        String strExtInteractionID = (String) mapChatSession.get('sessionID');
        String strChatChannel = (String) mapChatSession.get('chatChannel');
        
        // 1. Check duplicate Case (sử dụng hàm từ Utils)
        String strExistingCaseID = FEC_Utils.checkExistCaseByExtInteractionID(strExtInteractionID);

        if (strExistingCaseID != null) {
            // Case đã tồn tại - trả về ID hoặc xử lý logic khác
            return strExistingCaseID;
        }

        // 2. Map data to Case fields (tạo Case mới)
        try {
            // Khởi tạo Case List (Không thực hiện DML trong vòng Loop)
            List<Case> listCasesToInsert = new List<Case>();
            
            Case newCase = new Case();
            // Lấy Record Type ID cho Chat Interaction (Không hard code ID)
            // newCase.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Chat_Interaction').getRecordTypeId();
            
            // Map dữ liệu từ ChatHub qua Case
            newCase.FEC_ExternalInteractionID__c = strExtInteractionID;
            newCase.FEC_Chat_Channel__c = FEC_Utils.getInteractionChannel(strChatChannel);
            newCase.Subject = 'Chat Interaction - ' + newCase.FEC_Chat_Channel__c;

            // Map thông tin khách hàng (PhoneNum, NationalID, CustomerName, KYCStatus)
            newCase.FEC_Phone__c = (String) mapCustomerInfo.get('phoneNumber');
            newCase.FEC_NationalID__c = (String) mapCustomerInfo.get('nationalID'); // Giả định đã giải mã nếu cần
            // newCase.ContactEmail = (String) mapCustomerInfo.get('customerName'); // Tạm dùng CustomerName để đại diện
            newCase.FEC_KYCStatus__c = (String) mapCustomerInfo.get('kYCStatus');

            listCasesToInsert.add(newCase);
            
            // Thực hiện DML
            if (!listCasesToInsert.isEmpty()) {
                // Comment giải thích source code: Thực hiện insert Case mới sau khi gom tất cả record vào list.
                insert listCasesToInsert;
                return listCasesToInsert[0].Id;
            }
            
        } catch (Exception e) {
            // Xử lý lỗi (ghi log, thông báo)
            System.debug('Error creating Case from ChatHub: ' + e.getMessage());
            // Có thể dùng FEC_Utils.writeLogChathubEvent(e);
            return null; 
        }

        return null;
    }

    /** * saveChatHistoryAndAttachment
    * Handles the incoming 'sessionHistoryByIdEvent' to save full chat history and attachments.
    * @param strJsonData: JSON string containing full chat history list.
    * @return isSuccess: Boolean indicating if the operation was successful.
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 
    */ 
    @AuraEnabled
    public static Boolean saveChatHistoryAndAttachment(String strJsonData) {
        // Tương tự logic sessionHistoryByIdEvent [cite: 17, 6] và setDataIntoPegaCase
        List<Object> listChatHistories = (List<Object>) JSON.deserializeUntyped(strJsonData);
        if (listChatHistories == null || listChatHistories.isEmpty()) {
            return true;
        }

        // Lấy Case ID (pegaID)
        Map<String, Object> mapFirstHistory = (Map<String, Object>) listChatHistories[0];
        String strCaseID = (String) mapFirstHistory.get('pegaID');
        if (String.isBlank(strCaseID)) {
             // Cần phải có Case ID để lưu trữ
             return false;
        }

        List<FEC_ChatHistory__c> listChatHistoryRecords = new List<FEC_ChatHistory__c>();
        List<AttachmentInfo> listAttachments = new List<AttachmentInfo>();
        
        // 1. Transform raw data to separate history records and attachments
        // Comment: Duyệt qua lịch sử chat để chuẩn hóa dữ liệu và tách riêng tệp đính kèm.
        for (Object historyObj : listChatHistories) {
            Map<String, Object> mapHistory = (Map<String, Object>) historyObj;
            String strMessageType = (String) mapHistory.get('messageType');

            FEC_ChatHistory__c chatHistory = new FEC_ChatHistory__c();
            chatHistory.FEC_Case__c = strCaseID;
            chatHistory.FEC_SessionID__c = (String) mapHistory.get('sessionID');
            chatHistory.FEC_SenderName__c = (String) mapHistory.get('senderName');
            chatHistory.FEC_Message__c = (String) mapHistory.get('message');
            chatHistory.FEC_MessageType__c = strMessageType;
            // Áp dụng định dạng Datetime từ Core JS
            // chatHistory.FEC_CreatedAt__c = FEC_Utils.formatDateTimeToString((Datetime) mapHistory.get('createdAt'));
            
            if (strMessageType == 'attachment' || strMessageType == 'image') {
                AttachmentInfo attInfo = new AttachmentInfo();
                attInfo.strFileName = (String) mapHistory.get('fileName');
                attInfo.strFileUrl = (String) mapHistory.get('message'); // message là URL trong trường hợp này
                listAttachments.add(attInfo);

                // Cập nhật trường Message để hiển thị tên file
                chatHistory.FEC_Message__c = '[' + attInfo.strFileName + ']'; 
            }
            
            listChatHistoryRecords.add(chatHistory);
        }

        // 2. Thực hiện DML (Không DML trong Loop)
        try {
            // Comment: Thực hiện insert tất cả lịch sử chat vào đối tượng FEC_ChatHistory__c.
            insert listChatHistoryRecords;

            // 3. Gọi hàm xử lý tải và đính kèm file (tương tự uploadFileIntoPega)
            // Do logic tải file từ URL bên ngoài thường phức tạp (HTTP Callout, lưu ContentVersion) 
            // nên ta sẽ tách riêng hàm này.
            if (!listAttachments.isEmpty()) {
                // Sửa lỗi: Mã hóa List<AttachmentInfo> thành JSON String để truyền vào @future
                String strJsonAttachments = JSON.serialize(listAttachments);
                handleFileDownloadAndAttachment(strCaseID, strJsonAttachments); 
            }

            return true;
        } catch (Exception e) {
            System.debug('Error saving chat history: ' + e.getMessage());
            return false;
        }
    }
    
    // Utility Class mô phỏng AttachmentInfo (Vẫn cần giữ lại cho hàm saveChatHistoryAndAttachment)
    public class AttachmentInfo {
        @AuraEnabled public String strFileName;
        @AuraEnabled public String strFileUrl;
    }

    /** * handleFileDownloadAndAttachment
    * Placeholder for logic to download files from URL and create ContentVersion/ContentDocumentLink.
    * (Tương tự logic trong uploadFileIntoPega)
    * @param strCaseID: ID of the Case record to attach files to.
    * @param strJsonAttachments: JSON String chứa List<AttachmentInfo> (Đã sửa lỗi @future).
    * @created: 2025/12/03 long.nguyen.50
    * @modified: 2025/12/11 Gemini (Fixed loop error and improved CDL linking)
    */ 
    @future(callout=true)
    private static void handleFileDownloadAndAttachment(String strCaseID, String strJsonAttachments) {
        // Tái tạo lại List<AttachmentInfo> từ JSON String bên trong hàm @future
        List<AttachmentInfo> listAttachments = (List<AttachmentInfo>) JSON.deserialize(
            strJsonAttachments, List<AttachmentInfo>.class
        );
        
        List<ContentVersion> listCVToInsert = new List<ContentVersion>();
        
        // Comment: Vòng lặp chính để chuẩn bị ContentVersion (Tránh DML trong Loop)
        for (AttachmentInfo att : listAttachments) {
            // Simulate file content loading (Callout)
            Blob fileBody = Blob.valueOf('Simulated file content from ' + att.strFileUrl);
            
            ContentVersion cv = new ContentVersion();
            cv.Title = att.strFileName;
            cv.PathOnClient = att.strFileName;
            cv.VersionData = fileBody;
            cv.Origin = 'C'; // C = Chatter/Content
            listCVToInsert.add(cv);
        }
        
        // DML: Insert ContentVersion
        if (!listCVToInsert.isEmpty()) {
            // Comment giải thích source code: Thực hiện insert ContentVersion list.
            insert listCVToInsert;
            
            // Liên kết ContentDocument với Case (Case ID)
            List<ContentDocumentLink> listCDLToInsert = new List<ContentDocumentLink>();
            
            // Comment giải thích source code: Truy vấn ContentDocumentId và lưu vào Map để tránh SOQL trong Loop.
            Map<Id, Id> mapCVIdToCDId = new Map<Id, Id>();
            for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :listCVToInsert]) {
                mapCVIdToCDId.put(cv.Id, cv.ContentDocumentId);
            }
            
            // Comment giải thích source code: Lặp qua List<ContentVersion> vừa được chèn để tạo ContentDocumentLink.
            for (ContentVersion cv : listCVToInsert) {
                Id contentDocId = mapCVIdToCDId.get(cv.Id); 

                if (contentDocId != null) {
                    ContentDocumentLink cdl = new ContentDocumentLink();
                    cdl.ContentDocumentId = contentDocId;
                    cdl.LinkedEntityId = strCaseID;
                    cdl.ShareType = 'V'; // Viewer permission
                    listCDLToInsert.add(cdl);
                }
            }

            // DML: Insert ContentDocumentLink
            if (!listCDLToInsert.isEmpty()) {
                // Comment giải thích source code: Insert ContentDocumentLink list (Bulkification).
                insert listCDLToInsert;
            }
        }
    }
}