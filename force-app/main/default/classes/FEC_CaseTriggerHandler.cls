/**
 * Class Description: Handler class xử lý logic nghiệp vụ cho Case Trigger
 * @created  : 2026/01/03 Toannd61
 * @modified :    
 */
public without sharing class FEC_CaseTriggerHandler {
    
    // Trigger guard để tránh recursive
    public static Boolean isExecuting = false;
    public static Boolean isSystemUpdate = false;
    
    /**
     * Method Description: Main entry point được gọi từ trigger
     * @return void
     * @created: 2026/01/03 Toannd61
     * @modified: 2026/01/06 - Added onBeforeInsert handler
     * @modified: 2026/01/16 - Added onAfterInsert handler for auto follow-up
     */
    public static void run() {
        if (isExecuting) {
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
        setEmail2CaseChannelBeforeInsert(newCases);
        syncChannelFromInteractionForCustomerCase(newCases);
        generateFECIdSearch(newCases);
        updateCaseParticipantsOnInsert(newCases);
        assignEntitlement(newCases);
                
        // Delegate: Check duplicate External Interaction ID (Story 4)
        new CaseTriggerHandler().onBeforeInsert(newCases);
        syncGlobalSearchFromParent(newCases, null);
        setParentIdFromEmailThread(newCases);
        stripSubjectThreadToken(newCases);
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
                
        // Delegate: Check duplicate External Interaction ID (Story 4)
        new CaseTriggerHandler().onBeforeUpdate(newCases, oldMap);
        syncGlobalSearchFromParent(newCases, oldMap);
    }

    /**
     * Method Description: Xử lý logic sau khi insert Case (auto follow-up)
     * @param newCases Danh sách Case mới vừa được insert
     * @return void
     * @created: 2026/01/16 Toannd61
     */
    private void onAfterInsert(List<Case> newCases) {
        isExecuting = true;
        handleAutoFollowUpOnInsert(newCases);
        updateEmail2CaseFieldsOnInsert(newCases);
        FEC_CasePendingStatusService.syncPendingStatusWhenSubmittedOwnerChanges(newCases, null);
        syncGlobalSearch(newCases, null);
        FEC_CaseManagerListService.syncFromOwnerCases(newCases, null);
        redirectEmailReplyToCustomerCase(newCases);
        
        isExecuting = false;
    }

    /**
     * Method Description: Xử lý logic sau khi update Case
     * @param newCases Danh sách Case mới sau update
     * @param oldMap Map chứa giá trị cũ của Case trước update
     * @return void
     * @created: 2026/01/03
     * @modified: 2026/01/16
     * @modified: 2026/02/02
     * @modified: 2026/04/06 - Added Auto Notification for Internal User (Loại 3 Email + Loại 4 SF App)
     */
    private void onAfterUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        isExecuting = true;
        updateLastModified(newCases, oldMap);
        handleFollowUpOnResolved(newCases, oldMap);
        handleAutoFollowUpOnUpdate(newCases, oldMap);
        if (!FEC_GetNextWorkController.isGetNextWork) {
            FEC_CaseBusinessService.createRoutingActionHistoryOnOwnerChange(newCases, oldMap);
        }
        FEC_CasePendingStatusService.syncPendingStatusWhenSubmittedOwnerChanges(newCases, oldMap);
        FEC_CaseManagerListService.syncFromOwnerCases(newCases, oldMap);
        syncGlobalSearch(newCases, oldMap);
        FEC_NotificationService.sendEmailNotifications(newCases, oldMap);
        FEC_NotificationService.sendSFAppNotifications(newCases, oldMap);
        isExecuting = false;
    }

    private void syncGlobalSearch(List<Case> newCases, Map<Id, Case> oldMap) {
        // 1. Dynamically get the 'Interaction' Record Type ID
        Id interactionRtId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Interaction').getRecordTypeId();
        
        // Map to hold the Interaction Case Id -> the new FEC_ID_Search__c value
        Map<Id, String> interactionIdToSearchKey = new Map<Id, String>();

        // 2. Identify which 'Interaction' Cases meet the criteria
        for (Case c : newCases) {
            if (c.RecordTypeId == interactionRtId) {
                // Check Insert Condition: oldMap is null AND FEC_ID_Search__c has a value
                Boolean isInsertCriteriaMet = (oldMap == null && c.FEC_ID_Search__c != null);
                
                // Check Update Condition: oldMap exists AND FEC_ID_Search__c has changed
                Boolean isUpdateCriteriaMet = (oldMap != null && c.FEC_ID_Search__c != oldMap.get(c.Id).FEC_ID_Search__c);

                if (isInsertCriteriaMet || isUpdateCriteriaMet) {
                    interactionIdToSearchKey.put(c.Id, c.FEC_ID_Search__c);
                }
            }
        }

        // 3. Exit early if no cases meet the criteria to save SOQL/DML limits
        if (interactionIdToSearchKey.isEmpty()) {
            return;
        }

        // 4. Query related Cases (where Record Type is NOT Interaction)
        List<Case> relatedCases = [
            SELECT Id, FEC_Interaction__c, FEC_Global_Search__c 
            FROM Case 
            WHERE FEC_Interaction__c IN :interactionIdToSearchKey.keySet()
            AND RecordTypeId != :interactionRtId
        ];

        List<Case> casesToUpdate = new List<Case>();

        // 5. Apply the updated search string to the related cases
        for (Case childCase : relatedCases) {
            String newSearchValue = interactionIdToSearchKey.get(childCase.FEC_Interaction__c);
            
            // Only update if the value is actually different (saves unnecessary DML)
            if (childCase.FEC_Global_Search__c != newSearchValue) {
                childCase.FEC_Global_Search__c = newSearchValue;
                casesToUpdate.add(childCase);
            }
        }

        // 6. Update the child records safely
        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }

    private void syncGlobalSearchFromParent(List<Case> newCases, Map<Id, Case> oldMap) {
        Id interactionRtId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Interaction').getRecordTypeId();
        
        // Set to hold the IDs of the parent Interaction cases we need to query
        Set<Id> parentInteractionIds = new Set<Id>();
        
        // List to keep track of which specific child cases need updating
        List<Case> casesToProcess = new List<Case>();

        // 1. Identify non-Interaction cases where the lookup has been set or changed
        for (Case c : newCases) {
            if (c.RecordTypeId != interactionRtId) {
                // Check Insert: Lookup is populated right on creation
                Boolean isInsertCriteriaMet = (oldMap == null && c.FEC_Interaction__c != null);
                
                // Check Update: Lookup has changed (e.g., reparented to a new Interaction)
                Boolean isUpdateCriteriaMet = (oldMap != null && c.FEC_Interaction__c != oldMap.get(c.Id).FEC_Interaction__c);

                // Also check if they just cleared the lookup entirely so we can clear the search field
                Boolean isLookupCleared = (oldMap != null && c.FEC_Interaction__c == null && oldMap.get(c.Id).FEC_Interaction__c != null);

                if (isInsertCriteriaMet || isUpdateCriteriaMet || isLookupCleared) {
                    if (c.FEC_Interaction__c != null) {
                        parentInteractionIds.add(c.FEC_Interaction__c);
                    }
                    casesToProcess.add(c);
                }
            }
        }

        // Exit early if nothing changed to save SOQL limits
        if (casesToProcess.isEmpty()) {
            return;
        }

        // 2. Query the parent Interaction cases to get their FEC_ID_Search__c values
        Map<Id, Case> parentCases = new Map<Id, Case>();
        if (!parentInteractionIds.isEmpty()) {
            parentCases = new Map<Id, Case>([
                SELECT Id, FEC_ID_Search__c 
                FROM Case 
                WHERE Id IN :parentInteractionIds
            ]);
        }

        // 3. Apply the parent's search value directly to the child case records
        for (Case c : casesToProcess) {
            if (c.FEC_Interaction__c == null) {
                // If the user removed the lookup, clear the search field too
                c.FEC_Global_Search__c = null;
            } else if (parentCases.containsKey(c.FEC_Interaction__c)) {
                // Pull the search field down from the parent map
                c.FEC_Global_Search__c = parentCases.get(c.FEC_Interaction__c).FEC_ID_Search__c;
            }
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
        
        Id interactionRecordTypeId = getInteractionRecordTypeId();
        if (interactionRecordTypeId == null) {
            return;
        }

        List<Id> caseIdsToUpdate = new List<Id>();

        for (Case c : newCases) {
            if ((c.Origin != null && c.Origin.startsWith('Email'))
                && c.RecordTypeId == interactionRecordTypeId) {
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
            if (c.RecordTypeId == interactionRecordTypeId && String.isBlank(c.FEC_Channel__c)) {
                // Phân loại cho Ubank hoặc FE -> Channel Email
                if (c.Origin == FEC_ConstantCommon.CASE_ORIGIN_EMAIL_UBANK || c.Origin == FEC_ConstantCommon.CASE_ORIGIN_EMAIL_FE) {
                    c.FEC_Channel__c = FEC_ConstantCommon.EMAIL;
                    c.FEC_Interaction_Subchannel__c = FEC_ConstantCommon.SUBCHANNEL_INCOMING_EMAIL;
                    c.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE;
                }
                // Phân loại cho Internal -> Channel Internal
                else if (c.Origin == FEC_ConstantCommon.CASE_ORIGIN_EMAIL_INTERNAL) {
                    c.FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INTERNAL;
                    c.FEC_Interaction_Subchannel__c = FEC_ConstantCommon.SUBCHANNEL_INTERNAL_EMAIL;
                    c.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE;
                }
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

        FEC_System_Config__c sysConfig = FEC_System_Config__c.getOrgDefaults();
        String sendToValue = sysConfig != null ? sysConfig.FEC_Send_To_Email_Ubank__c : null;

        Map<Id, EmailMessage> caseIdToEmailMap = new Map<Id, EmailMessage>();
        for (EmailMessage em : [SELECT Id, ParentId, FromAddress, ToAddress, CreatedDate
                                FROM EmailMessage
                                WHERE ParentId IN :caseIds
                                AND FromAddress != NULL
                                ORDER BY CreatedDate ASC]) {
            if (!caseIdToEmailMap.containsKey(em.ParentId)) {
                caseIdToEmailMap.put(em.ParentId, em);
            }
        }

        List<Case> casesToDml = [
            SELECT Id, RecordTypeId, OwnerId, FEC_Is_Reply_Interaction_email__c, 
                   ParentId, FEC_Channel__c, FEC_Send_To__c, Origin, CaseNumber
            FROM Case 
            WHERE Id IN :caseIds
        ];

        List<Case> casesForRouting = new List<Case>();
        List<Case> casesToPublish = new List<Case>();

        for (Case c : casesToDml) {
            EmailMessage relatedEmail = caseIdToEmailMap.get(c.Id);

            if (relatedEmail != null) {
                c.FEC_Interaction_Email__c = relatedEmail.FromAddress;
            }

            if (c.FEC_Channel__c == FEC_ConstantCommon.CHANNEL_INTERNAL) {
                if (relatedEmail != null) {
                    c.FEC_Send_To__c = relatedEmail.ToAddress;
                }
            } else if (c.Origin == FEC_ConstantCommon.CASE_ORIGIN_EMAIL_FE) {
                // Ép cứng địa chỉ cho FE Credit
                c.FEC_Send_To__c = FEC_ConstantCommon.EMAIL_READONLY_FROM_FECREDIT;
                c.FEC_Interaction_Subchannel__c = FEC_ConstantCommon.SUBCHANNEL_INCOMING_EMAIL;
                c.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE;
                casesForRouting.add(c);
            } else {
                // Với Ubank: Tuyệt đối chỉ lấy từ Custom Setting
                if (c.Origin == FEC_ConstantCommon.CASE_ORIGIN_EMAIL_UBANK) {
                    c.FEC_Send_To__c = sendToValue;
                } 
                // Các trường hợp khác: Lấy ToAddress thực tế của mail làm fallback
                else if (relatedEmail != null) {
                    c.FEC_Send_To__c = relatedEmail.ToAddress;
                }

                c.FEC_Interaction_Subchannel__c = FEC_ConstantCommon.SUBCHANNEL_INCOMING_EMAIL;
                c.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE;
                casesForRouting.add(c);
            }

            if (c.Origin == FEC_ConstantCommon.CASE_ORIGIN_EMAIL_UBANK) {
                casesToPublish.add(c);
            }
        }
        // assignCases(casesToDml);
        if (!casesForRouting.isEmpty()) {
            FEC_InteractionRoutingService.assignInteractionReply(casesForRouting);
            FEC_InteractionRoutingService.assignNewInteractionEmail(casesForRouting);
        }
        // @Thangtv: Publish platform events to automatically open U-bank cases
        if (!casesToPublish.isEmpty()) {
            System.debug('platform events Case Auto Open is starting');
            FEC_InteractionRoutingController.publishRoutingEvents(casesToPublish);
        }

        if (!casesToDml.isEmpty()) {
            isExecuting = true;
            try {
                update casesToDml;
            } finally {
                isExecuting = false;
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

    /**
     * Parse thread token [ ref:ORGID.CASEID:ref ] từ Subject của case mới tạo bởi email reply
     * và set ParentId = Case ID gốc
     */
    private void setParentIdFromEmailThread(List<Case> newCases) {
        Pattern threadPattern = Pattern.compile('\\[ ref:[A-Za-z0-9]+\\.([A-Za-z0-9]{15,18}):ref \\]');
        Set<String> parentCaseIds = new Set<String>();
        Map<Case, String> caseToParentId = new Map<Case, String>();

        for (Case c : newCases) {
            if (String.isBlank(c.Subject) || c.ParentId != null) continue;
            Matcher m = threadPattern.matcher(c.Subject);
            if (m.find()) {
                String rawId = m.group(1);
                parentCaseIds.add(rawId);
                caseToParentId.put(c, rawId);
            }
        }

        if (parentCaseIds.isEmpty()) return;

        Map<String, Case> validParents = new Map<String, Case>();
        for (Case parent : [SELECT Id, FEC_Send_To__c, FEC_Interaction_Email__c FROM Case WHERE Id IN :parentCaseIds]) {
            validParents.put(String.valueOf(parent.Id).substring(0, 15), parent);
            validParents.put(String.valueOf(parent.Id), parent);
        }

        for (Case c : caseToParentId.keySet()) {
            String rawId = caseToParentId.get(c);
            String key15 = rawId.length() >= 15 ? rawId.substring(0, 15) : rawId;
            Case parentCase = validParents.containsKey(rawId) ? validParents.get(rawId) : validParents.get(key15);
            if (parentCase != null) {
                c.ParentId = parentCase.Id;
                if (String.isBlank(c.FEC_Send_To__c) && String.isNotBlank(parentCase.FEC_Send_To__c)) {
                    c.FEC_Send_To__c = parentCase.FEC_Send_To__c;
                }
            }
        }
    }

    private void stripSubjectThreadToken(List<Case> cases) {
        Pattern p = Pattern.compile('\\s*\\[\\s*ref:[^\\]]*:ref\\s*\\]');
        for (Case c : cases) {
            if (String.isNotBlank(c.Subject)) {
                c.Subject = p.matcher(c.Subject).replaceAll('').trim();
            }
        }
    }

    /**
     * Khi Email-to-Case tạo case mới từ email reply của khách có thread token Customer Case,
     * tạo EmailMessage incoming trên Customer Case đó và xóa case mới (async).
     */
    private void redirectEmailReplyToCustomerCase(List<Case> newCases) {
        Set<Id> candidateIds = new Set<Id>();
        for (Case c : newCases) {
            if (c.ParentId == null) continue;
            if (c.Origin == null || !c.Origin.startsWith('Email')) continue;
            candidateIds.add(c.Id);
        }
        if (candidateIds.isEmpty()) return;

        // Kiểm tra parent là Customer Case
        Map<Id, Case> caseMap = new Map<Id, Case>(
            [SELECT Id, ParentId FROM Case WHERE Id IN :candidateIds]
        );
        Set<Id> parentIds = new Set<Id>();
        for (Case c : caseMap.values()) parentIds.add(c.ParentId);

        Map<Id, Case> parentMap = new Map<Id, Case>(
            [SELECT Id, RecordType.DeveloperName FROM Case WHERE Id IN :parentIds]
        );

        Set<Id> validCaseIds = new Set<Id>();
        for (Case c : caseMap.values()) {
            Case parent = parentMap.get(c.ParentId);
            if (parent != null && parent.RecordType.DeveloperName == FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME) {
                validCaseIds.add(c.Id);
            }
        }
        if (validCaseIds.isEmpty()) return;

        // Copy EmailMessage incoming sang Customer Case
        List<EmailMessage> incomingMsgs = [
            SELECT Id, ParentId, FromAddress, FromName, ToAddress, CcAddress,
                   Subject, TextBody, HtmlBody, MessageDate
            FROM EmailMessage
            WHERE ParentId IN :validCaseIds AND Incoming = true
        ];
        List<EmailMessage> toInsert = new List<EmailMessage>();
        for (EmailMessage em : incomingMsgs) {
            Case c = caseMap.get(em.ParentId);
            if (c == null) continue;
            EmailMessage newEm = new EmailMessage();
            newEm.ParentId    = c.ParentId;
            newEm.FromAddress = em.FromAddress;
            newEm.FromName    = em.FromName;
            newEm.ToAddress   = em.ToAddress;
            newEm.CcAddress   = em.CcAddress;
            newEm.Subject     = em.Subject != null
                ? em.Subject.replaceAll('(?i)\\s*\\[\\s*ref:[^\\]]*:ref\\s*\\]', '').trim() : '';
            newEm.TextBody    = em.TextBody;
            newEm.HtmlBody    = em.HtmlBody;
            newEm.Incoming    = true;
            newEm.Status      = '0';
            newEm.MessageDate = em.MessageDate != null ? em.MessageDate : Datetime.now();
            toInsert.add(newEm);
        }
        if (!toInsert.isEmpty()) {
            try { insert toInsert; } catch (Exception e) {
                System.debug('redirectEmailReply insert failed: ' + e.getMessage());
            }
        }

        // Xóa case async để tránh conflict với các service đang chạy trong cùng transaction
        deleteCasesAsync(new List<Id>(validCaseIds));
    }

    @future
    private static void deleteCasesAsync(List<Id> caseIds) {
        try {
            List<Case> toDelete = [SELECT Id FROM Case WHERE Id IN :caseIds];
            if (!toDelete.isEmpty()) delete toDelete;
        } catch (Exception e) {
            System.debug('deleteCasesAsync failed: ' + e.getMessage());
        }
    }

    private static void updateLastModified(List<Case> newCases, Map<Id, Case> oldMap) {
        List<Case> caseUpdates = new List<Case>();
        for (Case c : newCases) {
            Case oldCase = oldMap.get(c.Id);
            if (isSystemUpdate || c.FEC_Interaction_View_Mode__c != oldCase.FEC_Interaction_View_Mode__c) {
                continue;
            }
            Case caseUpdate = new Case(
                Id = c.Id,
                FEC_Last_Updated_By_View__c = c.FEC_Last_Updated_By__c,
                FEC_Last_Updated_On_View__c = c.FEC_Last_Updated_On__c
            );
            caseUpdates.add(caseUpdate);
        }
        if (!caseUpdates.isEmpty()) {
            update caseUpdates;
        }
    }
}