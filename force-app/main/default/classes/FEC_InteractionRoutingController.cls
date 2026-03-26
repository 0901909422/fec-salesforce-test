/**
 * Class Description: Controller class to expose Routing assignments for Email Interactions to LWC
 * @created  : 2026/03/11
 */
public without sharing class FEC_InteractionRoutingController {

    @AuraEnabled
    public static void executeRoutingAssignments() {
        try {
            Id interactionRtId = FEC_CommonUltils.getRecordTypeIdByDev(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);
            if (interactionRtId == null) {
                return;
            }

            // Validate the current user has the proper Email routing skill
            Datetime rightnow = system.now();
            List<ServiceResourceSkill> currentUserSkills = [
                SELECT Id 
                FROM ServiceResourceSkill 
                WHERE ServiceResource.RelatedRecordId = :UserInfo.getUserId()
                AND Skill.DeveloperName = :System.Label.FEC_Ubank_Skill_DevName
                AND FEC_Active__c = true 
                AND EffectiveStartDate <= :rightnow 
                AND (EffectiveEndDate >= :rightnow OR EffectiveEndDate = NULL)
                LIMIT 1
            ];

            if (currentUserSkills.isEmpty()) {
                return;
            }

            // Lấy Queue
            List<Group> queueGrouplst = [
                SELECT Id
                FROM Group
                WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
                AND DeveloperName = :System.Label.FEC_Ubank_Email_DevName
                LIMIT 1
            ];

            if(queueGrouplst.isEmpty()) return;
            Id queueId = queueGrouplst.get(0).Id;

            List<Case> casesToRoute = [
                SELECT Id, RecordTypeId, OwnerId, ParentId, 
                       FEC_Is_Reply_Interaction_email__c, FEC_Channel__c, FEC_Send_To__c
                FROM Case
                WHERE RecordTypeId = :interactionRtId
                AND OwnerId = :queueId LIMIT 200
            ];

            if (!casesToRoute.isEmpty()) {
                FEC_InteractionRoutingService.assignInteractionReply(casesToRoute);
                FEC_InteractionRoutingService.assignNewInteractionEmail(casesToRoute);
                
                // Update the records with new Owner assignments
                update casesToRoute;
            }
        } catch (Exception e) {
            return;
        }
    }
}