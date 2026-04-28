// Handler ContentVersion: chặn Upload phiên bản mới và Sửa chi tiết file khi file gắn Case đang Review.
public without sharing class FEC_ContentVersionTriggerHandler {
  public void run() {
    if (Trigger.isBefore && Trigger.isInsert) {
      onBeforeInsert(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
      onBeforeUpdate(Trigger.new);
    }
  }

  // Chặn Upload phiên bản mới khi file gắn Case Review (chỉ khi đã có ContentDocumentId). Chặn upload file đơn >2GB.
  private void onBeforeInsert(List<ContentVersion> newlst) {
    for (ContentVersion cv : newlst) {
      if (cv.ContentDocumentId == null && cv.VersionData != null && cv.VersionData.size() > FEC_FileActionOnReviewService.MAX_FILE_SIZE_BYTES) {
        cv.addError(FEC_FileActionOnReviewService.ERROR_FILE_SIZE_EXCEEDS_2GB);
      }
    }
    Set<Id> docIds = new Set<Id>();
    for (ContentVersion cv : newlst) {
      if (cv.ContentDocumentId != null) {
        docIds.add(cv.ContentDocumentId);
      }
    }
    if (docIds.isEmpty()) {
      return;
    }
    Set<Id> blockedDocIds = FEC_FileActionOnReviewService.getContentDocumentIdsLinkedToReviewCases(docIds);
    Map<Id, Id> docIdToPreviousStageId = getPreviousLatestStageIdByContentDocumentId(docIds);
    for (ContentVersion cv : newlst) {
      if (cv.ContentDocumentId != null && blockedDocIds.contains(cv.ContentDocumentId)) {
        cv.addError(FEC_FileActionOnReviewService.ERROR_FILE_ACTION_IN_REVIEW);
      } else if (cv.ContentDocumentId != null && cv.FEC_Stage_ID__c == null) {
        Id prevStageId = docIdToPreviousStageId.get(cv.ContentDocumentId);
        if (prevStageId != null) {
          cv.FEC_Stage_ID__c = prevStageId;
        }
      }
    }
  }

  // Lấy FEC_Stage_ID__c của bản latest hiện tại (trước khi insert bản mới) theo ContentDocumentId.
  private Map<Id, Id> getPreviousLatestStageIdByContentDocumentId(Set<Id> contentDocumentIds) {
    Map<Id, Id> docIdToStageId = new Map<Id, Id>();
    if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
      return docIdToStageId;
    }
    for (ContentVersion cv : [SELECT ContentDocumentId, FEC_Stage_ID__c FROM ContentVersion WHERE ContentDocumentId IN :contentDocumentIds AND IsLatest = true]) {
      if (cv.FEC_Stage_ID__c != null) {
        docIdToStageId.put(cv.ContentDocumentId, cv.FEC_Stage_ID__c);
      }
    }
    return docIdToStageId;
  }

  // Chặn Sửa chi tiết file khi file gắn Case Review.
  private void onBeforeUpdate(List<ContentVersion> newlst) {
    Set<Id> docIds = new Set<Id>();
    for (ContentVersion cv : newlst) {
      if (cv.ContentDocumentId != null) {
        docIds.add(cv.ContentDocumentId);
      }
    }
    if (docIds.isEmpty()) {
      return;
    }
    Set<Id> blockedDocIds = FEC_FileActionOnReviewService.getContentDocumentIdsLinkedToReviewCases(docIds);
    for (ContentVersion cv : newlst) {
      if (cv.ContentDocumentId != null && blockedDocIds.contains(cv.ContentDocumentId)) {
        cv.addError(FEC_FileActionOnReviewService.ERROR_FILE_ACTION_IN_REVIEW);
      }
    }
  }
}