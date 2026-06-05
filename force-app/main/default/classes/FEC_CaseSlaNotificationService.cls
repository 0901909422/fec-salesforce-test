/**
 * Service xác định người nhận thông báo SLA (bell) theo Category/Sub-Category và lịch sử routing Case.
 */
public without sharing class FEC_CaseSlaNotificationService {

    private static final String SLA_CATEGORY_REQUEST = 'Request';
    private static final String SLA_CATEGORY_INTERNAL_TASK = 'Internal Task';
    private static final String SLA_SUBCATEGORY_CODE_ISL01 = 'ISL01';
    private static final String SLA_SUBCATEGORY_CODE_ISC01 = 'ISC01';
    /** CS Support → User Group SP; CS Customer Care → User Group CC. */
    private static final String SLA_RECIP_USER_GROUP_CS_SUPPORT = FEC_ConstantCommon.RD_ASSESSMENT_TEAM_SP;
    private static final String SLA_RECIP_USER_GROUP_CS_CUSTOMER_CARE = FEC_ConstantCommon.RD_ASSESSMENT_TEAM_CC;
    private static final String SLA_RECIP_ROLE_SENIOR_CC_SPECIALIST = 'Senior Customer Care Specialist';
    private static final String SLA_RECIP_ROLE_CC_MANAGER = 'Customer Care Manager';
    private static final String SLA_RECIP_ROLE_UNIT_HEAD_CC = 'Unit Head of Customer Care';
    private static final String SLA_RECIP_ROLE_SENIOR_CSS_SUPPORT = 'Senior Customer Service Support Specialist';
    private static final String SLA_RECIP_ROLE_UNIT_HEAD_CSS = 'Unit Head of Customer Service Support';
    /**
     * Trường hợp 2: Category = Request hoặc Internal Task.
     */
    public static Boolean isSlaCancelRequestInternalTaskCase(Case c) {
        if (c == null) {
            return false;
        }
        String categoryName = c.FEC_Category__r != null ? c.FEC_Category__r.Name : null;
        if (SLA_CATEGORY_REQUEST.equalsIgnoreCase(categoryName)) {
            return true;
        }
        if (!SLA_CATEGORY_INTERNAL_TASK.equalsIgnoreCase(categoryName)) {
            return false;
        }
        String subCategoryCode = c.FEC_SubCategory__r != null
            ? c.FEC_SubCategory__r.FEC_Code__c
            : null;
        return String.isNotBlank(subCategoryCode) &&
            (
                subCategoryCode.containsIgnoreCase(SLA_SUBCATEGORY_CODE_ISL01) ||
                subCategoryCode.containsIgnoreCase(SLA_SUBCATEGORY_CODE_ISC01)
            );
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
        for (Id caseId : slaCaseById.keySet()) {
            Case slaCase = slaCaseById.get(caseId);
            Boolean isViolating = caseIdToIsViolating != null &&
                caseIdToIsViolating.get(caseId) == true;
            Set<String> performUserIds = caseIdToPerformUserIds.containsKey(caseId)
                ? caseIdToPerformUserIds.get(caseId)
                : new Set<String>();

            Set<String> recipientIds;
            if (isSlaCancelRequestInternalTaskCase(slaCase)) {
                // Trường hợp 2 — Request / Internal Task
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
                    unitHeadCcIds
                );
            }
            caseIdToRecipientIds.put(caseId, deduplicateRecipientIds(recipientIds));
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
        Set<String> unitHeadCcIds
    ) {
        if (isViolating == true) {
            return resolveSlaRecipientsCase1Violating(
                performUserIds,
                performUserById,
                seniorCcManagerIds,
                unitHeadCcIds
            );
        }
        return resolveSlaRecipientsCase1Warning(
            performUserIds,
            performUserById,
            seniorCcSpecialistIds
        );
    }

    /**
     * Trường hợp 1 — Lần 1 (vàng): có perform user User Group CC → user đã xử lý (chỉ CC)
     * + Senior Customer Care Specialist; không có CC → chỉ Senior Customer Care Specialist.
     */
    private static Set<String> resolveSlaRecipientsCase1Warning(
        Set<String> performUserIds,
        Map<Id, User> performUserById,
        Set<String> seniorCcSpecialistIds
    ) {
        Set<String> recipientIds = new Set<String>();
        if (
            hasPerformUserInUserGroup(
                performUserIds,
                performUserById,
                SLA_RECIP_USER_GROUP_CS_CUSTOMER_CARE
            )
        ) {
            mergeRecipientIds(
                recipientIds,
                filterPerformUserIdsByUserGroup(
                    performUserIds,
                    performUserById,
                    SLA_RECIP_USER_GROUP_CS_CUSTOMER_CARE
                )
            );
            mergeRecipientIds(recipientIds, seniorCcSpecialistIds);
        } else {
            mergeRecipientIds(recipientIds, seniorCcSpecialistIds);
        }
        return recipientIds;
    }

    /**
     * Trường hợp 1 — Lần 2 (đỏ): có perform user User Group CC → user đã xử lý (chỉ CC)
     * + Customer Care Manager + Unit Head of Customer Care; không có CC → chỉ hai role trên.
     */
    private static Set<String> resolveSlaRecipientsCase1Violating(
        Set<String> performUserIds,
        Map<Id, User> performUserById,
        Set<String> seniorCcManagerIds,
        Set<String> unitHeadCcIds
    ) {
        Set<String> recipientIds = new Set<String>();
        if (
            hasPerformUserInUserGroup(
                performUserIds,
                performUserById,
                SLA_RECIP_USER_GROUP_CS_CUSTOMER_CARE
            )
        ) {
            mergeRecipientIds(
                recipientIds,
                filterPerformUserIdsByUserGroup(
                    performUserIds,
                    performUserById,
                    SLA_RECIP_USER_GROUP_CS_CUSTOMER_CARE
                )
            );
        }
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
                performUserById,
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
     * Trường hợp 2 — Lần 1 (vàng): có perform user User Group SP → user đã xử lý (chỉ SP);
     * không có SP → role Senior Customer Service Support Specialist.
     */
    private static Set<String> resolveSlaRecipientsCase2Warning(
        Set<String> performUserIds,
        Map<Id, User> performUserById,
        Set<String> seniorCssSupportIds
    ) {
        Set<String> recipientIds = new Set<String>();
        if (
            hasPerformUserInUserGroup(
                performUserIds,
                performUserById,
                SLA_RECIP_USER_GROUP_CS_SUPPORT
            )
        ) {
            mergeRecipientIds(
                recipientIds,
                filterPerformUserIdsByUserGroup(
                    performUserIds,
                    performUserById,
                    SLA_RECIP_USER_GROUP_CS_SUPPORT
                )
            );
        } else {
            mergeRecipientIds(recipientIds, seniorCssSupportIds);
        }
        return recipientIds;
    }

    /**
     * Trường hợp 2 — Lần 2 (đỏ): có perform user User Group SP → user đã xử lý (chỉ SP)
     * + Senior Customer Service Support Specialist + Unit Head of Customer Service Support;
     * không có SP → chỉ hai role trên.
     */
    private static Set<String> resolveSlaRecipientsCase2Violating(
        Set<String> performUserIds,
        Map<Id, User> performUserById,
        Set<String> seniorCssSupportIds,
        Set<String> unitHeadCssIds
    ) {
        Set<String> recipientIds = new Set<String>();
        if (
            hasPerformUserInUserGroup(
                performUserIds,
                performUserById,
                SLA_RECIP_USER_GROUP_CS_SUPPORT
            )
        ) {
            mergeRecipientIds(
                recipientIds,
                filterPerformUserIdsByUserGroup(
                    performUserIds,
                    performUserById,
                    SLA_RECIP_USER_GROUP_CS_SUPPORT
                )
            );
        }
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
            SELECT Id, FEC_User_Group__c
            FROM User
            WHERE Id IN :performUserIds
        ]);
    }

    /** Có ít nhất một perform user có FEC_User_Group__c khớp userGroupCode (vd SP, CC). */
    private static Boolean hasPerformUserInUserGroup(
        Set<String> performUserIds,
        Map<Id, User> performUserById,
        String userGroupCode
    ) {
        if (performUserIds == null || performUserIds.isEmpty() || String.isBlank(userGroupCode)) {
            return false;
        }
        for (String performUserIdStr : performUserIds) {
            User performUser = performUserById.get((Id) performUserIdStr);
            if (
                performUser != null &&
                userGroupMatches(performUser.FEC_User_Group__c, userGroupCode)
            ) {
                return true;
            }
        }
        return false;
    }

    private static Boolean userGroupMatches(String userGroup, String expectedGroup) {
        return String.isNotBlank(userGroup) &&
            String.isNotBlank(expectedGroup) &&
            userGroup.trim().equalsIgnoreCase(expectedGroup.trim());
    }

    /** Perform user trong history có FEC_User_Group__c khớp userGroupCode. */
    private static Set<String> filterPerformUserIdsByUserGroup(
        Set<String> performUserIds,
        Map<Id, User> performUserById,
        String userGroupCode
    ) {
        Set<String> filtered = new Set<String>();
        if (performUserIds == null || performUserIds.isEmpty() || String.isBlank(userGroupCode)) {
            return filtered;
        }
        for (String performUserIdStr : performUserIds) {
            User performUser = performUserById.get((Id) performUserIdStr);
            if (
                performUser != null &&
                userGroupMatches(performUser.FEC_User_Group__c, userGroupCode)
            ) {
                filtered.add(performUserIdStr);
            }
        }
        return filtered;
    }

    private static void mergeRecipientIds(Set<String> target, Set<String> source) {
        if (target == null || source == null || source.isEmpty()) {
            return;
        }
        target.addAll(source);
    }

    /** Lọc trùng Id người nhận (và bỏ blank) trước khi trả kết quả cuối. */
    private static Set<String> deduplicateRecipientIds(Set<String> recipientIds) {
        Set<String> deduped = new Set<String>();
        if (recipientIds == null || recipientIds.isEmpty()) {
            return deduped;
        }
        for (String recipientId : recipientIds) {
            if (String.isNotBlank(recipientId)) {
                deduped.add(recipientId.trim());
            }
        }
        return deduped;
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
}
