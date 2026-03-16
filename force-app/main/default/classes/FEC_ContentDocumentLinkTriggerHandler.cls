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
    preventCaseLinksExceeding2GBTotal(newlst);
  }

  private void onBeforeDelete(List<ContentDocumentLink> oldlst) {
    preventRemoveFromRecordInCaseReview(oldlst);
  }

  // Share: một số luồng Lightning chỉ fire after insert; xóa CDL vi phạm để share không lưu.
  private void onAfterInsert(List<ContentDocumentLink> newlst) {
    undoShareWhenFileOnReviewCase(newlst);
    setContentVersionStageWhenAttachToCase(newlst);
  }

  // Lưu FEC_Current_Case_Stage__c của Case vào FEC_Stage_ID__c trên ContentVersion khi attach file vào Case.
  private void setContentVersionStageWhenAttachToCase(List<ContentDocumentLink> newlst) {
    Set<Id> caseIds = new Set<Id>();
    Set<Id> docIds = new Set<Id>();
    for (ContentDocumentLink cdl : newlst) {
      if (cdl.LinkedEntityId != null && cdl.LinkedEntityId.getSObjectType() == Case.SObjectType) {
        caseIds.add(cdl.LinkedEntityId);
        docIds.add(cdl.ContentDocumentId);
      }
    }
    if (caseIds.isEmpty() || docIds.isEmpty()) {
      return;
    }
    Map<Id, Id> caseIdToStageId = new Map<Id, Id>();
    for (Case c : [SELECT Id, FEC_Current_Case_Stage__c FROM Case WHERE Id IN :caseIds]) {
      caseIdToStageId.put(c.Id, c.FEC_Current_Case_Stage__c);
    }
    Map<Id, Id> docIdToLatestCvId = new Map<Id, Id>();
    for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE ContentDocumentId IN :docIds AND IsLatest = true]) {
      docIdToLatestCvId.put(cv.ContentDocumentId, cv.Id);
    }
    Map<Id, ContentVersion> toUpdate = new Map<Id, ContentVersion>();
    for (ContentDocumentLink cdl : newlst) {
      if (cdl.LinkedEntityId == null || cdl.LinkedEntityId.getSObjectType() != Case.SObjectType) {
        continue;
      }
      Id stageId = caseIdToStageId.get(cdl.LinkedEntityId);
      Id cvId = docIdToLatestCvId.get(cdl.ContentDocumentId);
      if (stageId != null && cvId != null) {
        toUpdate.put(cvId, new ContentVersion(Id = cvId, FEC_Stage_ID__c = stageId));
      }
    }
    if (!toUpdate.isEmpty()) {
      update toUpdate.values();
    }
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

  // Tổng dung lượng file gắn Case giới hạn 2GB. Chặn gắn (addError) theo thứ tự chọn: file khiến tổng vượt 2GB không được gắn.
  private void preventCaseLinksExceeding2GBTotal(List<ContentDocumentLink> newlst) {
    List<ContentDocumentLink> caseLinks = new List<ContentDocumentLink>();
    for (ContentDocumentLink cdl : newlst) {
      if (cdl.LinkedEntityId != null && cdl.LinkedEntityId.getSObjectType() == Case.SObjectType) {
        caseLinks.add(cdl);
      }
    }
    if (caseLinks.isEmpty()) {
      return;
    }
    Set<Id> caseIds = new Set<Id>();
    Set<Id> newDocIds = new Set<Id>();
    for (ContentDocumentLink cdl : caseLinks) {
      caseIds.add(cdl.LinkedEntityId);
      newDocIds.add(cdl.ContentDocumentId);
    }
    Map<Id, Integer> docIdToSize = new Map<Id, Integer>();
    for (ContentVersion cv : [SELECT ContentDocumentId, ContentSize FROM ContentVersion WHERE ContentDocumentId IN :newDocIds AND IsLatest = true]) {
      docIdToSize.put(cv.ContentDocumentId, cv.ContentSize != null ? Integer.valueOf(cv.ContentSize) : 0);
    }
    List<ContentDocumentLink> existingLinks = [
      SELECT ContentDocumentId, LinkedEntityId
      FROM ContentDocumentLink
      WHERE LinkedEntityId IN :caseIds
    ];
    Set<Id> existingDocIds = new Set<Id>();
    for (ContentDocumentLink l : existingLinks) {
      existingDocIds.add(l.ContentDocumentId);
    }
    Map<Id, Integer> existingDocIdToSize = new Map<Id, Integer>();
    if (!existingDocIds.isEmpty()) {
      for (ContentVersion cv : [SELECT ContentDocumentId, ContentSize FROM ContentVersion WHERE ContentDocumentId IN :existingDocIds AND IsLatest = true]) {
        existingDocIdToSize.put(cv.ContentDocumentId, cv.ContentSize != null ? Integer.valueOf(cv.ContentSize) : 0);
      }
    }
    Map<Id, Long> caseIdToCurrentTotal = new Map<Id, Long>();
    for (ContentDocumentLink l : existingLinks) {
      Integer sz = existingDocIdToSize.get(l.ContentDocumentId);
      if (sz == null) {
        sz = 0;
      }
      Long prev = caseIdToCurrentTotal.get(l.LinkedEntityId);
      caseIdToCurrentTotal.put(l.LinkedEntityId, (prev != null ? prev : 0L) + sz);
    }
    Map<Id, List<ContentDocumentLink>> caseIdToNewLinksInOrder = new Map<Id, List<ContentDocumentLink>>();
    for (ContentDocumentLink cdl : caseLinks) {
      Id cid = cdl.LinkedEntityId;
      if (!caseIdToNewLinksInOrder.containsKey(cid)) {
        caseIdToNewLinksInOrder.put(cid, new List<ContentDocumentLink>());
      }
      caseIdToNewLinksInOrder.get(cid).add(cdl);
    }
    Long maxBytes = FEC_FileActionOnReviewService.MAX_FILE_SIZE_BYTES;
    for (Id caseId : caseIds) {
      Long runningTotal = caseIdToCurrentTotal.get(caseId);
      if (runningTotal == null) {
        runningTotal = 0L;
      }
      List<ContentDocumentLink> ordered = caseIdToNewLinksInOrder.get(caseId);
      if (ordered == null) {
        continue;
      }
      for (ContentDocumentLink cdl : ordered) {
        Integer sz = docIdToSize.get(cdl.ContentDocumentId);
        if (sz == null) {
          sz = 0;
        }
        if (runningTotal + sz > maxBytes) {
          cdl.addError(FEC_FileActionOnReviewService.ERROR_CASE_FILE_TOTAL_EXCEEDS_2GB);
        } else {
          runningTotal += sz;
        }
      }
    }
  }
}