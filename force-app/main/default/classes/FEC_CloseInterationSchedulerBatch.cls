public without sharing class FEC_CloseInterationSchedulerBatch implements Schedulable, Database.Batchable<SObject> {
  public FEC_CloseInterationSchedulerBatch() {
  }
  
  // ================= SCHEDULABLE =================
  public void execute(SchedulableContext sc) {
    Database.executeBatch(this, 200);
  }
  
  // ================= BATCH =================
  public Database.QueryLocator start(Database.BatchableContext bc) {
    Set<String> statuslst = new Set<String>{ 'Open' };
    Set<String> interationStatuslst = new Set<String>{ 'Open' };
    
    Map<String, Id> queueDevNameToId = new Map<String, Id>();
    
    for (Group g : [
          SELECT Id, DeveloperName
          FROM Group
          WHERE Type = 'Queue'
          AND DeveloperName IN (
              'FEC_Ubank_Email',
              'FEC_CSM_Mailbox',
              'FEC_Support_Mailbox',
              'FEC_Care_Mailbox',
              'FEC_Ecom_Mailbox',
              'FEC_Office_Based_Mailbox',
              'FEC_Day_2_Check',
              'FEC_OM_Mailbox',
              'FEC_Quality_Control_Mailbox'
          )
    ]) {
      queueDevNameToId.put(g.DeveloperName, g.Id);
    }
    // Luồng 4 - Email
    Set<String> emailChannelSet = new Set<String>{ 'Email' };
    Set<String> sendToSet = new Set<String>{ 'dichvukhachhang@ubank.vn' };
    Set<Id> ubankEmailQueueIds = new Set<Id>();
    if (queueDevNameToId.containsKey('FEC_Ubank_Email')) {
      ubankEmailQueueIds.add(queueDevNameToId.get('FEC_Ubank_Email'));
    }
    
    Set<Id> userUBankIds = new Set<Id>();
    
    List<GroupMember> groupMembersUbankEmail = [
    SELECT UserOrGroupId
    FROM GroupMember
    WHERE GroupId IN :ubankEmailQueueIds
    ];
    
    for (GroupMember gm : groupMembersUbankEmail) {
      if (gm.UserOrGroupId.getSObjectType() == User.SObjectType) {
        userUBankIds.add(gm.UserOrGroupId);
      }
    }
    
    // Luồng 5 - Internal Email
    Set<String> internalChannelSet = new Set<String>{ 'Internal' };
    Set<String> internalSubChannelSet = new Set<String>{ 'Internal Email' };
    Set<Id> internalMailboxQueueIds = new Set<Id>();
    
    for (String key : new List<String>{
      'FEC_CSM_Mailbox',
      'FEC_Support_Mailbox',
      'FEC_Care_Mailbox',
      'FEC_Ecom_Mailbox',
      'FEC_Office_Based_Mailbox',
      'FEC_Day_2_Check',
      'FEC_OM_Mailbox',
      'FEC_Quality_Control_Mailbox'
    }) {
      if (queueDevNameToId.containsKey(key)) {
        internalMailboxQueueIds.add(queueDevNameToId.get(key));
      }
    }
    
    Set<Id> userInternalMailIds = new Set<Id>();
    
    List<GroupMember> groupMembersInternalMail = [
    SELECT UserOrGroupId
    FROM GroupMember
    WHERE GroupId IN :internalMailboxQueueIds
    ];
    
    for (GroupMember gm : groupMembersInternalMail) {
      if (gm.UserOrGroupId.getSObjectType() == User.SObjectType) {
        userInternalMailIds.add(gm.UserOrGroupId);
      }
    }
    
    // return Database.getQueryLocator(
    //   'SELECT Id, RecordTypeId, Status, OwnerId  ' +
    //   'FROM Case ' +
    //   'WHERE RecordType.DeveloperName = \'Interaction\' AND Status IN :statuslst AND FEC_Interaction_Status__c  IN :interationStatuslst'
    //   );
    
    String query =
      'SELECT Id, RecordTypeId, Status, OwnerId, ' +
      'FEC_Channel__c, FEC_Interaction_Subchannel__c, FEC_Send_To__c, IsClosed ' +
      'FROM Case ' +
      'WHERE RecordType.DeveloperName = \'Interaction\' ' +
      'AND Status IN :statuslst ' +
      'AND FEC_Interaction_Status__c IN :interationStatuslst ' +
      
    'AND NOT ( ' +
      'FEC_Channel__c = \'Email\' ' +
      'AND IsClosed = FALSE ' +
      'AND FEC_Send_To__c = \'dichvukhachhang@ubank.vn\' ' +
      'AND OwnerId IN :userUBankIds ' +
      ') ' +
      
    'AND NOT ( ' +
      'FEC_Channel__c = \'Internal\' ' +
      'AND FEC_Interaction_Subchannel__c = \'Internal Email\' ' +
      'AND IsClosed = FALSE ' +
      'AND OwnerId IN :userInternalMailIds ' +
      ')';
    
    return Database.getQueryLocator(query);
  }
  
  public void execute(Database.BatchableContext bc, List<Case> scope) {
    List<Case> interationlst = new List<Case>();
    
    for (Case item : scope) {
      if (
        String.isNotBlank(item.OwnerId) &&
        item.OwnerId.getSObjectType() == User.SObjectType
      ) {
        interationlst.add(item);
      }
    }
    
    if (interationlst.isEmpty())
      return;
    
    List<User> userlst = [
      SELECT Id, Email, UserRole.Name
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];
    
    User currUser = userlst.get(0);
    String emailId;
    String roleName;
    
    if (currUser != null) {
      emailId = currUser.Email?.substringBefore('@');
      roleName = currUser.UserRole?.Name;
    }
    
    Map<Id, Case> interationMap = new Map<Id, Case>(interationlst);
    Map<Id, List<Case>> interationToServiceCaseMap = new Map<Id, List<Case>>();
    
    List<Case> updatedlst = new List<Case>();
    
    List<Case> serviceCaselst = [
      SELECT
        Id,
        FEC_Interaction__c,
        Status,
        FEC_Is_Submited__c,
        FEC_Stage_Name__c
      FROM Case
      WHERE
        FEC_Interaction__c IN :interationMap.keySet()
        AND FEC_Is_Submited__c = FALSE
    ];
    
    for (Case item : serviceCaselst) {
      if (String.isNotBlank(item.FEC_Interaction__c)) {
        if (!interationToServiceCaseMap.containsKey(item.FEC_Interaction__c))
          interationToServiceCaseMap.put(
          item.FEC_Interaction__c,
        new List<Case>()
          );
        
        interationToServiceCaseMap.get(item.FEC_Interaction__c).add(item);
      }
    }
    
    List<FEC_Case_Remarks__c> remarklst = new List<FEC_Case_Remarks__c>();
    
    for (Case item : interationlst) {
      if (interationToServiceCaseMap.containsKey(item.Id)) {
        for (Case child : interationToServiceCaseMap.get(item.Id)) {
          child.Status = FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED;
          
          updatedlst.add(child);
          
          FEC_Case_Remarks__c caseRemark = new FEC_Case_Remarks__c();
          caseRemark.FEC_Case_Remarks__c = Label.FEC_RemarkMsg;
          caseRemark.FEC_User__c = emailId;
          caseRemark.FEC_User_Role__c = roleName;
          caseRemark.FEC_Stage_Name__c = child.FEC_Stage_Name__c;
          caseRemark.FEC_Case__c = child.Id;
          
          remarklst.add(caseRemark);
        }
      }
      
      item.Status = FEC_ConstantCommon.CASE_STATUS_AUTO_CLOSED;
      item.FEC_Outcome_Code__c = FEC_ConstantCommon.OUTCOME_CODE_COMPLETED;
      item.FEC_Interaction_Remarks__c = null;
      
      updatedlst.add(item);
    }
    
    if (!updatedlst.isEmpty()) {
      FEC_CaseTriggerHandler.isExecuting = true;
      update updatedlst;
      FEC_CaseTriggerHandler.isExecuting = false;
    }
    
    if (!remarklst.isEmpty())
      insert remarklst;
  }
  
  public void finish(Database.BatchableContext bc) {
  }
}