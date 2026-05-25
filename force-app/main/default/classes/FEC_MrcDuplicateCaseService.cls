/**
 * RL05.02 — phát hiện Case RL05 đang xử lý trùng hợp đồng (case cũ hơn, cùng số HĐ),
 * banner trên Case Business, và áp Cancel theo FEC_MRC_Request_Handling_Option__c.
 */
public without sharing class FEC_MrcDuplicateCaseService {
    public static final String OPT_CANCEL_PREVIOUS =
        'Cancel previous request, create new request';
    public static final String OPT_CANCEL_NEW =
        'Cancel new request, continue previous request handling';

    public class OpenDupInfo {
        public String caseIdStr;
        public String caseNumber;
    }

    /** Trả Case RL05 đang mở, có CreatedDate nhỏ hơn case hiện tại (cùng hợp đồng). */
    public static OpenDupInfo findOlderOpenRl05DuplicateInfo(
        Id currentCaseId,
        Id customerHistoryId,
        String contractNumberText,
        Datetime currentCreatedDate,
        String subCategoryCode,
        String subCodeCode
    ) {
        Id dupId = findOlderOpenRl05DuplicateId(
            currentCaseId,
            customerHistoryId,
            contractNumberText,
            currentCreatedDate,
            subCategoryCode,
            subCodeCode
        );
        if (dupId == null) {
            return null;
        }
        List<Case> rows = [
            SELECT FEC_ID_Search__c, CaseNumber
            FROM Case
            WHERE Id = :dupId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return null;
        }
        OpenDupInfo out = new OpenDupInfo();
        out.caseIdStr = String.valueOf(dupId);
        out.caseNumber = resolveCaseIdForBanner(rows[0]);
        return out;
    }

    /** Case ID hiển thị Noti-11 — FEC_Case_ID__c (formula) dùng FEC_ID_Search__c làm text. */
    private static String resolveCaseIdForBanner(Case c) {
        if (c == null) {
            return null;
        }
        if (String.isNotBlank(c.FEC_ID_Search__c)) {
            return c.FEC_ID_Search__c.trim();
        }
        return c.CaseNumber;
    }

    public static Id findOlderOpenRl05DuplicateId(
        Id currentCaseId,
        Id customerHistoryId,
        String contractNumberText,
        Datetime currentCreatedDate,
        String subCategoryCode,
        String subCodeCode
    ) {
        if (
            currentCaseId == null ||
            currentCreatedDate == null ||
            String.isBlank(subCodeCode) ||
            !subCodeCode.toUpperCase().contains('RL05.02')
        ) {
            return null;
        }
        if (String.isBlank(subCategoryCode) || !subCategoryCode.toUpperCase().contains('RL05')) {
            return null;
        }
        if (customerHistoryId == null && String.isBlank(contractNumberText)) {
            return null;
        }

        String contractNum = String.isBlank(contractNumberText)
            ? null
            : contractNumberText.trim();
        List<Case> dups;
        if (String.isNotBlank(contractNum)) {
            dups = [
                SELECT Id
                FROM Case
                WHERE
                    FEC_Account_Contract_Number_Text__c = :contractNum
                    AND Id != :currentCaseId
                    AND IsClosed = FALSE
                    AND FEC_SubCategory__r.FEC_Code__c LIKE '%RL05%'
                    AND (
                        FEC_SubCode__r.FEC_Code__c LIKE '%RL05.02%'
                        OR FEC_SubCode__r.Name LIKE '%RL05.02%'
                    )
                    AND FEC_Final_Status__c LIKE 'Pending%'
                    AND CreatedDate < :currentCreatedDate
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        } else {
            dups = [
                SELECT Id
                FROM Case
                WHERE
                    FEC_Account_or_Contract__c = :customerHistoryId
                    AND Id != :currentCaseId
                    AND IsClosed = FALSE
                    AND FEC_SubCategory__r.FEC_Code__c LIKE '%RL05%'
                    AND (
                        FEC_SubCode__r.FEC_Code__c LIKE '%RL05.02%'
                        OR FEC_SubCode__r.Name LIKE '%RL05.02%'
                    )
                    AND FEC_Final_Status__c LIKE 'Pending%'
                    AND CreatedDate < :currentCreatedDate
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        }
        return dups.isEmpty() ? null : dups[0].Id;
    }

    /** After update Case: đổi FEC_MRC_Request_Handling_Option__c → auto-cancel đúng case + remark. */
    public static void applyHandlingOptionChanges(List<Case> newCases, Map<Id, Case> oldMap) {
        if (FEC_CaseTriggerHandler.isSystemUpdate || newCases == null || oldMap == null) {
            return;
        }
        List<Case> candidates = new List<Case>();
        for (Case c : newCases) {
            Case oldC = oldMap.get(c.Id);
            if (oldC == null) {
                continue;
            }
            if (c.FEC_MRC_Request_Handling_Option__c == oldC.FEC_MRC_Request_Handling_Option__c) {
                continue;
            }
            if (String.isBlank(c.FEC_MRC_Request_Handling_Option__c)) {
                continue;
            }
            candidates.add(c);
        }
        if (candidates.isEmpty()) {
            return;
        }

        Set<Id> ids = new Map<Id, Case>(candidates).keySet();
        List<Case> fullRows = [
            SELECT
                Id,
                CaseNumber,
                FEC_ID_Search__c,
                CreatedDate,
                FEC_MRC_Request_Handling_Option__c,
                FEC_Account_or_Contract__c,
                FEC_Account_Contract_Number_Text__c,
                FEC_SubCategory__r.FEC_Code__c,
                FEC_SubCode__r.FEC_Code__c
            FROM Case
            WHERE Id IN :ids
        ];

        List<Case> toCancelStatus = new List<Case>();
        List<FEC_Case_Remarks__c> remarks = new List<FEC_Case_Remarks__c>();

        String emailLocal = emailLocalSafe(UserInfo.getUserEmail());
        String roleName = resolveUserRoleName();

        for (Case c : fullRows) {
            String subCat = c.FEC_SubCategory__r == null
                ? null
                : c.FEC_SubCategory__r.FEC_Code__c;
            String subCod = c.FEC_SubCode__r == null ? null : c.FEC_SubCode__r.FEC_Code__c;
            Id olderDupId = findOlderOpenRl05DuplicateId(
                c.Id,
                c.FEC_Account_or_Contract__c,
                c.FEC_Account_Contract_Number_Text__c,
                c.CreatedDate,
                subCat,
                subCod
            );

            String opt = c.FEC_MRC_Request_Handling_Option__c;
            if (!OPT_CANCEL_PREVIOUS.equals(opt) && !OPT_CANCEL_NEW.equals(opt)) {
                continue;
            }
            if (String.isBlank(subCod) || !subCod.toUpperCase().contains('RL05.02')) {
                continue;
            }
            if (String.isBlank(subCat) || !subCat.toUpperCase().contains('RL05')) {
                continue;
            }

            if (OPT_CANCEL_PREVIOUS.equals(opt)) {
                if (olderDupId == null) {
                    continue;
                }
                toCancelStatus.add(
                    new Case(
                        Id = olderDupId,
                        Status = FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED
                    )
                );
                remarks.add(
                    buildRemark(
                        olderDupId,
                        String.format(
                            System.Label.FEC_MRC_Dup_Remark_Cancel_Prev,
                            new List<String>{ resolveCaseIdForBanner(c) }
                        ),
                        emailLocal,
                        roleName
                    )
                );
            } else if (OPT_CANCEL_NEW.equals(opt)) {
                String olderNum = FEC_ConstantCommon.STR_EMPTY;
                if (olderDupId != null) {
                    List<Case> peerLst = [
                        SELECT FEC_ID_Search__c, CaseNumber
                        FROM Case
                        WHERE Id = :olderDupId
                        LIMIT 1
                    ];
                    if (!peerLst.isEmpty()) {
                        olderNum = resolveCaseIdForBanner(peerLst[0]);
                        if (olderNum == null) {
                            olderNum = FEC_ConstantCommon.STR_EMPTY;
                        }
                    }
                }
                toCancelStatus.add(
                    new Case(Id = c.Id, Status = FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED)
                );
                remarks.add(
                    buildRemark(
                        c.Id,
                        String.format(
                            System.Label.FEC_MRC_Dup_Remark_Cancel_New,
                            new List<String>{ olderNum }
                        ),
                        emailLocal,
                        roleName
                    )
                );
            }
        }

        if (toCancelStatus.isEmpty()) {
            return;
        }

        try {
            FEC_CaseTriggerHandler.isSystemUpdate = true;
            Database.update(toCancelStatus, AccessLevel.USER_MODE);
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'FEC_MrcDuplicateCaseService: update cancelled cases failed — ' + e.getMessage()
            );
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = false;
        }

        if (!remarks.isEmpty()) {
            try {
                insert remarks;
            } catch (Exception e) {
                System.debug(
                    LoggingLevel.ERROR,
                    'FEC_MrcDuplicateCaseService: insert remarks failed — ' + e.getMessage()
                );
            }
        }
    }

    private static FEC_Case_Remarks__c buildRemark(
        Id caseId,
        String body,
        String emailLocal,
        String roleName
    ) {
        FEC_Case_Remarks__c r = new FEC_Case_Remarks__c();
        r.FEC_Case__c = caseId;
        r.FEC_Case_Remarks__c = body;
        r.FEC_User__c = emailLocal;
        r.FEC_User_Role__c = roleName;
        return r;
    }

    private static String emailLocalSafe(String email) {
        if (String.isBlank(email) || !email.contains('@')) {
            return email;
        }
        return email.substring(0, email.indexOf('@'));
    }

    private static String resolveUserRoleName() {
        Id rid = UserInfo.getUserRoleId();
        if (rid == null) {
            return null;
        }
        List<UserRole> rl = [
            SELECT Name
            FROM UserRole
            WHERE Id = :rid
            LIMIT 1
        ];
        return rl.isEmpty() ? null : rl[0].Name;
    }
}
