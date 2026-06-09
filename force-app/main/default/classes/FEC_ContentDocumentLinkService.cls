/**
 * Tiện ích tạo ContentDocumentLink: gắn ContentDocument (file) tới bản ghi (ví dụ Case).
 * Trigger FEC_ContentDocumentLink vẫn chạy (review mode, giới hạn 2GB, v.v.).
 */
public with sharing class FEC_ContentDocumentLinkService {
  /** Kết quả gọi từ LWC: message + id để query SOQL. */
  public class LinkContentDocumentResult {
    @AuraEnabled
    public Boolean success { get; set; }
    @AuraEnabled
    public String message { get; set; }
    /** Id ContentDocumentLink — query: SELECT ... FROM ContentDocumentLink WHERE Id = :this */
    @AuraEnabled
    public Id contentDocumentLinkId { get; set; }
    @AuraEnabled
    public Id contentDocumentId { get; set; }
    @AuraEnabled
    public Id linkedEntityId { get; set; }
  }

  /**
   * Tạo liên kết file → bản ghi. Nếu đã tồn tại cùng ContentDocument + LinkedEntity thì trả Id cũ, success = true.
   *
   * @param contentDocumentId Id ContentDocument
   * @param linkedEntityId Id bản ghi đích (ví dụ Case.Id)
   * @param shareType 'V' (Viewer), 'C' (Collaborator), 'I' (Inferred). Mặc định 'V'.
   * @param visibility 'AllUsers' hoặc 'InternalUsers'. Mặc định 'AllUsers'.
   */
  @AuraEnabled
  public static LinkContentDocumentResult linkContentDocumentToRecord(
    Id contentDocumentId,
    Id linkedEntityId,
    String shareType,
    String visibility
  ) {
    LinkContentDocumentResult res = new LinkContentDocumentResult();
    res.contentDocumentId = contentDocumentId;
    res.linkedEntityId = linkedEntityId;
    res.success = false;
    res.contentDocumentLinkId = null;

    if (contentDocumentId == null || linkedEntityId == null) {
      res.message = 'contentDocumentId và linkedEntityId là bắt buộc.';
      return res;
    }

    try {
      List<ContentDocumentLink> existing = [
        SELECT Id
        FROM ContentDocumentLink
        WHERE ContentDocumentId = :contentDocumentId AND LinkedEntityId = :linkedEntityId
        LIMIT 1
      ];
      if (!existing.isEmpty()) {
        res.success = true;
        res.contentDocumentLinkId = existing[0].Id;
        res.message = 'Liên kết đã tồn tại (trả về Id hiện có).';
        return res;
      }

      ContentDocumentLink cdl = new ContentDocumentLink();
      cdl.ContentDocumentId = contentDocumentId;
      cdl.LinkedEntityId = linkedEntityId;
      cdl.ShareType = String.isNotBlank(shareType) ? shareType : 'V';
      cdl.Visibility = String.isNotBlank(visibility) ? visibility : 'AllUsers';

      insert cdl;
      res.success = true;
      res.contentDocumentLinkId = cdl.Id;
      res.message = 'Đã tạo ContentDocumentLink thành công.';
    } catch (DmlException e) {
      res.message = e.getNumDml() > 0 ? e.getDmlMessage(0) : e.getMessage();
    } catch (Exception e) {
      res.message = e.getMessage();
    }
    return res;
  }
}
