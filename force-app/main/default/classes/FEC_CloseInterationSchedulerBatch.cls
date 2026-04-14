public without sharing class FEC_CloseInterationSchedulerBatch implements Schedulable, Database.Batchable<SObject> {
  public FEC_CloseInterationSchedulerBatch() {
  }
  
  // ================= SCHEDULABLE =================
  public void execute(SchedulableContext sc) {
    Database.executeBatch(this, 200);
  }
  
  // ================= BATCH =================
  public Database.QueryLocator start(Database.BatchableContext bc) {
    Set<String> statuslst = new Set<String>{ FEC_ConstantCommon.CASE_STATUS_OPEN };
    Set<String> interationStatuslst = new Set<String>{ FEC_ConstantCommon.CASE_STATUS_OPEN };
    
    Map<String, Id> queueDevNameToId = new Map<String, Id>();
    
    Set<String> queueNames = new Set<String>{
      FEC_ConstantCommon.QUEUE_UBANK_EMAIL_NAME,
      FEC_ConstantCommon.QUEUE_CSM_MAILBOX_NAME,
      FEC_ConstantCommon.QUEUE_SUPPORT_MAILBOX_NAME,
      FEC_ConstantCommon.QUEUE_CARE_MAILBOX_NAME,
      FEC_ConstantCommon.QUEUE_ECOM_MAILBOX_NAME,
      FEC_ConstantCommon.QUEUE_OFFICE_BASED_MAILBOX_NAME,
      FEC_ConstantCommon.QUEUE_DAY_2_CHECK_NAME,
      FEC_ConstantCommon.QUEUE_OM_MAILBOX_NAME,
      FEC_ConstantCommon.QUEUE_QUALITY_CONTROL_MAILBOX_NAME
    };
    
    List<Group> groups = [
      SELECT Id, DeveloperName
      FROM Group
      WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
      AND DeveloperName IN :queueNames
    ];
    
    for (Group g : groups) {
      queueDevNameToId.put(g.DeveloperName, g.Id);
    }
    // Luồng 4 - Email
    Set<String> emailChannelSet = new Set<String>{ FEC_ConstantCommon.EMAIL };
    Set<String> sendToSet = new Set<String>{ FEC_ConstantCommon.EMAIL_UBANK_VN };
    Set<Id> ubankEmailQueueIds = new Set<Id>();
    if (queueDevNameToId.containsKey(FEC_ConstantCommon.QUEUE_UBANK_EMAIL_NAME)) {
      ubankEmailQueueIds.add(queueDevNameToId.get(FEC_ConstantCommon.QUEUE_UBANK_EMAIL_NAME));
    }
    
    // Set<Id> userUBankIds = new Set<Id>();
    
    // List<GroupMember> groupMembersUbankEmail = [
    // SELECT UserOrGroupId
    // FROM GroupMember
    // WHERE GroupId IN :ubankEmailQueueIds
    // ];
    
    // for (GroupMember gm : groupMembersUbankEmail) {
      //   if (gm.UserOrGroupId.getSObjectType() == User.SObjectType) {
        //     userUBankIds.add(gm.UserOrGroupId);
      //   }
    // }
    
    // Luồng 5 - Internal Email
    Set<String> internalChannelSet = new Set<String>{ FEC_ConstantCommon.CHANNEL_INTERNAL };
    Set<String> internalSubChannelSet = new Set<String>{ FEC_ConstantCommon.SUBCHANNEL_INTERNAL_EMAIL };
    Set<Id> internalMailboxQueueIds = new Set<Id>();
    
    for (String key : new List<String>{
      FEC_ConstantCommon.QUEUE_CSM_MAILBOX_NAME,
      FEC_ConstantCommon.QUEUE_SUPPORT_MAILBOX_NAME,
      FEC_ConstantCommon.QUEUE_CARE_MAILBOX_NAME,
      FEC_ConstantCommon.QUEUE_ECOM_MAILBOX_NAME,
      FEC_ConstantCommon.QUEUE_OFFICE_BASED_MAILBOX_NAME,
      FEC_ConstantCommon.QUEUE_DAY_2_CHECK_NAME,
      FEC_ConstantCommon.QUEUE_OM_MAILBOX_NAME,
      FEC_ConstantCommon.QUEUE_QUALITY_CONTROL_MAILBOX_NAME
    }) {
      if (queueDevNameToId.containsKey(key)) {
        internalMailboxQueueIds.add(queueDevNameToId.get(key));
      }
    }
    
    // Set<Id> userInternalMailIds = new Set<Id>();
    
    // List<GroupMember> groupMembersInternalMail = [
    // SELECT UserOrGroupId
    // FROM GroupMember
    // WHERE GroupId IN :internalMailboxQueueIds
    // ];
    
    // for (GroupMember gm : groupMembersInternalMail) {
      //   if (gm.UserOrGroupId.getSObjectType() == User.SObjectType) {
        //     userInternalMailIds.add(gm.UserOrGroupId);
      //   }
    // }
    
    Set<String> internalSendToSet = new Set<String>{
      FEC_ConstantCommon.EMAIL_SUPPORT_CSM,
      FEC_ConstantCommon.EMAIL_CS_SUPPORT,
      FEC_ConstantCommon.EMAIL_CUSTOMER_CARE,
      FEC_ConstantCommon.EMAIL_E_COM,
      FEC_ConstantCommon.EMAIL_F2F,
      FEC_ConstantCommon.EMAIL_CS_D2C,
      FEC_ConstantCommon.EMAIL_CS_OM,
      FEC_ConstantCommon.EMAIL_CS_QC_TEAM
    };
    
    
    
    String query =
      'SELECT Id, RecordTypeId, Status, OwnerId, ' +
      'FEC_Channel__c, FEC_Interaction_Subchannel__c, FEC_Send_To__c, IsClosed ' +
      'FROM Case ' +
      'WHERE RecordType.DeveloperName = \'' + FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME + '\' ' +
      'AND Status IN :statuslst ' +
      'AND FEC_Interaction_Status__c IN :interationStatuslst ' +
      
    'AND (FEC_Channel__c != \'Email\' ' +
      '     OR IsClosed = TRUE ' +
      '     OR FEC_Send_To__c != \'' + FEC_ConstantCommon.EMAIL_UBANK_VN + '\' '  +
      '     OR (Owner.Type != \'User\' AND OwnerId NOT IN :ubankEmailQueueIds) ' +
      ') ' +
      
    'AND (FEC_Channel__c != \'Internal\' ' +
      '     OR FEC_Interaction_Subchannel__c != \'' + FEC_ConstantCommon.SUBCHANNEL_INTERNAL_EMAIL + '\' ' +
      '     OR IsClosed = TRUE ' +
      '     OR FEC_Send_To__c NOT IN :internalSendToSet ' +
      '     OR (Owner.Type != \'User\' AND OwnerId NOT IN :internalMailboxQueueIds)' +
      ') ';
    System.debug('### Batch Query: ');
    System.debug(query);
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