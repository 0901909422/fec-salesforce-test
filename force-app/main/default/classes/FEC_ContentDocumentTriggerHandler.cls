// Handler ContentDocument: chặn Xóa file khi file gắn Case đang Review.
public without sharing class FEC_ContentDocumentTriggerHandler {
  public void run() {
    if (Trigger.isBefore && Trigger.isDelete) {
      onBeforeDelete(Trigger.old);
    }
  }

  // Chặn xóa khi file gắn Case review.
  private void onBeforeDelete(List<ContentDocument> oldlst) {
    Set<Id> docIds = new Set<Id>();
    for (ContentDocument cd : oldlst) {
      docIds.add(cd.Id);
    }
    Set<Id> blockedDocIds = FEC_FileActionOnReviewService.getContentDocumentIdsLinkedToReviewCases(docIds);
    for (ContentDocument cd : oldlst) {
      if (blockedDocIds.contains(cd.Id)) {
        cd.addError(FEC_FileActionOnReviewService.ERROR_FILE_ACTION_IN_REVIEW);
      }
    }
  }
}
