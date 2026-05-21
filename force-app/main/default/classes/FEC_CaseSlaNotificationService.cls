/**
 * Service xác định người nhận thông báo SLA (bell) theo Category/Sub-Category và lịch sử routing Case.
 */
public without sharing class FEC_CaseSlaNotificationService {

    private static final String SLA_CATEGORY_REQUEST = 'Request';
    private static final String SLA_CATEGORY_INTERNAL_TASK = 'Internal Task';
    private static final String SLA_SUBCODE_ISL01 = 'ISL01';
    private static final String SLA_SUBCODE_ISC01 = 'ISC01';
    private static final String SLA_RECIP_QUEUE_CS_CUSTOMER_CARE = 'CS_Customer_Care';
    private static final String SLA_RECIP_QUEUE_CS_SUPPORT = 'CS_Support';
    private static final String SLA_RECIP_ROLE_SENIOR_CC_SPECIALIST = 'Senior Customer Care Specialist';
    private static final String SLA_RECIP_ROLE_CC_MANAGER = 'Customer Care Manager';
    private static final String SLA_RECIP_ROLE_UNIT_HEAD_CC = 'Unit Head of Customer Care';
    private static final String SLA_RECIP_ROLE_SENIOR_CSS_SUPPORT = 'Senior Customer Service Support Specialist';
    private static final String SLA_RECIP_ROLE_UNIT_HEAD_CSS = 'Unit Head of Customer Service Support';
    /** Trường hợp 1 — Lần 1: bổ sung Senior CC (email) khi có CS Customer Care trong history. */
    private static final List<String> SLA_CASE1_WARN_EXTRA_SENIOR_CC_EMAILS = new List<String>{
        'nhu.ho@fecredit.com.vn',
        'dien.pham.1@fecredit.com.vn',
        'dung.van.1@fecredit.com.vn',
        'dung.luu.1@fecredit.com.vn'
    };

    /**
     * Trường hợp 2: Category = Request / Internal Task và Sub-Code ISL01 hoặc ISC01 (Hủy yêu cầu).
     */
    public static Boolean isSlaCancelRequestInternalTaskCase(Case c) {
        if (c == null) {
            return false;
        }
        String categoryName = c.FEC_Category__r != null ? c.FEC_Category__r.Name : null;
        String subCategoryCode = c.FEC_SubCategory__r != null
            ? c.FEC_SubCategory__r.FEC_Code__c
            : null;
        Boolean isRequestOrInternalTask =
            SLA_CATEGORY_REQUEST.equalsIgnoreCase(categoryName) ||
            SLA_CATEGORY_INTERNAL_TASK.equalsIgnoreCase(categoryName);
        Boolean isCancelSubCode =
            SLA_SUBCODE_ISL01.equalsIgnoreCase(subCategoryCode) ||
            SLA_SUBCODE_ISC01.equalsIgnoreCase(subCategoryCode);
        return isRequestOrInternalTask && isCancelSubCode;
    }

    /**
     * Quét FEC_Routing_Action_History__c (distinct Perform User) rồi áp rule II theo từng Case.
     */
    public static Map<Id, Set<String>> buildSlaNotificationRecipientsByCase(
        Map<Id, Case> slaCaseById,
        Map<Id, Boolean> caseIdToIsViolating
    ) {
        Map<Id, Set<String>> caseIdToPerformUserIds = buildCaseIdToPerformUserIdsFromRoutingHistory(
            slaCaseById.keySet()
        );
        Map<Id, Set<String>> caseIdToRecipientIds = new Map<Id, Set<String>>();

        Set<Id> allPerformUserIds = collectAllPerformUserIds(caseIdToPerformUserIds);
        Map<Id, User> performUserById = queryPerformUsersById(allPerformUserIds);

        Set<String> seniorCcSpecialistIds = queryActiveUserRecipientIdsByRoleFragment(
            SLA_RECIP_ROLE_SENIOR_CC_SPECIALIST
        );
        Set<String> seniorCcManagerIds = queryActiveUserRecipientIdsByRoleFragment(
            SLA_RECIP_ROLE_CC_MANAGER
        );
        Set<String> unitHeadCcIds = queryActiveUserRecipientIdsByRoleFragment(
            SLA_RECIP_ROLE_UNIT_HEAD_CC
        );
        Set<String> seniorCssSupportIds = queryActiveUserRecipientIdsByRoleFragment(
            SLA_RECIP_ROLE_SENIOR_CSS_SUPPORT
        );
        Set<String> unitHeadCssIds = queryActiveUserRecipientIdsByRoleFragment(
            SLA_RECIP_ROLE_UNIT_HEAD_CSS
        );
        Set<String> case1WarnExtraSeniorCcIds = queryActiveUserRecipientIdsByEmails(
            SLA_CASE1_WARN_EXTRA_SENIOR_CC_EMAILS
        );

        for (Id caseId : slaCaseById.keySet()) {
            Case slaCase = slaCaseById.get(caseId);
            Boolean isViolating = caseIdToIsViolating != null &&
                caseIdToIsViolating.get(caseId) == true;
            Set<String> performUserIds = caseIdToPerformUserIds.containsKey(caseId)
                ? caseIdToPerformUserIds.get(caseId)
                : new Set<String>();

            Set<String> recipientIds;
            if (isSlaCancelRequestInternalTaskCase(slaCase)) {
                // Trường hợp 2 — Request/Internal Task + ISL01/ISC01
                recipientIds = resolveSlaRecipientsCase2CancelRequest(
                    performUserIds,
                    performUserById,
                    isViolating,
                    seniorCssSupportIds,
                    unitHeadCssIds
                );
            } else {
                // Trường hợp 1 — các Case còn lại
                recipientIds = resolveSlaRecipientsCase1Remaining(
                    performUserIds,
                    performUserById,
                    isViolating,
                    seniorCcSpecialistIds,
                    seniorCcManagerIds,
                    unitHeadCcIds,
                    case1WarnExtraSeniorCcIds
                );
            }
            caseIdToRecipientIds.put(caseId, recipientIds);
        }
        return caseIdToRecipientIds;
    }

    /** Trường hợp 1 — phân nhánh Lần 1 (vàng) / Lần 2 (đỏ). */
    private static Set<String> resolveSlaRecipientsCase1Remaining(
        Set<String> performUserIds,
        Map<Id, User> performUserById,
        Boolean isViolating,
        Set<String> seniorCcSpecialistIds,
        Set<String> seniorCcManagerIds,
        Set<String> unitHeadCcIds,
        Set<String> case1WarnExtraSeniorCcIds
    ) {
        if (isViolating == true) {
            return resolveSlaRecipientsCase1Violating(
                performUserIds,
                seniorCcManagerIds,
                unitHeadCcIds
            );
        }
        return resolveSlaRecipientsCase1Warning(
            performUserIds,
            performUserById,
            seniorCcSpecialistIds,
            case1WarnExtraSeniorCcIds
        );
    }

    /**
     * Trường hợp 1 — Lần 1 (vàng): có CS Customer Care trong history → tất cả user đã xử lý
     * + 4 email Senior CC; không có CS Customer Care → role Senior Customer Care Specialist.
     */
    private static Set<String> resolveSlaRecipientsCase1Warning(
        Set<String> performUserIds,
        Map<Id, User> performUserById,
        Set<String> seniorCcSpecialistIds,
        Set<String> case1WarnExtraSeniorCcIds
    ) {
        Set<String> recipientIds = new Set<String>();
        if (
            hasPerformUserInMainQueue(
                performUserIds,
                performUserById,
                SLA_RECIP_QUEUE_CS_CUSTOMER_CARE
            ) ||
            hasPerformUserInMainQueue(performUserIds, performUserById, 'CS Customer Care')
        ) {
            mergeRecipientIds(recipientIds, performUserIds);
            mergeRecipientIds(recipientIds, case1WarnExtraSeniorCcIds);
        } else {
            mergeRecipientIds(recipientIds, seniorCcSpecialistIds);
        }
        return recipientIds;
    }

    /**
     * Trường hợp 1 — Lần 2 (đỏ): tất cả user đã xử lý + Customer Care Manager
     * + Unit Head of Customer Care (không dùng role CS Support).
     */
    private static Set<String> resolveSlaRecipientsCase1Violating(
        Set<String> performUserIds,
        Set<String> seniorCcManagerIds,
        Set<String> unitHeadCcIds
    ) {
        Set<String> recipientIds = new Set<String>();
        mergeRecipientIds(recipientIds, performUserIds);
        mergeRecipientIds(recipientIds, seniorCcManagerIds);
        mergeRecipientIds(recipientIds, unitHeadCcIds);
        return recipientIds;
    }

    /** Trường hợp 2 — phân nhánh Lần 1 (vàng) / Lần 2 (đỏ). */
    private static Set<String> resolveSlaRecipientsCase2CancelRequest(
        Set<String> performUserIds,
        Map<Id, User> performUserById,
        Boolean isViolating,
        Set<String> seniorCssSupportIds,
        Set<String> unitHeadCssIds
    ) {
        if (isViolating == true) {
            return resolveSlaRecipientsCase2Violating(
                performUserIds,
                seniorCssSupportIds,
                unitHeadCssIds
            );
        }
        return resolveSlaRecipientsCase2Warning(
            performUserIds,
            performUserById,
            seniorCssSupportIds
        );
    }

    /**
     * Trường hợp 2 — Lần 1 (vàng): có CS Support trong history → tất cả user đã xử lý;
     * không có → role Senior Customer Service Support Specialist.
     */
    private static Set<String> resolveSlaRecipientsCase2Warning(
        Set<String> performUserIds,
        Map<Id, User> performUserById,
        Set<String> seniorCssSupportIds
    ) {
        Set<String> recipientIds = new Set<String>();
        if (
            hasPerformUserInMainQueue(performUserIds, performUserById, SLA_RECIP_QUEUE_CS_SUPPORT) ||
            hasPerformUserInMainQueue(performUserIds, performUserById, 'CS Support')
        ) {
            mergeRecipientIds(recipientIds, performUserIds);
        } else {
            mergeRecipientIds(recipientIds, seniorCssSupportIds);
        }
        return recipientIds;
    }

    /**
     * Trường hợp 2 — Lần 2 (đỏ): tất cả user đã xử lý + Senior Customer Service Support Specialist
     * + Unit Head of Customer Service Support (không dùng Customer Care Manager / Unit Head CC).
     */
    private static Set<String> resolveSlaRecipientsCase2Violating(
        Set<String> performUserIds,
        Set<String> seniorCssSupportIds,
        Set<String> unitHeadCssIds
    ) {
        Set<String> recipientIds = new Set<String>();
        mergeRecipientIds(recipientIds, performUserIds);
        mergeRecipientIds(recipientIds, seniorCssSupportIds);
        mergeRecipientIds(recipientIds, unitHeadCssIds);
        return recipientIds;
    }

    private static Map<Id, Set<String>> buildCaseIdToPerformUserIdsFromRoutingHistory(
        Set<Id> caseIds
    ) {
        Map<Id, Set<String>> caseIdToPerformUserIds = new Map<Id, Set<String>>();
        if (caseIds == null || caseIds.isEmpty()) {
            return caseIdToPerformUserIds;
        }
        for (FEC_Routing_Action_History__c history : [
            SELECT FEC_Case__c, FEC_Perform_User__c
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c IN :caseIds AND FEC_Perform_User__c != NULL
        ]) {
            if (!caseIdToPerformUserIds.containsKey(history.FEC_Case__c)) {
                caseIdToPerformUserIds.put(history.FEC_Case__c, new Set<String>());
            }
            caseIdToPerformUserIds.get(history.FEC_Case__c)
                .add(String.valueOf(history.FEC_Perform_User__c));
        }
        return caseIdToPerformUserIds;
    }

    private static Set<Id> collectAllPerformUserIds(
        Map<Id, Set<String>> caseIdToPerformUserIds
    ) {
        Set<Id> allPerformUserIds = new Set<Id>();
        if (caseIdToPerformUserIds == null) {
            return allPerformUserIds;
        }
        for (Set<String> performUserIdStrs : caseIdToPerformUserIds.values()) {
            if (performUserIdStrs == null) {
                continue;
            }
            for (String performUserIdStr : performUserIdStrs) {
                if (String.isNotBlank(performUserIdStr)) {
                    allPerformUserIds.add((Id) performUserIdStr);
                }
            }
        }
        return allPerformUserIds;
    }

    private static Map<Id, User> queryPerformUsersById(Set<Id> performUserIds) {
        if (performUserIds == null || performUserIds.isEmpty()) {
            return new Map<Id, User>();
        }
        return new Map<Id, User>([
            SELECT
                Id,
                Division,
                UserRole.Name,
                FEC_Main_Queue__c,
                FEC_User_Group__c,
                FEC_User_Division_Group__c
            FROM User
            WHERE Id IN :performUserIds
        ]);
    }

    /** User Perform có FEC_Main_Queue__c chứa queueFragment (vd CS_Customer_Care, CS_Support). */
    private static Boolean hasPerformUserInMainQueue(
        Set<String> performUserIds,
        Map<Id, User> performUserById,
        String queueFragment
    ) {
        if (performUserIds == null || performUserIds.isEmpty()) {
            return false;
        }
        for (String performUserIdStr : performUserIds) {
            User performUser = performUserById.get((Id) performUserIdStr);
            if (
                performUser != null &&
                userMainQueueContainsFragment(performUser.FEC_Main_Queue__c, queueFragment)
            ) {
                return true;
            }
        }
        return false;
    }

    private static Boolean userMainQueueContainsFragment(String mainQueue, String queueFragment) {
        return String.isNotBlank(mainQueue) &&
            String.isNotBlank(queueFragment) &&
            mainQueue.contains(queueFragment);
    }

    private static void mergeRecipientIds(Set<String> target, Set<String> source) {
        if (target == null || source == null || source.isEmpty()) {
            return;
        }
        target.addAll(source);
    }

    private static Set<String> queryActiveUserRecipientIdsByRoleFragment(String roleNameFragment) {
        Set<String> recipientIds = new Set<String>();
        if (String.isBlank(roleNameFragment)) {
            return recipientIds;
        }
        for (User u : [
            SELECT Id
            FROM User
            WHERE
                IsActive = TRUE
                AND UserRoleId != NULL
                AND UserRole.Name LIKE :('%' + roleNameFragment + '%')
        ]) {
            recipientIds.add(String.valueOf(u.Id));
        }
        return recipientIds;
    }

    private static Set<String> queryActiveUserRecipientIdsByEmails(List<String> emails) {
        Set<String> recipientIds = new Set<String>();
        if (emails == null || emails.isEmpty()) {
            return recipientIds;
        }
        List<String> activeEmails = new List<String>();
        for (String email : emails) {
            if (String.isNotBlank(email)) {
                activeEmails.add(email.trim());
            }
        }
        if (activeEmails.isEmpty()) {
            return recipientIds;
        }
        for (User u : [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Email IN :activeEmails
        ]) {
            recipientIds.add(String.valueOf(u.Id));
        }
        return recipientIds;
    }
}
