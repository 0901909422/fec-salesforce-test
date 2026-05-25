public without sharing class FEC_CaseExecuteService {
  public class ExecuteVisibilityResult {
    @AuraEnabled public Boolean value;
    @AuraEnabled public Boolean shouldUpdate;
    @AuraEnabled public String message;
  }
  
  //thangtv: không ép true — luôn tính lại quyền qua canExecute
  @AuraEnabled
  public static ExecuteVisibilityResult forceShowExecute(Id caseId) {
    return canExecute(caseId);
  }
  
  @AuraEnabled
  public static void forceHideExecute(Id caseId) {
    if (caseId == null) {
      return;
    }
    try {
      FEC_CaseInitUpdateService.registerSystemCaseUpdate(caseId);
      FEC_CaseTriggerHandler.isSystemUpdate = true;
      updateCaseExecuteFlag(caseId, false);
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
      FEC_Assignment_Count__c,FEC_Case_Executor__c,
      FEC_Can_Execute__c FROM Case WHERE Id = : caseId LIMIT 1
    ];
    
    Id userId = UserInfo.getUserId();
    String currentUsername = UserInfo.getUserName();
    
    System.debug('==============================');
    System.debug('FEC_CaseExecuteService START');
    System.debug('Case Id = ' + caseId);
    System.debug('User Id = ' + userId);
    System.debug('Owner Id = ' + c.OwnerId);
    System.debug('Current FEC_Can_Execute__c = ' + c.FEC_Can_Execute__c);
    System.debug('Executor = ' + c.FEC_Case_Executor__c);
    System.debug('==============================');
    
    /* * 0. EXECUTOR CHECK * * If already executed by another user * => hide Execute - hieutt cập nhật ngày 25/5/2026
     * button */
    if (String.isNotBlank(c.FEC_Case_Executor__c)
    && c.FEC_Case_Executor__c != currentUsername) {
      System.debug('FAILED: already executed by another user');
      return buildResult(c, false,'Case đã được execute bởi User khác');
    }
    /*
     * 1. Closed check
     */
    if (c.IsClosed) {
      System.debug('FAILED: Case is closed');
      
      return buildResult(c, false,'');
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
      
      return buildResult(c, false,'');
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
     *
     * PRIORITY:
     * If current user is case owner
     * => always show Execute
     */
    Boolean canExecute = false;
    
    /*
     * Current user is owner
     */
    if (c.OwnerId == userId) {
      
      System.debug(
        'Current user is case owner => FORCE TRUE'
        );
      
      canExecute = true;
    }
    
    /*
     * Queue member logic
     */
    else {
      
      canExecute = assignmentCount == 0;
    }
    
    return buildResult(c, canExecute,'');
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
      
      return QUEUE_MEMBERSHIP_ACCESS.isUserInQueue(currentUserId, c.OwnerId)
        || QUEUE_MEMBERSHIP_ACCESS.isUserRoleInQueue(currentUserId, c.OwnerId);
    }
    
    return false;
  }
  
  private static final QueueMembershipAccess QUEUE_MEMBERSHIP_ACCESS =
    new QueueMembershipAccess();
  
  private static ExecuteVisibilityResult buildResult(
  Case c, Boolean canExecute, String message) {
    ExecuteVisibilityResult result = new ExecuteVisibilityResult();
    
    result.value = canExecute;
    
    Boolean currentValue = c.FEC_Can_Execute__c == true;
    
    result.shouldUpdate = currentValue != canExecute;

    result.message = message;
    
    System.debug('----------------------');
    System.debug('currentValue = ' + currentValue);
    
    System.debug('newValue = ' + canExecute);
    
    System.debug('shouldUpdate = ' + result.shouldUpdate);

    System.debug( 'message = ' + message );
    System.debug('----------------------');
    
    /*
     * IMPORTANT:
     * Update field used by
     * Dynamic Action visibility
     */
    if (result.shouldUpdate) {
      try {
        System.debug('START UPDATE CASE');

        FEC_CaseInitUpdateService.registerSystemCaseUpdate(c.Id);
        FEC_CaseTriggerHandler.isSystemUpdate = true;

        //thangtv: SYSTEM_MODE — reset flag khi user không có FLS edit trên Case
        updateCaseExecuteFlag(c.Id, canExecute);
        
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
  
  // @AuraEnabled
  // public static void executeCase(Id caseId) {
    //   Id userId = UserInfo.getUserId();
    
    //   System.debug('==============================');
    //   System.debug('START executeCase');
    //   System.debug('caseId = ' + caseId);
    //   System.debug('userId = ' + userId);
    //   System.debug('==============================');
    
    //   Case c = [SELECT Id, OwnerId FROM Case WHERE Id = : caseId LIMIT 1];
    
    //   Id oldOwnerId = c.OwnerId;
    
    //   System.debug('OLD OwnerId = ' + oldOwnerId);
    
    //   /*
    //    * STOP IF OWNER ALREADY CURRENT USER
    //    */
    //   if (oldOwnerId == userId) {
      //     System.debug('SKIP UPDATE: Owner already current user');
      
      //     return;
    //   }
    
    //   /*
    //    * UPDATE OWNER
    //    */
    //   try {
      //     FEC_CaseTriggerHandler.isSystemUpdate = true;
      
      //     update new Case(Id = caseId, OwnerId = userId);
      
      //     /*
      //      * Routing history
      //     //  */
      //     // createRoutingActionHistory(caseId, oldOwnerId, userId);
      
      //     System.debug('SUCCESS: Owner updated');
      
      //     System.debug('NEW OwnerId = ' + userId);
      
    //   } catch (Exception e) {
      //     System.debug('ERROR executeCase = ' + e.getMessage());
      
      //     throw new AuraHandledException(e.getMessage());
      
    //   } finally {
      //     FEC_CaseTriggerHandler.isSystemUpdate = false;
    //   }
  // }
  
  
  @AuraEnabled
  public static void executeCase(Id caseId) {
    Id userId = UserInfo.getUserId();
    
    User currentUser =
      [SELECT Id, Username FROM User WHERE Id = : userId LIMIT 1];
    
    System.debug('==============================');
    System.debug('START executeCase');
    System.debug('caseId = ' + caseId);
    System.debug('userId = ' + userId);
    System.debug('==============================');
    
    Case c = [
      SELECT Id, OwnerId,
      FEC_Case_Executor__c FROM Case WHERE Id = : caseId LIMIT 1 FOR UPDATE
    ];
    
    /*
     * CHECK EXECUTOR
     */
    if (String.isNotBlank(c.FEC_Case_Executor__c)
    && c.FEC_Case_Executor__c != currentUser.Username) {
      throw new AuraHandledException(
        'Case đã được execute bởi User: ' + c.FEC_Case_Executor__c);
    }
    
    Id oldOwnerId = c.OwnerId;
    
    System.debug('OLD OwnerId = ' + oldOwnerId);
    
    Case updateCase = new Case(Id = caseId);
    
    Boolean hasUpdate = false;
    
    /*
     * SAVE EXECUTOR FIRST TIME
     */
    if (String.isBlank(c.FEC_Case_Executor__c)) {
      updateCase.FEC_Case_Executor__c = currentUser.Username;
      
      hasUpdate = true;
    }
    
    /*
     * UPDATE OWNER
     */
    if (c.OwnerId != userId) {
      updateCase.OwnerId = userId;
      
      hasUpdate = true;
    }
    
    /*
     * NOTHING TO UPDATE
     */
    if (!hasUpdate) {
      System.debug('SKIP UPDATE: no changes');
      
      return;
    }
    
    try {
      FEC_CaseTriggerHandler.isSystemUpdate = true;
      
      update updateCase;
      
      System.debug('SUCCESS executeCase');
      
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
  Id caseId, Id oldOwnerId, Id newOwnerId) {
    if (caseId == null || oldOwnerId == null || newOwnerId == null) {
      return;
    }
    
    /*
     * Case info
     */
    Case c = [
    SELECT Id, OwnerId,
    FEC_Current_Case_Stage__r.FEC_Code__c FROM Case WHERE Id = : caseId LIMIT 1
  ];
    
    /*
     * Execute user
     */
    User currentUser = [
    SELECT Id, Email,
    UserRole.Name FROM User WHERE Id = : UserInfo.getUserId() LIMIT 1
  ];
    
    String oldOwnerDisplay;
    
    /*
     * USER
     */
    if (String.valueOf(oldOwnerId).startsWith('005')) {
      
      List<User> oldUsers = [
            SELECT Id,
                   Email
            FROM User
            WHERE Id = :oldOwnerId
            LIMIT 1
        ];
      
      if (!oldUsers.isEmpty()) {
        oldOwnerDisplay =
          emailLocalPart(oldUsers[0].Email);
      }
    }
    
    /*
     * QUEUE
     */
    else if (
      String.valueOf(oldOwnerId).startsWith('00G')
    ) {
      
      List<Group> oldQueues = [
            SELECT Id,
                   Name,
                   Type
            FROM Group
            WHERE Id = :oldOwnerId
            LIMIT 1
        ];
      
      if (!oldQueues.isEmpty()) {
        oldOwnerDisplay =
          oldQueues[0].Name;
      }
    }
    /*
     * Resolve new owner display
     */
    String newOwnerDisplay;
    
    /*
     * NEW OWNER = USER
     */
    if (String.valueOf(newOwnerId).startsWith('005')) {
      
      List<User> newUsers = [
            SELECT Id,
                   Email
            FROM User
            WHERE Id = :newOwnerId
            LIMIT 1
        ];
      
      if (!newUsers.isEmpty()) {
        
        newOwnerDisplay =
          emailLocalPart(newUsers[0].Email);
      }
    }
    
    /*
     * NEW OWNER = QUEUE
     */
    else if (
      String.valueOf(newOwnerId).startsWith('00G')
    ) {
      
      List<Group> newQueues = [
            SELECT Id,
                   Name,
                   Type
            FROM Group
            WHERE Id = :newOwnerId
            LIMIT 1
        ];
      
      if (!newQueues.isEmpty()) {
        
        newOwnerDisplay =
          newQueues[0].Name;
      }
    }
    
    /*
     * Create history
     */
    FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
      
    FEC_Routing_Action__c = 'Change Owner',
    
    FEC_Routing_Action_Type__c = 'Case',
    
    /*
     * Original queue/user owner
     */
    FEC_Original_User_Queue__c = oldOwnerDisplay,
    
    FEC_Original_User_Queue_ID__c = oldOwnerId,
    
    /*
     * Updated owner
     */
    FEC_Updated_User_Queue__c = newOwnerDisplay,
    
    FEC_Updated_User_Queue_ID__c = newOwnerId,
    
    /*
     * Execute user
     */
    FEC_User__c = emailLocalPart(currentUser.Email),
    
    /*
     * Execute user role
     */
    FEC_User_Role__c =
      currentUser.UserRole != null ? currentUser.UserRole.Name : null,
    
    /*
     * Stage
     */
    FEC_Stage_Name__c = c.FEC_Current_Case_Stage__r != null
      ? c.FEC_Current_Case_Stage__r.FEC_Code__c
      : null,
    
    /*
     * Case
     */
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
  
  private static void updateCaseExecuteFlag(Id caseId, Boolean canExecute) {
    Database.update(
      new Case(Id = caseId, FEC_Can_Execute__c = canExecute),
    AccessLevel.SYSTEM_MODE
      );
  }
  
  //thangtv: đọc GroupMember without sharing (giống FEC_AssignmentExecuteService)
  private class QueueMembershipAccess {
    Boolean isUserInQueue(Id userId, Id queueId) {
      if (userId == null || queueId == null) {
        return false;
      }
      
      Set<Id> visitedGroupIds = new Set<Id>();
      Set<Id> groupsToProcess = new Set<Id>{ queueId };
      
      while (!groupsToProcess.isEmpty()) {
        Set<Id> currentBatch = new Set<Id>(groupsToProcess);
        groupsToProcess.clear();
        visitedGroupIds.addAll(currentBatch);
        
        for (GroupMember gm : [
          SELECT GroupId, UserOrGroupId
          FROM GroupMember
          WHERE GroupId IN :currentBatch
        ]) {
          Id memberId = gm.UserOrGroupId;
          if (memberId == userId) {
            return true;
          }
          if (memberId.getSObjectType() == Group.SObjectType
            && !visitedGroupIds.contains(memberId)
          && !groupsToProcess.contains(memberId)) {
            groupsToProcess.add(memberId);
          }
        }
      }
      return false;
    }
    
    Boolean isUserRoleInQueue(Id userId, Id queueId) {
      if (userId == null || queueId == null) {
        return false;
      }
      
      User userRecord = [
        SELECT Id, UserRoleId
        FROM User
        WHERE Id = :userId
        LIMIT 1
      ];
      
      if (userRecord.UserRoleId == null) {
        return false;
      }
      
      Set<Id> queueRoleIds = new Set<Id>();
      for (Group g : [
        SELECT RelatedId
        FROM Group
        WHERE Id IN (
          SELECT UserOrGroupId
          FROM GroupMember
          WHERE GroupId = :queueId
        )
        AND Type IN (
          'Role',
          'RoleAndSubordinates',
          'RoleAndSubordinatesInternal'
        )
      ]) {
        if (g.RelatedId != null) {
          queueRoleIds.add(g.RelatedId);
        }
      }
      
      return queueRoleIds.contains(userRecord.UserRoleId);
    }
  }
}