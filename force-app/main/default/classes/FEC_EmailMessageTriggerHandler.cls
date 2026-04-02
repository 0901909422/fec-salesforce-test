/**
 * Handler cho EmailMessage trigger
 * Khi khách hàng reply email từ Customer Case:
 * - Salesforce nhận email incoming → tạo EmailMessage trên case tạm (Interaction)
 * - Trigger này detect thread token → copy EmailMessage sang Customer Case gốc
 */
public without sharing class FEC_EmailMessageTriggerHandler {

    public static void run(List<EmailMessage> newMsgs) {
        // Chỉ xử lý email incoming
        List<EmailMessage> incomingMsgs = new List<EmailMessage>();
        for (EmailMessage em : newMsgs) {
            if (em.Incoming == true && String.isNotBlank(em.Subject)) {
                incomingMsgs.add(em);
            }
        }
        if (incomingMsgs.isEmpty()) return;

        // Parse thread token [ ref:ORGID.CASEID:ref ] từ subject
        Pattern threadPattern = Pattern.compile('\\[\\s*ref:[A-Za-z0-9]+\\.([A-Za-z0-9]{15,18}):ref\\s*\\]');
        Map<Id, Id> emailToCustomerCase = new Map<Id, Id>(); // EmailMessage.Id → Customer Case Id

        for (EmailMessage em : incomingMsgs) {
            Matcher m = threadPattern.matcher(em.Subject);
            if (!m.find()) continue;
            String rawId = m.group(1);
            try {
                Id caseId = (Id) rawId;
                emailToCustomerCase.put(em.Id, caseId);
            } catch (Exception e) {
                System.debug('Invalid case id in thread token: ' + rawId);
            }
        }
        if (emailToCustomerCase.isEmpty()) return;

        // Kiểm tra các case ID đó có phải Customer Case không
        Set<Id> candidateCaseIds = new Set<Id>(emailToCustomerCase.values());
        Map<Id, Case> customerCaseMap = new Map<Id, Case>([
            SELECT Id, RecordType.DeveloperName
            FROM Case
            WHERE Id IN :candidateCaseIds
            AND RecordType.DeveloperName = :FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME
        ]);

        // Tạo EmailMessage mới trên Customer Case
        List<EmailMessage> toInsert = new List<EmailMessage>();
        for (EmailMessage em : incomingMsgs) {
            Id targetCaseId = emailToCustomerCase.get(em.Id);
            if (targetCaseId == null || !customerCaseMap.containsKey(targetCaseId)) continue;
            // Không copy nếu EmailMessage đã thuộc Customer Case rồi
            if (em.ParentId == targetCaseId) continue;

            EmailMessage newEm = new EmailMessage();
            newEm.ParentId    = targetCaseId;
            newEm.FromAddress = em.FromAddress;
            newEm.FromName    = em.FromName;
            newEm.ToAddress   = em.ToAddress;
            newEm.CcAddress   = em.CcAddress;
            newEm.Subject     = em.Subject.replaceAll('(?i)\\s*\\[\\s*ref:[^\\]]*:ref\\s*\\]', '').trim();
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
