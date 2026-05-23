/**
 * Stores and loads deferred batch case import payloads (processed at end of day).
 */
public with sharing class FEC_BatchCaseCreationPendingService {
  public static final String PAYLOAD_CONTENT_TITLE = 'BatchCaseCreation_ImportPayload';

  public class ImportPayload {
    public String templateName;
    public List<Object> rows;
  }

  public static void attachPendingImportPayload(
    Id batchId,
    String templateName,
    String rowsJson
  ) {
    if (batchId == null || String.isBlank(rowsJson)) {
      return;
    }
    Map<String, Object> payload = new Map<String, Object>{
      'templateName' => templateName,
      'rows' => JSON.deserializeUntyped(rowsJson)
    };
    ContentVersion cv = new ContentVersion();
    cv.Title = PAYLOAD_CONTENT_TITLE;
    cv.PathOnClient = PAYLOAD_CONTENT_TITLE + '.json';
    cv.VersionData = Blob.valueOf(JSON.serialize(payload));
    cv.Description = FEC_ConstantCommon.JSON_DATA_FOR_PROCESSING;
    cv.FirstPublishLocationId = batchId;
    insert cv;
  }

  public static ImportPayload loadPendingImportPayload(Id batchId) {
    ImportPayload out = new ImportPayload();
    if (batchId == null) {
      return out;
    }
    for (ContentDocumentLink link : [
      SELECT
        ContentDocument.Title,
        ContentDocument.LatestPublishedVersion.VersionData,
        ContentDocument.LatestPublishedVersion.Description
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :batchId
      ORDER BY ContentDocument.CreatedDate DESC
    ]) {
      if (link.ContentDocument == null || link.ContentDocument.LatestPublishedVersion == null) {
        continue;
      }
      String docTitle = link.ContentDocument.Title;
      if (!PAYLOAD_CONTENT_TITLE.equalsIgnoreCase(docTitle)) {
        continue;
      }
      ContentVersion cv = link.ContentDocument.LatestPublishedVersion;
      if (cv.Description != FEC_ConstantCommon.JSON_DATA_FOR_PROCESSING) {
        continue;
      }
      if (cv.VersionData == null) {
        continue;
      }
      Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(
        cv.VersionData.toString()
      );
      out.templateName = parsed.get('templateName') == null
        ? null
        : String.valueOf(parsed.get('templateName'));
      Object rowsObj = parsed.get('rows');
      if (rowsObj instanceof List<Object>) {
        out.rows = (List<Object>) rowsObj;
      }
      return out;
    }
    return out;
  }
}
