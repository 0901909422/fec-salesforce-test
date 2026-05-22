//PhongBT 18/05/26: Document Request sử dụng cục routing action mới
public without sharing class FEC_DocumentRequestRoutingService {
  public class StageRoutingResult {
    @AuraEnabled
    public String nextTeam { get; set; }
    @AuraEnabled
    public String nextQueueLabel { get; set; }
    @AuraEnabled
    public String nextQueueId { get; set; }
  }

  //PhongBT 18/05/26: Document Request sử dụng cục routing action mới
  @AuraEnabled
  public static StageRoutingResult getStageChangeRouting(
    Id caseId,
    String teamUserGroup
  ) {
    StageRoutingResult result = new StageRoutingResult();
    if (caseId == null || String.isBlank(teamUserGroup)) {
      return result;
    }

    List<Case> cases = [
      SELECT Id, FEC_Current_Case_Stage__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (cases.isEmpty() || cases[0].FEC_Current_Case_Stage__c == null) {
      return result;
    }

    Id currentStageId = cases[0].FEC_Current_Case_Stage__c;
    List<FEC_Stage_Change__c> changelst = [
      SELECT FEC_Next_Queue__c, FEC_Team_User_Group__c
      FROM FEC_Stage_Change__c
      WHERE
        FEC_Previous_Stage__c = :currentStageId
        AND FEC_Team_User_Group__c = :teamUserGroup
        AND FEC_Active__c = TRUE
        AND FEC_IsReverted__c = FALSE
      LIMIT 1
    ];
    if (changelst.isEmpty()) {
      return result;
    }

    FEC_Stage_Change__c sc = changelst[0];
    result.nextTeam = sc.FEC_Team_User_Group__c;
    Group nextQueue = resolveQueueFromStageChangeValue(sc.FEC_Next_Queue__c);
    if (nextQueue != null) {
      result.nextQueueLabel = nextQueue.Name;
      result.nextQueueId = (String) nextQueue.Id;
    }
    return result;
  }

  private static Group resolveQueueFromStageChangeValue(String nextQueueValue) {
    if (String.isBlank(nextQueueValue)) {
      return null;
    }
    String normalized = nextQueueValue.trim();
    try {
      Id queueId = Id.valueOf(normalized);
      List<Group> queuesById = [
        SELECT Id, Name, DeveloperName
        FROM Group
        WHERE Id = :queueId AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
        LIMIT 1
      ];
      if (!queuesById.isEmpty()) {
        return queuesById[0];
      }
    } catch (Exception ignore) {
    }

    List<Group> queuesByDeveloperName = [
      SELECT Id, Name, DeveloperName
      FROM Group
      WHERE
        Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
        AND DeveloperName = :normalized
      LIMIT 1
    ];
    if (!queuesByDeveloperName.isEmpty()) {
      return queuesByDeveloperName[0];
    }

    List<Group> queuesByName = [
      SELECT Id, Name, DeveloperName
      FROM Group
      WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE AND Name = :normalized
      LIMIT 1
    ];
    return queuesByName.isEmpty() ? null : queuesByName[0];
  }
}
