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
   * Route to / Revert mới nhất đã chuyển case về team của Owner hiện tại.
   * Owner hiện tại là User thì tra history theo queue team ({@code FEC_Main_Queue__c} / GroupMember)
   * vì bản ghi history ghi {@code FEC_Updated_User_Queue_ID__c} là Queue Id, không phải User Id.
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
    Set<String> lookupOwnerIds = new Set<String>();
    for (Id lookupId : resolveOwnerIdsForHistoryLookup(ownerId)) {
      lookupOwnerIds.add(String.valueOf(lookupId));
    }
    if (lookupOwnerIds.isEmpty()) {
      return null;
    }
    List<FEC_Routing_Action_History__c> hist = [
      SELECT FEC_Perform_User__c
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Case__c = :caseId
        AND FEC_Routing_Action__c IN :ROUTING_ACTIONS
        AND FEC_Updated_User_Queue_ID__c IN :lookupOwnerIds
        AND FEC_Perform_User__c != NULL
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT 1
    ];
    return hist.isEmpty() ? null : hist[0].FEC_Perform_User__c;
  }

  /**
   * User thường pick case từ queue team — history ghi Updated = Queue Id.
   * Thử queue team trước (Main Queue + GroupMember), fallback User Id cho route trực tiếp tới user.
   */
  private static List<Id> resolveOwnerIdsForHistoryLookup(Id ownerId) {
    List<Id> lookupIds = new List<Id>();
    if (ownerId == null) {
      return lookupIds;
    }
    if (ownerId.getSobjectType() == Group.SObjectType && isQueueOwnerId(ownerId)) {
      lookupIds.add(ownerId);
      return lookupIds;
    }
    if (ownerId.getSobjectType() == User.SObjectType) {
      lookupIds.addAll(resolveUserTeamQueueIds(ownerId));
      lookupIds.add(ownerId);
      return lookupIds;
    }
    lookupIds.add(ownerId);
    return lookupIds;
  }

  /** Queue team của user: {@code FEC_Main_Queue__c}, rồi queue membership (GroupMember / role). */
  private static Set<Id> resolveUserTeamQueueIds(Id userId) {
    Set<Id> queueIds = new Set<Id>();
    List<User> users = [
      SELECT FEC_Main_Queue__c, UserRoleId
      FROM User
      WHERE Id = :userId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (users.isEmpty()) {
      return queueIds;
    }
    User u = users[0];
    if (String.isNotBlank(u.FEC_Main_Queue__c)) {
      List<Group> mainQueues = [
        SELECT Id
        FROM Group
        WHERE
          Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
          AND DeveloperName = :u.FEC_Main_Queue__c
        WITH SYSTEM_MODE
        LIMIT 1
      ];
      if (!mainQueues.isEmpty()) {
        queueIds.add(mainQueues[0].Id);
      }
    }
    Set<Id> memberIds = new Set<Id>{ userId };
    if (u.UserRoleId != null) {
      for (Group roleGroup : [
        SELECT Id
        FROM Group
        WHERE
          RelatedId = :u.UserRoleId
          AND Type IN ('Role', 'RoleAndSubordinates')
      ]) {
        memberIds.add(roleGroup.Id);
      }
    }
    for (GroupMember gm : [
      SELECT GroupId
      FROM GroupMember
      WHERE
        UserOrGroupId IN :memberIds
        AND Group.Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
    ]) {
      queueIds.add(gm.GroupId);
    }
    return queueIds;
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
