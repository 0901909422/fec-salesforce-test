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
            handler.onAfterInsert(Trigger.new);
        }

        isExecuting = false;
    }

    private void onAfterInsert(List<EmailMessage> newEmailMsgs) {
        redirectIncomingReplyToServiceCase(newEmailMsgs);
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
    private void redirectIncomingReplyToServiceCase(List<EmailMessage> newMsgs) {
        // Lọc email phản hồi theo spec
        List<EmailMessage> replyMsgs = new List<EmailMessage>();
        for (EmailMessage em : newMsgs) {
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
            newEm.Subject     = String.isNotBlank(em.Subject)
                ? em.Subject.replaceAll('(?i)\\s*\\[\\s*ref:[^\\]]*:ref\\s*\\]', '').trim() : '';
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
