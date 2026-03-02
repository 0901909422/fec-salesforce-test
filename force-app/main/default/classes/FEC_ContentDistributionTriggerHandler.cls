// Handler ContentDistribution: chặn Public Link khi file gắn Case đang Review.
public without sharing class FEC_ContentDistributionTriggerHandler {
  public void run() {
    if (Trigger.isBefore && Trigger.isInsert) {
      onBeforeInsert(Trigger.new);
    }
  }

  // Chặn Public Link khi file gắn Case Review; lấy ContentDocumentId từ ContentVersion.
  private void onBeforeInsert(List<ContentDistribution> newlst) {
    Set<Id> docIds = new Set<Id>();
    Set<Id> versionIds = new Set<Id>();
    for (ContentDistribution cd : newlst) {
      if (cd.ContentDocumentId != null) {
        docIds.add(cd.ContentDocumentId);
      } else if (cd.ContentVersionId != null) {
        versionIds.add(cd.ContentVersionId);
      }
    }
    Map<Id, Id> versionToDocId = new Map<Id, Id>();
    if (versionIds.isEmpty() == false) {
      for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :versionIds]) {
        if (cv.ContentDocumentId != null) {
          docIds.add(cv.ContentDocumentId);
          versionToDocId.put(cv.Id, cv.ContentDocumentId);
        }
      }
    }
    if (docIds.isEmpty()) {
      return;
    }
    Set<Id> blockedDocIds = FEC_FileActionOnReviewService.getContentDocumentIdsLinkedToReviewCases(docIds);
    for (ContentDistribution cd : newlst) {
      Id docId = cd.ContentDocumentId;
      if (docId == null && cd.ContentVersionId != null) {
        docId = versionToDocId.get(cd.ContentVersionId);
      }
      if (docId != null && blockedDocIds.contains(docId)) {
        cd.addError(FEC_FileActionOnReviewService.ERROR_FILE_ACTION_IN_REVIEW);
      }
    }
  }
}
