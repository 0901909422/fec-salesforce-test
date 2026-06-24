/**
 * Class Description: Handler class xử lý logic nghiệp vụ cho EmailMessage Trigger
 * Khi khách hàng reply email từ Customer Case / Internal Case:
 *   - Incoming = true, ThreadIdentifier != null, ThreadIdentifier != MessageIdentifier
 *   - RecordType của case cha là Customer_Case hoặc Internal_Case
 *   → Copy EmailMessage incoming sang Customer/Internal Case gốc
 * @created  : 2026/04/03
 */
public without sharing class FEC_EmailMessageTriggerHandler {

    // Trigger guard để tránh recursive
    public static Boolean isExecuting = false;

    private static final Set<String> TARGET_RECORD_TYPES = new Set<String>{
        FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME,
        FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME
    };

    /**
     * Method Description: Main entry point được gọi từ trigger
     * @param newMsgs Danh sách EmailMessage mới vừa được insert
     * @return void
     * @created: 2026/04/03
     */
    public static void run() {
        if (isExecuting) {
            return;
        }
        isExecuting = true;

        FEC_EmailMessageTriggerHandler handler = new FEC_EmailMessageTriggerHandler();

        if (Trigger.isAfter && Trigger.isInsert) {
            Set<Id> handledInteractionReplyEmailIds = handler.createNewInteractionForInteractionReply(Trigger.new);
            handler.redirectIncomingReplyToServiceCase(Trigger.new, handledInteractionReplyEmailIds);
        }

        isExecuting = false;
    }

    /**
     * Khi Email-to-Case đưa email reply vào cùng Interaction cũ theo ThreadIdentifier,
     * tạo Interaction mới có ParentId = Interaction cũ, copy đúng 1 EmailMessage sang Interaction mới,
     * rồi xóa EmailMessage reply khỏi Interaction cũ.
     */
    private Set<Id> createNewInteractionForInteractionReply(List<EmailMessage> newMsgs) {
        Set<Id> handledEmailIds = new Set<Id>();
        List<EmailMessage> replyMsgs = new List<EmailMessage>();
        Set<Id> parentCaseIds = new Set<Id>();

        for (EmailMessage em : newMsgs) {
            if (em.Id == null) continue;
            if (em.Incoming != true) continue;
            if (em.ParentId == null) continue;
            if (String.isBlank(em.ThreadIdentifier)) continue;
            if (em.ThreadIdentifier == em.MessageIdentifier) continue;
            replyMsgs.add(em);
            parentCaseIds.add(em.ParentId);
        }
        if (replyMsgs.isEmpty()) return handledEmailIds;

        Map<Id, Case> parentCaseMap = new Map<Id, Case>([
            SELECT Id, RecordTypeId, RecordType.DeveloperName, ParentId, OwnerId,
                   Origin, Status, Subject, SuppliedEmail, Description,
                   FEC_Channel__c, FEC_Interaction_Subchannel__c,
                   FEC_Interaction_View_Mode__c, FEC_Send_To__c, FEC_Interaction_Email__c
            FROM Case
            WHERE Id IN :parentCaseIds
        ]);

        Set<Id> interactionParentIds = new Set<Id>();
        for (Case parentCase : parentCaseMap.values()) {
            if (parentCase.ParentId != null) {
                interactionParentIds.add(parentCase.ParentId);
            }
        }


        Set<Id> serviceCaseParentIds = new Set<Id>();
        if (!interactionParentIds.isEmpty()) {
            for (Case c : [SELECT Id, RecordType.DeveloperName FROM Case
                            WHERE Id IN :interactionParentIds
                            AND RecordType.DeveloperName IN :TARGET_RECORD_TYPES]) {
                serviceCaseParentIds.add(c.Id);
            }
        }

        Map<Id, Integer> interactionParentOutgoingCount = new Map<Id, Integer>();
        if (!interactionParentIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT ParentId parentId, COUNT(Id) outboundCount
                FROM EmailMessage
                WHERE ParentId IN :interactionParentIds AND Incoming = false
                GROUP BY ParentId
            ]) {
                interactionParentOutgoingCount.put((Id) ar.get('parentId'), (Integer) ar.get('outboundCount'));
            }
        }

        Map<Id, Case> emailIdToNewCase = new Map<Id, Case>();
        List<Case> casesToInsert = new List<Case>();
        for (EmailMessage em : replyMsgs) {
            Case oldInteraction = parentCaseMap.get(em.ParentId);
            if (oldInteraction == null) continue;
            if (oldInteraction.RecordType == null || oldInteraction.RecordType.DeveloperName != 'Interaction') continue;
            if (oldInteraction.ParentId != null && serviceCaseParentIds.contains(oldInteraction.ParentId)) {
                continue;
            }
            if (oldInteraction.ParentId != null
                && interactionParentOutgoingCount.containsKey(oldInteraction.ParentId)
                && interactionParentOutgoingCount.get(oldInteraction.ParentId) > 0) {
                handledEmailIds.add(em.Id);
                continue;
            }

            Case newInteraction = new Case();
            newInteraction.RecordTypeId = oldInteraction.RecordTypeId;
            newInteraction.ParentId = oldInteraction.Id;
            newInteraction.OwnerId = oldInteraction.OwnerId;
            newInteraction.Origin = oldInteraction.Origin;
            newInteraction.Status = String.isNotBlank(oldInteraction.Status) ? oldInteraction.Status : 'Open';
            newInteraction.Subject = String.isNotBlank(em.Subject) ? stripThreadToken(em.Subject) : oldInteraction.Subject;
            newInteraction.Description = 'Created from inbound email reply on Interaction ' + String.valueOf(oldInteraction.Id);
            newInteraction.SuppliedEmail = em.FromAddress;
            newInteraction.FEC_Channel__c = String.isNotBlank(oldInteraction.FEC_Channel__c) ? oldInteraction.FEC_Channel__c : 'Email';
            newInteraction.FEC_Interaction_Subchannel__c = String.isNotBlank(oldInteraction.FEC_Interaction_Subchannel__c) ? oldInteraction.FEC_Interaction_Subchannel__c : 'Incoming Email';
            newInteraction.FEC_Send_To__c = String.isNotBlank(oldInteraction.FEC_Send_To__c) ? oldInteraction.FEC_Send_To__c : em.ToAddress;
            newInteraction.FEC_Interaction_Email__c = String.isNotBlank(oldInteraction.FEC_Interaction_Email__c) ? oldInteraction.FEC_Interaction_Email__c : em.FromAddress;
            casesToInsert.add(newInteraction);
            emailIdToNewCase.put(em.Id, newInteraction);
        }
        if (casesToInsert.isEmpty()) return handledEmailIds;

        insert casesToInsert;

        List<Case> parentPatches = new List<Case>();
        List<EmailMessage> emailsToInsert = new List<EmailMessage>();
        List<Id> originalEmailIdsToDelete = new List<Id>();
        for (EmailMessage em : replyMsgs) {
            Case newInteraction = emailIdToNewCase.get(em.Id);
            if (newInteraction == null || newInteraction.Id == null) continue;

            EmailMessage newEm = new EmailMessage();
            newEm.ParentId = newInteraction.Id;
            newEm.FromAddress = em.FromAddress;
            newEm.FromName = em.FromName;
            newEm.ToAddress = em.ToAddress;
            newEm.CcAddress = em.CcAddress;
            newEm.Subject = stripThreadToken(em.Subject);
            newEm.TextBody = em.TextBody;
            newEm.HtmlBody = em.HtmlBody;
            newEm.Incoming = true;
            newEm.Status = '0';
            newEm.MessageDate = em.MessageDate != null ? em.MessageDate : Datetime.now();
            newEm.ThreadIdentifier = em.ThreadIdentifier;
            newEm.MessageIdentifier = em.MessageIdentifier;
            emailsToInsert.add(newEm);
            originalEmailIdsToDelete.add(em.Id);

            handledEmailIds.add(em.Id);
        }

        if (!emailsToInsert.isEmpty()) {
            insert emailsToInsert;
        }

        if (!parentPatches.isEmpty()) {
            update parentPatches;
        }

        if (!originalEmailIdsToDelete.isEmpty()) {
            try {
                delete [SELECT Id FROM EmailMessage WHERE Id IN :originalEmailIdsToDelete];
            } catch (Exception e) {
                System.debug('delete original interaction reply EmailMessage failed: ' + e.getMessage());
            }
        }

        return handledEmailIds;
    }

    private static String stripThreadToken(String subject) {
        if (String.isBlank(subject)) return '';
        String result = subject.replaceAll('(?i)\\s*\\[\\s*ref:[^\\]]*:ref\\s*\\]', '');
        result = result.replaceAll('(?i)\\s*\\[\\s*fec-parent:[^\\]]+\\s*\\]', '');
        return result.trim();
    }

    /**
     * Method Description: Khi khách hàng reply email từ Customer/Internal Case,
     * copy EmailMessage incoming sang case gốc.
     * Điều kiện xác định email phản hồi (AND):
     *   1. Incoming = true
     *   2. ThreadIdentifier != null
     *   3. ThreadIdentifier != MessageIdentifier
     *   4. ParentId trỏ đến Interaction case có ParentId là Customer/Internal Case
     * @param newMsgs Danh sách EmailMessage mới
     * @return void
     * @created: 2026/04/03
     */
    private void redirectIncomingReplyToServiceCase(List<EmailMessage> newMsgs, Set<Id> skipEmailIds) {
        if (skipEmailIds == null) skipEmailIds = new Set<Id>();
        // Lọc email phản hồi theo spec
        List<EmailMessage> replyMsgs = new List<EmailMessage>();
        for (EmailMessage em : newMsgs) {
            if (skipEmailIds.contains(em.Id)) continue;
            if (em.Incoming != true) continue;
            if (String.isBlank(em.ThreadIdentifier)) continue;
            if (em.ThreadIdentifier == em.MessageIdentifier) continue;
            replyMsgs.add(em);
        }
        if (replyMsgs.isEmpty()) return;

        // Lấy ParentId để check RecordType
        Set<Id> parentIds = new Set<Id>();
        for (EmailMessage em : replyMsgs) {
            if (em.ParentId != null) parentIds.add(em.ParentId);
        }
        if (parentIds.isEmpty()) return;

        // Check case cha trực tiếp có phải Customer/Internal Case không
        Map<Id, Case> directServiceCaseMap = new Map<Id, Case>([
            SELECT Id, RecordType.DeveloperName
            FROM Case
            WHERE Id IN :parentIds
            AND RecordType.DeveloperName IN :TARGET_RECORD_TYPES
        ]);

        // Lấy Interaction cases có ParentId trỏ về Customer/Internal Case
        Set<Id> interactionIds = new Set<Id>();
        for (EmailMessage em : replyMsgs) {
            if (!directServiceCaseMap.containsKey(em.ParentId)) {
                interactionIds.add(em.ParentId);
            }
        }

        Map<Id, Case> interactionMap = new Map<Id, Case>();
        if (!interactionIds.isEmpty()) {
            for (Case c : [SELECT Id, ParentId FROM Case WHERE Id IN :interactionIds AND ParentId != null]) {
                interactionMap.put(c.Id, c);
            }
        }

        // Verify ParentId của Interaction là Customer/Internal Case
        Set<Id> targetIds = new Set<Id>();
        for (Case c : interactionMap.values()) targetIds.add(c.ParentId);
        Map<Id, Case> targetCaseMap = new Map<Id, Case>();
        if (!targetIds.isEmpty()) {
            for (Case c : [SELECT Id, RecordType.DeveloperName FROM Case WHERE Id IN :targetIds AND RecordType.DeveloperName IN :TARGET_RECORD_TYPES]) {
                targetCaseMap.put(c.Id, c);
            }
        }

        // Copy EmailMessage incoming sang Customer/Internal Case
        List<EmailMessage> toInsert = new List<EmailMessage>();
        for (EmailMessage em : replyMsgs) {
            Id targetCaseId = null;

            if (directServiceCaseMap.containsKey(em.ParentId)) {
                // EmailMessage đã trên Customer/Internal Case rồi - không cần copy
                continue;
            }

            Case interaction = interactionMap.get(em.ParentId);
            if (interaction == null || !targetCaseMap.containsKey(interaction.ParentId)) continue;
            targetCaseId = interaction.ParentId;

            EmailMessage newEm = new EmailMessage();
            newEm.ParentId    = targetCaseId;
            newEm.FromAddress = em.FromAddress;
            newEm.FromName    = em.FromName;
            newEm.ToAddress   = em.ToAddress;
            newEm.CcAddress   = em.CcAddress;
            newEm.Subject     = stripThreadToken(em.Subject);
            newEm.TextBody    = em.TextBody;
            newEm.HtmlBody    = em.HtmlBody;
            newEm.Incoming    = true;
            newEm.Status      = '0';
            newEm.MessageDate = em.MessageDate != null ? em.MessageDate : Datetime.now();
            toInsert.add(newEm);
        }

        if (!toInsert.isEmpty()) {
            try {
                insert toInsert;
            } catch (Exception e) {
                System.debug('FEC_EmailMessageTriggerHandler insert failed: ' + e.getMessage());
            }
        }
    }
}