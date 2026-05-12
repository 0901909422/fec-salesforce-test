/**
 * Danh sách file gắn Case qua ContentDocumentLink (cho LWC fec_FileUploadCard).
 */
public with sharing class FEC_CaseLinkedFilesController {
  public class CaseLinkedFileRow {
    @AuraEnabled
    public Id linkId { get; set; }
    @AuraEnabled
    public Id contentDocumentId { get; set; }
    @AuraEnabled
    public String title { get; set; }
    @AuraEnabled
    public String fileExtension { get; set; }
    @AuraEnabled
    public Long contentSize { get; set; }
    @AuraEnabled
    public Datetime linkedCreatedDate { get; set; }
    /** ContentDocument.Owner (User / Group name). */
    @AuraEnabled
    public String ownerName { get; set; }
    /** ContentDocument.LastModifiedDate — cột Last Modified trên UI. */
    @AuraEnabled
    public Datetime lastModifiedDate { get; set; }
  }

  /**
   * Không cacheable — gọi imperative sau upload để luôn dữ liệu mới.
   */
  @AuraEnabled
  public static List<CaseLinkedFileRow> getLinkedFilesForCase(Id caseId) {
    List<CaseLinkedFileRow> out = new List<CaseLinkedFileRow>();
    if (caseId == null) {
      return out;
    }
    for (ContentDocumentLink cdl : [
      SELECT
        Id,
        ContentDocumentId,
        ContentDocument.Title,
        ContentDocument.FileExtension,
        ContentDocument.LastModifiedDate,
        ContentDocument.Owner.Name,
        ContentDocument.LatestPublishedVersion.ContentSize,
        ContentDocument.LatestPublishedVersion.CreatedDate,
        SystemModstamp
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :caseId
      ORDER BY SystemModstamp DESC
    ]) {
      CaseLinkedFileRow row = new CaseLinkedFileRow();
      row.linkId = cdl.Id;
      row.contentDocumentId = cdl.ContentDocumentId;
      row.title = cdl.ContentDocument != null ? cdl.ContentDocument.Title : null;
      row.fileExtension = cdl.ContentDocument != null ? cdl.ContentDocument.FileExtension : null;
      if (cdl.ContentDocument != null) {
        row.ownerName = cdl.ContentDocument.Owner != null ? cdl.ContentDocument.Owner.Name : null;
        row.lastModifiedDate = cdl.ContentDocument.LastModifiedDate;
      }
      if (cdl.ContentDocument != null && cdl.ContentDocument.LatestPublishedVersion != null) {
        ContentVersion lv = cdl.ContentDocument.LatestPublishedVersion;
        row.contentSize = lv.ContentSize != null ? lv.ContentSize : 0L;
        row.linkedCreatedDate = lv.CreatedDate;
      } else {
        row.contentSize = 0L;
        row.linkedCreatedDate = cdl.SystemModstamp;
      }
      out.add(row);
    }
    return out;
  }
}
