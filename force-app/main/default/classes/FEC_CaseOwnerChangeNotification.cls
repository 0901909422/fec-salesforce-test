/**
 * Class Description: Service gửi email thông báo khi Case được chuyển Owner (Change Owner từ Listview hoặc bất kỳ thao tác nào đổi OwnerId).
 * Gửi tới: New Owner (User) - email của User, hoặc New Queue - Queue Email (nếu Queue có cấu hình Email).
 * @created  : 2026/03/14
 * @modified :
 */
public without sharing class FEC_CaseOwnerChangeNotification {

    private static final Integer MAX_EMAILS_PER_CALL = 10;

    /**
     * Method Description: Gửi email thông báo tới New Owner (User email hoặc Queue Email) cho các Case có OwnerId thay đổi.
     * @param newCases Danh sách Case mới (Trigger.new)
     * @param oldMap Map chứa giá trị cũ của Case (Trigger.oldMap)
     * @return void
     * @created: 2026/03/14
     * @modified:
     */
    public static void sendNotificationToNewOwner(List<Case> newCases, Map<Id, Case> oldMap) {
        if (newCases == null || oldMap == null) {
            return;
        }
        List<Case> ownerChangedCases = new List<Case>();
        for (Case c : newCases) {
            Case oldCase = oldMap.get(c.Id);
            if (oldCase != null && c.OwnerId != oldCase.OwnerId && c.OwnerId != null) {
                ownerChangedCases.add(c);
            }
        }
        if (ownerChangedCases.isEmpty()) {
            return;
        }
        Set<Id> newOwnerIds = new Set<Id>();
        for (Case c : ownerChangedCases) {
            newOwnerIds.add(c.OwnerId);
        }
        Map<Id, User> userById = new Map<Id, User>();
        Map<Id, Group> queueById = new Map<Id, Group>();
        List<Id> userIds = new List<Id>();
        List<Id> queueIds = new List<Id>();
        for (Id ownerId : newOwnerIds) {
            if (ownerId.getSObjectType() == User.SObjectType) {
                userIds.add(ownerId);
            } else if (ownerId.getSObjectType() == Group.SObjectType) {
                queueIds.add(ownerId);
            }
        }
        if (!userIds.isEmpty()) {
            for (User u : [SELECT Id, Email FROM User WHERE Id IN :userIds AND Email != null]) {
                userById.put(u.Id, u);
            }
        }
        if (!queueIds.isEmpty()) {
            for (Group g : [SELECT Id, Email FROM Group WHERE Id IN :queueIds AND Type = 'Queue']) {
                queueById.put(g.Id, g);
            }
        }
        String subjectLabel = getSubjectLabel();
        String bodyLabel = getBodyLabel();
        String baseUrl = getBaseUrl();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Case c : ownerChangedCases) {
            Id ownerId = c.OwnerId;
            String caseNumber = c.CaseNumber != null ? c.CaseNumber : c.Id;
            String caseLink = baseUrl + '/' + c.Id;
            String subject = String.format(subjectLabel, new List<String>{ caseNumber });
            String body = String.format(bodyLabel, new List<String>{ caseNumber, caseLink });
            User ownerUser = userById.get(ownerId);
            if (ownerUser != null && String.isNotBlank(ownerUser.Email)) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTargetObjectId(ownerId);
                mail.setSaveAsActivity(false);
                mail.setWhatId(c.Id);
                mail.setSubject(subject);
                mail.setPlainTextBody(body);
                emails.add(mail);
            } else {
                Group queue = queueById.get(ownerId);
                if (queue != null && String.isNotBlank(queue.Email)) {
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new List<String>{ queue.Email.trim() });
                    mail.setWhatId(c.Id);
                    mail.setSubject(subject);
                    mail.setPlainTextBody(body);
                    mail.setSaveAsActivity(false);
                    emails.add(mail);
                }
            }
        }
        // Gửi theo từng batch để không vượt governor limit (10 email/lần gọi trong sync)
        for (Integer i = 0; i < emails.size(); i += MAX_EMAILS_PER_CALL) {
            Integer endIndex = Math.min(i + MAX_EMAILS_PER_CALL, emails.size());
            List<Messaging.SingleEmailMessage> batch = new List<Messaging.SingleEmailMessage>();
            for (Integer j = i; j < endIndex; j++) {
                batch.add(emails[j]);
            }
            try {
                Messaging.sendEmail(batch);
            } catch (Exception e) {
                System.debug('FEC_CaseOwnerChangeNotification.sendNotificationToNewOwner batch failed: ' + e.getMessage());
            }
        }
    }

    /**
     * @description Lấy nội dung subject email từ Custom Label.
     * @return Chuỗi subject (có placeholder {0} cho Case number)
     */
    private static String getSubjectLabel() {
        try {
            return System.Label.FEC_Email_Subject_Case_Owner_Change;
        } catch (Exception e) {
            return 'Case {0} assigned to you';
        }
    }

    /**
     * @description Lấy nội dung body email từ Custom Label.
     * @return Chuỗi body (placeholder {0}: Case number, {1}: Case link)
     */
    private static String getBodyLabel() {
        try {
            return System.Label.FEC_Email_Body_Case_Owner_Change;
        } catch (Exception e) {
            return 'Case {0} has been assigned to you. View: {1}';
        }
    }

    /**
     * @description Lấy base URL của org.
     * @return Base URL hoặc chuỗi rỗng nếu lỗi
     */
    private static String getBaseUrl() {
        try {
            return System.URL.getOrgDomainUrl().toExternalForm();
        } catch (Exception e) {
            return '';
        }
    }
}
