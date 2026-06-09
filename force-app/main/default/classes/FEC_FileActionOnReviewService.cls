public without sharing class FEC_FileActionOnReviewService {
  /** Giới hạn dung lượng file đơn (2GB) khi upload, đơn vị byte. */
  public static final Long MAX_FILE_SIZE_BYTES = 2L * 1024 * 1024 * 1024;
  public static final String ERROR_FILE_ACTION_IN_REVIEW = 'Cannot perform this action on the file while the Case is in Review mode.';
  public static final String ERROR_FILE_DELETE_STAGE_MISMATCH = 'Cannot delete file: Case must be in the same stage as when the file was attached.';
  /** Thông báo khi upload file đơn vượt quá 2GB. */
  public static final String ERROR_FILE_SIZE_EXCEEDS_2GB = 'Dung lượng file vượt quá 2GB. Hệ thống không cho phép upload file có dung lượng lớn hơn 2GB.';
  /** Thông báo khi tổng file gắn Case vượt 2GB (file không được gắn). */
  public static final String ERROR_CASE_FILE_TOTAL_EXCEEDS_2GB = 'Tổng dung lượng file gắn Case không được vượt quá 2GB. File này không được gắn vào Case.';

  // Trả về Set Case Id đang ở trạng thái chặn thao tác file (review hoặc Interaction không handling).
  public static Set<Id> getCaseIdsThatBlockFileActions(Set<Id> caseIds) {
    if (caseIds == null || caseIds.isEmpty()) {
      return new Set<Id>();
    }
    List<Case> cases = [
      SELECT Id, RecordType.DeveloperName, FEC_Interaction_View_Mode__c
      FROM Case
      WHERE Id IN :caseIds
    ];
    Set<Id> block = new Set<Id>();
    for (Case c : cases) {
      Boolean isReview = FEC_ConstantCommon.INTERACTION_REVIEW_MODE.equals(c.FEC_Interaction_View_Mode__c);
      Boolean isInteractionNotHandling = FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME.equals(c.RecordType != null ? c.RecordType.DeveloperName : null)
          && !FEC_ConstantCommon.INTERACTION_HANDLING_MODE.equals(c.FEC_Interaction_View_Mode__c);
      if (isReview || isInteractionNotHandling) {
        block.add(c.Id);
      }
    }
    return block;
  }

  // Trả về Set ContentDocument Id bị chặn: file chỉ gắn Case review và không có Case handling.
  public static Set<Id> getContentDocumentIdsLinkedToReviewCases(Set<Id> contentDocumentIds) {
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

    Set<Id> caseIdsToBlock = getCaseIdsThatBlockFileActions(caseIds);

    Set<Id> blockedDocIds = new Set<Id>();
    for (Id docId : docIdToCaseIds.keySet()) {
      Set<Id> linkedCaseIds = docIdToCaseIds.get(docId);
      Boolean hasBlockingCase = false;
      Boolean hasNonBlockingCase = false;
      for (Id caseId : linkedCaseIds) {
        if (caseIdsToBlock.contains(caseId)) {
          hasBlockingCase = true;
        } else {
          hasNonBlockingCase = true;
        }
      }
      if (hasBlockingCase && !hasNonBlockingCase) {
        blockedDocIds.add(docId);
      }
    }
    return blockedDocIds;
  }
}