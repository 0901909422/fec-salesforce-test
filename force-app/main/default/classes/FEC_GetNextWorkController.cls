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
            WHERE Type = :FEC_Constants.QUEUE
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

        Case c = new Case(
            Id = caseId,
            OwnerId = UserInfo.getUserId(),
            FEC_Interaction_View_Mode__c = FEC_Constants.HANDLING,
            FEC_Get_Next_Work__c = true
        );

        update c;
        return c.Id;
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