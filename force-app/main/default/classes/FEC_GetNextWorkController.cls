/****************************************************************************************
 * File Name    : FEC_GetNextWorkController
 * Author       : Quangdv7
 * Date         : 2025-12-07
 * Description  : Call data object Case and Queue
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-12-07     Quangdv7             Create
 
****************************************************************************************/

public without sharing class FEC_GetNextWorkController {
    public static Boolean isGetNextWork = false;

    @AuraEnabled(cacheable=true)

   /**
    * @description getAllUserQueues
    * @Date 2025/12/07
    * @param null
    * @return List options
    */
    public static List<Option> getAllUserQueues() {
        Id currentUserId = UserInfo.getUserId();

        Set<Id> memberIds = new Set<Id>();
        memberIds.add(currentUserId);

        for (GroupMember gm : [
            SELECT GroupId
            FROM GroupMember
            WHERE UserOrGroupId = :currentUserId
        ]) {
            memberIds.add(gm.GroupId);
        }

        User u = [
            SELECT UserRoleId
            FROM User
            WHERE Id = :currentUserId
            LIMIT 1
        ];

        if (u.UserRoleId != null) {

            for (Group roleGroup : [
                SELECT Id
                FROM Group
                WHERE RelatedId = :u.UserRoleId
            ]) {
                memberIds.add(roleGroup.Id);
            }
        }

         List<Group> queues = [
            SELECT Id, Name
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            AND Id IN (
                SELECT GroupId
                FROM GroupMember
                WHERE UserOrGroupId IN :memberIds
            )
            ORDER BY Name ASC
        ];

        List<Option> options = new List<Option>();
        for (Group q : queues) {
            options.add(new Option(q.Name, q.Id));
        }
        return options;
    }

    /**
    * @description getOldestCase
    * @Date 2025/12/07
    * @param queueId
    * @return static Id
    */
    @AuraEnabled
    public static Id getOldestCase(Id queueId) {
        if (queueId == null) {
            return null;
        }

        List<Case> cases = [
            SELECT Id, FEC_Case_Created_On__c, OwnerId, RecordType.DeveloperName, CreatedDate
            FROM Case
            WHERE OwnerId = :queueId
            AND RecordType.DeveloperName IN (:FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME, :FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)
            AND Status NOT IN (
                :FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED,
                :FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED,
                :FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED,
                :FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANNOT_CONTACT_CUSTOMER,
                :FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED
            )
            AND (
                FEC_Assignment_Count__c = null
                OR FEC_Assignment_Count__c = 0
            )
            ORDER BY FEC_Case_Created_On__c ASC NULLS LAST, CreatedDate ASC
            LIMIT 1
        ];

        Case th1Case = cases.isEmpty() ? null : cases[0];
        Case th2Case = findOldestCaseWithQueueAssignment(queueId);
        if (th1Case == null) {
            return th2Case != null ? th2Case.Id : null;
        }
        if (th2Case == null) {
            return th1Case.Id;
        }
        return isCaseOlder(th1Case, th2Case) ? th1Case.Id : th2Case.Id;
    }

    /**
    * @description takeOwnership
    * @Date 2025/12/07
    * @param caseId
    * @param queueId
    * @return static Id
    */
    @AuraEnabled
    public static Id takeOwnership(Id caseId, Id queueId) {
        if (caseId == null) return null;
        List<Case> countCheck = [
            SELECT FEC_Assignment_Count__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (
            !countCheck.isEmpty()
            && countCheck[0].FEC_Assignment_Count__c != null
            && countCheck[0].FEC_Assignment_Count__c > 0
            && queueId != null
        ) {
            return takeAssignmentOwnership(caseId, queueId);
        }

        isGetNextWork = true;
        Id currentUserId = UserInfo.getUserId();

        User u = [
            SELECT Email, UserRole.Name
            FROM User
            WHERE Id = :currentUserId
            LIMIT 1
        ];

        Case c = new Case(
            Id = caseId,
            OwnerId = UserInfo.getUserId(),
            FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE,
            FEC_Get_Next_Work__c = true
        );

        Case oldCase = [
            SELECT Id, OwnerId, Owner.Name, FEC_Team__c,
                    FEC_Current_Case_Stage__r.FEC_Code__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        try {
            
            isGetNextWork = true; 
            update c;           

            FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
                FEC_Case__c = caseId,
                FEC_Routing_Action__c = FEC_ConstantCommon.CASE_TYPE_DESCRIPTION,
                FEC_Decision__c = FEC_ConstantCommon.STR_EMPTY,
                FEC_Original_User_Queue__c = oldCase.Owner.Name,
                FEC_Updated_User_Queue__c = FEC_CommonUltils.getEmailPrefix(u.Email),
                FEC_Stage_Name__c = oldCase.FEC_Current_Case_Stage__r != null 
                    ? oldCase.FEC_Current_Case_Stage__r.FEC_Code__c 
                    : null,
                FEC_User__c = FEC_CommonUltils.getEmailPrefix(u.Email),
                FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null,
                FEC_Original_User_Queue_ID__c = oldCase.OwnerId,
                FEC_Updated_User_Queue_ID__c = currentUserId,
                FEC_Description__c = FEC_ConstantCommon.CASE_TYPE_DESCRIPTION
            );
            insert history;

            return c.Id;

        } finally {
            isGetNextWork = false; 
        }
    }

    private static Case findOldestCaseWithQueueAssignment(Id queueId) {
        List<Group> queues = [
            SELECT Name
            FROM Group
            WHERE Id = :queueId
            AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            LIMIT 1
        ];
        if (queues.isEmpty()) {
            return null;
        }

        String queueName = queues[0].Name;
        Set<Id> caseIds = new Set<Id>();
        for (FEC_Assignment__c a : [
            SELECT FEC_Case__c
            FROM FEC_Assignment__c
            WHERE FEC_Assignment_Owner_Text__c = :queueName
            AND FEC_Assignment_Status__c != :FEC_ConstantCommon.STATUS_COMPLETED
            AND FEC_Case__c != null
        ]) {
            caseIds.add(a.FEC_Case__c);
        }
        if (caseIds.isEmpty()) {
            return null;
        }

        List<Case> cases = [
            SELECT Id, FEC_Case_Created_On__c, CreatedDate
            FROM Case
            WHERE Id IN :caseIds
            AND RecordType.DeveloperName IN (
                :FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME,
                :FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME
            )
            AND Status NOT IN (
                :FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED,
                :FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED,
                :FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED,
                :FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANNOT_CONTACT_CUSTOMER,
                :FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED
            )
            AND FEC_Assignment_Count__c > 0
            ORDER BY FEC_Case_Created_On__c ASC NULLS LAST, CreatedDate ASC
            LIMIT 1
        ];

        return cases.isEmpty() ? null : cases[0];
    }

    private static Id takeAssignmentOwnership(Id caseId, Id queueId) {
        isGetNextWork = true;
        Id currentUserId = UserInfo.getUserId();
        User u = [
            SELECT Email, UserRole.Name
            FROM User
            WHERE Id = :currentUserId
            LIMIT 1
        ];

        List<Group> queues = [
            SELECT Id, Name
            FROM Group
            WHERE Id = :queueId
            AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            LIMIT 1
        ];
        if (queues.isEmpty()) {
            return null;
        }
        Group queue = queues[0];

        List<FEC_Assignment__c> assignments = [
            SELECT Id
            FROM FEC_Assignment__c
            WHERE FEC_Case__c = :caseId
            AND FEC_Assignment_Owner_Text__c = :queue.Name
            AND FEC_Assignment_Status__c != :FEC_ConstantCommon.STATUS_COMPLETED
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        if (assignments.isEmpty()) {
            return null;
        }

        Case oldCase = [
            SELECT Id, FEC_Current_Case_Stage__r.FEC_Code__c, Status
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        String statusBefore = oldCase.Status;

        try {
            isGetNextWork = true;
            update new FEC_Assignment__c(
                Id = assignments[0].Id,
                FEC_Assignment_Owner__c = currentUserId
            );
            update new Case(
                Id = caseId,
                FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE,
                FEC_Get_Next_Work__c = true
            );

            Case endCase = [
                SELECT Status
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
                FEC_Case__c = caseId,
                FEC_Assignment__c = assignments[0].Id,
                FEC_Routing_Action__c = FEC_ConstantCommon.CASE_TYPE_DESCRIPTION,
                FEC_Routing_Action_Type__c = FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
                FEC_Decision__c = FEC_ConstantCommon.CASE_TYPE_DESCRIPTION,
                FEC_Original_User_Queue__c = queue.Name,
                FEC_Updated_User_Queue__c = FEC_CommonUltils.getEmailPrefix(u.Email),
                FEC_Stage_Name__c = oldCase.FEC_Current_Case_Stage__r != null
                    ? oldCase.FEC_Current_Case_Stage__r.FEC_Code__c
                    : null,
                FEC_User__c = FEC_CommonUltils.getEmailPrefix(u.Email),
                FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null,
                FEC_Original_User_Queue_ID__c = queueId,
                FEC_Updated_User_Queue_ID__c = currentUserId,
                FEC_Current_Status__c = statusBefore,
                FEC_Changed_Status__c = endCase.Status
            );

            insert history;
            return caseId;
        } finally {
            isGetNextWork = false; 
        }
    }

    private static Boolean isCaseOlder(Case a, Case b) {
        if (a.FEC_Case_Created_On__c != null && b.FEC_Case_Created_On__c != null) {
            if (a.FEC_Case_Created_On__c != b.FEC_Case_Created_On__c) {
                return a.FEC_Case_Created_On__c < b.FEC_Case_Created_On__c;
            }
        } else if (a.FEC_Case_Created_On__c != null) {
            return true;
        } else if (b.FEC_Case_Created_On__c != null) {
            return false;
        }
        return a.CreatedDate < b.CreatedDate;
    }

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public Option(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
}