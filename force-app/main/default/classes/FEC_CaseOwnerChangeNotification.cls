/**
 * Service gửi email thông báo khi Case được chuyển Owner (Change Owner từ Listview hoặc bất kỳ thao tác nào đổi OwnerId).
 * Gửi tới: New Owner (User) - email của User, hoặc New Queue - Queue Email (nếu Queue có cấu hình Email).
 * @created 2026/03/14
 */
public without sharing class FEC_CaseOwnerChangeNotification {

    private static final Integer MAX_EMAILS_PER_CALL = 100;

    /**
     * Gửi email thông báo tới New Owner (User email hoặc Queue Email) cho các Case có OwnerId thay đổi.
     * @param newCases Trigger.new
     * @param oldMap Trigger.oldMap
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
            String prefix = String.valueOf(ownerId).substring(0, 3);
            if (prefix == '005') {
                userIds.add(ownerId);
            } else if (prefix == '00G') {
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
            if (emails.size() >= MAX_EMAILS_PER_CALL) {
                break;
            }
        }
        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                System.debug('FEC_CaseOwnerChangeNotification.sendNotificationToNewOwner failed: ' + e.getMessage());
            }
        }
    }

    private static String getSubjectLabel() {
        try {
            return System.Label.FEC_Email_Subject_Case_Owner_Change;
        } catch (Exception e) {
            return 'Case {0} assigned to you';
        }
    }

    private static String getBodyLabel() {
        try {
            return System.Label.FEC_Email_Body_Case_Owner_Change;
        } catch (Exception e) {
            return 'Case {0} has been assigned to you. View: {1}';
        }
    }

    private static String getBaseUrl() {
        try {
            return System.URL.getOrgDomainUrl().toExternalForm();
        } catch (Exception e) {
            return '';
        }
    }
}
