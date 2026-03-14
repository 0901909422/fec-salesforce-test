/**
 * Class Description: Handler class xử lý logic nghiệp vụ cho Case Trigger
 * @created  : 2026/01/03 Toannd61
 * @modified :    
 */
public without sharing class FEC_CaseTriggerHandler {
    
    // Trigger guard để tránh recursive
    private static Boolean isExecuting = false;
    public static Boolean skipTrigger = false;
    
    /**
     * Method Description: Main entry point được gọi từ trigger
     * @return void
     * @created: 2026/01/03 Toannd61
     * @modified: 2026/01/06 - Added onBeforeInsert handler
     * @modified: 2026/01/16 - Added onAfterInsert handler for auto follow-up
     */
    public static void run() {
        if (skipTrigger) {
            return;
        }

        FEC_CaseTriggerHandler handler = new FEC_CaseTriggerHandler();
        
        if (Trigger.isBefore && Trigger.isInsert) {
            List<Case> newCases = (List<Case>) Trigger.new;
            handler.onBeforeInsert(newCases);
        }
        
        if (Trigger.isBefore && Trigger.isUpdate) {
            List<Case> newCases = (List<Case>) Trigger.new;
            Map<Id, Case> oldMap = (Map<Id, Case>) Trigger.oldMap;
            handler.onBeforeUpdate(newCases, oldMap);
        }
        
        if (Trigger.isAfter && Trigger.isInsert) {
            List<Case> newCases = (List<Case>) Trigger.new;
            handler.onAfterInsert(newCases);
        }
        
        if (Trigger.isAfter && Trigger.isUpdate) {
            List<Case> newCases = (List<Case>) Trigger.new;
            Map<Id, Case> oldMap = (Map<Id, Case>) Trigger.oldMap;
            handler.onAfterUpdate(newCases, oldMap);
        }
    }

    /**
     * Method Description: Xử lý logic trước khi insert Case (generate FEC_ID_Search__c)
     * @param newCases Danh sách Case mới sẽ được insert
     * @return void
     * @created: 2026/01/06 Toannd61
     * @modified: 2026/01/29 - Added updateCaseParticipants for Customer Case / Internal Case
     */
    private void onBeforeInsert(List<Case> newCases) {
        generateFECIdSearch(newCases);
        updateCaseParticipantsOnInsert(newCases);
        syncChannelFromInteractionForCustomerCase(newCases);
        assignEntitlement(newCases);
        setEmail2CaseChannelBeforeInsert(newCases);
    }

    /**
     * Method Description: Xử lý logic trước khi update Case
     * @param newCases Danh sách Case mới
     * @param oldMap Map chứa giá trị cũ của Case
     * @return void
     * @created: 2026/02/02 Toannd61
     */
    private void onBeforeUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        updateCaseParticipantsOnUpdate(newCases, oldMap);
        syncChannelFromInteractionForCustomerCase(newCases);
        FEC_InteractionRoutingService.assignInteractionReply(newCases);
        FEC_InteractionRoutingService.assignNewInteractionEmail(newCases);
    }

    /**
     * Method Description: Xử lý logic sau khi insert Case (auto follow-up)
     * @param newCases Danh sách Case mới vừa được insert
     * @return void
     * @created: 2026/01/16 Toannd61
     */
    private void onAfterInsert(List<Case> newCases) {
        // Tránh recursive trigger
        if (isExecuting) {
            return;
        }
        
        isExecuting = true;
        
        try {
            handleAutoFollowUpOnInsert(newCases);
            updateEmail2CaseFieldsOnInsert(newCases);
        } finally {
            isExecuting = false;
        }
    }

    /**
     * Method Description: Xử lý logic sau khi update Case
     * @param newCases Danh sách Case mới sau update
     * @param oldMap Map chứa giá trị cũ của Case trước update
     * @return void
     * @created: 2026/01/03
     * @modified: 2026/01/16
     * @modified: 2026/02/02
     */
    private void onAfterUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        // Tránh recursive trigger
        if (isExecuting) {
            return;
        }
        
        isExecuting = true;
        
        try {
            handleFollowUpOnResolved(newCases, oldMap);
            handleAutoFollowUpOnUpdate(newCases, oldMap);
        } finally {
            isExecuting = false;
        }
    }

    /**
     * @description Xử lý logic Follow-up khi Case được resolved
     * @param newCases Danh sách Case mới
     * @param oldCaseMap Map chứa các giá trị cũ của Case
     */
    private void handleFollowUpOnResolved(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        // Danh sách các Case đã chuyển sang trạng thái Resolved
        Set<Id> resolvedCaseIds = new Set<Id>();
        
        for (Case newCase : newCases) {
            Case oldCase = oldCaseMap.get(newCase.Id);
            
            // Kiểm tra xem Case có chuyển sang Resolved không (dùng common)
            Boolean oldWasResolved = FEC_CommonUltils.isCaseStatusResolved(oldCase.Status);
            Boolean newIsResolved = FEC_CommonUltils.isCaseStatusResolved(newCase.Status);
            
            if (newIsResolved && !oldWasResolved) {
                resolvedCaseIds.add(newCase.Id);
            }
        }
        
        // Nếu có Case được resolved, xóa các watchers có followType = 'UNTIL_RESOLVED'
        if (!resolvedCaseIds.isEmpty()) {
            FEC_FollowUpController.removeWatchersOnCaseResolved(resolvedCaseIds);
        }
    }
    
    /**
     * Method Description: Auto-generate FEC_ID_Search__c cho Case mới
     * Format: [Prefix]-[SequenceNumber]
     * Prefix dựa trên Custom Metadata Type (FEC_CaseID_Prefix__mdt)
     * @param newCases Danh sách Case mới
     * @return void
     * @created: 2026/01/06 Toannd61
     * @modified: 2026/01/07 - Fix duplicate issue với Aggregate MAX() query theo prefix
     */
    private void generateFECIdSearch(List<Case> newCases) {
        // BƯỚC 1: LẤY PREFIX CONFIG TỪ CUSTOM METADATA TYPE
        Map<String, String> prefixConfigMap = new Map<String, String>();
        
        for (FEC_CaseID_Prefix__mdt config : [SELECT FEC_Record_Type__c, FEC_Channel__c, FEC_Prefix__c 
                                               FROM FEC_CaseID_Prefix__mdt]) {
            // Tạo key để tra cứu: RecordType|Channel hoặc RecordType|
            String recordType = FEC_CommonUltils.defaultToEmpty(config.FEC_Record_Type__c);
            String channel = FEC_CommonUltils.defaultToEmpty(config.FEC_Channel__c);
            String key = recordType + FEC_ConstantCommon.KEY_DELIMITER_PIPE + channel;
            
            prefixConfigMap.put(key, config.FEC_Prefix__c);
        }

        // BƯỚC 2: LẤY RECORD TYPE INFO
        Set<Id> recordTypeIds = new Set<Id>();
        for (Case c : newCases) {
            if (c.RecordTypeId != null) {
                recordTypeIds.add(c.RecordTypeId);
            }
        }
        
        Map<Id, String> recordTypeDeveloperNameMap = new Map<Id, String>();
        if (!recordTypeIds.isEmpty()) {
            for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE Id IN :recordTypeIds]) {
                recordTypeDeveloperNameMap.put(rt.Id, rt.DeveloperName);
            }
        }
        
        // BƯỚC 3: PHÂN NHÓM CASES THEO PREFIX
        Map<String, List<Case>> casesByPrefix = new Map<String, List<Case>>();
        
        for (Case c : newCases) {
            // Xác định prefix cho Case này
            String prefix = determinePrefixForCase(c, recordTypeDeveloperNameMap, prefixConfigMap);
            
            if (!casesByPrefix.containsKey(prefix)) {
                casesByPrefix.put(prefix, new List<Case>());
            }
            casesByPrefix.get(prefix).add(c);
        }
        
        // BƯỚC 4: LẤY MAX NUMBER CHO TỪNG PREFIX (SỬ DỤNG AGGREGATE)
        Map<String, Integer> maxNumberByPrefix = new Map<String, Integer>();
        
        for (String prefix : casesByPrefix.keySet()) {
            Integer maxNum = getMaxNumberForPrefix(prefix);
            maxNumberByPrefix.put(prefix, maxNum);
        }
        
        // BƯỚC 5: GENERATE ID CHO TỪNG CASE
        for (String prefix : casesByPrefix.keySet()) {
            Integer currentNum = maxNumberByPrefix.get(prefix);
            
            for (Case c : casesByPrefix.get(prefix)) {
                currentNum++;
                String seqStr = String.valueOf(currentNum).leftPad(4, '0');
                c.FEC_ID_Search__c = prefix + FEC_ConstantCommon.FEC_ID_SEARCH_DELIMITER + seqStr;
            }
        }
    }
    
    /**
     * Method Description: Xác định prefix cho một Case dựa trên RecordType và Channel
     * @param c Case cần xác định prefix
     * @param recordTypeNameMap Map RecordTypeId -> DeveloperName
     * @param prefixConfigMap Map key -> Prefix từ Custom Metadata
     * @return String Prefix
     * @created: 2026/01/07
     */
    private String determinePrefixForCase(Case c, Map<Id, String> recordTypeNameMap, Map<String, String> prefixConfigMap) {
        String prefix = 'S'; // Fallback mặc định
        String recordTypeName = recordTypeNameMap.get(c.RecordTypeId);
        String channel = FEC_CommonUltils.defaultToEmpty(c.FEC_Channel__c);
        
        // Thứ tự ưu tiên tra cứu:
        // 1. RecordType + Channel (cho Interaction)
        // 2. RecordType only (cho Customer_Case, Internal_Case)
        
        if (String.isNotBlank(recordTypeName) && String.isNotBlank(channel)) {
            String key = recordTypeName + FEC_ConstantCommon.KEY_DELIMITER_PIPE + channel;
            if (prefixConfigMap.containsKey(key)) {
                prefix = prefixConfigMap.get(key);
            } else {
                // Fallback: thử RecordType only
                key = recordTypeName + FEC_ConstantCommon.KEY_DELIMITER_PIPE;
                if (prefixConfigMap.containsKey(key)) {
                    prefix = prefixConfigMap.get(key);
                }
            }
        } else if (String.isNotBlank(recordTypeName)) {
            String key = recordTypeName + FEC_ConstantCommon.KEY_DELIMITER_PIPE;
            if (prefixConfigMap.containsKey(key)) {
                prefix = prefixConfigMap.get(key);
            }
        }
        
        return prefix;
    }
    
    /**
     * Method Description: Lấy số lớn nhất hiện có cho một prefix cụ thể (sử dụng Aggregate MAX)
     * @param prefix Prefix cần tìm (ví dụ: 'S', 'I', 'C')
     * @return Integer Số lớn nhất hiện có (0 nếu chưa có record nào)
     * @created: 2026/01/07
     */
    private Integer getMaxNumberForPrefix(String prefix) {
        Integer maxNum = 0;
        
        try {
            // Query tất cả FEC_ID_Search__c có prefix này
            List<Case> cases = [SELECT FEC_ID_Search__c 
                               FROM Case 
                               WHERE FEC_ID_Search__c LIKE :prefix + FEC_ConstantCommon.FEC_ID_SEARCH_DELIMITER + '%'
                               ALL ROWS];
            
            // Tách số và tìm max
            for (Case c : cases) {
                try {
                    String numberPart = c.FEC_ID_Search__c.substringAfterLast(FEC_ConstantCommon.FEC_ID_SEARCH_DELIMITER);
                    if (numberPart.isNumeric()) {
                        Integer num = Integer.valueOf(numberPart);
                        if (num > maxNum) {
                            maxNum = num;
                        }
                    }
                } catch (Exception e) {
                    System.debug('Lỗi parse number từ: ' + c.FEC_ID_Search__c + ' - ' + e.getMessage());
                }
            }
        } catch (Exception e) {
            System.debug('Lỗi query max number cho prefix ' + prefix + ': ' + e.getMessage());
        }
        
        return maxNum;
    }
    
    /**
     * Method Description: Cập nhật Case (Email2Case) sau insert khi thỏa điều kiện:
     * Origin = Email2Case, RecordType DeveloperName = Interaction, FEC_Channel__c rỗng.
     * Gán FEC_Interaction_Email__c từ EmailMessage.FromAddress, FEC_Send_To__c, FEC_Channel__c = Email.
     * Gọi @future để tránh thời điểm After Insert chưa có EmailMessage / FromAddress (Email-to-Case tạo EmailMessage sau Case).
     * @param newCases Danh sách Case mới vừa được insert
     * @return void
     * @created: 2026/02/10 LongNH76
     */
      private void updateEmail2CaseFieldsOnInsert(List<Case> newCases) {
        // Tận dụng cờ isExecuting (đã có sẵn) để chặn Trigger chạy lại hàm này nếu update kích hoạt lại
        if (isExecuting) {
            return;
        }

        Id interactionRecordTypeId = getInteractionRecordTypeId();
        if (interactionRecordTypeId == null) {
            return;
        }

        List<Id> caseIdsToUpdate = new List<Id>();

        for (Case c : newCases) {
            if (c.Origin == FEC_ConstantCommon.CASE_ORIGIN_EMAIL2CASE && c.RecordTypeId == interactionRecordTypeId) {
                caseIdsToUpdate.add(c.Id);
            }
        }

        if (caseIdsToUpdate.isEmpty()) {
            return;
        }

        // Chạy bất đồng bộ: sau khi transaction insert commit, EmailMessage đã có và FromAddress đã fill
        updateEmail2CaseFieldsAsync(caseIdsToUpdate);
    }

    /**
     * Before Insert: Gán FEC_Channel__c = 'Email', FEC_Interaction_Subchannel__c = 'Incoming Email' cho Case Email2Case.
     */
    private void setEmail2CaseChannelBeforeInsert(List<Case> newCases) {
        Id interactionRecordTypeId = getInteractionRecordTypeId();
        if (interactionRecordTypeId == null) {
            return;
        }
        for (Case c : newCases) {
            if (c.Origin == FEC_ConstantCommon.CASE_ORIGIN_EMAIL2CASE
                    && c.RecordTypeId == interactionRecordTypeId
                    && String.isBlank(c.FEC_Channel__c)) {
                c.FEC_Channel__c = FEC_ConstantCommon.EMAIL;
                c.FEC_Interaction_Subchannel__c = FEC_ConstantCommon.SUBCHANNEL_INCOMING_EMAIL;
            }
        }
    }

    /**
     * Cập nhật Case (FEC_Interaction_Email__c, FEC_Send_To__c) chạy sau transaction insert.
     * FEC_Channel__c đã được set trong Before Insert.
     */
    @future
    public static void updateEmail2CaseFieldsAsync(List<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return;
        }

        String sendToValue = System.Label.UBankCustomberServiceEmail;

        Map<Id, String> caseIdToFromAddress = new Map<Id, String>();
        for (EmailMessage em : [SELECT Id, ParentId, FromAddress, CreatedDate
                                FROM EmailMessage
                                WHERE ParentId IN :caseIds
                                AND FromAddress != NULL AND ToAddress  = :sendToValue
                                ORDER BY CreatedDate ASC]) {
            if (!caseIdToFromAddress.containsKey(em.ParentId)) {
                caseIdToFromAddress.put(em.ParentId, em.FromAddress);
            }
        }

        List<Case> casesToDml = new List<Case>();
        for (Id caseId : caseIds) {
            String fromAddr = caseIdToFromAddress.get(caseId);
            casesToDml.add(new Case(
                Id = caseId,
                FEC_Interaction_Email__c = fromAddr,
                FEC_Send_To__c = sendToValue,
                FEC_Interaction_Subchannel__c = FEC_ConstantCommon.SUBCHANNEL_INCOMING_EMAIL
            ));
        }

        // assignCases(casesToDml);

        if (!casesToDml.isEmpty()) {
            FEC_CaseTriggerHandler.skipTrigger = true;
            try {
                update casesToDml;
            } finally {
                FEC_CaseTriggerHandler.skipTrigger = false;
            }
        }
    }

    /**
     * Lấy RecordType Id của Case có DeveloperName = "Interaction".
     * @return Id hoặc null nếu không tìm thấy
     */
    private static Id getInteractionRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (!rtMap.containsKey(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)) return null;
        return rtMap.get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME).getRecordTypeId();
    }

    /**
     * Method Description: Tự động thêm Case vào Follow-up của Creator và Owner khi Case được tạo
     * Logic: Khi User tạo Case, tự động thêm Case vào danh sách Follow-up của:
     *   - Creator (CreatedById)
     *   - Owner (OwnerId) - nếu khác Creator
     * @param newCases Danh sách Case mới vừa được insert
     * @return void
     * @created: 2026/01/16 Toannd61
     */
    private void handleAutoFollowUpOnInsert(List<Case> newCases) {
        // Map<CaseId, Set<UserId>> - Danh sách user cần follow cho từng Case
        Map<Id, Set<Id>> caseUserMap = new Map<Id, Set<Id>>();
        
        for (Case c : newCases) {
            Set<Id> userIds = new Set<Id>();
            
            // Thêm Creator vào danh sách follow
            if (c.CreatedById != null) {
                userIds.add(c.CreatedById);
            }
            
            // Thêm Owner vào danh sách follow (nếu khác Creator); chỉ thêm nếu Owner là User (không phải Queue)
            if (c.OwnerId != null && c.OwnerId != c.CreatedById && c.OwnerId.getSObjectType() == User.SObjectType) {
                userIds.add(c.OwnerId);
            }
            
            if (!userIds.isEmpty()) {
                caseUserMap.put(c.Id, userIds);
            }
        }
        
        // Bulk thêm users vào follow-up với type = 'Until Case is Resolved'
        if (!caseUserMap.isEmpty()) {
            FEC_FollowUpController.addUsersToFollowUpBulk(caseUserMap, System.Label.FEC_FollowUp_Type_Until_Case_Resolved);
        }
    }
    
    /**
     * Method Description: Tự động thêm User vào Follow-up khi User tham gia xử lý Case
     * Logic: Khi Owner thay đổi, tự động thêm Owner mới vào danh sách Follow-up
     * @param newCases Danh sách Case sau update
     * @param oldCaseMap Map chứa các giá trị cũ của Case
     * @return void
     * @created: 2026/01/16 Toannd61
     */
    private void handleAutoFollowUpOnUpdate(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        // Map<CaseId, Set<UserId>> - Danh sách user cần follow cho từng Case
        Map<Id, Set<Id>> caseUserMap = new Map<Id, Set<Id>>();
        
        for (Case newCase : newCases) {
            Case oldCase = oldCaseMap.get(newCase.Id);
            Set<Id> userIds = new Set<Id>();
            
            // Kiểm tra Owner có thay đổi không; chỉ thêm nếu Owner là User (không phải Queue)
            if (newCase.OwnerId != null && newCase.OwnerId != oldCase.OwnerId
                    && newCase.OwnerId.getSObjectType() == User.SObjectType) {
                userIds.add(newCase.OwnerId);
            }
            
            // Có thể thêm các điều kiện khác ở đây:
            // - Thêm LastModifiedBy nếu thực hiện hành động quan trọng
            // - Thêm các user từ các field khác
            
            if (!userIds.isEmpty()) {
                caseUserMap.put(newCase.Id, userIds);
            }
        }
        
        // Bulk thêm users vào follow-up với type = 'Until Case is Resolved'
        if (!caseUserMap.isEmpty()) {
            FEC_FollowUpController.addUsersToFollowUpBulk(caseUserMap, System.Label.FEC_FollowUp_Type_Until_Case_Resolved);
        }
    }
    
    /**
     * Method Description: Cập nhật danh sách người tham gia xử lý Case (FEC_Case_Participants__c)
     * Điều kiện: Chỉ áp dụng cho Record Type = Customer Case hoặc Internal Case
     * Logic: Khi Case được khởi tạo với Owner là User cụ thể, add OwnerID vào FEC_Case_Participants__c
     * @param newCases Danh sách Case mới sẽ được insert
     * @return void
     * @created: 2026/01/29 Toannd61
     */
    private void updateCaseParticipantsOnInsert(List<Case> newCases) {
        // Lấy Record Type IDs cần kiểm tra
        Set<Id> recordTypeIds = new Set<Id>();
        for (Case c : newCases) {
            if (c.RecordTypeId != null) {
                recordTypeIds.add(c.RecordTypeId);
            }
        }
        
        if (recordTypeIds.isEmpty()) {
            return;
        }
        
        // Query RecordType để lấy DeveloperName
        Map<Id, String> recordTypeDeveloperNameMap = new Map<Id, String>();
        for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType 
                              WHERE Id IN :recordTypeIds AND SObjectType = 'Case']) {
            recordTypeDeveloperNameMap.put(rt.Id, rt.DeveloperName);
        }
        
        // Định nghĩa các Record Type được phép
        Set<String> allowedRecordTypes = new Set<String>{'Customer_Case', 'Internal_Case'};
        
        for (Case c : newCases) {
            // Kiểm tra Record Type
            String recordTypeName = recordTypeDeveloperNameMap.get(c.RecordTypeId);
            if (String.isBlank(recordTypeName) || !allowedRecordTypes.contains(recordTypeName)) {
                continue;
            }
            
            // Kiểm tra Owner là User (không phải Queue); add OwnerId vào FEC_Case_Participants__c
            if (c.OwnerId != null && c.OwnerId.getSObjectType() == User.SObjectType) {
                c.FEC_Case_Participants__c = addParticipant(c.FEC_Case_Participants__c, c.OwnerId);
            }
        }
    }
    
    /**
     * Method Description: Cập nhật danh sách người tham gia khi Owner thay đổi
     * Điều kiện: Chỉ áp dụng cho Record Type = Customer Case hoặc Internal Case
     * Logic: Khi Owner thay đổi thành User mới, add OwnerID mới vào FEC_Case_Participants__c
     * @param newCases Danh sách Case sau update
     * @param oldCaseMap Map chứa các giá trị cũ của Case
     * @return void
     * @created: 2026/01/29 Toannd61
     * @modified: 2026/02/02 - 
     */
    private void updateCaseParticipantsOnUpdate(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        // Lọc các Case có Owner thay đổi
        List<Case> casesToUpdate = new List<Case>();
        Set<Id> recordTypeIds = new Set<Id>();
        
        for (Case newCase : newCases) {
            Case oldCase = oldCaseMap.get(newCase.Id);
            
            // Kiểm tra Owner có thay đổi không; chỉ xử lý nếu Owner mới là User (không phải Queue)
            if (newCase.OwnerId != null && newCase.OwnerId != oldCase.OwnerId
                    && newCase.OwnerId.getSObjectType() == User.SObjectType) {
                casesToUpdate.add(newCase);
                if (newCase.RecordTypeId != null) {
                    recordTypeIds.add(newCase.RecordTypeId);
                }
            }
        }
        
        if (casesToUpdate.isEmpty()) {
            return;
        }
        
        // Query RecordType để lấy DeveloperName
        Map<Id, String> recordTypeDeveloperNameMap = new Map<Id, String>();
        for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType 
                              WHERE Id IN :recordTypeIds AND SObjectType = 'Case']) {
            recordTypeDeveloperNameMap.put(rt.Id, rt.DeveloperName);
        }
        
        // Định nghĩa các Record Type được phép
        Set<String> allowedRecordTypes = new Set<String>{'Customer_Case', 'Internal_Case'};
        
        for (Case c : casesToUpdate) {
            // Kiểm tra Record Type
            String recordTypeName = recordTypeDeveloperNameMap.get(c.RecordTypeId);
            if (String.isBlank(recordTypeName) || !allowedRecordTypes.contains(recordTypeName)) {
                continue;
            }
            
            // Add OwnerID mới vào FEC_Case_Participants__c (update trực tiếp trong Before context)
            c.FEC_Case_Participants__c = addParticipant(c.FEC_Case_Participants__c, c.OwnerId);
        }
    }
    
    /**
     * Method Description: Đồng bộ FEC_Channel__c từ FEC_Interaction__r.FEC_Channel__c cho Customer Case.
     * Điều kiện: Chỉ áp dụng cho Record Type = Customer Case và Case có FEC_Interaction__c.
     * @param newCases Danh sách Case (insert hoặc update)
     * @return void
     * @created: 2026/02/05
     */
    private void syncChannelFromInteractionForCustomerCase(List<Case> newCases) {
        Set<Id> recordTypeIds = new Set<Id>();
        Set<Id> interactionCaseIds = new Set<Id>();
        for (Case c : newCases) {
            if (c.RecordTypeId != null && c.FEC_Interaction__c != null) {
                recordTypeIds.add(c.RecordTypeId);
                interactionCaseIds.add(c.FEC_Interaction__c);
            }
        }
        if (interactionCaseIds.isEmpty()) {
            return;
        }
        Map<Id, String> recordTypeDeveloperNameMap = new Map<Id, String>();
        for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType
                              WHERE Id IN :recordTypeIds AND SObjectType = 'Case']) {
            recordTypeDeveloperNameMap.put(rt.Id, rt.DeveloperName);
        }
        if (recordTypeDeveloperNameMap.isEmpty()) {
            return;
        }
        Map<Id, String> interactionIdToChannel = new Map<Id, String>();
        for (Case interactionCase : [SELECT Id, FEC_Channel__c FROM Case WHERE Id IN :interactionCaseIds]) {
            if (String.isNotBlank(interactionCase.FEC_Channel__c)) {
                interactionIdToChannel.put(interactionCase.Id, interactionCase.FEC_Channel__c);
            }
        }
        if (interactionIdToChannel.isEmpty()) {
            return;
        }
        String customerCaseDevName = FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME;
        for (Case c : newCases) {
            String rtName = recordTypeDeveloperNameMap.get(c.RecordTypeId);
            if (customerCaseDevName.equals(rtName) && c.FEC_Interaction__c != null) {
                String channel = interactionIdToChannel.get(c.FEC_Interaction__c);
                if (String.isNotBlank(channel)) {
                    c.FEC_Channel__c = channel;
                }
            }
        }
    }
    
    /**
     * Method Description: Thêm User ID vào danh sách participants (tránh duplicate)
     * @param currentParticipants Chuỗi participants hiện tại (phân cách bằng dấu phẩy)
     * @param newUserId User ID cần thêm
     * @return String Chuỗi participants đã được cập nhật
     * @created: 2026/01/29 Toannd61
     */
    private String addParticipant(String currentParticipants, Id newUserId) {
        if (newUserId == null) {
            return currentParticipants;
        }
        
        String userIdStr = String.valueOf(newUserId);
        
        // Nếu chưa có participants nào
        if (String.isBlank(currentParticipants)) {
            return userIdStr;
        }
        
        // Kiểm tra xem User đã tồn tại trong danh sách chưa
        Set<String> existingIds = new Set<String>(currentParticipants.split(','));
        
        // Trim whitespace
        Set<String> trimmedIds = new Set<String>();
        for (String id : existingIds) {
            trimmedIds.add(id.trim());
        }
        
        // Nếu User đã tồn tại, không thêm nữa
        if (trimmedIds.contains(userIdStr)) {
            return currentParticipants;
        }
        
        // Thêm User mới vào danh sách
        return currentParticipants + ',' + userIdStr;
    }

    private void assignEntitlement(List<Case> caseList) {

        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Case.getRecordTypeInfosByName();

        if (!rtMap.containsKey(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)) {
            return;
        }

        Id interactionRtId = rtMap.get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME).getRecordTypeId();

        String entitlementName = System.Label.Interaction_Entitlement_Name;

        List<Entitlement> entList = [
            SELECT Id
            FROM Entitlement
            WHERE Name = :entitlementName
            LIMIT 1
        ];

        if (entList.isEmpty()) {
            return;
        }

        Id entitlementId = entList[0].Id;

        for (Case c : caseList) {
            if (c.RecordTypeId == interactionRtId &&
                c.EntitlementId == null) {

                c.EntitlementId = entitlementId;
            }
        }
    }

}