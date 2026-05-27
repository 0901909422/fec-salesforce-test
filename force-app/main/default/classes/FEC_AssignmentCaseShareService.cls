/**
 * Chia sẻ Case cho User khi FEC_Assignment__c.FEC_Assignment_Owner__c được gán User Id.
 */
public without sharing class FEC_AssignmentCaseShareService {

    private static final String CASE_ACCESS_EDIT = 'Edit';

    @TestVisible
    private static List<Database.Error> lastShareErrors = new List<Database.Error>();

    @TestVisible
    public static List<Database.Error> getLastShareErrorsForTest() {
        return lastShareErrors;
    }

    /**
     * @param assignments Bản ghi assignment (cần FEC_Case__c, FEC_Assignment_Owner__c).
     */
    public static void shareCasesForAssignments(List<FEC_Assignment__c> assignments) {
        if (assignments == null || assignments.isEmpty()) {
            return;
        }

        Map<Id, Set<Id>> caseIdToUserIds = new Map<Id, Set<Id>>();
        for (FEC_Assignment__c a : assignments) {
            Id caseId = a.FEC_Case__c;
            Id userId = a.FEC_Assignment_Owner__c;
            if (caseId == null || userId == null || !isUserId(userId)) {
                continue;
            }
            if (!caseIdToUserIds.containsKey(caseId)) {
                caseIdToUserIds.put(caseId, new Set<Id>());
            }
            caseIdToUserIds.get(caseId).add(userId);
        }

        if (!caseIdToUserIds.isEmpty()) {
            shareCasesWithUsers(caseIdToUserIds);
        }
    }

    public static void shareCaseWithUser(Id caseId, Id userId) {
        if (caseId == null || userId == null || !isUserId(userId)) {
            return;
        }
        shareCasesWithUsers(new Map<Id, Set<Id>>{ caseId => new Set<Id>{ userId } });
    }

    private static void shareCasesWithUsers(Map<Id, Set<Id>> caseIdToUserIds) {
        lastShareErrors = new List<Database.Error>();

        Set<Id> caseIds = caseIdToUserIds.keySet();
        Set<Id> allUserIds = new Set<Id>();
        for (Set<Id> userIds : caseIdToUserIds.values()) {
            allUserIds.addAll(userIds);
        }

        Map<Id, Case> casesById = new Map<Id, Case>(
            [SELECT Id, OwnerId FROM Case WHERE Id IN :caseIds]
        );

        Set<String> existingShareKeys = new Set<String>();
        for (CaseShare cs : [
            SELECT CaseId, UserOrGroupId
            FROM CaseShare
            WHERE CaseId IN :caseIds AND UserOrGroupId IN :allUserIds
        ]) {
            existingShareKeys.add(shareKey(cs.CaseId, cs.UserOrGroupId));
        }

        Map<Id, List<CaseShare>> sharesByCaseOwnerId = new Map<Id, List<CaseShare>>();
        for (Id caseId : caseIdToUserIds.keySet()) {
            Case c = casesById.get(caseId);
            if (c == null) {
                continue;
            }
            Id caseOwnerId = c.OwnerId;
            if (!sharesByCaseOwnerId.containsKey(caseOwnerId)) {
                sharesByCaseOwnerId.put(caseOwnerId, new List<CaseShare>());
            }

            for (Id userId : caseIdToUserIds.get(caseId)) {
                if (userId == caseOwnerId) {
                    continue;
                }
                if (existingShareKeys.contains(shareKey(caseId, userId))) {
                    continue;
                }
                sharesByCaseOwnerId.get(caseOwnerId).add(
                    new CaseShare(
                        CaseId = caseId,
                        UserOrGroupId = userId,
                        CaseAccessLevel = CASE_ACCESS_EDIT,
                        RowCause = Schema.CaseShare.RowCause.Manual
                    )
                );
            }
        }

        for (Id caseOwnerId : sharesByCaseOwnerId.keySet()) {
            List<CaseShare> batch = sharesByCaseOwnerId.get(caseOwnerId);
            if (batch.isEmpty()) {
                continue;
            }
            insertSharesAsCaseOwner(caseOwnerId, batch);
        }
    }

    private static void insertSharesAsCaseOwner(Id caseOwnerId, List<CaseShare> shares) {
        if (caseOwnerId == null || shares == null || shares.isEmpty()) {
            return;
        }

        recordInsertResults(Database.insert(shares, false));
    }

    private static void recordInsertResults(List<Database.SaveResult> results) {
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                lastShareErrors.addAll(results[i].getErrors());
                System.debug(
                    LoggingLevel.ERROR,
                    'FEC_AssignmentCaseShareService share failed: ' +
                        results[i].getErrors()[0].getStatusCode() +
                        ' — ' +
                        results[i].getErrors()[0].getMessage()
                );
            }
        }
    }

    private static Boolean isUserId(Id recordId) {
        return recordId != null && recordId.getSObjectType() == User.SObjectType;
    }

    private static String shareKey(Id caseId, Id userOrGroupId) {
        return String.valueOf(caseId) + '|' + String.valueOf(userOrGroupId);
    }
}