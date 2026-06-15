/**
 * Upload file lên Case qua ContentVersion + FirstPublishLocationId (tương tự Files chuẩn).
 * Trigger FEC_ContentDocumentLink vẫn chạy khi tạo link.
 */
public with sharing class FEC_CaseFileUploadService {
  private class FileUploadItem {
    String title;
    String pathOnClient;
    Blob versionData;

    FileUploadItem(String title, String pathOnClient, Blob versionData) {
      this.title = title;
      this.pathOnClient = pathOnClient;
      this.versionData = versionData;
    }
  }

  /**
   * MyCase CreateCSCase UploadDocument: fileName|extension|base64Data.
   * base64Data có thể là file gốc hoặc ZIP chứa file gốc (Pega gửi ZIP).
   */
  public static void uploadMyCaseDocumentsToCase(Id caseId, List<String> filePayloads) {
    if (caseId == null || filePayloads == null || filePayloads.isEmpty()) {
      return;
    }

    List<ContentVersion> versions = new List<ContentVersion>();

    for (String payload : filePayloads) {
      if (String.isBlank(payload)) {
        continue;
      }

      Integer i1 = payload.indexOf('|');
      Integer i2 = i1 >= 0 ? payload.indexOf('|', i1 + 1) : -1;
      if (i1 < 0 || i2 <= i1) {
        continue;
      }

      String fileName = payload.substring(0, i1);
      String extension = payload.substring(i1 + 1, i2);
      String base64Data = payload.substring(i2 + 1);
      if (String.isBlank(base64Data)) {
        continue;
      }

      Blob decodedBody = EncodingUtil.base64Decode(base64Data);
      for (
        FileUploadItem item : resolveMyCaseFileUploadItems(
          fileName,
          extension,
          decodedBody,
          isZipBase64(base64Data)
        )
      ) {
        versions.add(buildContentVersion(caseId, item));
      }
    }

    if (!versions.isEmpty()) {
      insert versions;
    }
  }

  @TestVisible
  private static Boolean isZipBase64(String base64Data) {
    return String.isNotBlank(base64Data) && base64Data.startsWith('UEsDB');
  }

  @TestVisible
  private static List<FileUploadItem> resolveMyCaseFileUploadItems(
    String fileName,
    String extension,
    Blob decodedBody,
    Boolean tryUnzip
  ) {
    List<FileUploadItem> items = new List<FileUploadItem>();
    if (decodedBody == null) {
      return items;
    }

    if (tryUnzip == true) {
      items.addAll(extractFilesFromZip(decodedBody, fileName, extension));
      if (!items.isEmpty()) {
        return items;
      }
    }

    String resolvedFileName = resolveFileNameWithExtension(fileName, extension);
    items.add(
      new FileUploadItem(trimTitle(resolvedFileName), '/' + resolvedFileName, decodedBody)
    );
    return items;
  }

  private static List<FileUploadItem> extractFilesFromZip(
    Blob zipBlob,
    String preferredFileName,
    String extension
  ) {
    List<FileUploadItem> items = new List<FileUploadItem>();
    try {
      Compression.ZipReader reader = new Compression.ZipReader(zipBlob);
      List<String> entryNames = reader.getEntryNames();
      if (entryNames == null || entryNames.isEmpty()) {
        return items;
      }

      for (String entryName : entryNames) {
        if (String.isBlank(entryName) || entryName.endsWith('/')) {
          continue;
        }

        String entryFileName = entryName.contains('/')
          ? entryName.substring(entryName.lastIndexOf('/') + 1)
          : entryName;
        Blob fileBody = reader.extract(entryName);
        if (fileBody == null) {
          continue;
        }

        String resolvedName = resolveZipEntryFileName(preferredFileName, extension, entryFileName);
        items.add(
          new FileUploadItem(trimTitle(resolvedName), '/' + resolvedName, fileBody)
        );
      }
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.WARN,
        '[FEC_CaseFileUploadService] ZIP extract failed: ' + ex.getMessage()
      );
    }
    return items;
  }

  private static String resolveZipEntryFileName(
    String preferredFileName,
    String extension,
    String entryFileName
  ) {
    if (String.isNotBlank(preferredFileName)) {
      return resolveFileNameWithExtension(preferredFileName, extension);
    }
    return entryFileName;
  }

  private static String resolveFileNameWithExtension(String fileName, String extension) {
    if (String.isBlank(fileName)) {
      return String.isNotBlank(extension) ? 'file.' + extension.trim() : 'file';
    }
    if (String.isBlank(extension)) {
      return fileName.trim();
    }

    String ext = extension.trim().replaceFirst('^\\.', '');
    String name = fileName.trim();
    if (name.toLowerCase().endsWith('.' + ext.toLowerCase())) {
      return name;
    }
    return name + '.' + ext;
  }

  private static String trimTitle(String fileName) {
    if (String.isBlank(fileName)) {
      return fileName;
    }
    return fileName.length() > 255 ? fileName.substring(0, 255) : fileName;
  }

  private static ContentVersion buildContentVersion(Id caseId, FileUploadItem item) {
    ContentVersion cv = new ContentVersion();
    cv.Title = item.title;
    cv.PathOnClient = item.pathOnClient.startsWith('/')
      ? item.pathOnClient
      : '/' + item.pathOnClient;
    cv.VersionData = item.versionData;
    cv.FirstPublishLocationId = caseId;
    return cv;
  }

  /**
   * @param caseId Case.Id
   * @param filePayloads Mỗi phần tử: title|pathOnClient|base64VersionData (pipe — base64 không chứa prefix data:)
   */
  @AuraEnabled
  public static void uploadFilesToCase(Id caseId, List<String> filePayloads) {
    if (caseId == null || filePayloads == null || filePayloads.isEmpty()) {
      return;
    }

    List<ContentVersion> versions = new List<ContentVersion>();

    for (String payload : filePayloads) {
      if (String.isBlank(payload)) {
        continue;
      }
      Integer i1 = payload.indexOf('|');
      Integer i2 = i1 >= 0 ? payload.indexOf('|', i1 + 1) : -1;
      if (i1 <= 0 || i2 <= i1) {
        continue;
      }

      String title = payload.substring(0, i1);
      String pathOnClient = payload.substring(i1 + 1, i2);
      String b64 = payload.substring(i2 + 1);

      if (String.isBlank(b64)) {
        continue;
      }

      Blob body = EncodingUtil.base64Decode(b64);
      String resolvedPath = String.isNotBlank(pathOnClient)
        ? (pathOnClient.startsWith('/') ? pathOnClient : '/' + pathOnClient)
        : '/' + trimTitle(title);
      versions.add(
        buildContentVersion(
          caseId,
          new FileUploadItem(trimTitle(title), resolvedPath, body)
        )
      );
    }

    if (!versions.isEmpty()) {
      try {
        insert versions;
      } catch (DmlException e) {
        throw new AuraHandledException(
          e.getNumDml() > 0 ? e.getDmlMessage(0) : e.getMessage()
        );
      }
    }
  }
}