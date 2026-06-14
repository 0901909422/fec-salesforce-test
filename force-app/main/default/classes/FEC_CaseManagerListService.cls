/**
 * Ghi FEC_Manager_ID_List__c và FEC_Manager_ID_List_2__c trên Case:
 * CSV Id User theo Role Hierarchy phía trên Owner
 * (User.UserRoleId → UserRole.ParentRoleId), gom mọi User active trong từng role cấp trên
 * (cấp gần trước, xa sau). Owner là Queue hoặc User không có Role → xóa cả 2 field.
 *
 * Vì CONTAINS() trong formula không hỗ trợ LongTextArea, 2 field Text(255) được dùng nối tiếp:
 *   - FEC_Manager_ID_List__c  : 13 manager gần nhất (≤255 ký tự)
 *   - FEC_Manager_ID_List_2__c: 13 manager tiếp theo (≤255 ký tự)
 * Formula FEC_Is_Manager_For_Cur_User__c dùng OR để kiểm tra cả 2 field.
 *
 * Role hierarchy: UserRole được nạp theo lớp (bulk), không SOQL trong vòng while từng bậc.
 */
public without sharing class FEC_CaseManagerListService {
  private static final String CSV_DELIMITER = ',';
  private static final Integer MAX_ROLE_HIERARCHY_DEPTH = 100;
  private static final Integer FIELD_MAX_LENGTH = 255;
  // SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
  private static Set<Id> txnManagerListSyncedCaseIds = new Set<Id>();

  /**
   * @param newCases Trigger.new
   * @param oldMap Trigger.oldMap (null khi insert)
   */
  public static void syncFromOwnerCases(List<Case> newCases, Map<Id, Case> oldMap) {
    if (newCases == null || newCases.isEmpty()) {
      return;
    }

    Set<Id> userOwnerIds = new Set<Id>();
    for (Case c : newCases) {
      if (!shouldRecalculateManagerCsvForCase(c, oldMap)) {
        continue;
      }
      if (c.OwnerId != null && c.OwnerId.getSObjectType() == User.SObjectType) {
        userOwnerIds.add(c.OwnerId);
      }
    }

    Map<Id, String> csvByOwner = buildManagerCsvForUserIds(userOwnerIds);

    List<Case> toUpdate = new List<Case>();
    for (Case c : newCases) {
      if (!shouldRecalculateManagerCsvForCase(c, oldMap)) {
        continue;
      }
      if (c.OwnerId.getSObjectType() != User.SObjectType) {
        toUpdate.add(
          new Case(Id = c.Id, FEC_Manager_ID_List__c = null, FEC_Manager_ID_List_2__c = null)
        );
      } else {
        String fullCsv = csvByOwner.containsKey(c.OwnerId) ? csvByOwner.get(c.OwnerId) : null;
        List<String> chunks = splitManagerCsv(fullCsv);
        toUpdate.add(
          new Case(
            Id = c.Id,
            FEC_Manager_ID_List__c = chunks[0],
            FEC_Manager_ID_List_2__c = chunks[1]
          )
        );
      }
    }

    if (!toUpdate.isEmpty()) {
      Boolean priorSystem = FEC_CaseTriggerHandler.isSystemUpdate;
      FEC_CaseTriggerHandler.isSystemUpdate = true;
      try {
        Database.update(toUpdate, AccessLevel.SYSTEM_MODE);
      } finally {
        FEC_CaseTriggerHandler.isSystemUpdate = priorSystem;
      }
    }
  }

  private static Boolean shouldRecalculateManagerCsvForCase(Case c, Map<Id, Case> oldMap) {
    if (c.OwnerId == null) {
      return false;
    }
    if (oldMap != null) {
      Case oldC = oldMap.get(c.Id);
      if (oldC != null && c.OwnerId == oldC.OwnerId) {
        return false;
      }
    }
    return true;
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
    // SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
    Set<Id> pendingCaseIds = new Set<Id>();
    for (Id caseId : caseIds) {
      if (!txnManagerListSyncedCaseIds.contains(caseId)) {
        pendingCaseIds.add(caseId);
      }
    }
    if (pendingCaseIds.isEmpty()) {
      return;
    }
    List<Case> cases = [
      SELECT Id, OwnerId
      FROM Case
      WHERE Id IN :pendingCaseIds
    ];
    syncFromOwnerCases(cases, null);
    // SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
    txnManagerListSyncedCaseIds.addAll(pendingCaseIds);
  }

  /**
   * Bulk: một lần SOQL User, vài vòng SOQL UserRole theo chiều sâu tối đa (chung cho mọi owner),
   * một SOQL User theo các role tổ tiên đã gom.
   * Trả về full CSV (không giới hạn độ dài) — việc split 2 field do splitManagerCsv() xử lý.
   */
  public static Map<Id, String> buildManagerCsvForUserIds(Set<Id> ownerUserIds) {
    Map<Id, String> result = new Map<Id, String>();
    if (ownerUserIds == null || ownerUserIds.isEmpty()) {
      return result;
    }

    Set<Id> userIds = new Set<Id>();
    for (Id uid : ownerUserIds) {
      if (uid != null && uid.getSObjectType() == User.SObjectType) {
        userIds.add(uid);
      }
    }

    for (Id uid : userIds) {
      result.put(uid, null);
    }

    if (userIds.isEmpty()) {
      return result;
    }

    Map<Id, User> usersById = new Map<Id, User>(
      [SELECT Id, UserRoleId FROM User WHERE Id IN :userIds]
    );

    Set<Id> starterRoleIds = new Set<Id>();
    for (User u : usersById.values()) {
      if (u.UserRoleId != null) {
        starterRoleIds.add(u.UserRoleId);
      }
    }

    Map<Id, Id> roleIdToParentId = loadRoleHierarchyParentMap(starterRoleIds);

    Set<Id> allAncestorRoleIds = new Set<Id>();
    Map<Id, List<Id>> userIdToAncestorRoles = new Map<Id, List<Id>>();

    for (Id uid : userIds) {
      User u = usersById.get(uid);
      if (u == null || u.UserRoleId == null) {
        continue;
      }
      List<Id> anc = ancestorRoleIdsOrderedForRole(u.UserRoleId, roleIdToParentId);
      userIdToAncestorRoles.put(uid, anc);
      allAncestorRoleIds.addAll(anc);
    }

    if (allAncestorRoleIds.isEmpty()) {
      return result;
    }

    Map<Id, List<Id>> roleIdToUserIds = new Map<Id, List<Id>>();
    for (Id rid : allAncestorRoleIds) {
      roleIdToUserIds.put(rid, new List<Id>());
    }

    for (User u : [
      SELECT Id, UserRoleId
      FROM User
      WHERE UserRoleId IN :allAncestorRoleIds AND IsActive = TRUE
    ]) {
      if (roleIdToUserIds.containsKey(u.UserRoleId)) {
        roleIdToUserIds.get(u.UserRoleId).add(u.Id);
      }
    }

    for (Id uid : userIds) {
      List<Id> ancestorRoleIdsOrdered = userIdToAncestorRoles.get(uid);
      if (ancestorRoleIdsOrdered == null || ancestorRoleIdsOrdered.isEmpty()) {
        result.put(uid, null);
        continue;
      }
      result.put(uid, composeManagerCsv(ancestorRoleIdsOrdered, roleIdToUserIds));
    }

    return result;
  }

  /**
   * Từ Owner (User), các User active thuộc các Role nằm trên Owner trong Role Hierarchy
   * (tương đương danh sách "Managers in the Role Hierarchy"); trả về CSV Id hoặc null.
   */
  public static String buildManagerIdListCsv(Id ownerUserId) {
    if (ownerUserId == null || ownerUserId.getSObjectType() != User.SObjectType) {
      return null;
    }
    Map<Id, String> m = buildManagerCsvForUserIds(new Set<Id>{ ownerUserId });
    return m.get(ownerUserId);
  }

  /**
   * Nạp map RoleId → ParentRoleId cho mọi role trên các chuỗi ancestor xuất phát từ starterRoleIds.
   * Mỗi vòng chỉ một SOQL SELECT ... WHERE Id IN :frontier.
   */
  private static Map<Id, Id> loadRoleHierarchyParentMap(Set<Id> startingRoleIds) {
    Map<Id, Id> roleIdToParentId = new Map<Id, Id>();
    if (startingRoleIds == null || startingRoleIds.isEmpty()) {
      return roleIdToParentId;
    }

    Set<Id> frontier = new Set<Id>(startingRoleIds);
    Set<Id> visited = new Set<Id>();
    Integer depthGuard = 0;

    while (!frontier.isEmpty() && depthGuard < MAX_ROLE_HIERARCHY_DEPTH) {
      depthGuard++;

      Set<Id> toQuery = new Set<Id>();
      for (Id rid : frontier) {
        if (!visited.contains(rid)) {
          toQuery.add(rid);
        }
      }

      if (toQuery.isEmpty()) {
        break;
      }

      Map<Id, UserRole> rowsById = new Map<Id, UserRole>(
        [SELECT Id, ParentRoleId FROM UserRole WHERE Id IN :toQuery]
      );

      frontier.clear();
      for (Id qid : toQuery) {
        visited.add(qid);
        UserRole ur = rowsById.get(qid);
        Id parentId = ur == null ? null : ur.ParentRoleId;
        roleIdToParentId.put(qid, parentId);
        if (parentId != null && !visited.contains(parentId)) {
          frontier.add(parentId);
        }
      }
    }

    return roleIdToParentId;
  }

  /** Thứ tự: role cha trực tiếp của Owner trước, rồi lần lượt lên trên — chỉ dùng map, không SOQL. */
  private static List<Id> ancestorRoleIdsOrderedForRole(
    Id ownerRoleId,
    Map<Id, Id> roleIdToParentId
  ) {
    List<Id> ancestorRoleIdsOrdered = new List<Id>();
    Id cursor = ownerRoleId;
    Set<Id> visited = new Set<Id>();
    Integer depth = 0;

    while (cursor != null && depth < MAX_ROLE_HIERARCHY_DEPTH) {
      if (!roleIdToParentId.containsKey(cursor)) {
        break;
      }
      Id parentRoleId = roleIdToParentId.get(cursor);
      if (parentRoleId == null) {
        break;
      }
      if (visited.contains(parentRoleId)) {
        break;
      }
      visited.add(parentRoleId);
      ancestorRoleIdsOrdered.add(parentRoleId);
      cursor = parentRoleId;
      depth++;
    }
    return ancestorRoleIdsOrdered;
  }

  /** Ghép full CSV theo thứ tự từ role gần đến xa, không giới hạn độ dài. */
  private static String composeManagerCsv(
    List<Id> ancestorRoleIdsOrdered,
    Map<Id, List<Id>> roleIdToUserIds
  ) {
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
   * Chia full CSV thành 2 chunk, mỗi chunk tối đa FIELD_MAX_LENGTH ký tự, không cắt giữa ID.
   * Trả về List gồm đúng 2 phần tử: [chunk1, chunk2] — null nếu chunk rỗng.
   * chunk1: các manager gần nhất (ưu tiên); chunk2: các manager xa hơn.
   */
  @TestVisible
  private static List<String> splitManagerCsv(String fullCsv) {
    List<String> chunks = new List<String>{ null, null };
    if (String.isBlank(fullCsv)) {
      return chunks;
    }

    List<String> ids = fullCsv.split(CSV_DELIMITER);
    List<String> chunk1 = new List<String>();
    List<String> chunk2 = new List<String>();
    Integer len1 = 0;
    Integer len2 = 0;
    Boolean chunk1Full = false;

    for (String id : ids) {
      if (!chunk1Full) {
        Integer needed = chunk1.isEmpty() ? id.length() : 1 + id.length();
        if (len1 + needed <= FIELD_MAX_LENGTH) {
          chunk1.add(id);
          len1 += needed;
          continue;
        }
        chunk1Full = true;
      }
      Integer needed = chunk2.isEmpty() ? id.length() : 1 + id.length();
      if (len2 + needed <= FIELD_MAX_LENGTH) {
        chunk2.add(id);
        len2 += needed;
      }
      // IDs vượt quá 2 field (>~26 managers) bị bỏ qua — trường hợp hierarchy rất lớn.
    }

    chunks[0] = chunk1.isEmpty() ? null : String.join(chunk1, CSV_DELIMITER);
    chunks[1] = chunk2.isEmpty() ? null : String.join(chunk2, CSV_DELIMITER);
    return chunks;
  }

  /**
   * Đồng bộ lại FEC_Manager_ID_List__c và FEC_Manager_ID_List_2__c cho các Case đã tồn tại
   * (backfill sau deploy, hoặc khi Role/User thay đổi).
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
