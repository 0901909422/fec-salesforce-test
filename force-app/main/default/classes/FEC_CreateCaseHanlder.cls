/** * Controller xử lý tạo Case tương tác từ Genesys
* @created      : 2025/12/29 long.nguyen.50
* @modified     : 2026/01/02 long.nguyen.50 - Thêm logging và chuẩn hóa Naming
*/
public without sharing class FEC_CreateCaseHanlder {
    
    public class FEC_InteractionCaseDTO {
        @AuraEnabled public String channel;
        @AuraEnabled public String subChannel;
        @AuraEnabled public String otherSubChannel;
        @AuraEnabled public String externalInteractionId;
        @AuraEnabled public String phoneNumber;
        @AuraEnabled public String nationalId;
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String contractNumber;
        @AuraEnabled public String transcription;
        @AuraEnabled public String kycMethod;
        @AuraEnabled public String kycResult;
        @AuraEnabled public String customerName;
    }
    
    public class FEC_InteractionCaseResponse {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String linkId;
        @AuraEnabled public String caseNo;
    }
    
    public class FEC_CustomerCaseDTO {
        @AuraEnabled public String customerName;
        @AuraEnabled public String phoneNumber;
        @AuraEnabled public String userType;
        @AuraEnabled public String businessProcessId;
        @AuraEnabled public String productTypeId;
        @AuraEnabled public String categoryId;
        @AuraEnabled public String subCategoryId;
        @AuraEnabled public String subCodeId;
        @AuraEnabled public String remarks;
    }

    /** * Tạo Interaction Case từ dữ liệu Genesys
    * @param dto Dữ liệu từ LWC
    * @return FEC_InteractionCaseResponse
    * @created: 2025/12/29 long.nguyen.50
    * @modified: 2026/01/02 long.nguyen.50 - Thêm log chi tiết
    */
    @AuraEnabled 
    public static FEC_InteractionCaseResponse createInteractionCase(String jsonInput) {
        // System.debug('### [FEC] Raw JSON: ' + jsonInput);
        // Tự ép kiểu để xem lỗi ở đâu
        FEC_InteractionCaseDTO dto = (FEC_InteractionCaseDTO)JSON.deserialize(jsonInput, FEC_InteractionCaseDTO.class);
        // System.debug('### [FEC] DTO after manual deserialize: ' + dto);
        // System.debug('### [FEC] Start createInteractionCase with DTO: ' + JSON.serialize(dto)); // Log Input Data
        
        if (dto == null) {
            System.debug('### [FEC] Error: InteractionCaseDTO is null');
            throw new IllegalArgumentException('InteractionCaseDTO cannot be null');
        }

        try {
            Map<String, Id> rtMap = getRecordTypeIds();
            // System.debug('### [FEC] RecordType Mapping: ' + rtMap);

            Case interactionCase = new Case();
            interactionCase.RecordTypeId = rtMap.get('Interaction');
            
            // CHANNEL / STATUS
            // CHANNEL / STATUS
            // ---------------------------
                // CHANNEL / STATUS
            // ---------------------------
            interactionCase.FEC_Channel__c = dto.channel;
            interactionCase.FEC_Interaction_Subchannel__c = dto.subChannel;
            interactionCase.FEC_Other_Subchannel__c = (dto.subChannel == 'Other' ? dto.otherSubChannel : null);
            
            if (dto.channel == 'Chat') {
                interactionCase.Status = 'Pending';
                interactionCase.FEC_External_Interaction_ID__c = dto.externalInteractionId;
            } else {
                interactionCase.Status = 'Open';
            }
            
            // CUSTOMER INFO
            // CUSTOMER INFO
            // ---------------------------
                // CUSTOMER INFO
            // ---------------------------
            interactionCase.FEC_Phone_Number__c = dto.phoneNumber;
            interactionCase.FEC_National_ID_Passport_ID__c = dto.nationalId;
            interactionCase.FEC_Account_Number__c = dto.accountNumber;
            interactionCase.FEC_Customer_Username__c = dto.customerName;
        
        
            // ---------------------------
                
            // ---------------------------
            // INTERACTION DATA
            // INTERACTION DATA
            // ---------------------------
                // INTERACTION DATA
            // ---------------------------
            interactionCase.FEC_Transcription__c = dto.transcription;
            interactionCase.FEC_KYC_Method__c = dto.kycMethod;
            interactionCase.FEC_KYC_Result__c = dto.kycResult;
            
            // System.debug('### [FEC] Inserting Interaction Case: ' + interactionCase);
            insert interactionCase;
            // System.debug('### [FEC] Insert Success. New Case ID: ' + interactionCase.Id);

            // Re-query to get formula/auto-number fields if necessary
            interactionCase = [
                SELECT Id, FEC_Link_ID__c 
                FROM Case 
                WHERE Id = :interactionCase.Id
            ];
            System.debug('interactionCase: ' + interactionCase);
            
            FEC_InteractionCaseResponse res = new FEC_InteractionCaseResponse();
            res.caseId = interactionCase.Id;
            res.linkId = interactionCase.FEC_Link_ID__c;
            

            if (res.linkId != null && res.linkId.contains('>')) {
                res.caseNo = res.linkId.substringBetween('>', '</');
            }
            
            System.debug('### [FEC] Final Response: ' + JSON.serialize(res));
            return res;

        } catch (Exception e) {
            System.debug('### [FEC] Exception in createInteractionCase: ' + e.getMessage() + ' | StackTrace: ' + e.getStackTraceString());
            throw new AuraHandledException('Lỗi khi tạo Case tương tác: ' + e.getMessage());
        }
    }
    
    /** * Tạo Customer Case liên kết với Interaction
    * @param dto Dữ liệu tạo case
    * @param interactionCaseId ID của interaction case cha
    * @return Case record sau khi tạo
    * @created: 2025/12/29 long.nguyen.50
    */
    public static Case createCustomerCase(FEC_CustomerCaseDTO dto, Id interactionCaseId) {
        System.debug('### [FEC] Start createCustomerCase for Interaction ID: ' + interactionCaseId);
        
        try {
            Map<String, Id> rtMap = getRecordTypeIds();
            Case c = new Case();
            c.RecordTypeId = rtMap.get('Customer_Case');
            
            c.FEC_Customer_Name__c = dto.customerName;
            c.FEC_Phone_Number__c = dto.phoneNumber;
            c.FEC_Customer_Type__c = dto.userType;
            c.FEC_Business_Process__c = dto.businessProcessId;
            c.FEC_Product_Type__c = dto.productTypeId;
            c.FEC_Category__c = dto.categoryId;
            c.FEC_SubCategory__c = dto.subCategoryId;
            c.FEC_SubCode__c = dto.subCodeId;
            c.FEC_Remarks__c = dto.remarks;
            c.FEC_Interaction__c = interactionCaseId;
            
            insert c;
            System.debug('### [FEC] Customer Case Created Success: ' + c.Id);
            return c;

        } catch (Exception e) {
            System.debug('### [FEC] Exception in createCustomerCase: ' + e.getMessage());
            return null;
        }
    }
    
    /** * Lấy danh sách RecordType ID cho Case
    * @return Map<DeveloperName, RecordTypeId>
    */
    private static Map<String, Id> getRecordTypeIds() {
        Map<String, Id> rtMap = new Map<String, Id>();
        // Không hardcode ID, dùng DeveloperName theo rule dự án
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Case'
            AND DeveloperName IN ('Interaction', 'Customer_Case')
        ]) {
            rtMap.put(rt.DeveloperName, rt.Id);
        }
        return rtMap;
    }
}