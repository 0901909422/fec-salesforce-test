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

  // Chặn Upload phiên bản mới khi file gắn Case Review (chỉ khi đã có ContentDocumentId).
  private void onBeforeInsert(List<ContentVersion> newlst) {
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
