public with sharing class FEC_CaseExecuteService {
  public class ExecuteVisibilityResult {
    @AuraEnabled public Boolean value;
    @AuraEnabled public Boolean shouldUpdate;
  }

  @AuraEnabled
  public static void forceShowExecute(Id caseId) {
    try {
      FEC_CaseTriggerHandler.isSystemUpdate = true;

      update new Case(Id = caseId, FEC_Can_Execute__c = true);

      System.debug('FORCE UPDATE FEC_Can_Execute__c = true');

    } catch (Exception e) {
      System.debug('forceShowExecute ERROR = ' + e.getMessage());

      throw new AuraHandledException(e.getMessage());

    } finally {
      FEC_CaseTriggerHandler.isSystemUpdate = false;
    }
  }

  @AuraEnabled
  public static void forceHideExecute(Id caseId) {
    try {
      FEC_CaseTriggerHandler.isSystemUpdate = true;

      update new Case(Id = caseId, FEC_Can_Execute__c = false);

      System.debug('FORCE UPDATE FEC_Can_Execute__c = false');

    } catch (Exception e) {
      System.debug('forceHideExecute ERROR = ' + e.getMessage());

      throw new AuraHandledException(e.getMessage());

    } finally {
      FEC_CaseTriggerHandler.isSystemUpdate = false;
    }
  }

  @AuraEnabled
  public static ExecuteVisibilityResult canExecute(Id caseId) {
    Case c = [
      SELECT Id, OwnerId, IsClosed, FEC_Interaction_View_Mode__c,
      FEC_Assignment_Count__c,
      FEC_Can_Execute__c FROM Case WHERE Id = : caseId LIMIT 1
    ];

    Id userId = UserInfo.getUserId();

    System.debug('==============================');
    System.debug('FEC_CaseExecuteService START');
    System.debug('Case Id = ' + caseId);
    System.debug('User Id = ' + userId);
    System.debug('Owner Id = ' + c.OwnerId);
    System.debug('Current FEC_Can_Execute__c = ' + c.FEC_Can_Execute__c);
    System.debug('==============================');

    /*
     * 1. Closed check
     */
    if (c.IsClosed) {
      System.debug('FAILED: Case is closed');

      return buildResult(c, false);
    }

    /*
     * 2. Access check
     */
    Boolean hasAccess = hasCaseAccess(c, userId);

    System.debug('hasAccess = ' + hasAccess);

    /*
     * User must be:
     * - owner
     * OR
     * - queue member
     */
    if (!hasAccess) {
      System.debug('FAILED: User has no access');

      return buildResult(c, false);
    }

    /*
     * 3. Assignment count check
     */
    Integer assignmentCount = c.FEC_Assignment_Count__c == null
        ? 0
        : Integer.valueOf(c.FEC_Assignment_Count__c);

    System.debug('assignmentCount = ' + assignmentCount);

    /*
     * 4. Execute condition
     */
    Boolean canExecute = assignmentCount == 0;

    System.debug('FINAL canExecute = ' + canExecute);

    return buildResult(c, canExecute);
  }

  private static Boolean hasCaseAccess(Case c, Id currentUserId) {
    if (c == null || currentUserId == null || c.OwnerId == null) {
      return false;
    }

    /*
     * CASE 1:
     * Owner is User
     */
    if (isUserOwner(c.OwnerId)) {
      System.debug('CHECK BY User Owner');

      return isCurrentUserOwner(c.OwnerId, currentUserId);
    }

    /*
     * CASE 2:
     * Owner is Queue
     */
    if (isQueueOwner(c.OwnerId)) {
      System.debug('CHECK BY Queue Owner');

      return isUserInQueue(currentUserId, c.OwnerId);
    }

    return false;
  }

  private static Boolean isUserInQueue(Id userId, Id queueId) {
    if (userId == null || queueId == null) {
      return false;
    }

    Set<Id> visitedGroupIds = new Set<Id>();

    Set<Id> groupsToProcess = new Set<Id>{queueId};

    while (!groupsToProcess.isEmpty()) {
      Set<Id> currentBatch = new Set<Id>(groupsToProcess);

      groupsToProcess.clear();

      visitedGroupIds.addAll(currentBatch);

      List<GroupMember> members = [
        SELECT GroupId,
        UserOrGroupId FROM GroupMember WHERE GroupId IN : currentBatch
      ];

      for (GroupMember gm : members) {
        Id memberId = gm.UserOrGroupId;

        /*
         * Direct User
         */
        if (memberId == userId) {
          return true;
        }

        /*
         * Nested Group
         */
        if (memberId.getSObjectType() == Group.SObjectType) {
          if (!visitedGroupIds.contains(memberId)
              && !groupsToProcess.contains(memberId)) {
            groupsToProcess.add(memberId);
          }
        }
      }
    }

    return false;
  }

  private static ExecuteVisibilityResult buildResult(
      Case c, Boolean canExecute) {
    ExecuteVisibilityResult result = new ExecuteVisibilityResult();

    result.value = canExecute;

    Boolean currentValue = c.FEC_Can_Execute__c == true;

    result.shouldUpdate = currentValue != canExecute;

    System.debug('----------------------');
    System.debug('currentValue = ' + currentValue);

    System.debug('newValue = ' + canExecute);

    System.debug('shouldUpdate = ' + result.shouldUpdate);
    System.debug('----------------------');

    /*
     * IMPORTANT:
     * Update field used by
     * Dynamic Action visibility
     */
    if (result.shouldUpdate) {
      try {
        System.debug('START UPDATE CASE');

        FEC_CaseTriggerHandler.isSystemUpdate = true;

        /*
         * UPDATE HERE
         */
        update new Case(Id = c.Id, FEC_Can_Execute__c = canExecute);

        System.debug('Case updated successfully');

        System.debug('Updated FEC_Can_Execute__c = ' + canExecute);

      } catch (Exception e) {
        System.debug('UPDATE ERROR = ' + e.getMessage());

        throw e;

      } finally {
        FEC_CaseTriggerHandler.isSystemUpdate = false;

        System.debug('RESET isSystemUpdate flag');
      }
    } else {
      System.debug('SKIP UPDATE: value unchanged');
    }

    return result;
  }

  @AuraEnabled
  public static void executeCase(Id caseId) {
    Id userId = UserInfo.getUserId();

    System.debug('==============================');
    System.debug('START executeCase');
    System.debug('caseId = ' + caseId);
    System.debug('userId = ' + userId);
    System.debug('==============================');

    Case c = [SELECT Id, OwnerId FROM Case WHERE Id = : caseId LIMIT 1];

    System.debug('OLD OwnerId = ' + c.OwnerId);

    /*
     * STOP IF OWNER ALREADY CURRENT USER
     */
    if (c.OwnerId == userId) {
      System.debug('SKIP UPDATE: Owner already current user');

      return;
    }

    /*
     * UPDATE OWNER
     */
    try {
      FEC_CaseTriggerHandler.isSystemUpdate = true;

      update new Case(Id = caseId, OwnerId = userId);

      System.debug('SUCCESS: Owner updated');

      System.debug('NEW OwnerId = ' + userId);

    } catch (Exception e) {
      System.debug('ERROR executeCase = ' + e.getMessage());

      throw new AuraHandledException(e.getMessage());

    } finally {
      FEC_CaseTriggerHandler.isSystemUpdate = false;
    }
  }

  /**
   * Create Routing Action History
   */
  public static void createRoutingActionHistory(
      Id caseId, String oldOwnerName, String newOwnerName) {
    Case c = [
      SELECT Id,
      FEC_Current_Case_Stage__r.FEC_Code__c FROM Case WHERE
          Id = : caseId LIMIT 1
    ];

    User currentUser = [
      SELECT Id, Email,
      UserRole.Name FROM User WHERE Id = : UserInfo.getUserId() LIMIT 1
    ];

    List<User> oldOwner = [
      SELECT Id, Name, Email, UserRole.Name,
      FEC_Main_Queue__c FROM User WHERE Name = : oldOwnerName LIMIT 1
    ];
    User oldOwnerUser = oldOwner.isEmpty() ? null : oldOwner[0];

    List<Group> oldOwnerGroup = [
      SELECT Id, DeveloperName, Name,
      Type FROM Group WHERE
          DeveloperName = : oldOwnerUser.FEC_Main_Queue__c LIMIT 1
    ];

    List<User> newOwner = [
      SELECT Id, Name, Email,
      UserRole.Name FROM User WHERE Name = : newOwnerName LIMIT 1
    ];
    User newOwnerUser = newOwner.isEmpty() ? null : newOwner[0];

    FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(

        FEC_Routing_Action__c = 'Change Owner',

        FEC_Routing_Action_Type__c = 'Case',

        FEC_Original_User_Queue__c =
            oldOwnerGroup.isEmpty() ? null : oldOwnerGroup[0].Id,

        FEC_Original_User_Queue_ID__c =
            oldOwnerGroup.isEmpty() ? null : oldOwnerGroup[0].Id,

        FEC_Updated_User_Queue__c = emailLocalPart(newOwnerUser.Email),

        FEC_Updated_User_Queue_ID__c = newOwnerUser.Id,

        FEC_User__c = emailLocalPart(currentUser.Email),

        FEC_User_Role__c = currentUser.UserRole.Name,

        FEC_Stage_Name__c = c.FEC_Current_Case_Stage__r.FEC_Code__c,

        FEC_Case__c = c.Id);

    insert history;

    System.debug('Routing Action History created: ' + history.Id);
  }

  public static String emailLocalPart(String email) {
    if (String.isBlank(email)) {
      return null;
    }
    List<String> parts = email.split('@');
    return parts.isEmpty() ? email.trim() : parts[0].trim();
  }

  private static Boolean isUserOwner(Id ownerId) {
    return ownerId != null && ownerId.getSObjectType() == User.SObjectType;
  }

  private static Boolean isQueueOwner(Id ownerId) {
    return ownerId != null && ownerId.getSObjectType() == Group.SObjectType;
  }

  private static Boolean isCurrentUserOwner(Id ownerId, Id currentUserId) {
    return ownerId != null && currentUserId != null && ownerId == currentUserId;
  }
}