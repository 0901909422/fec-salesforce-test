/**
 * Đồng bộ User.ManagerId theo Role Hierarchy (UserRole.ParentRoleId / Reports To):
 *   1. Lấy Role của user
 *   2. Lấy Parent Role (Reports To)
 *   3. Tìm User active được gán Parent Role
 *   4. Cập nhật ManagerId
 */
public without sharing class FEC_UserManagerSyncService {

  /**
   * @param users Cần Id, ManagerId, UserRoleId, FEC_User_Group__c, UserRole.ParentRoleId
   * @return Map UserId → ManagerId (null = không có parent role; không có key = không đổi)
   */
  public static Map<Id, Id> resolveManagersForUsers(List<User> users) {
    Map<Id, Id> managerByUserId = new Map<Id, Id>();
    if (users == null || users.isEmpty()) {
      return managerByUserId;
    }

    Set<Id> parentRoleIds = new Set<Id>();
    for (User u : users) {
      Id parentRoleId = getParentRoleId(u);
      if (parentRoleId != null) {
        parentRoleIds.add(parentRoleId);
      }
    }

    Map<Id, List<User>> usersByRoleId = loadActiveUsersByRoleId(parentRoleIds);

    for (User u : users) {
      Id parentRoleId = getParentRoleId(u);
      if (parentRoleId == null) {
        managerByUserId.put(u.Id, null);
        continue;
      }

      List<User> managers = usersByRoleId.get(parentRoleId);
      if (managers == null || managers.isEmpty()) {
        continue;
      }
      managerByUserId.put(u.Id, pickManager(managers, u.FEC_User_Group__c));
    }

    return managerByUserId;
  }

  public static List<User> buildUserUpdates(List<User> users, Map<Id, Id> managerByUserId) {
    List<User> toUpdate = new List<User>();
    if (users == null || managerByUserId == null || managerByUserId.isEmpty()) {
      return toUpdate;
    }

    for (User u : users) {
      if (!managerByUserId.containsKey(u.Id)) {
        continue;
      }
      Id newManagerId = managerByUserId.get(u.Id);
      if (u.ManagerId != newManagerId) {
        toUpdate.add(new User(Id = u.Id, ManagerId = newManagerId));
      }
    }

    return toUpdate;
  }

  public static void syncManagers(List<User> users) {
    Map<Id, Id> managerByUserId = resolveManagersForUsers(users);
    List<User> toUpdate = buildUserUpdates(users, managerByUserId);
    if (!toUpdate.isEmpty()) {
      update toUpdate;
    }
  }

  @TestVisible
  private static Id getParentRoleId(User u) {
    if (u == null || u.UserRoleId == null || u.UserRole == null) {
      return null;
    }
    return u.UserRole.ParentRoleId;
  }

  @TestVisible
  private static Map<Id, List<User>> loadActiveUsersByRoleId(Set<Id> roleIds) {
    Map<Id, List<User>> usersByRoleId = new Map<Id, List<User>>();
    if (roleIds == null || roleIds.isEmpty()) {
      return usersByRoleId;
    }

    for (User managerCandidate : [
      SELECT Id, UserRoleId, FEC_User_Group__c, LastName, Name
      FROM User
      WHERE IsActive = TRUE AND UserRoleId IN :roleIds
      ORDER BY LastName ASC, Name ASC, Id ASC
    ]) {
      if (!usersByRoleId.containsKey(managerCandidate.UserRoleId)) {
        usersByRoleId.put(managerCandidate.UserRoleId, new List<User>());
      }
      usersByRoleId.get(managerCandidate.UserRoleId).add(managerCandidate);
    }

    return usersByRoleId;
  }

  /**
   * Nhiều user cùng parent role: ưu tiên cùng FEC_User_Group__c, sau đó thứ tự tên ổn định.
   */
  @TestVisible
  private static Id pickManager(List<User> candidates, String userGroup) {
    if (candidates == null || candidates.isEmpty()) {
      return null;
    }
    if (candidates.size() == 1) {
      return candidates[0].Id;
    }

    if (String.isNotBlank(userGroup)) {
      for (User candidate : candidates) {
        if (userGroup == candidate.FEC_User_Group__c) {
          return candidate.Id;
        }
      }
    }

    return candidates[0].Id;
  }
}
