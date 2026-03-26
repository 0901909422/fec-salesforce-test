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
            SELECT Id, CreatedDate, OwnerId, RecordType.DeveloperName
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
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        return cases.isEmpty() ? null : cases[0].Id;
    }

    /**
    * @description takeOwnership
    * @Date 2025/12/07
    * @param caseId
    * @return static Id
    */
    @AuraEnabled
    public static Id takeOwnership(Id caseId) {
        if (caseId == null) return null;

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

        update c;

        // Create history record
        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c();
        history.FEC_Case__c = caseId;
        history.FEC_Routing_Action__c = FEC_ConstantCommon.CASE_ROUTING_ACTION;
        history.FEC_Decision__c = '';
        history.FEC_Original_User_Queue__c = oldCase.Owner.Name;
        history.FEC_Updated_User_Queue__c = FEC_CommonUltils.getEmailPrefix(u.Email);
        history.FEC_Stage_Name__c = oldCase.FEC_Current_Case_Stage__r != null 
             ? oldCase.FEC_Current_Case_Stage__r.FEC_Code__c 
            : null;
        history.FEC_User__c = FEC_CommonUltils.getEmailPrefix(u.Email);
        history.FEC_User_Role__c = u.UserRole != null ? u.UserRole.Name : null;
        history.FEC_Original_User_Queue_ID__c = oldCase.OwnerId;
        history.FEC_Updated_User_Queue_ID__c = currentUserId;
        history.FEC_Description__c = FEC_ConstantCommon.CASE_TYPE_DESCRIPTION;
        insert history;

        updateCaseTeamFromLatestHistory(caseId);
        
        return c.Id;
    }

    private static void updateCaseTeamFromLatestHistory(Id caseId) {
        if (caseId == null) return;

        List<FEC_Routing_Action_History__c> histories = [
            SELECT Id,
                FEC_Original_User_Queue_ID__c,
                FEC_Updated_User_Queue_ID__c,
                CreatedDate
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :caseId
            AND FEC_Routing_Action__c = :FEC_ConstantCommon.CASE_ROUTING_ACTION
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (histories.isEmpty()) return;

        FEC_Routing_Action_History__c latest = histories[0];

        Case caseRecord = [
            SELECT Id, FEC_Team__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        FEC_RoutingActionHistoryTriggerHandler.updateCaseTeams(
            latest.FEC_Original_User_Queue_ID__c,
            latest.FEC_Updated_User_Queue_ID__c,
            caseRecord
        );

        update caseRecord;
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