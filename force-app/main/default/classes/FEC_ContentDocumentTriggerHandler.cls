// Handler ContentDocument: chặn Xóa file khi file gắn Case đang Review.
public without sharing class FEC_ContentDocumentTriggerHandler {
  public void run() {
    if (Trigger.isBefore && Trigger.isDelete) {
      onBeforeDelete(Trigger.old);
    }
  }

  // Chặn xóa khi file gắn Case review hoặc khi Case stage khác stage lúc attach (FEC_Stage_ID__c).
  private void onBeforeDelete(List<ContentDocument> oldlst) {
    Set<Id> docIds = new Set<Id>();
    for (ContentDocument cd : oldlst) {
      docIds.add(cd.Id);
    }
    Set<Id> blockedDocIds = FEC_FileActionOnReviewService.getContentDocumentIdsLinkedToReviewCases(docIds);
    Set<Id> stageMismatchDocIds = getContentDocumentIdsWithCaseStageMismatch(docIds);
    for (ContentDocument cd : oldlst) {
      if (blockedDocIds.contains(cd.Id)) {
        cd.addError(FEC_FileActionOnReviewService.ERROR_FILE_ACTION_IN_REVIEW);
      } else if (stageMismatchDocIds.contains(cd.Id)) {
        cd.addError(FEC_FileActionOnReviewService.ERROR_FILE_DELETE_STAGE_MISMATCH);
      }
    }
  }

  // Trả về Set ContentDocument Id: file gắn Case mà FEC_Current_Case_Stage__c khác FEC_Stage_ID__c (stage lúc attach).
  private Set<Id> getContentDocumentIdsWithCaseStageMismatch(Set<Id> contentDocumentIds) {
    if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
      return new Set<Id>();
    }
    List<ContentDocumentLink> links = [
      SELECT ContentDocumentId, LinkedEntityId
      FROM ContentDocumentLink
      WHERE ContentDocumentId IN :contentDocumentIds
    ];
    Set<Id> caseIds = new Set<Id>();
    Map<Id, Set<Id>> docIdToCaseIds = new Map<Id, Set<Id>>();
    for (ContentDocumentLink cdl : links) {
      if (cdl.LinkedEntityId != null && cdl.LinkedEntityId.getSObjectType() == Case.SObjectType) {
        caseIds.add(cdl.LinkedEntityId);
        if (!docIdToCaseIds.containsKey(cdl.ContentDocumentId)) {
          docIdToCaseIds.put(cdl.ContentDocumentId, new Set<Id>());
        }
        docIdToCaseIds.get(cdl.ContentDocumentId).add(cdl.LinkedEntityId);
      }
    }
    if (caseIds.isEmpty()) {
      return new Set<Id>();
    }
    Map<Id, Id> caseIdToCurrentStage = new Map<Id, Id>();
    for (Case c : [SELECT Id, FEC_Current_Case_Stage__c FROM Case WHERE Id IN :caseIds]) {
      caseIdToCurrentStage.put(c.Id, c.FEC_Current_Case_Stage__c);
    }
    Map<Id, Id> docIdToAttachStage = new Map<Id, Id>();
    for (ContentVersion cv : [SELECT Id, ContentDocumentId, FEC_Stage_ID__c FROM ContentVersion WHERE ContentDocumentId IN :contentDocumentIds AND IsLatest = true]) {
      docIdToAttachStage.put(cv.ContentDocumentId, cv.FEC_Stage_ID__c);
    }
    Set<Id> mismatchDocIds = new Set<Id>();
    for (Id docId : docIdToCaseIds.keySet()) {
      Id attachStageId = docIdToAttachStage.get(docId);
      if (attachStageId == null) {
        continue;
      }
      for (Id caseId : docIdToCaseIds.get(docId)) {
        Id currentStageId = caseIdToCurrentStage.get(caseId);
        if (currentStageId != attachStageId) {
          mismatchDocIds.add(docId);
          break;
        }
      }
    }
    return mismatchDocIds;
  }
}
