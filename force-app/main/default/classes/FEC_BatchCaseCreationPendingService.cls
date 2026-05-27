/**
 * Stores and loads deferred batch case import payloads (processed at end of day).
 */
public without sharing class FEC_BatchCaseCreationPendingService {
  public static final String PAYLOAD_CONTENT_TITLE = 'BatchCaseCreation_ImportPayload';

  public class ImportPayload {
    public String templateName;
    public List<Object> rows;
    public List<String> sourceHeaders;
    public List<List<String>> sourceRows;
  }

  public static void attachPendingImportPayload(
    Id batchId,
    String templateName,
    String rowsJson
  ) {
    attachPendingImportPayload(batchId, templateName, rowsJson, null, null);
  }

  public static void attachPendingImportPayload(
    Id batchId,
    String templateName,
    String rowsJson,
    String sourceHeadersJson,
    String sourceRowsJson
  ) {
    if (batchId == null || String.isBlank(rowsJson)) {
      return;
    }
    Map<String, Object> payload = new Map<String, Object>{
      'templateName' => templateName,
      'rows' => JSON.deserializeUntyped(rowsJson)
    };
    if (String.isNotBlank(sourceHeadersJson)) {
      payload.put('sourceHeaders', JSON.deserializeUntyped(sourceHeadersJson));
    }
    if (String.isNotBlank(sourceRowsJson)) {
      payload.put('sourceRows', JSON.deserializeUntyped(sourceRowsJson));
    }
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
    for (ContentVersion cv : [
      SELECT VersionData, Description
      FROM ContentVersion
      WHERE
        FirstPublishLocationId = :batchId
        AND Title = :PAYLOAD_CONTENT_TITLE
      ORDER BY CreatedDate DESC
      LIMIT 1
    ]) {
      if (!isPayloadContentVersion(cv)) {
        continue;
      }
      return parsePayloadBlob(cv.VersionData);
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
      if (!PAYLOAD_CONTENT_TITLE.equalsIgnoreCase(link.ContentDocument.Title)) {
        continue;
      }
      ContentVersion cv = link.ContentDocument.LatestPublishedVersion;
      if (!isPayloadContentVersion(cv)) {
        continue;
      }
      return parsePayloadBlob(cv.VersionData);
    }
    return out;
  }

  private static Boolean isPayloadContentVersion(ContentVersion cv) {
    if (cv == null || cv.VersionData == null) {
      return false;
    }
    if (String.isBlank(cv.Description)) {
      return true;
    }
    return cv.Description == FEC_ConstantCommon.JSON_DATA_FOR_PROCESSING;
  }

  private static ImportPayload parsePayloadBlob(Blob versionData) {
    ImportPayload out = new ImportPayload();
    if (versionData == null) {
      return out;
    }
    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(
      versionData.toString()
    );
    out.templateName = parsed.get('templateName') == null
      ? null
      : String.valueOf(parsed.get('templateName'));
    Object rowsObj = parsed.get('rows');
    if (rowsObj instanceof List<Object>) {
      out.rows = (List<Object>) rowsObj;
    }
    Object headersObj = parsed.get('sourceHeaders');
    if (headersObj instanceof List<Object>) {
      out.sourceHeaders = new List<String>();
      for (Object headerObj : (List<Object>) headersObj) {
        out.sourceHeaders.add(headerObj == null ? '' : String.valueOf(headerObj));
      }
    }
    Object sourceRowsObj = parsed.get('sourceRows');
    if (sourceRowsObj instanceof List<Object>) {
      out.sourceRows = parseSourceRows((List<Object>) sourceRowsObj);
    }
    return out;
  }

  private static List<List<String>> parseSourceRows(List<Object> rawRows) {
    List<List<String>> out = new List<List<String>>();
    if (rawRows == null) {
      return out;
    }
    for (Object rowObj : rawRows) {
      List<String> row = new List<String>();
      if (rowObj instanceof List<Object>) {
        for (Object cellObj : (List<Object>) rowObj) {
          row.add(cellObj == null ? '' : String.valueOf(cellObj));
        }
      }
      out.add(row);
    }
    return out;
  }
}
