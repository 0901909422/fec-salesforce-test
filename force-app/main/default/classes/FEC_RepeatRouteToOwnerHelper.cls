/**
 * Route to lần 2+ tới cùng queue đích: gán user từ FEC_Routing_Action_History__c
 * thay vì queue Stage Change (ping-pong Route to giữa các team).
 */
public without sharing class FEC_RepeatRouteToOwnerHelper {
  private static final List<String> ROUTING_ACTIONS = new List<String>{
    FEC_CaseBusinessService.ROUTE_TO,
    FEC_CaseBusinessService.REVERT
  };

  /**
   * Route to lần 2+ tới cùng queue đích: gán {@code FEC_Perform_User__c} của bản ghi history
   * Route to / Revert mới nhất đã chuyển case về Owner hiện tại (queue/user nguồn).
   * Lần 1 tới queue đích vẫn giữ queue từ Stage Change.
   */
  public static String applyRepeatRouteToUserOwner(
    String caseId,
    Id currentOwnerId,
    String targetOwnerIdStr
  ) {
    if (String.isBlank(caseId) || String.isBlank(targetOwnerIdStr) || currentOwnerId == null) {
      return targetOwnerIdStr;
    }
    Id targetOwnerId;
    try {
      targetOwnerId = Id.valueOf(targetOwnerIdStr.trim());
    } catch (Exception e) {
      return targetOwnerIdStr;
    }
    if (!isQueueOwnerId(targetOwnerId)) {
      return targetOwnerIdStr;
    }
    if (!hasPriorRouteToDestinationQueue(caseId, targetOwnerId)) {
      return targetOwnerIdStr;
    }
    Id performerId = findLatestPerformerWhoRoutedToOwner(caseId, currentOwnerId);
    return performerId != null ? String.valueOf(performerId) : targetOwnerIdStr;
  }

  private static Boolean hasPriorRouteToDestinationQueue(
    String caseId,
    Id destinationQueueId
  ) {
    if (String.isBlank(caseId) || destinationQueueId == null) {
      return false;
    }
    List<FEC_Routing_Action_History__c> prior = [
      SELECT Id
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Case__c = :caseId
        AND FEC_Routing_Action__c IN :ROUTING_ACTIONS
        AND FEC_Updated_User_Queue_ID__c = :String.valueOf(destinationQueueId)
      LIMIT 1
    ];
    return !prior.isEmpty();
  }

  private static Id findLatestPerformerWhoRoutedToOwner(String caseId, Id ownerId) {
    if (String.isBlank(caseId) || ownerId == null) {
      return null;
    }
    List<FEC_Routing_Action_History__c> hist = [
      SELECT FEC_Perform_User__c
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Case__c = :caseId
        AND FEC_Routing_Action__c IN :ROUTING_ACTIONS
        AND FEC_Updated_User_Queue_ID__c = :String.valueOf(ownerId)
        AND FEC_Perform_User__c != NULL
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT 1
    ];
    return hist.isEmpty() ? null : hist[0].FEC_Perform_User__c;
  }

  private static Boolean isQueueOwnerId(Id ownerId) {
    if (ownerId == null || ownerId.getSobjectType() != Group.SObjectType) {
      return false;
    }
    List<Group> grp = [
      SELECT Type
      FROM Group
      WHERE Id = :ownerId
      LIMIT 1
    ];
    return !grp.isEmpty() &&
      FEC_ConstantCommon.GROUP_TYPE_QUEUE.equals(grp[0].Type);
  }
}
