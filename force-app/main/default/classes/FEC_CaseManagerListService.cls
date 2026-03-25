/**
 * Ghi FEC_Manager_ID_List__c trên Case: CSV Id User theo Role Hierarchy phía trên Owner
 * (User.UserRoleId → UserRole.ParentRoleId), gom mọi User active trong từng role cấp trên
 * (cấp gần trước, xa sau). Owner là Queue hoặc User không có Role → xóa FEC_Manager_ID_List__c.
 */
public without sharing class FEC_CaseManagerListService {
  private static final String CSV_DELIMITER = ',';
  private static final Integer MAX_ROLE_HIERARCHY_DEPTH = 100;

  /**
   * @param newCases Trigger.new
   * @param oldMap Trigger.oldMap (null khi insert)
   */
  public static void syncFromOwnerCases(List<Case> newCases, Map<Id, Case> oldMap) {
    if (newCases == null || newCases.isEmpty()) {
      return;
    }

    Map<Id, String> ownerIdToCsvCache = new Map<Id, String>();
    List<Case> toUpdate = new List<Case>();

    for (Case c : newCases) {
      if (c.OwnerId == null) {
        continue;
      }
      if (oldMap != null) {
        Case oldC = oldMap.get(c.Id);
        if (oldC != null && c.OwnerId == oldC.OwnerId) {
          continue;
        }
      }

      if (c.OwnerId.getSObjectType() != User.SObjectType) {
        toUpdate.add(new Case(Id = c.Id, FEC_Manager_ID_List__c = null));
        continue;
      }

      String csv = getOrBuildManagerCsv(c.OwnerId, ownerIdToCsvCache);
      toUpdate.add(new Case(Id = c.Id, FEC_Manager_ID_List__c = csv));
    }

    if (!toUpdate.isEmpty()) {
      Database.update(toUpdate, AccessLevel.SYSTEM_MODE);
    }
  }

  /**
   * Gọi từ FEC_RoutingActionHistoryTrigger (after insert RAH): đồng bộ lại FEC_Manager_ID_List__c
   * theo Owner hiện tại của Case (sau khi insert history có thể đã đổi owner trong cùng transaction).
   */
  public static void applyAfterRoutingHistoryInsert(
    List<FEC_Routing_Action_History__c> newRecords
  ) {
    if (newRecords == null || newRecords.isEmpty()) {
      return;
    }
    Set<Id> caseIds = new Set<Id>();
    for (FEC_Routing_Action_History__c h : newRecords) {
      if (h.FEC_Case__c != null) {
        caseIds.add(h.FEC_Case__c);
      }
    }
    if (caseIds.isEmpty()) {
      return;
    }
    List<Case> cases = [
      SELECT Id, OwnerId
      FROM Case
      WHERE Id IN :caseIds
    ];
    syncFromOwnerCases(cases, null);
  }

  /**
   * Từ Owner (User), các User active thuộc các Role nằm trên Owner trong Role Hierarchy
   * (tương đương danh sách "Managers in the Role Hierarchy"); trả về CSV Id hoặc null.
   */
  public static String buildManagerIdListCsv(Id ownerUserId) {
    if (ownerUserId == null || ownerUserId.getSObjectType() != User.SObjectType) {
      return null;
    }

    List<User> ownerRows = [
      SELECT UserRoleId
      FROM User
      WHERE Id = :ownerUserId
      LIMIT 1
    ];
    if (ownerRows.isEmpty() || ownerRows[0].UserRoleId == null) {
      return null;
    }

    List<Id> ancestorRoleIdsOrdered = collectAncestorRoleIdsOrdered(ownerRows[0].UserRoleId);
    if (ancestorRoleIdsOrdered.isEmpty()) {
      return null;
    }

    List<User> usersInRoles = [
      SELECT Id, UserRoleId
      FROM User
      WHERE UserRoleId IN :ancestorRoleIdsOrdered AND IsActive = true
    ];

    Map<Id, List<Id>> roleIdToUserIds = new Map<Id, List<Id>>();
    for (Id rid : ancestorRoleIdsOrdered) {
      roleIdToUserIds.put(rid, new List<Id>());
    }
    for (User u : usersInRoles) {
      if (roleIdToUserIds.containsKey(u.UserRoleId)) {
        roleIdToUserIds.get(u.UserRoleId).add(u.Id);
      }
    }

    List<String> orderedManagerIds = new List<String>();
    Set<Id> seenUserIds = new Set<Id>();
    for (Id rid : ancestorRoleIdsOrdered) {
      List<Id> idsForRole = roleIdToUserIds.get(rid);
      if (idsForRole == null || idsForRole.isEmpty()) {
        continue;
      }
      List<String> sortKeys = new List<String>();
      for (Id uid : idsForRole) {
        sortKeys.add(String.valueOf(uid));
      }
      sortKeys.sort();
      for (String key : sortKeys) {
        Id uid = (Id) key;
        if (!seenUserIds.contains(uid)) {
          seenUserIds.add(uid);
          orderedManagerIds.add(key);
        }
      }
    }

    return orderedManagerIds.isEmpty() ? null : String.join(orderedManagerIds, CSV_DELIMITER);
  }

  /**
   * Thứ tự: role cha trực tiếp của Owner trước, rồi lần lượt lên trên (ParentRoleId).
   */
  private static List<Id> collectAncestorRoleIdsOrdered(Id ownerRoleId) {
    List<Id> ancestorRoleIdsOrdered = new List<Id>();
    Id cursor = ownerRoleId;
    Set<Id> visitedRoles = new Set<Id>();
    Integer depth = 0;

    while (cursor != null && depth < MAX_ROLE_HIERARCHY_DEPTH) {
      if (visitedRoles.contains(cursor)) {
        break;
      }
      visitedRoles.add(cursor);

      List<UserRole> rows = [
        SELECT ParentRoleId
        FROM UserRole
        WHERE Id = :cursor
        LIMIT 1
      ];
      if (rows.isEmpty()) {
        break;
      }
      Id parentRoleId = rows[0].ParentRoleId;
      if (parentRoleId == null) {
        break;
      }
      ancestorRoleIdsOrdered.add(parentRoleId);
      cursor = parentRoleId;
      depth++;
    }
    return ancestorRoleIdsOrdered;
  }

  private static String getOrBuildManagerCsv(Id userId, Map<Id, String> cache) {
    if (!cache.containsKey(userId)) {
      cache.put(userId, buildManagerIdListCsv(userId));
    }
    return cache.get(userId);
  }

  /**
   * Đồng bộ lại FEC_Manager_ID_List__c cho các Case đã tồn tại (backfill sau deploy, hoặc khi Role/User thay đổi).
   * Truyền oldMap = null nên mọi bản ghi trong list đều được tính lại.
   */
  public static void recalculateForCaseIds(Set<Id> caseIds) {
    if (caseIds == null || caseIds.isEmpty()) {
      return;
    }
    List<Case> cases = [SELECT Id, OwnerId FROM Case WHERE Id IN :caseIds];
    syncFromOwnerCases(cases, null);
  }
}
