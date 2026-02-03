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

    return Database.getQueryLocator(
      'SELECT Id, RecordTypeId, Status ' +
        'FROM Case ' +
        'WHERE RecordType.DeveloperName = \'Interaction\' AND Status IN :statuslst'
    );
  }

  public void execute(Database.BatchableContext bc, List<Case> scope) {
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

    Map<Id, Case> interationMap = new Map<Id, Case>(scope);
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

    for (Case item : scope) {
      if (interationToServiceCaseMap.containsKey(item.Id)) {
        for (Case child : interationToServiceCaseMap.get(item.Id)) {
          child.Status = 'Resolved-Cancelled';

          updatedlst.add(child);

          FEC_Case_Remarks__c caseRemark = new FEC_Case_Remarks__c();
          caseRemark.FEC_Case_Remarks__c = 'Yêu cầu được tự động chuyển trạng thái Resolved-AutoCancelled theo quy trình tự động kết thúc tương tác cuối ngày';
          caseRemark.FEC_User__c = emailId;
          caseRemark.FEC_User_Role__c = roleName;
          caseRemark.FEC_Stage_Name__c = child.FEC_Stage_Name__c;
          caseRemark.FEC_Case__c = child.Id;

          remarklst.add(caseRemark);
        }
      }

      item.Status = 'Auto-Closed';
      updatedlst.add(item);
    }

    if (!updatedlst.isEmpty())
      update updatedlst;

    if (!remarklst.isEmpty())
      insert remarklst;
  }

  public void finish(Database.BatchableContext bc) {
  }
}