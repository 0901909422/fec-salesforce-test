/**
 * Class Description: Service class to handle Routing assignments for Email Interactions
 * @created  : 2026/03/11
 */
public with sharing class FEC_InteractionRoutingService {

    /**
     * @description Assigns reply emails back to the original agent if they are active and available
     */
    public static void assignInteractionReply(List<Case> newCases) {

        if (newCases == null || newCases.isEmpty()) {
            return;
        }

        Id interactionRtId = FEC_CommonUltils.getRecordTypeIdByDev(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);
        if (interactionRtId == null) {
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

        Map<Id, Case> candidateCases = new Map<Id, Case>();
        Set<Id> parentIds = new Set<Id>();

        for (Case c : newCases) {
            if (c.RecordTypeId == interactionRtId &&
                c.OwnerId == queueId &&
                c.FEC_Is_Reply_Interaction_email__c &&
                c.ParentId != null) {

                candidateCases.put(c.Id, c);
                parentIds.add(c.ParentId);
            }
        }

        System.debug('candidateCases: ' + candidateCases.size());
        if (candidateCases.isEmpty()) return;

        Map<Id, Case> parentMap = new Map<Id, Case>(
            [SELECT Id, OwnerId, RecordTypeId
             FROM Case
             WHERE Id IN :parentIds]
        );

        Map<Id, Case> eligibleCases = new Map<Id, Case>();
        Set<Id> agentUserIds = new Set<Id>();

        for (Case c : candidateCases.values()) {
            Case parentCase = parentMap.get(c.ParentId);
            if (parentCase == null || parentCase.RecordTypeId != interactionRtId) continue;

            eligibleCases.put(c.Id, c);
            if (parentCase.OwnerId != null) {
                agentUserIds.add(parentCase.OwnerId);
            }
        }

        if (eligibleCases.isEmpty() || agentUserIds.isEmpty()) return;

        List<ServiceResource> srList = [
            SELECT Id, RelatedRecordId, IsActive
            FROM ServiceResource
            WHERE RelatedRecordId IN :agentUserIds
        ];

        Map<Id, ServiceResource> userToSR = new Map<Id, ServiceResource>();
        Set<Id> srIds = new Set<Id>();
        for (ServiceResource sr : srList) {
            userToSR.put(sr.RelatedRecordId, sr);
            srIds.add(sr.Id);
        }

        if (srIds.isEmpty()) return;

        Map<Id, Integer> srCapacity = getServiceResourceCapacities(srIds);
        Set<Id> absentSR = getAbsentServiceResources(srIds);
        Map<Id, Integer> agentCaseCount = getAgentCaseCounts(agentUserIds, interactionRtId);

        for (Case c : eligibleCases.values()) {
            Case parentCase = parentMap.get(c.ParentId);
            Id agentId = parentCase.OwnerId;

            if (!userToSR.containsKey(agentId)) continue;

            ServiceResource sr = userToSR.get(agentId);

            if (!sr.IsActive || absentSR.contains(sr.Id) || !srCapacity.containsKey(sr.Id)) {
                continue;
            }
            
            Integer maxCapacity = srCapacity.get(sr.Id);
            Integer currentCount = agentCaseCount.containsKey(agentId) ? agentCaseCount.get(agentId) : 0;

            Integer available = maxCapacity - currentCount;

            if (available > 0) {
                System.debug('Assigning case ' + c.Id + ' to agent ' + agentId);
                c.OwnerId = agentId;
                agentCaseCount.put(agentId, currentCount + 1);
            }
        }
    }

    /**
     * @description Assigns new incoming emails to the most available Ubank Email agent
     */
    public static void assignNewInteractionEmail(List<Case> newCases) {

        if (newCases == null || newCases.isEmpty()) return;

        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();

        if (!rtMap.containsKey(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)) return;
        Id interactionRtId = rtMap.get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME).getRecordTypeId();

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

        Map<Id, Case> candidateCases = new Map<Id, Case>();
        Set<Id> parentIds = new Set<Id>();

        String routingEmail = getRoutingEmail();
        for (Case c : newCases) {
            if (c.RecordTypeId == interactionRtId &&
                c.OwnerId == queueId && ((
                    !c.FEC_Is_Reply_Interaction_email__c &&
                    c.FEC_Channel__c == FEC_ConstantCommon.EMAIL &&
                    c.FEC_Send_To__c == routingEmail
                ) || (c.FEC_Is_Reply_Interaction_email__c && c.ParentId != null))
                ) {
                candidateCases.put(c.Id, c);
                parentIds.add(c.ParentId);
            }
        }

        System.debug('candidateCases: ' + candidateCases.size() );
        if (candidateCases.isEmpty()) return;

        Map<Id, Case> parentMap = new Map<Id, Case>(
            [SELECT Id, RecordTypeId
             FROM Case
             WHERE Id IN :parentIds]
        );

        Map<Id, Case> eligibleCases = new Map<Id, Case>();

        for (Case c : candidateCases.values()) {
            Case parentCase = parentMap.get(c.ParentId);
            if (parentCase == null || parentCase.RecordTypeId == interactionRtId) {
                eligibleCases.put(c.Id, c);
            }
        }

        if (eligibleCases.isEmpty()) return;

        Datetime rightnow = system.now();

        List<ServiceResourceSkill> skillList = [
            SELECT Id,
                   ServiceResourceId,
                   FEC_Skill_Level__c,
                   FEC_Capacity__c,
                   ServiceResource.IsActive,
                   ServiceResource.RelatedRecordId
            FROM ServiceResourceSkill
            WHERE Skill.DeveloperName = :System.Label.FEC_Ubank_Skill_DevName
            AND FEC_Active__c = true AND EffectiveStartDate <= :rightnow AND ( EffectiveEndDate >= :rightnow OR EffectiveEndDate = NULL)
        ];

        if (skillList.isEmpty()) return;

        Map<Id, Integer> srCapacity = new Map<Id, Integer>();
        Map<Id, Integer> srSkillLevel = new Map<Id, Integer>();
        Map<Id, Id> srToUser = new Map<Id, Id>();
        Set<Id> srIds = new Set<Id>();

        for (ServiceResourceSkill s : skillList) {
            if (s.ServiceResource.IsActive == true) {
                srIds.add(s.ServiceResourceId);
                srToUser.put(s.ServiceResourceId, s.ServiceResource.RelatedRecordId);
                
                srCapacity.put(
                    s.ServiceResourceId,
                    s.FEC_Capacity__c == null ? 0 : Integer.valueOf(s.FEC_Capacity__c)
                );
                
                srSkillLevel.put(
                    s.ServiceResourceId,
                    s.FEC_Skill_Level__c == null ? 0 : Integer.valueOf(s.FEC_Skill_Level__c)
                );
            }
        }

        if (srIds.isEmpty()) return;

        Set<Id> absentSR = getAbsentServiceResources(srIds);
        Set<Id> agentUserIds = new Set<Id>(srToUser.values());
        Map<Id, Integer> currentCountMap = getAgentCaseCounts(agentUserIds, interactionRtId);

        for (Case c : eligibleCases.values()) {

            Id bestUser;
            Integer bestAvailable = -999999;
            Integer bestSkill = -999999;

            for (Id srId : srIds) {

                if (absentSR.contains(srId)) continue;

                Id userId = srToUser.get(srId);

                Integer maxCapacity = srCapacity.get(srId);
                Integer current = currentCountMap.containsKey(userId) ? currentCountMap.get(userId) : 0;

                Integer available = maxCapacity - current;
                if (available <= 0) continue;

                Integer skillLevel = srSkillLevel.get(srId);

                if (available > bestAvailable ||
                   (available == bestAvailable && skillLevel > bestSkill)) {

                    bestAvailable = available;
                    bestSkill = skillLevel;
                    bestUser = userId;
                }
            }

            if (bestUser != null) {
                System.debug('Assigning case ' + c.Id + ' to agent ' + bestUser);
                c.OwnerId = bestUser;

                Integer newCount = currentCountMap.containsKey(bestUser) ? currentCountMap.get(bestUser) + 1 : 1;
                currentCountMap.put(bestUser, newCount);
            }
        }
    }

    // --- HELPER METHODS ---

    /**
     * @description Retrieve the capacities of a set of Service Resources
     */
    private static Map<Id, Integer> getServiceResourceCapacities(Set<Id> srIds) {
        Map<Id, Integer> srCapacity = new Map<Id, Integer>();
        for (ServiceResourceSkill skill : [
            SELECT Id, ServiceResourceId, FEC_Capacity__c
            FROM ServiceResourceSkill
            WHERE ServiceResourceId IN :srIds and FEC_Active__c  = true
        ]) {
            if (skill.FEC_Capacity__c != null) {
                srCapacity.put(skill.ServiceResourceId, Integer.valueOf(skill.FEC_Capacity__c));
            }
        }
        return srCapacity;
    }

    /**
     * @description Fetch any absent Service Resources given a set of Service Resource Ids
     */
    private static Set<Id> getAbsentServiceResources(Set<Id> srIds) {
        Set<Id> absentSR = new Set<Id>();
        Datetime nowTime = System.now();
        for (FEC_Service_Resource_Absence__c abs : [
            SELECT FEC_Service_Resource__c
            FROM FEC_Service_Resource_Absence__c
            WHERE FEC_Service_Resource__c IN :srIds
            AND FEC_Start_Date__c <= :nowTime
            AND (FEC_End_Date__c >= :nowTime OR FEC_End_Date__c = NULL)
        ]) {
            absentSR.add(abs.FEC_Service_Resource__c);
        }
        return absentSR;
    }

    /**
     * @description Aggregate current Email interactions belonging to agents
     */
    private static Map<Id, Integer> getAgentCaseCounts(Set<Id> agentUserIds, Id interactionRtId) {
        Map<Id, Integer> agentCaseCount = new Map<Id, Integer>();
        Set<String> interationStatuslst = new Set<String>{ 'Open' };

        String routingEmail = getRoutingEmail();
        for (AggregateResult ar : [
            SELECT OwnerId ownerId, COUNT(Id) total
            FROM Case
            WHERE RecordTypeId = :interactionRtId
            AND FEC_Channel__c = :FEC_ConstantCommon.EMAIL
            AND FEC_On_Hold__c = false
            AND FEC_Send_To__c = :routingEmail
            AND OwnerId IN :agentUserIds
            AND IsClosed = false
            AND FEC_Interaction_Status__c  IN :interationStatuslst
            GROUP BY OwnerId
        ]) {
            agentCaseCount.put((Id) ar.get('ownerId'), (Integer) ar.get('total'));
        }
        return agentCaseCount;
    }

    /**
     * @description Lấy email routing từ Custom Setting (FEC_System_Config__c)
     * Fallback về Custom Label nếu chưa cấu hình.
     */
    private static String getRoutingEmail() {
        FEC_System_Config__c sysConfig = FEC_System_Config__c.getOrgDefaults();
        return sysConfig != null ? sysConfig.FEC_Send_To_Email_Ubank__c : null;
    }
}