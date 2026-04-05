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
                // Publish platform events after successful DML
                System.debug('route start');
                publishRoutingEvents(casesToRoute);
            }
        } catch (Exception e) {
            return;
        }
    }

    // Thangtv - Auto open case to the new Case Owner
    // 03/04/2026
    public static void publishRoutingEvents(List<Case> routedCases) {
        
        if (routedCases == null || routedCases.isEmpty()) {
            return;
        }
        System.debug('route start111 ' + routedCases);
        List<FEC_Interaction_Routed__e> eventsToPublish = new List<FEC_Interaction_Routed__e>();
        Datetime routedAt = System.now();

        for (Case c : routedCases) {
            eventsToPublish.add(new FEC_Interaction_Routed__e(
                CaseId__c     = (String)c.Id,
                CaseNumber__c = c.CaseNumber,
                OwnerId__c    = (String)c.OwnerId,
                ParentId__c   = c.ParentId == null ? null : (String)c.ParentId,
                Channel__c    = c.FEC_Channel__c,
                SendTo__c     = c.FEC_Send_To__c,
                IsReply__c    = c.FEC_Is_Reply_Interaction_email__c,
                RoutedAt__c   = routedAt,
                Source__c     = 'FEC_InteractionRoutingController'
            ));
        }

        if (!eventsToPublish.isEmpty()) {
            List<Database.SaveResult> publishResults = EventBus.publish(eventsToPublish);
            // Optional: log failures
            for (Integer i = 0; i < publishResults.size(); i++) {
                if (!publishResults[i].isSuccess()) {
                    for (Database.Error err : publishResults[i].getErrors()) {
                        System.debug(
                            LoggingLevel.ERROR,
                            'Platform Event publish failed for Case event index ' + i +
                            ': ' + err.getStatusCode() + ' - ' + err.getMessage()
                        );
                    }
                }
            }
        }
    }
}