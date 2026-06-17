/**
 * Batch: cập nhật User.ManagerId theo Role Hierarchy (Reports To) cho mọi user active có role.
 */
public without sharing class FEC_UserManagerSyncBatch implements Database.Batchable<SObject> {

  public Database.QueryLocator start(Database.BatchableContext bc) {
    if (Test.isRunningTest()) {
      return Database.getQueryLocator([
        SELECT Id, ManagerId, UserRoleId, FEC_User_Group__c, UserRole.ParentRoleId
        FROM User
        WHERE IsActive = TRUE
          AND UserRoleId != NULL
          AND LastName IN ('ChildAgent', 'AlphaManager', 'BetaManager', 'IsolatedAgent', 'OrphanAgent')
      ]);
    }
    return Database.getQueryLocator([
      SELECT Id, ManagerId, UserRoleId, FEC_User_Group__c, UserRole.ParentRoleId
      FROM User
      WHERE IsActive = TRUE AND UserRoleId != NULL
    ]);
  }

  public void execute(Database.BatchableContext bc, List<User> scope) {
    FEC_UserManagerSyncService.syncManagers(scope);
  }

  public void finish(Database.BatchableContext bc) {
  }
}
