// Handler ContentDocumentLink: chặn gắn/gỡ/share file khi Case đang review hoặc Interaction không handling.
public without sharing class FEC_ContentDocumentLinkTriggerHandler {
  private static Boolean isExecuting = false;

  public void run() {
    if (Trigger.isBefore && Trigger.isInsert) {
      if (isExecuting) {
        return;
      }
      isExecuting = true;
      try {
        onBeforeInsert(Trigger.new);
      } finally {
        isExecuting = false;
      }
    }

    if (Trigger.isBefore && Trigger.isDelete) {
      onBeforeDelete(Trigger.old);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
      //   handler.onBeforeUpdate(newCases, oldMap);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
      if (isExecuting) {
        return;
      }
      isExecuting = true;
      try {
        onAfterInsert(Trigger.new);
      } finally {
        isExecuting = false;
      }
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
      //   handler.onAfterUpdate(newCases, oldMap);
    }
  }

  private void onBeforeInsert(List<ContentDocumentLink> newlst) {
    preventUploadInCaseReview(newlst);
    preventShareWhenFileOnReviewCase(newlst);
  }

  private void onBeforeDelete(List<ContentDocumentLink> oldlst) {
    preventRemoveFromRecordInCaseReview(oldlst);
  }

  // Share: một số luồng Lightning chỉ fire after insert; xóa CDL vi phạm để share không lưu.
  private void onAfterInsert(List<ContentDocumentLink> newlst) {
    undoShareWhenFileOnReviewCase(newlst);
  }

  // Chặn gắn file vào Case đang review hoặc Interaction không handling.
  private void preventUploadInCaseReview(List<ContentDocumentLink> newlst) {
    Set<Id> caseIds = new Set<Id>();
    for (ContentDocumentLink cdl : newlst) {
      if (cdl.LinkedEntityId != null && cdl.LinkedEntityId.getSObjectType() == Case.SObjectType) {
        caseIds.add(cdl.LinkedEntityId);
      }
    }
    if (caseIds.isEmpty()) {
      return;
    }
    Set<Id> caseIdsToBlock = FEC_FileActionOnReviewService.getCaseIdsThatBlockFileActions(caseIds);
    for (ContentDocumentLink cdl : newlst) {
      if (caseIdsToBlock.contains(cdl.LinkedEntityId)) {
        cdl.addError(FEC_FileActionOnReviewService.ERROR_FILE_ACTION_IN_REVIEW);
      }
    }
  }

  // Chặn gỡ file khỏi record khi Case đang review.
  private void preventRemoveFromRecordInCaseReview(List<ContentDocumentLink> oldlst) {
    Set<Id> caseIds = new Set<Id>();
    for (ContentDocumentLink cdl : oldlst) {
      if (cdl.LinkedEntityId != null && cdl.LinkedEntityId.getSObjectType() == Case.SObjectType) {
        caseIds.add(cdl.LinkedEntityId);
      }
    }
    if (caseIds.isEmpty()) {
      return;
    }
    Set<Id> caseIdsToBlock = FEC_FileActionOnReviewService.getCaseIdsThatBlockFileActions(caseIds);
    for (ContentDocumentLink cdl : oldlst) {
      if (caseIdsToBlock.contains(cdl.LinkedEntityId)) {
        cdl.addError(FEC_FileActionOnReviewService.ERROR_FILE_ACTION_IN_REVIEW);
      }
    }
  }

  // Chặn Share khi file đã gắn Case review; xét cả link hiện có và link trong batch.
  private void preventShareWhenFileOnReviewCase(List<ContentDocumentLink> newlst) {
    Set<Id> docIds = new Set<Id>();
    for (ContentDocumentLink cdl : newlst) {
      docIds.add(cdl.ContentDocumentId);
    }
    if (docIds.isEmpty()) {
      return;
    }
    Set<Id> blockedDocIds = FEC_FileActionOnReviewService.getContentDocumentIdsLinkedToReviewCases(docIds);
    Set<Id> caseIdsInBatch = new Set<Id>();
    for (ContentDocumentLink cdl : newlst) {
      if (cdl.LinkedEntityId != null && cdl.LinkedEntityId.getSObjectType() == Case.SObjectType) {
        caseIdsInBatch.add(cdl.LinkedEntityId);
      }
    }
    if (!caseIdsInBatch.isEmpty()) {
      Set<Id> caseIdsToBlock = FEC_FileActionOnReviewService.getCaseIdsThatBlockFileActions(caseIdsInBatch);
      for (ContentDocumentLink cdl : newlst) {
        if (cdl.LinkedEntityId != null && caseIdsToBlock.contains(cdl.LinkedEntityId)) {
          blockedDocIds.add(cdl.ContentDocumentId);
        }
      }
    }
    for (ContentDocumentLink cdl : newlst) {
      if (!blockedDocIds.contains(cdl.ContentDocumentId)) {
        continue;
      }
      if (cdl.LinkedEntityId != null && cdl.LinkedEntityId.getSObjectType() == Case.SObjectType) {
        continue;
      }
      cdl.addError(FEC_FileActionOnReviewService.ERROR_FILE_ACTION_IN_REVIEW);
    }
  }

  // After-insert: xóa link Share (tới User/Group) khi file gắn Case review.
  private void undoShareWhenFileOnReviewCase(List<ContentDocumentLink> newlst) {
    Set<Id> docIds = new Set<Id>();
    for (ContentDocumentLink cdl : newlst) {
      docIds.add(cdl.ContentDocumentId);
    }
    if (docIds.isEmpty()) {
      return;
    }
    Set<Id> blockedDocIds = FEC_FileActionOnReviewService.getContentDocumentIdsLinkedToReviewCases(docIds);
    List<ContentDocumentLink> toDelete = new List<ContentDocumentLink>();
    for (ContentDocumentLink cdl : newlst) {
      if (!blockedDocIds.contains(cdl.ContentDocumentId)) {
        continue;
      }
      if (cdl.LinkedEntityId != null && cdl.LinkedEntityId.getSObjectType() == Case.SObjectType) {
        continue;
      }
      toDelete.add(cdl);
    }
    if (!toDelete.isEmpty()) {
      delete toDelete;
    }
  }
}