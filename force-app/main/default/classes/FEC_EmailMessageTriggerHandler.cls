/**
 * Handler cho EmailMessage trigger
 * Khi khách hàng reply email từ Customer Case / Internal Case:
 * - Incoming = true
 * - ThreadIdentifier != null và ThreadIdentifier != MessageIdentifier (là email reply, không phải email gốc)
 * - RecordType của case cha là Customer_Case hoặc Internal_Case
 * → Email đã được Salesforce gắn đúng vào case, không cần tạo Interaction mới
 * → Trigger này đảm bảo EmailMessage được giữ nguyên trên case đúng
 */
public without sharing class FEC_EmailMessageTriggerHandler {

    private static final Set<String> TARGET_RECORD_TYPES = new Set<String>{
        FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME,
        FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME
    };

    public static void run(List<EmailMessage> newMsgs) {
        // Lọc email phản hồi theo spec:
        // 1. Incoming = true
        // 2. ThreadIdentifier != null
        // 3. ThreadIdentifier != MessageIdentifier
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

        Map<Id, Case> caseMap = new Map<Id, Case>([
            SELECT Id, RecordType.DeveloperName
            FROM Case
            WHERE Id IN :parentIds
            AND RecordType.DeveloperName IN :TARGET_RECORD_TYPES
        ]);

        // Lấy Interaction cases có ParentId trỏ về Customer/Internal Case
        Set<Id> interactionIds = new Set<Id>();
        for (EmailMessage em : replyMsgs) {
            if (!caseMap.containsKey(em.ParentId)) interactionIds.add(em.ParentId);
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
            if (caseMap.containsKey(em.ParentId)) continue; // đã đúng case rồi
            Case interaction = interactionMap.get(em.ParentId);
            if (interaction == null || !targetCaseMap.containsKey(interaction.ParentId)) continue;

            EmailMessage newEm = new EmailMessage();
            newEm.ParentId    = interaction.ParentId;
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
            try { insert toInsert; }
            catch (Exception e) { System.debug('FEC_EmailMessageTriggerHandler insert failed: ' + e.getMessage()); }
        }
    }
}