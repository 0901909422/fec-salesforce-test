/**
 * Gửi email SLA DS/TS theo FEC_Template__c khi FEC_SLA_Notification_1/2/3__c được stamp (trigger after update).
 */
public without sharing class FEC_CaseDsTsSlaNotificationSender {

    public static void sendAfterCaseUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        if (newCases == null || newCases.isEmpty() || oldMap == null) {
            return;
        }
        if (!Test.isRunningTest()) {
            FEC_CaseDsTsSlaSchedulable.ensureScheduled();
        }

        Set<Id> caseIdsToNotify = collectNewlyStampedCaseIds(newCases, oldMap);
        if (caseIdsToNotify.isEmpty()) {
            return;
        }

        Map<String, FEC_Template__c> templateByApi = loadActiveSlaTemplates();
        if (templateByApi.isEmpty()) {
            System.debug('FEC_DEBUG DS/TS SLA: no active templates found.');
            return;
        }

        String senderEmail = resolveSenderEmailAddress();
        Map<Id, Case> casesById = buildCasesFromTrigger(newCases, caseIdsToNotify);
        List<FEC_Notification.EmailInfo> emailsToSend = buildEmailInfos(
            caseIdsToNotify,
            casesById,
            templateByApi
        );

        if (!emailsToSend.isEmpty()) {
            FEC_Notification.executeSendEmailsBulk(emailsToSend, senderEmail);
        }
    }

    private static Set<Id> collectNewlyStampedCaseIds(List<Case> newCases, Map<Id, Case> oldMap) {
        Set<Id> caseIds = new Set<Id>();
        for (Case c : newCases) {
            Case oldC = oldMap.get(c.Id);
            if (oldC == null) {
                continue;
            }
            if (detectNewlyStampedSlot(c, oldC) != null && c.IsClosed != true) {
                caseIds.add(c.Id);
            }
        }
        return caseIds;
    }

    private static Map<Id, Case> buildCasesFromTrigger(List<Case> newCases, Set<Id> caseIds) {
        Map<Id, Case> casesById = new Map<Id, Case>();
        Set<Id> categoryIds = new Set<Id>();
        for (Case c : newCases) {
            if (!caseIds.contains(c.Id)) {
                continue;
            }
            casesById.put(c.Id, c);
            if (c.FEC_Category__c != null) {
                categoryIds.add(c.FEC_Category__c);
            }
        }
        if (!categoryIds.isEmpty()) {
            Map<Id, FEC_Category__c> categoriesById = new Map<Id, FEC_Category__c>([
                SELECT Id, Name
                FROM FEC_Category__c
                WHERE Id IN :categoryIds
            ]);
            for (Case c : casesById.values()) {
                FEC_Category__c category = categoriesById.get(c.FEC_Category__c);
                if (category != null) {
                    c.FEC_Category__r = category;
                }
            }
        }
        return casesById;
    }

    private static List<FEC_Notification.EmailInfo> buildEmailInfos(
        Set<Id> caseIds,
        Map<Id, Case> casesById,
        Map<String, FEC_Template__c> templateByApi
    ) {
        List<FEC_Notification.EmailInfo> emailsToSend = new List<FEC_Notification.EmailInfo>();

        for (Id caseId : caseIds) {
            emailsToSend.addAll(
                buildEmailInfosForCase(caseId, casesById.get(caseId), templateByApi)
            );
        }
        return emailsToSend;
    }

    @TestVisible
    private static List<FEC_Notification.EmailInfo> buildEmailInfosForCase(
        Id caseId,
        Case row,
        Map<String, FEC_Template__c> templateByApi
    ) {
        List<FEC_Notification.EmailInfo> emails = new List<FEC_Notification.EmailInfo>();
        if (row == null) {
            return emails;
        }

        FEC_CaseDsTsSlaService.SlaEligibilityContext ctx =
            FEC_CaseDsTsSlaService.evaluateEligibility(row);
        if (!ctx.isEligible) {
            return emails;
        }

        List<String> profiles = ctx.activeProfiles != null && !ctx.activeProfiles.isEmpty()
            ? ctx.activeProfiles
            : (String.isNotBlank(ctx.queueProfile)
                ? new List<String>{ ctx.queueProfile }
                : new List<String>());

        for (String queueProfile : profiles) {
            FEC_Notification.EmailInfo info = buildEmailInfoForProfile(
                caseId,
                row,
                queueProfile,
                templateByApi
            );
            if (info != null) {
                emails.add(info);
            }
        }
        return emails;
    }

    @TestVisible
    private static FEC_Notification.EmailInfo buildEmailInfoForProfile(
        Id caseId,
        Case row,
        String queueProfile,
        Map<String, FEC_Template__c> templateByApi
    ) {
        if (String.isBlank(queueProfile)) {
            return null;
        }

        String templateApi = FEC_CaseDsTsSlaService.resolveSlaTemplateApiName(queueProfile);
        if (String.isBlank(templateApi)) {
            return null;
        }

        FEC_Template__c tmpl = templateByApi.get(templateApi);
        if (tmpl == null || String.isBlank(tmpl.FEC_Subject_Line__c)) {
            System.debug(
                'FEC_DEBUG DS/TS SLA: skip case ' + caseId
                    + ' profile=' + queueProfile
                    + ' template=' + templateApi
            );
            return null;
        }

        List<String> toEmails = FEC_CaseDsTsSlaService.resolveRecipientEmails(
            FEC_CaseDsTsSlaService.resolveRecipientUserIdsByProfile(queueProfile)
        );
        if (toEmails.isEmpty()) {
            return null;
        }

        String header = null;
        String footer = null;
        if (tmpl.FEC_Enhanced_Letterhead__r != null) {
            header = tmpl.FEC_Enhanced_Letterhead__r.FEC_Header__c;
            footer = tmpl.FEC_Enhanced_Letterhead__r.FEC_Footer__c;
        }

        return new FEC_Notification.EmailInfo(
            row.Id,
            String.join(toEmails, ','),
            tmpl.FEC_Subject_Line__c,
            header,
            tmpl.FEC_Body__c,
            footer,
            tmpl.Id
        );
    }

    private static Map<String, FEC_Template__c> loadActiveSlaTemplates() {
        Map<String, FEC_Template__c> templateByApi = new Map<String, FEC_Template__c>();
        for (FEC_Template__c t : [
            SELECT Id, FEC_API_Name__c, FEC_Subject_Line__c, FEC_Body__c, FEC_Active__c,
                   FEC_Enhanced_Letterhead__c,
                   FEC_Enhanced_Letterhead__r.FEC_Header__c,
                   FEC_Enhanced_Letterhead__r.FEC_Footer__c
            FROM FEC_Template__c
            WHERE FEC_API_Name__c IN (
                :FEC_CaseDsTsSlaService.TEMPLATE_API_DS,
                :FEC_CaseDsTsSlaService.TEMPLATE_API_TS
            )
              AND FEC_Active__c = true
        ]) {
            if (String.isNotBlank(t.FEC_API_Name__c)) {
                templateByApi.put(t.FEC_API_Name__c, t);
            }
        }
        return templateByApi;
    }

    private static String resolveSenderEmailAddress() {
        Id orgWideId = FEC_CommonUltils.getOrgWideEmailIdForNotification();
        if (orgWideId == null) {
            return '';
        }
        List<OrgWideEmailAddress> orgEmails = [
            SELECT Address
            FROM OrgWideEmailAddress
            WHERE Id = :orgWideId
            LIMIT 1
        ];
        return orgEmails.isEmpty() ? '' : orgEmails[0].Address;
    }

    private static Integer detectNewlyStampedSlot(Case newC, Case oldC) {
        if (newC.FEC_SLA_Notification_1__c != oldC.FEC_SLA_Notification_1__c
            && newC.FEC_SLA_Notification_1__c != null) {
            return 1;
        }
        if (newC.FEC_SLA_Notification_2__c != oldC.FEC_SLA_Notification_2__c
            && newC.FEC_SLA_Notification_2__c != null) {
            return 2;
        }
        if (newC.FEC_SLA_Notification_3__c != oldC.FEC_SLA_Notification_3__c
            && newC.FEC_SLA_Notification_3__c != null) {
            return 3;
        }
        return null;
    }
}
