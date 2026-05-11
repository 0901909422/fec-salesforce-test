public without sharing class FEC_BatchCaseHandlingZipService {

    private static final Integer MAX_ATTACHMENT_CASE_SET = 1000;
    private static final Integer MAX_ZIP_BYTES = 10 * 1024 * 1024;

    public static FEC_BatchCaseHandlingZipResult downloadAttachmentsZip(String filtersJson, Integer startIndex, Integer endIndex) {
        FEC_BatchCaseHandlingZipResult out = new FEC_BatchCaseHandlingZipResult();
        out.success = false;
        out.message = 'No attachment data.';
        if (startIndex == null || endIndex == null || startIndex < 1 || endIndex < startIndex) {
            out.message = 'Case set không hợp lệ.';
            return out;
        }
        Integer maxEnd = Math.min(endIndex, MAX_ATTACHMENT_CASE_SET);
        Integer start = startIndex;
        Integer countToTake = maxEnd - start + 1;
        if (countToTake < 1) {
            out.message = 'Case set không hợp lệ.';
            return out;
        }
        Integer offsetRows = start - 1;
        if (offsetRows > 2000) {
            offsetRows = 2000;
        }

        List<String> whereParts = FEC_BatchCaseHandlingCaseFilter.buildBaseCaseWhere();
        List<Map<String, Object>> filterMaps = FEC_BatchCaseHandlingCaseFilter.parseFilterMaps(filtersJson);
        whereParts.addAll(FEC_BatchCaseHandlingCaseFilter.buildDynamicWhereFromFilters(filterMaps));
        String whereClause = String.join(whereParts, ' AND ');

        List<Case> cases = Database.query(
            'SELECT Id, FEC_ID_Search__c FROM Case WHERE ' + whereClause +
            ' ORDER BY FEC_Case_Created_On__c ASC NULLS LAST LIMIT ' + countToTake + ' OFFSET ' + offsetRows
        );
        if (cases.isEmpty()) {
            out.message = 'Không có Case trong khoảng đã chọn.';
            return out;
        }

        Map<Id, String> caseLabelById = new Map<Id, String>();
        Set<Id> caseIds = new Set<Id>();
        for (Case c : cases) {
            caseIds.add(c.Id);
            caseLabelById.put(c.Id, String.isBlank(c.FEC_ID_Search__c) ? String.valueOf(c.Id) : c.FEC_ID_Search__c);
        }
        List<ContentDocumentLink> links = [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :caseIds
        ];
        if (links.isEmpty()) {
            out.message = 'Các Case đã chọn không có tệp đính kèm.';
            return out;
        }

        Map<Id, Id> docToCase = new Map<Id, Id>();
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : links) {
            docIds.add(l.ContentDocumentId);
            if (!docToCase.containsKey(l.ContentDocumentId)) {
                docToCase.put(l.ContentDocumentId, l.LinkedEntityId);
            }
        }
        List<ContentVersion> versions = [
            SELECT Id, Title, FileExtension, ContentSize, VersionData, ContentDocumentId
            FROM ContentVersion
            WHERE IsLatest = true AND ContentDocumentId IN :docIds
        ];
        if (versions.isEmpty()) {
            out.message = 'Không lấy được tệp đính kèm.';
            return out;
        }

        Compression.ZipWriter writer = new Compression.ZipWriter();
        Integer totalSize = 0;
        Integer added = 0;
        for (ContentVersion cv : versions) {
            Integer sz = cv.ContentSize == null ? 0 : cv.ContentSize;
            if (totalSize + sz > MAX_ZIP_BYTES) {
                break;
            }
            Id ownerCaseId = docToCase.get(cv.ContentDocumentId);
            String caseLabel = caseLabelById.get(ownerCaseId);
            String ext = String.isBlank(cv.FileExtension) ? FEC_ConstantCommon.STR_EMPTY : '.' + cv.FileExtension;
            String entryName = String.valueOf(caseLabel) + ' - ' + cv.Title + ext;
            writer.addEntry(entryName, cv.VersionData);
            totalSize += sz;
            added += 1;
        }
        if (added == 0) {
            out.message = 'Tổng dung lượng file vượt quá 10MB.';
            return out;
        }

        Blob zipBlob = writer.getArchive();
        ContentVersion zipCv = new ContentVersion();
        zipCv.Title = 'BatchCaseAttachments_' + String.valueOf(Datetime.now().getTime());
        zipCv.PathOnClient = '/' + zipCv.Title + '.zip';
        zipCv.VersionData = zipBlob;
        zipCv.FirstPublishLocationId = UserInfo.getUserId();
        insert zipCv;

        ContentVersion inserted = [
            SELECT Id
            FROM ContentVersion
            WHERE Id = :zipCv.Id
            LIMIT 1
        ];
        out.success = true;
        out.fileName = zipCv.Title + '.zip';
        out.downloadUrl = FEC_ConstantCommon.CONTENT_VERSION_DOWNLOAD_URL_PREFIX + String.valueOf(inserted.Id);
        out.message = 'Tải file thành công.';
        return out;
    }

    public static FEC_BatchCaseHandlingZipResult zipExcelFiles(List<Map<String, Object>> files, String archiveName) {
        FEC_BatchCaseHandlingZipResult out = new FEC_BatchCaseHandlingZipResult();
        out.success = false;
        if (files == null || files.isEmpty()) {
            out.message = 'No files to zip.';
            return out;
        }
        Compression.ZipWriter writer = new Compression.ZipWriter();
        Integer added = 0;
        Long totalRawBytes = 0;
        Set<String> usedNames = new Set<String>();
        for (Map<String, Object> f : files) {
            if (f == null) {
                continue;
            }
            String name = f.get('fileName') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(f.get('fileName'));
            String b64 = f.get('base64Body') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(f.get('base64Body'));
            if (String.isBlank(name) || String.isBlank(b64)) {
                continue;
            }
            Blob entryBlob;
            try {
                entryBlob = EncodingUtil.base64Decode(b64);
            } catch (Exception ex) {
                continue;
            }
            Integer entrySize = entryBlob == null ? 0 : entryBlob.size();
            if (totalRawBytes + entrySize > MAX_ZIP_BYTES) {
                out.message = 'Tổng dung lượng file vượt quá 10MB.';
                return out;
            }
            String entry = name;
            Integer dup = 1;
            while (usedNames.contains(entry)) {
                Integer dot = entry.lastIndexOf('.');
                if (dot > 0) {
                    entry = name.substring(0, dot) + '_' + String.valueOf(dup) + name.substring(dot);
                } else {
                    entry = name + '_' + String.valueOf(dup);
                }
                dup += 1;
            }
            usedNames.add(entry);
            writer.addEntry(entry, entryBlob);
            totalRawBytes += entrySize;
            added += 1;
        }
        if (added == 0) {
            out.message = 'No files to zip.';
            return out;
        }
        Blob archive = writer.getArchive();
        if (archive != null && archive.size() > MAX_ZIP_BYTES) {
            out.message = 'Tổng dung lượng file vượt quá 10MB.';
            return out;
        }
        String prefix = String.isBlank(archiveName) ? 'FilteredCasesExport' : archiveName;
        String title = prefix + '_' + String.valueOf(Datetime.now().getTime());
        ContentVersion cv = new ContentVersion();
        cv.Title = title;
        cv.PathOnClient = '/' + title + '.zip';
        cv.VersionData = archive;
        cv.FirstPublishLocationId = UserInfo.getUserId();
        insert cv;
        ContentVersion ins = [
            SELECT Id
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];
        out.success = true;
        out.fileName = title + '.zip';
        out.downloadUrl = FEC_ConstantCommon.CONTENT_VERSION_DOWNLOAD_URL_PREFIX + String.valueOf(ins.Id);
        out.message = 'Tải file thành công.';
        return out;
    }

    public static FEC_BatchCaseHandlingZipResult downloadCaseAttachmentsZip(Id caseId) {
        FEC_BatchCaseHandlingZipResult out = new FEC_BatchCaseHandlingZipResult();
        out.success = false;
        out.message = 'No attachment data.';
        if (caseId == null) {
            out.message = 'Case không hợp lệ.';
            return out;
        }
        Case c = [
            SELECT Id, FEC_ID_Search__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :caseId
        ];
        if (links.isEmpty()) {
            out.message = 'Case không có tệp đính kèm.';
            return out;
        }
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : links) {
            docIds.add(l.ContentDocumentId);
        }
        List<ContentVersion> versions = [
            SELECT Id, Title, FileExtension, ContentSize, VersionData
            FROM ContentVersion
            WHERE IsLatest = true AND ContentDocumentId IN :docIds
        ];
        if (versions.isEmpty()) {
            out.message = 'Không lấy được tệp đính kèm.';
            return out;
        }
        Compression.ZipWriter writer = new Compression.ZipWriter();
        Integer totalSize = 0;
        Integer added = 0;
        String caseLabel = String.isBlank(c.FEC_ID_Search__c) ? String.valueOf(c.Id) : c.FEC_ID_Search__c;
        for (ContentVersion cv : versions) {
            Integer sz = cv.ContentSize == null ? 0 : cv.ContentSize;
            if (totalSize + sz > MAX_ZIP_BYTES) {
                break;
            }
            String ext = String.isBlank(cv.FileExtension) ? FEC_ConstantCommon.STR_EMPTY : '.' + cv.FileExtension;
            writer.addEntry(caseLabel + ' - ' + cv.Title + ext, cv.VersionData);
            totalSize += sz;
            added += 1;
        }
        if (added == 0) {
            out.message = 'Tổng dung lượng file vượt quá 10MB.';
            return out;
        }
        ContentVersion zipCv = new ContentVersion();
        zipCv.Title = 'CaseAttachments_' + caseLabel + '_' + String.valueOf(Datetime.now().getTime());
        zipCv.PathOnClient = '/' + zipCv.Title + '.zip';
        zipCv.VersionData = writer.getArchive();
        zipCv.FirstPublishLocationId = UserInfo.getUserId();
        insert zipCv;
        out.success = true;
        out.fileName = zipCv.Title + '.zip';
        out.downloadUrl = FEC_ConstantCommon.CONTENT_VERSION_DOWNLOAD_URL_PREFIX + String.valueOf(zipCv.Id);
        out.message = 'Tải file thành công.';
        return out;
    }
}
