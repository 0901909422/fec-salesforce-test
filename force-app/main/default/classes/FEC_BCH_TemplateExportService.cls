public without sharing class FEC_BCH_TemplateExportService {

    private static final String DBG = 'FEC_BCH_EXPORT';
    private static final Integer MAX_EXPORT_DATA_ROWS = 5000;

    public class ExportRequest {
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public Integer headerRowIndex;
        @AuraEnabled public List<Integer> mappedColumnIndexes;
        @AuraEnabled public List<List<String>> dataRows;
        @AuraEnabled public Integer insertColumnsBeforeIndex;

        @AuraEnabled public List<String> insertColumnHeaders;
        @AuraEnabled public List<List<String>> insertColumnValues;
        @AuraEnabled public String templateSheetName;
    }

    public class ExportWorkbookResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String base64Body;
        @AuraEnabled public String errorCode;
        @AuraEnabled public String errorMessage;
    }

    public static ExportWorkbookResponse exportWorkbook(String requestJson) {
        ExportWorkbookResponse out = new ExportWorkbookResponse();
        out.success = false;
        if (String.isBlank(requestJson)) {
            return fail(out, 'EMPTY_REQUEST', 'requestJson is blank');
        }
        try {
            ExportRequest req = (ExportRequest) JSON.deserialize(requestJson, ExportRequest.class);
            if (req == null || req.contentVersionId == null) {
                return fail(out, 'INVALID_REQUEST', 'contentVersionId is required');
            }
            List<ContentVersion> versions = [
                SELECT VersionData
                FROM ContentVersion
                WHERE Id = :req.contentVersionId
                LIMIT 1
            ];
            if (versions.isEmpty()) {
                return fail(out, 'TEMPLATE_NOT_FOUND', String.valueOf(req.contentVersionId));
            }
            if (versions[0].VersionData == null) {
                return fail(out, 'TEMPLATE_EMPTY', String.valueOf(req.contentVersionId));
            }
            Blob sourceBlob = versions[0].VersionData;
            dbg('TEMPLATE', 'bytes=' + sourceBlob.size());
            Map<String, Blob> entryByPath = readZipEntries(sourceBlob);
            if (entryByPath.isEmpty()) {
                return fail(out, 'ZIP_READ_EMPTY', 'no zip entries');
            }
            dbg('ZIP', 'entries=' + entryByPath.size());
            String workbookXml = blobToUtf8(entryByPath.get('xl/workbook.xml'));
            String workbookRelsXml = blobToUtf8(entryByPath.get('xl/_rels/workbook.xml.rels'));
            //tungnm37 - patch đúng sheet LWC đã map header (tránh ghi nhầm sheet lookup)
            String worksheetPath = resolveWorksheetPath(
                workbookXml,
                workbookRelsXml,
                req.templateSheetName
            );
            if (String.isBlank(worksheetPath) || !entryByPath.containsKey(worksheetPath)) {
                return fail(
                    out,
                    'WORKSHEET_NOT_FOUND',
                    'path=' +
                        worksheetPath +
                        ';hasPath=' +
                        entryByPath.containsKey(worksheetPath)
                );
            }
            Integer headerRowIndex = req.headerRowIndex == null || req.headerRowIndex < 0 ? 0 : req.headerRowIndex;
            List<Integer> mappedCols = req.mappedColumnIndexes == null
                ? new List<Integer>()
                : req.mappedColumnIndexes;
            List<List<String>> dataRows = req.dataRows == null ? new List<List<String>>() : req.dataRows;
            if (dataRows.isEmpty()) {
                return fail(out, 'NO_DATA_ROWS', 'dataRows is empty');
            }
            if (dataRows.size() > MAX_EXPORT_DATA_ROWS) {
                return fail(out, 'ROW_LIMIT', String.valueOf(dataRows.size()));
            }
            String worksheetXml = blobToUtf8(entryByPath.get(worksheetPath));
            //tungnm37 - tìm dòng data mẫu linh hoạt (tránh TEMPLATE_ROW_MISSING → mất format Result)
            Integer templateDataRow1 = resolveTemplateDataRowNum(worksheetXml, headerRowIndex);
            if (templateDataRow1 == null || templateDataRow1 < 1) {
                return fail(out, 'TEMPLATE_ROW_MISSING', 'headerRow=' + headerRowIndex);
            }
            Integer insertBefore = req.insertColumnsBeforeIndex;
            List<String> insertHeaders = req.insertColumnHeaders == null
                ? new List<String>()
                : req.insertColumnHeaders;
            List<List<String>> insertValues = req.insertColumnValues == null
                ? new List<List<String>>()
                : req.insertColumnValues;
            // 30/05/2026 11:30 linhdev - __Status/__Errors sau cột cuối sheet; giữ mappedCols từ file gốc
            if (isResultStatusErrorsInsert(insertHeaders)) {
                insertBefore = alignResultExportInsertBeforeSheetEnd(
                    worksheetXml,
                    headerRowIndex + 1,
                    templateDataRow1,
                    insertBefore,
                    mappedCols,
                    dataRows
                );
            }
            ResultInsertColumnStyles resultColStyles = null;
            if (insertBefore != null && insertBefore >= 0 && !insertHeaders.isEmpty()) {
                resultColStyles = buildResultInsertColumnStyles(
                    entryByPath,
                    worksheetXml,
                    headerRowIndex + 1,
                    templateDataRow1,
                    insertBefore
                );
                worksheetXml = insertPropertyColumnsInWorksheet(
                    worksheetXml,
                    headerRowIndex + 1,
                    templateDataRow1,
                    insertBefore,
                    insertHeaders,
                    resultColStyles
                );
                mappedCols = shiftMappedColumnIndexes(mappedCols, insertBefore, insertHeaders.size());
                dataRows = mergeInsertColumnValues(
                    dataRows,
                    insertValues,
                    insertHeaders.size(),
                    insertBefore
                );
            }
            dbg('PATCH', 'sheet=' + worksheetPath + ';rows=' + dataRows.size() + ';dataRow=' + templateDataRow1);
            String patchedXml = patchWorksheetXml(
                worksheetXml,
                headerRowIndex,
                mappedCols,
                dataRows,
                entryByPath,
                workbookXml,
                workbookRelsXml,
                insertBefore,
                insertHeaders.size(),
                resultColStyles
            );
            entryByPath.put(worksheetPath, Blob.valueOf(patchedXml));
            Blob outBlob = writeZipEntries(entryByPath, sourceBlob);
            if (outBlob == null) {
                return fail(out, 'ZIP_WRITE_FAILED', worksheetPath);
            }
            dbg('OUT', 'bytes=' + outBlob.size());
            out.base64Body = EncodingUtil.base64Encode(outBlob);
            out.success = true;
            out.errorCode = FEC_ConstantCommon.STR_EMPTY;
            out.errorMessage = FEC_ConstantCommon.STR_EMPTY;
            dbg('OK', 'base64Len=' + (out.base64Body == null ? 0 : out.base64Body.length()));
            return out;
        } catch (Exception ex) {
            return fail(out, 'EXCEPTION', ex.getTypeName() + ': ' + ex.getMessage());
        }
    }

    public static String exportWorkbookBase64(String requestJson) {
        ExportWorkbookResponse res = exportWorkbook(requestJson);
        return res != null && res.success == true ? res.base64Body : null;
    }

    // 30/05/2026 11:30 linhdev - map header import -> chỉ số cột Excel từ file gốc (không lệch Temporary Email / Case ID)
    public static List<Integer> resolveMappedColumnIndexesForHeaders(
        Id contentVersionId,
        Integer headerRowIndex,
        String sheetName,
        List<String> headers
    ) {
        List<Integer> mapped = new List<Integer>();
        if (contentVersionId == null || headers == null || headers.isEmpty()) {
            return mapped;
        }
        try {
            List<ContentVersion> versions = [
                SELECT VersionData
                FROM ContentVersion
                WHERE Id = :contentVersionId
                LIMIT 1
            ];
            if (versions.isEmpty() || versions[0].VersionData == null) {
                return mapped;
            }
            Map<String, Blob> entryByPath = readZipEntries(versions[0].VersionData);
            if (entryByPath.isEmpty()) {
                return mapped;
            }
            String workbookXml = blobToUtf8(entryByPath.get('xl/workbook.xml'));
            String workbookRelsXml = blobToUtf8(entryByPath.get('xl/_rels/workbook.xml.rels'));
            String worksheetPath = resolveWorksheetPath(workbookXml, workbookRelsXml, sheetName);
            if (String.isBlank(worksheetPath) || !entryByPath.containsKey(worksheetPath)) {
                return mapped;
            }
            String worksheetXml = blobToUtf8(entryByPath.get(worksheetPath));
            List<String> sharedStrings = parseSharedStrings(
                blobToUtf8(entryByPath.get('xl/sharedStrings.xml'))
            );
            Integer headerRowNum1 = headerRowIndex == null || headerRowIndex < 0 ? 1 : headerRowIndex + 1;
            return resolveMappedColumnIndexesFromHeaderRow(worksheetXml, headerRowNum1, sharedStrings, headers);
        } catch (Exception ex) {
            dbg('RESOLVE_MAP_FAIL', ex.getMessage());
            return mapped;
        }
    }

    // 30/05/2026 18:30 linhdev - đọc remark trực tiếp từ file import (SheetJS/LWC có thể không gửi đủ chuỗi dài)
    public static String readImportCellText(
        Id contentVersionId,
        String sheetName,
        Integer dataRowIndex0,
        Integer worksheetColIndex0
    ) {
        if (
            contentVersionId == null ||
            dataRowIndex0 == null ||
            dataRowIndex0 < 0 ||
            worksheetColIndex0 == null ||
            worksheetColIndex0 < 0
        ) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        try {
            List<ContentVersion> versions = [
                SELECT VersionData
                FROM ContentVersion
                WHERE Id = :contentVersionId
                LIMIT 1
            ];
            if (versions.isEmpty() || versions[0].VersionData == null) {
                return FEC_ConstantCommon.STR_EMPTY;
            }
            Map<String, Blob> entryByPath = readZipEntries(versions[0].VersionData);
            if (entryByPath.isEmpty()) {
                return FEC_ConstantCommon.STR_EMPTY;
            }
            String workbookXml = blobToUtf8(entryByPath.get('xl/workbook.xml'));
            String workbookRelsXml = blobToUtf8(entryByPath.get('xl/_rels/workbook.xml.rels'));
            String worksheetPath = resolveWorksheetPath(workbookXml, workbookRelsXml, sheetName);
            if (String.isBlank(worksheetPath) || !entryByPath.containsKey(worksheetPath)) {
                return FEC_ConstantCommon.STR_EMPTY;
            }
            String worksheetXml = blobToUtf8(entryByPath.get(worksheetPath));
            List<String> sharedStrings = parseSharedStrings(
                blobToUtf8(entryByPath.get('xl/sharedStrings.xml'))
            );
            // 30/05/2026 19:30 linhdev - đọc đúng cell ref; tránh regex row ăn nhầm cell self-closing trước cột remark
            String cellRef = columnIndexToLetter(worksheetColIndex0) + String.valueOf(dataRowIndex0 + 1);
            Pattern cellPat = Pattern.compile('(?s)<c r="' + cellRef + '"([^/>]*)(?:>(.*?)</c>|/>)');
            Matcher cellMat = cellPat.matcher(worksheetXml);
            if (!cellMat.find()) {
                return FEC_ConstantCommon.STR_EMPTY;
            }
            String attrs = cellMat.group(1) == null ? FEC_ConstantCommon.STR_EMPTY : cellMat.group(1);
            String cellBody = cellMat.group(2) == null ? FEC_ConstantCommon.STR_EMPTY : cellMat.group(2);
            String text = resolveCellDisplayText(attrs + cellBody, sharedStrings);
            // 30/05/2026 19:50 linhdev - giữ Result trong giới hạn cell Excel khi đọc lại remark từ file gốc
            if (text != null && text.length() > 32767) {
                text = text.substring(0, 32767);
            }
            return text == null ? FEC_ConstantCommon.STR_EMPTY : text;
        } catch (Exception ex) {
            dbg('READ_IMPORT_CELL_FAIL', ex.getMessage());
            return FEC_ConstantCommon.STR_EMPTY;
        }
    }

    private static ExportWorkbookResponse fail(
        ExportWorkbookResponse out,
        String code,
        String detail
    ) {
        out.success = false;
        out.base64Body = null;
        out.errorCode = code;
        out.errorMessage = detail;
        dbg(code, detail);
        return out;
    }

    private static void dbg(String step, String detail) {
        System.debug(LoggingLevel.ERROR, DBG + '|' + step + '|' + detail);
    }

    private static Map<String, Blob> readZipEntries(Blob archiveBlob) {
        Map<String, Blob> out = new Map<String, Blob>();
        if (archiveBlob == null) {
            return out;
        }
        Compression.ZipReader reader = new Compression.ZipReader(archiveBlob);
        List<String> entryNames = reader.getEntryNames();
        if (entryNames == null) {
            return out;
        }
        for (String entryName : entryNames) {
            if (String.isBlank(entryName) || entryName.endsWith('/')) {
                continue;
            }
            String path = normalizeZipPath(entryName);
            Blob body = reader.extract(entryName);
            if (String.isNotBlank(path) && body != null) {
                out.put(path, body);
            }
        }
        return out;
    }

    private static Blob writeZipEntries(Map<String, Blob> entryByPath, Blob sourceBlob) {
        Compression.ZipReader reader = new Compression.ZipReader(sourceBlob);
        Compression.ZipWriter writer = new Compression.ZipWriter();
        List<String> entryNames = reader.getEntryNames();
        if (entryNames == null) {
            return null;
        }
        for (String entryName : entryNames) {
            if (String.isBlank(entryName) || entryName.endsWith('/')) {
                continue;
            }
            String path = normalizeZipPath(entryName);
            Blob body = entryByPath.containsKey(path) ? entryByPath.get(path) : reader.extract(entryName);
            if (body != null) {
                writer.addEntry(entryName, body);
            }
        }
        return writer.getArchive();
    }

    private static String normalizeZipPath(String path) {
        if (String.isBlank(path)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return path.replace('\\', '/');
    }

    private static String blobToUtf8(Blob body) {
        if (body == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return body.toString();
    }

    //tungnm37 - ưu tiên sheet name từ LWC; fallback sheet có Case ID header
    private static String resolveWorksheetPath(
        String workbookXml,
        String workbookRelsXml,
        String preferredSheetName
    ) {
        if (String.isNotBlank(preferredSheetName)) {
            String byName = resolveWorksheetPathBySheetName(
                workbookXml,
                workbookRelsXml,
                preferredSheetName
            );
            if (String.isNotBlank(byName)) {
                return byName;
            }
        }
        return resolveMainWorksheetPath(workbookXml, workbookRelsXml);
    }

    private static String resolveWorksheetPathBySheetName(
        String workbookXml,
        String workbookRelsXml,
        String sheetName
    ) {
        if (String.isBlank(workbookXml) || String.isBlank(workbookRelsXml) || String.isBlank(sheetName)) {
            return null;
        }
        String want = sheetName.trim();
        String chosenRid = findSheetRelationshipId(workbookXml, want);
        return worksheetPathFromRelationshipId(workbookRelsXml, chosenRid);
    }

    private static String findSheetRelationshipId(String workbookXml, String sheetName) {
        if (String.isBlank(workbookXml) || String.isBlank(sheetName)) {
            return null;
        }
        String want = sheetName.trim();
        Pattern nameFirst = Pattern.compile('<sheet[^>]+name="([^"]+)"[^>]+r:id="([^"]+)"');
        Matcher nameFirstMat = nameFirst.matcher(workbookXml);
        while (nameFirstMat.find()) {
            if (want.equalsIgnoreCase(nameFirstMat.group(1).trim())) {
                return nameFirstMat.group(2);
            }
        }
        Pattern idFirst = Pattern.compile('<sheet[^>]+r:id="([^"]+)"[^>]+name="([^"]+)"');
        Matcher idFirstMat = idFirst.matcher(workbookXml);
        while (idFirstMat.find()) {
            if (want.equalsIgnoreCase(idFirstMat.group(2).trim())) {
                return idFirstMat.group(1);
            }
        }
        return null;
    }

    private static String worksheetPathFromRelationshipId(String workbookRelsXml, String relationshipId) {
        if (String.isBlank(workbookRelsXml) || String.isBlank(relationshipId)) {
            return null;
        }
        Pattern relPat = Pattern.compile(
            'Id="' + Pattern.quote(relationshipId) + '"[^>]+Target="([^"]+)"'
        );
        Matcher relMat = relPat.matcher(workbookRelsXml);
        if (!relMat.find()) {
            return null;
        }
        String target = relMat.group(1);
        if (target.startsWith('/')) {
            target = target.substring(1);
        }
        if (!target.startsWith('xl/')) {
            target = 'xl/' + target;
        }
        return target;
    }

    private static String resolveMainWorksheetPath(String workbookXml, String workbookRelsXml) {
        if (String.isBlank(workbookXml) || String.isBlank(workbookRelsXml)) {
            return 'xl/worksheets/sheet1.xml';
        }
        String chosenRid = null;
        Pattern sheetPat = Pattern.compile('<sheet[^>]+name="([^"]+)"[^>]+r:id="([^"]+)"');
        Matcher sheetMat = sheetPat.matcher(workbookXml);
        while (sheetMat.find()) {
            String sheetName = sheetMat.group(1);
            String rid = sheetMat.group(2);
            if (!'Sheet1'.equalsIgnoreCase(sheetName.trim())) {
                chosenRid = rid;
                break;
            }
        }
        if (String.isBlank(chosenRid)) {
            sheetMat = sheetPat.matcher(workbookXml);
            if (sheetMat.find()) {
                chosenRid = sheetMat.group(2);
            }
        }
        String path = worksheetPathFromRelationshipId(workbookRelsXml, chosenRid);
        return String.isNotBlank(path) ? path : 'xl/worksheets/sheet1.xml';
    }

    private class ValidationHeaderPair {
        List<String> mainMustContain;
        List<String> mainMustNotContain;
        List<String> lookupMustContain;
        Boolean mainMatchAny;
        Boolean lookupMatchAny;
    }

    private class ResultInsertColumnStyles {
        String headerCellStyleAttr;
        String dataStatusStyleAttr;
        String dataErrorsWrapStyleAttr;
    }

    private static String patchWorksheetXml(
        String xml,
        Integer headerRowIndex,
        List<Integer> mappedCols,
        List<List<String>> dataRows,
        Map<String, Blob> entryByPath,
        String workbookXml,
        String workbookRelsXml,
        Integer insertBeforeColIndex,
        Integer insertedColumnCount,
        ResultInsertColumnStyles resultColStyles
    ) {
        if (String.isBlank(xml)) {
            return xml;
        }
        // 28/05/2026 17:45 linhdev - đồng bộ logic resolve dòng data với exportWorkbook (giữ format sheet)
        Integer templateDataRow1 = resolveTemplateDataRowNum(xml, headerRowIndex);
        Integer rowCount = dataRows == null ? 0 : dataRows.size();
        if (rowCount < 1 || templateDataRow1 == null || templateDataRow1 < 1) {
            return xml;
        }
        String templateRowXml = extractRowXml(xml, templateDataRow1);
        if (String.isBlank(templateRowXml)) {
            return xml;
        }
        List<String> builtRows = new List<String>();
        for (Integer i = 0; i < rowCount; i++) {
            Integer rowNum1 = templateDataRow1 + i;
            List<String> values = dataRows[i];
            builtRows.add(
                buildDataRowXml(
                    templateRowXml,
                    templateDataRow1,
                    rowNum1,
                    mappedCols,
                    values,
                    resultColStyles,
                    insertBeforeColIndex,
                    insertedColumnCount
                )
            );
        }
        Integer keepRowsUntil = headerRowIndex + 1;
        if (templateDataRow1 != null && templateDataRow1 > 1 && templateDataRow1 - 1 > keepRowsUntil) {
            keepRowsUntil = templateDataRow1 - 1;
        }
        String sheetDataInner = rebuildSheetData(xml, keepRowsUntil, builtRows);
        String out = xml.replaceFirst(
            '(?s)<sheetData>.*?</sheetData>',
            '<sheetData>' + sheetDataInner + '</sheetData>'
        );
        Integer lastRow1 = templateDataRow1 + rowCount - 1;
        Integer lastColIndex = resolveLastPatchedColumnIndex(mappedCols);
        out = updateDimensionRef(out, lastRow1, lastColIndex);
        // 28/05/2026 17:45 linhdev - lỗi rebuild validation không được làm fail export (vẫn giữ format + data)
        try {
            out = applyHeaderBasedListValidations(
                out,
                entryByPath,
                workbookXml,
                workbookRelsXml,
                headerRowIndex,
                templateDataRow1,
                lastRow1,
                insertBeforeColIndex,
                insertedColumnCount
            );
        } catch (Exception validationEx) {
            dbg('VALIDATION_SKIP', validationEx.getMessage());
        }
        return out;
    }

    private static String resolveLookupSheetPath(String workbookXml, String workbookRelsXml) {
        if (String.isBlank(workbookXml) || String.isBlank(workbookRelsXml)) {
            return 'xl/worksheets/sheet2.xml';
        }
        String chosenRid = null;
        Pattern sheetPat = Pattern.compile('<sheet[^>]+name="([^"]+)"[^>]+r:id="([^"]+)"');
        Matcher sheetMat = sheetPat.matcher(workbookXml);
        while (sheetMat.find()) {
            String sheetName = sheetMat.group(1);
            if ('Sheet1'.equalsIgnoreCase(sheetName.trim())) {
                chosenRid = sheetMat.group(2);
                break;
            }
        }
        if (String.isBlank(chosenRid)) {
            return 'xl/worksheets/sheet2.xml';
        }
        Pattern relPat = Pattern.compile(
            'Id="' + Pattern.quote(chosenRid) + '"[^>]+Target="([^"]+)"'
        );
        Matcher relMat = relPat.matcher(workbookRelsXml);
        if (relMat.find()) {
            String target = relMat.group(1);
            if (target.startsWith('/')) {
                target = target.substring(1);
            }
            if (!target.startsWith('xl/')) {
                target = 'xl/' + target;
            }
            return target;
        }
        return 'xl/worksheets/sheet2.xml';
    }

    private static List<String> parseSharedStrings(String sharedStringsXml) {
        List<String> out = new List<String>();
        if (String.isBlank(sharedStringsXml)) {
            return out;
        }
        Pattern siPat = Pattern.compile('(?s)<si>(.*?)</si>');
        Matcher siMat = siPat.matcher(sharedStringsXml);
        while (siMat.find()) {
            String block = siMat.group(1);
            String text = FEC_ConstantCommon.STR_EMPTY;
            // 30/05/2026 19:45 linhdev - chỉ match tag <t>, không match nhầm <theme> trong rich text
            Pattern tPat = Pattern.compile('<t(?:\\s[^>]*)?>([^<]*)</t>');
            Matcher tMat = tPat.matcher(block);
            while (tMat.find()) {
                text += tMat.group(1);
            }
            out.add(text);
        }
        return out;
    }

    private static String normalizeHeaderName(String value) {
        if (String.isBlank(value)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return value.trim().toLowerCase().replaceAll('[^a-z0-9]', FEC_ConstantCommon.STR_EMPTY);
    }

    @TestVisible
    private static List<Integer> resolveMappedColumnIndexesFromHeaderRow(
        String worksheetXml,
        Integer headerRowNum1,
        List<String> sharedStrings,
        List<String> headers
    ) {
        List<Integer> indexes = new List<Integer>();
        if (String.isBlank(worksheetXml) || headers == null || headers.isEmpty()) {
            return indexes;
        }
        Map<Integer, String> colTexts = parseRowColumnTextsByIndex(worksheetXml, headerRowNum1, sharedStrings);
        if (colTexts.isEmpty()) {
            return indexes;
        }
        List<Integer> sortedCols = new List<Integer>(colTexts.keySet());
        sortedCols.sort();
        Integer searchCol = 0;
        for (String expectedHeader : headers) {
            String expectedNorm = normalizeHeaderName(expectedHeader);
            Integer matched = null;
            if (String.isNotBlank(expectedNorm)) {
                for (Integer col : sortedCols) {
                    if (col < searchCol) {
                        continue;
                    }
                    String cellText = colTexts.containsKey(col)
                        ? colTexts.get(col)
                        : FEC_ConstantCommon.STR_EMPTY;
                    if (expectedNorm.equals(normalizeHeaderName(cellText))) {
                        matched = col;
                        searchCol = col + 1;
                        break;
                    }
                }
            }
            if (matched == null) {
                matched = indexes.isEmpty() ? 0 : indexes[indexes.size() - 1] + 1;
            }
            indexes.add(matched);
        }
        return indexes;
    }

    private static Map<Integer, String> parseRowColumnTextsByIndex(
        String worksheetXml,
        Integer rowNum1,
        List<String> sharedStrings
    ) {
        Map<Integer, String> out = new Map<Integer, String>();
        String rowXml = extractRowXml(worksheetXml, rowNum1);
        if (String.isBlank(rowXml)) {
            return out;
        }
        Pattern cellPat = Pattern.compile('(?s)<c r="([A-Z]{1,3})' + rowNum1 + '"([^>]*)(?:>(.*?)</c>|/>)');
        Matcher cellMat = cellPat.matcher(rowXml);
        while (cellMat.find()) {
            String col = cellMat.group(1);
            String attrs = cellMat.group(2) == null ? FEC_ConstantCommon.STR_EMPTY : cellMat.group(2);
            String cellBody = cellMat.group(3) == null ? FEC_ConstantCommon.STR_EMPTY : cellMat.group(3);
            Integer colIdx = columnLetterToIndex(col);
            String text = resolveCellDisplayText(attrs + cellBody, sharedStrings);
            out.put(colIdx, text == null ? FEC_ConstantCommon.STR_EMPTY : text);
        }
        return out;
    }

    private static String resolveCellDisplayText(String cellXml, List<String> sharedStrings) {
        if (String.isBlank(cellXml)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        // 30/05/2026 18:30 linhdev - ghép mọi <t> trong inlineStr (remark dài có thể tách nhiều phần)
        if (cellXml.contains('<is>')) {
            String inlineText = FEC_ConstantCommon.STR_EMPTY;
            Pattern inlineTPat = Pattern.compile('<t(?:\\s[^>]*)?>([^<]*)</t>');
            Matcher inlineTMat = inlineTPat.matcher(cellXml);
            while (inlineTMat.find()) {
                inlineText += inlineTMat.group(1);
            }
            if (String.isNotBlank(inlineText)) {
                return inlineText;
            }
        }
        Pattern sharedPat = Pattern.compile('<v>(\\d+)</v>');
        Matcher sharedMat = sharedPat.matcher(cellXml);
        if (sharedMat.find() && sharedStrings != null && !sharedStrings.isEmpty()) {
            Integer idx = Integer.valueOf(sharedMat.group(1));
            if (idx >= 0 && idx < sharedStrings.size()) {
                return sharedStrings[idx];
            }
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    private static Map<String, String> parseRowHeaderColumns(
        String worksheetXml,
        Integer rowNum1,
        List<String> sharedStrings
    ) {
        Map<String, String> out = new Map<String, String>();
        String rowXml = extractRowXml(worksheetXml, rowNum1);
        if (String.isBlank(rowXml)) {
            return out;
        }
        Pattern cellPat = Pattern.compile('(?s)<c r="([A-Z]{1,3})' + rowNum1 + '"([^>]*)(?:>(.*?)</c>|/>)');
        Matcher cellMat = cellPat.matcher(rowXml);
        while (cellMat.find()) {
            String col = cellMat.group(1);
            String attrs = cellMat.group(2) == null ? FEC_ConstantCommon.STR_EMPTY : cellMat.group(2);
            String cellBody = cellMat.group(3) == null ? FEC_ConstantCommon.STR_EMPTY : cellMat.group(3);
            String text = resolveCellDisplayText(attrs + cellBody, sharedStrings);
            if (String.isNotBlank(text)) {
                out.put(col, normalizeHeaderName(text));
            }
        }
        return out;
    }

    private static String resolveLookupSheetName(String workbookXml) {
        if (String.isBlank(workbookXml)) {
            return 'Sheet1';
        }
        Pattern sheetPat = Pattern.compile('<sheet[^>]+name="([^"]+)"[^>]+r:id="([^"]+)"');
        Matcher sheetMat = sheetPat.matcher(workbookXml);
        while (sheetMat.find()) {
            String sheetName = sheetMat.group(1);
            if ('Sheet1'.equalsIgnoreCase(sheetName.trim())) {
                return sheetName;
            }
        }
        return 'Sheet1';
    }

    private static String buildLookupFormulaRef(
        String lookupSheetName,
        String col,
        Integer firstRow,
        Integer lastRow
    ) {
        String sheetRef = lookupSheetName;
        if (sheetRef.contains(' ') || sheetRef.contains('\'')) {
            sheetRef = '\'' + sheetRef.replace('\'', '\'\'') + '\'';
        }
        return sheetRef +
            '!$' +
            col +
            '$' +
            String.valueOf(firstRow) +
            ':$' +
            col +
            '$' +
            String.valueOf(lastRow);
    }

    private static Map<String, String> computeLookupColumnFormulas(
        String lookupXml,
        List<String> sharedStrings,
        String lookupSheetName
    ) {
        Map<String, String> formulas = new Map<String, String>();
        Map<String, Integer> firstRowByCol = new Map<String, Integer>();
        Map<String, Integer> lastRowByCol = new Map<String, Integer>();
        Pattern rowPat = Pattern.compile('(?s)<row r="(\\d+)"[^>]*>(.*?)</row>');
        Matcher rowMat = rowPat.matcher(lookupXml);
        while (rowMat.find()) {
            Integer rowNum1 = Integer.valueOf(rowMat.group(1));
            if (rowNum1 < 2) {
                continue;
            }
            String rowInner = rowMat.group(2);
            Pattern cellPat = Pattern.compile('(?s)<c r="([A-Z]{1,3})(\\d+)"([^>]*)(?:>(.*?)</c>|/>)');
            Matcher cellMat = cellPat.matcher(rowInner);
            while (cellMat.find()) {
                Integer cellRow = Integer.valueOf(cellMat.group(2));
                if (cellRow != rowNum1) {
                    continue;
                }
                String col = cellMat.group(1);
                String attrs = cellMat.group(3) == null ? FEC_ConstantCommon.STR_EMPTY : cellMat.group(3);
                String cellBody = cellMat.group(4) == null ? FEC_ConstantCommon.STR_EMPTY : cellMat.group(4);
                String text = resolveCellDisplayText(attrs + cellBody, sharedStrings);
                if (String.isBlank(text)) {
                    continue;
                }
                if (!firstRowByCol.containsKey(col)) {
                    firstRowByCol.put(col, rowNum1);
                }
                lastRowByCol.put(col, rowNum1);
            }
        }
        for (String col : firstRowByCol.keySet()) {
            Integer firstRow = firstRowByCol.get(col);
            Integer lastRow = lastRowByCol.get(col);
            formulas.put(
                col,
                buildLookupFormulaRef(lookupSheetName, col, firstRow, lastRow)
            );
        }
        return formulas;
    }

    private static List<ValidationHeaderPair> buildValidationHeaderPairs() {
        List<ValidationHeaderPair> pairs = new List<ValidationHeaderPair>();
        ValidationHeaderPair routing = new ValidationHeaderPair();
        routing.mainMustContain = new List<String>{ 'routingaction' };
        routing.mainMustNotContain = new List<String>{ 'assignmentrouting' };
        routing.lookupMustContain = new List<String>{ 'routingaction' };
        pairs.add(routing);
        ValidationHeaderPair assignmentRouting = new ValidationHeaderPair();
        assignmentRouting.mainMustContain = new List<String>{ 'assignmentroutingaction' };
        assignmentRouting.lookupMustContain = new List<String>{ 'assignmentroutingaction' };
        assignmentRouting.mainMustNotContain = new List<String>{ 'inputtedremarks' };
        pairs.add(assignmentRouting);
        ValidationHeaderPair classification = new ValidationHeaderPair();
        classification.mainMustContain = new List<String>{ 'classificationbycs' };
        classification.lookupMustContain = new List<String>{ 'classificationbycs' };
        pairs.add(classification);
        ValidationHeaderPair evaluation = new ValidationHeaderPair();
        evaluation.mainMustContain = new List<String>{ 'evaluationbycs' };
        evaluation.lookupMustContain = new List<String>{ 'evaluationbycs' };
        pairs.add(evaluation);
        ValidationHeaderPair finalProduct = new ValidationHeaderPair();
        finalProduct.mainMustContain = new List<String>{ 'finalproduct' };
        finalProduct.lookupMustContain = new List<String>{ 'productfinal' };
        pairs.add(finalProduct);
        ValidationHeaderPair csSupport = new ValidationHeaderPair();
        csSupport.mainMustContain = new List<String>{ 'cssupport', 'danhgia' };
        csSupport.mainMatchAny = true;
        csSupport.lookupMustContain = new List<String>{ 'cssupport', 'danhgia' };
        csSupport.lookupMatchAny = true;
        pairs.add(csSupport);
        ValidationHeaderPair csD2c = new ValidationHeaderPair();
        csD2c.mainMustContain = new List<String>{ 'csd2c', 'danhgia' };
        csD2c.mainMatchAny = true;
        csD2c.lookupMustContain = new List<String>{ 'csd2c', 'danhgia' };
        csD2c.lookupMatchAny = true;
        pairs.add(csD2c);
        ValidationHeaderPair riskLevel = new ValidationHeaderPair();
        riskLevel.mainMustContain = new List<String>{ 'risklevel', 'mucdoruiro' };
        riskLevel.mainMatchAny = true;
        riskLevel.lookupMustContain = new List<String>{ 'risklevel', 'mucdoruiro' };
        riskLevel.lookupMatchAny = true;
        pairs.add(riskLevel);
        ValidationHeaderPair requiredAction = new ValidationHeaderPair();
        requiredAction.mainMustContain = new List<String>{ 'requiredaction', 'requiredcorrectiveaction', 'hanhdongcanthiet' };
        requiredAction.mainMatchAny = true;
        requiredAction.lookupMustContain = new List<String>{ 'requiredaction', 'requiredcorrectiveaction', 'hanhdongcanthiet' };
        requiredAction.lookupMatchAny = true;
        pairs.add(requiredAction);
        return pairs;
    }

    @TestVisible
    private static String matchColumnByHeaderRules(
        Map<String, String> colToHeader,
        List<String> mustContain,
        List<String> mustNotContain,
        Boolean matchAnyContain
    ) {
        if (colToHeader == null || colToHeader.isEmpty()) {
            return null;
        }
        Boolean useAny = matchAnyContain == true;
        for (String col : colToHeader.keySet()) {
            String header = colToHeader.get(col);
            if (String.isBlank(header)) {
                continue;
            }
            Boolean matched = useAny ? false : true;
            if (mustContain != null && !mustContain.isEmpty()) {
                if (useAny) {
                    for (String token : mustContain) {
                        if (String.isNotBlank(token) && header.contains(token)) {
                            matched = true;
                            break;
                        }
                    }
                } else {
                    for (String token : mustContain) {
                        if (String.isBlank(token) || !header.contains(token)) {
                            matched = false;
                            break;
                        }
                    }
                }
            }
            if (!matched) {
                continue;
            }
            if (mustNotContain != null) {
                for (String token : mustNotContain) {
                    if (String.isNotBlank(token) && header.contains(token)) {
                        matched = false;
                        break;
                    }
                }
            }
            if (matched) {
                return col;
            }
        }
        return null;
    }

    private static String buildSqrefRange(String colLetter, Integer firstRow1, Integer lastRow1) {
        if (String.isBlank(colLetter)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (firstRow1.equals(lastRow1)) {
            return colLetter + String.valueOf(firstRow1);
        }
        return colLetter + String.valueOf(firstRow1) + ':' + colLetter + String.valueOf(lastRow1);
    }

    private static String buildValidationUid(Integer seed) {
        String suffix = String.valueOf(seed == null ? 1 : seed).leftPad(12, '0');
        return '{384C5710-23BE-435C-862B-' + suffix.right(12) + '}';
    }

    @TestVisible
    private static String buildDataValidationXml(String formula1, String sqref, String xrUid) {
        String uid = String.isNotBlank(xrUid) ? xrUid : buildValidationUid(1);
        return '<x14:dataValidation type="list" allowBlank="1" showInputMessage="1" showErrorMessage="1" xr:uid="' +
            uid +
            '"><x14:formula1><xm:f>' +
            escapeXml(formula1) +
            '</xm:f></x14:formula1><xm:sqref>' +
            sqref +
            '</xm:sqref></x14:dataValidation>';
    }

    // 28/05/2026 17:45 linhdev - resolve dòng data template (validation / sau header / fallback header) cho Result export
    @TestVisible
    private static Integer resolveTemplateDataRowNum(String worksheetXml, Integer headerRowIndex) {
        if (String.isBlank(worksheetXml)) {
            return null;
        }
        Integer headerRow1 = headerRowIndex == null || headerRowIndex < 0 ? 1 : headerRowIndex + 1;
        List<Integer> candidates = new List<Integer>();
        Integer fromValidations = resolveTemplateDataRowFromValidations(worksheetXml);
        if (fromValidations != null && fromValidations > headerRow1) {
            candidates.add(fromValidations);
        }
        candidates.add(headerRow1 + 1);
        candidates.add(headerRow1 + 2);
        candidates.add(headerRow1);
        Set<Integer> tried = new Set<Integer>();
        for (Integer cand : candidates) {
            if (cand == null || cand < 1 || tried.contains(cand)) {
                continue;
            }
            tried.add(cand);
            if (String.isNotBlank(extractRowXml(worksheetXml, cand))) {
                return cand;
            }
        }
        Pattern rowPat = Pattern.compile('<row r="(\\d+)"');
        Matcher rowMat = rowPat.matcher(worksheetXml);
        Integer bestAfterHeader = null;
        while (rowMat.find()) {
            Integer rowNum = Integer.valueOf(rowMat.group(1));
            if (rowNum <= headerRow1) {
                continue;
            }
            if (bestAfterHeader == null || rowNum < bestAfterHeader) {
                bestAfterHeader = rowNum;
            }
        }
        if (bestAfterHeader != null) {
            return bestAfterHeader;
        }
        return String.isNotBlank(extractRowXml(worksheetXml, headerRow1)) ? headerRow1 : null;
    }

    private static Integer resolveTemplateDataRowFromValidations(String worksheetXml) {
        Integer minRow = null;
        for (String node : parseExistingDataValidationNodes(worksheetXml)) {
            String sqref = extractDataValidationSqref(node);
            if (String.isBlank(sqref)) {
                continue;
            }
            Pattern p = Pattern.compile('([A-Z]{1,3})(\\d+)');
            Matcher m = p.matcher(sqref);
            while (m.find()) {
                Integer rowNum = Integer.valueOf(m.group(2));
                if (minRow == null || rowNum < minRow) {
                    minRow = rowNum;
                }
            }
        }
        return minRow;
    }

    private static String extractColumnFromSqref(String sqref) {
        if (String.isBlank(sqref)) {
            return null;
        }
        Pattern p = Pattern.compile('([A-Z]{1,3})\\d+');
        Matcher m = p.matcher(sqref.trim());
        return m.find() ? m.group(1) : null;
    }

    private static List<String> parseExistingDataValidationNodes(String mainWorksheetXml) {
        List<String> nodes = new List<String>();
        if (String.isBlank(mainWorksheetXml)) {
            return nodes;
        }
        Pattern blockPat = Pattern.compile(
            '(?s)<x14:dataValidations[^>]*>(.*?)</x14:dataValidations>'
        );
        Matcher blockMat = blockPat.matcher(mainWorksheetXml);
        if (!blockMat.find()) {
            return nodes;
        }
        Pattern valPat = Pattern.compile('(?s)<x14:dataValidation[^>]*>.*?</x14:dataValidation>');
        Matcher valMat = valPat.matcher(blockMat.group(1));
        while (valMat.find()) {
            nodes.add(valMat.group(0));
        }
        return nodes;
    }

    private static String extractDataValidationAttribute(String nodeXml, String attrName) {
        if (String.isBlank(nodeXml) || String.isBlank(attrName)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Pattern p = Pattern.compile(attrName + '="([^"]*)"');
        Matcher m = p.matcher(nodeXml);
        return m.find() ? m.group(1) : FEC_ConstantCommon.STR_EMPTY;
    }

    private static String extractDataValidationFormula(String nodeXml) {
        if (String.isBlank(nodeXml)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Pattern p = Pattern.compile('(?s)<xm:f>([^<]*)</xm:f>');
        Matcher m = p.matcher(nodeXml);
        return m.find() ? m.group(1) : FEC_ConstantCommon.STR_EMPTY;
    }

    private static String extractDataValidationSqref(String nodeXml) {
        if (String.isBlank(nodeXml)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Pattern p = Pattern.compile('<xm:sqref>([^<]*)</xm:sqref>');
        Matcher m = p.matcher(nodeXml);
        return m.find() ? m.group(1) : FEC_ConstantCommon.STR_EMPTY;
    }

    private static String extendExistingDataValidationNode(
        String nodeXml,
        Integer templateDataRow1,
        Integer lastDataRow1
    ) {
        String formula1 = extractDataValidationFormula(nodeXml);
        String sqrefRaw = extractDataValidationSqref(nodeXml);
        String col = extractColumnFromSqref(sqrefRaw);
        if (String.isBlank(formula1) || String.isBlank(col)) {
            return nodeXml;
        }
        String sqref = buildSqrefRange(col, templateDataRow1, lastDataRow1);
        String xrUid = extractDataValidationAttribute(nodeXml, 'xr:uid');
        return buildDataValidationXml(formula1, sqref, xrUid);
    }

    private static String applyHeaderBasedListValidations(
        String mainWorksheetXml,
        Map<String, Blob> entryByPath,
        String workbookXml,
        String workbookRelsXml,
        Integer headerRowIndex,
        Integer templateDataRow1,
        Integer lastDataRow1,
        Integer insertBeforeColIndex,
        Integer insertedColumnCount
    ) {
        if (String.isBlank(mainWorksheetXml) || entryByPath == null || entryByPath.isEmpty()) {
            return mainWorksheetXml;
        }
        List<String> sharedStrings = parseSharedStrings(
            blobToUtf8(entryByPath.get('xl/sharedStrings.xml'))
        );
        Integer headerRow1 = headerRowIndex + 1;
        Map<String, String> mainHeaders = parseRowHeaderColumns(
            mainWorksheetXml,
            headerRow1,
            sharedStrings
        );
        String lookupPath = resolveLookupSheetPath(workbookXml, workbookRelsXml);
        if (!entryByPath.containsKey(lookupPath)) {
            return extendExistingListValidationsOnly(
                mainWorksheetXml,
                templateDataRow1,
                lastDataRow1
            );
        }
        String lookupXml = blobToUtf8(entryByPath.get(lookupPath));
        Map<String, String> lookupHeaders = parseRowHeaderColumns(lookupXml, 1, sharedStrings);
        String lookupSheetName = resolveLookupSheetName(workbookXml);
        Map<String, String> lookupFormulas = computeLookupColumnFormulas(
            lookupXml,
            sharedStrings,
            lookupSheetName
        );
        List<String> validationNodes = new List<String>();
        Set<String> usedMainCols = new Set<String>();
        Set<String> usedLookupCols = new Set<String>();
        Integer uidSeed = 1;
        for (String existingNode : parseExistingDataValidationNodes(mainWorksheetXml)) {
            String col = extractColumnFromSqref(extractDataValidationSqref(existingNode));
            validationNodes.add(
                extendExistingDataValidationNode(existingNode, templateDataRow1, lastDataRow1)
            );
            if (String.isNotBlank(col)) {
                usedMainCols.add(col);
            }
        }
        for (ValidationHeaderPair pair : buildValidationHeaderPairs()) {
            String mainCol = matchColumnByHeaderRules(
                mainHeaders,
                pair.mainMustContain,
                pair.mainMustNotContain,
                pair.mainMatchAny
            );
            if (String.isBlank(mainCol) || usedMainCols.contains(mainCol)) {
                continue;
            }
            String lookupCol = matchColumnByHeaderRules(
                lookupHeaders,
                pair.lookupMustContain,
                null,
                pair.lookupMatchAny
            );
            if (
                String.isBlank(lookupCol) &&
                pair.mainMustContain != null &&
                pair.mainMustContain.contains('assignmentroutingaction')
            ) {
                lookupCol = matchColumnByHeaderRules(
                    lookupHeaders,
                    new List<String>{ 'routingaction' },
                    null,
                    false
                );
            }
            if (String.isBlank(lookupCol) || usedLookupCols.contains(lookupCol)) {
                continue;
            }
            String formula1 = lookupFormulas.get(lookupCol);
            if (String.isBlank(formula1)) {
                continue;
            }
            String sqref = buildSqrefRange(mainCol, templateDataRow1, lastDataRow1);
            validationNodes.add(buildDataValidationXml(formula1, sqref, buildValidationUid(uidSeed)));
            usedMainCols.add(mainCol);
            usedLookupCols.add(lookupCol);
            uidSeed += 1;
        }
        if (validationNodes.isEmpty()) {
            return mainWorksheetXml;
        }
        return upsertAllListValidations(mainWorksheetXml, validationNodes);
    }

    private static String extendExistingListValidationsOnly(
        String mainWorksheetXml,
        Integer templateDataRow1,
        Integer lastDataRow1
    ) {
        List<String> validationNodes = new List<String>();
        for (String existingNode : parseExistingDataValidationNodes(mainWorksheetXml)) {
            validationNodes.add(
                extendExistingDataValidationNode(existingNode, templateDataRow1, lastDataRow1)
            );
        }
        if (validationNodes.isEmpty()) {
            return mainWorksheetXml;
        }
        return upsertAllListValidations(mainWorksheetXml, validationNodes);
    }

    private static String upsertAllListValidations(
        String xml,
        List<String> x14ValidationNodes
    ) {
        if (x14ValidationNodes == null || x14ValidationNodes.isEmpty()) {
            return xml;
        }
        // 30/05/2026 15:10 linhdev - khai báo xmlns:xr cho xr:uid trong dataValidation (tránh Undeclared prefix)
        String x14Block =
            '<x14:dataValidations count="' +
            String.valueOf(x14ValidationNodes.size()) +
            '" xmlns:xm="http://schemas.microsoft.com/office/excel/2006/main" xmlns:xr="http://schemas.microsoft.com/office/spreadsheetml/2014/revision">' +
            String.join(x14ValidationNodes, FEC_ConstantCommon.STR_EMPTY) +
            '</x14:dataValidations>';
        return upsertX14DataValidationsBlock(xml, x14Block);
    }

    private static String replaceFirstMatch(String source, Pattern pattern, String replacement) {
        Matcher matcher = pattern.matcher(source);
        if (!matcher.find()) {
            return source;
        }
        return source.substring(0, matcher.start()) + replacement + source.substring(matcher.end());
    }

    private static String upsertX14DataValidationsBlock(String xml, String dataValidationsXml) {
        Pattern extDvPat = Pattern.compile(
            '(?s)<ext uri="\\{CCE6A557-97BC-4b89-ADB6-D9C93CAAB3DF\\}"[^>]*>.*?</ext>'
        );
        Matcher extDvMat = extDvPat.matcher(xml);
        // 30/05/2026 15:10 linhdev - xmlns:xr trên ext khi chèn/replace x14 dataValidations
        String extTag =
            '<ext uri="{CCE6A557-97BC-4b89-ADB6-D9C93CAAB3DF}" xmlns:x14="http://schemas.microsoft.com/office/spreadsheetml/2009/9/main" xmlns:xr="http://schemas.microsoft.com/office/spreadsheetml/2014/revision">' +
            dataValidationsXml +
            '</ext>';
        if (extDvMat.find()) {
            return replaceFirstMatch(xml, extDvPat, extTag);
        }
        Pattern existing = Pattern.compile(
            '(?s)<x14:dataValidations[^>]*/>|<x14:dataValidations[^>]*>.*?</x14:dataValidations>'
        );
        Matcher existingMatcher = existing.matcher(xml);
        if (existingMatcher.find()) {
            return replaceFirstMatch(xml, existing, dataValidationsXml);
        }
        Pattern extLst = Pattern.compile('(?s)(<extLst>)(.*?)(</extLst>)');
        Matcher extMat = extLst.matcher(xml);
        if (extMat.find()) {
            String replacement =
                extMat.group(1) +
                extMat.group(2) +
                extTag +
                extMat.group(3);
            return replaceFirstMatch(xml, extLst, replacement);
        }
        return xml.replace(
            '</worksheet>',
            '<extLst>' + extTag + '</extLst></worksheet>'
        );
    }

    private static String extractRowXml(String xml, Integer rowNum1) {
        Pattern p = Pattern.compile('(?s)(<row r="' + rowNum1 + '"[^>]*>.*?</row>)');
        Matcher m = p.matcher(xml);
        return m.find() ? m.group(1) : FEC_ConstantCommon.STR_EMPTY;
    }

    private static Boolean isResultStatusErrorsInsert(List<String> insertHeaders) {
        if (insertHeaders == null || insertHeaders.size() != 2) {
            return false;
        }
        return '__Status'.equals(insertHeaders[0]) && '__Errors'.equals(insertHeaders[1]);
    }

    // 30/05/2026 11:30 linhdev - insert sau cột cuối sheet; không ghi đè mappedCols
    private static Integer alignResultExportInsertBeforeSheetEnd(
        String worksheetXml,
        Integer headerRowNum1,
        Integer templateDataRowNum1,
        Integer requestedInsertBefore,
        List<Integer> mappedCols,
        List<List<String>> dataRows
    ) {
        Integer sheetMaxCol = resolveWorksheetMaxColumnIndex(
            worksheetXml,
            headerRowNum1,
            templateDataRowNum1
        );
        Integer mappedMaxCol = resolveMappedColumnsMaxIndex(mappedCols);
        Integer insertAt = sheetMaxCol >= 0 ? sheetMaxCol + 1 : 0;
        if (mappedMaxCol >= 0 && mappedMaxCol + 1 > insertAt) {
            insertAt = mappedMaxCol + 1;
        }
        if (requestedInsertBefore != null && requestedInsertBefore > insertAt) {
            insertAt = requestedInsertBefore;
        }
        if (dataRows != null && mappedCols != null) {
            Integer logicalWidth = mappedCols.size();
            for (Integer rowIdx = 0; rowIdx < dataRows.size(); rowIdx++) {
                List<String> row = dataRows[rowIdx];
                if (row == null) {
                    row = new List<String>();
                    dataRows[rowIdx] = row;
                }
                while (row.size() < logicalWidth) {
                    row.add(FEC_ConstantCommon.STR_EMPTY);
                }
            }
        }
        return insertAt;
    }

    private static Integer resolveWorksheetMaxColumnIndex(
        String worksheetXml,
        Integer headerRowNum1,
        Integer templateDataRowNum1
    ) {
        Integer maxIdx = -1;
        List<Integer> rowNums = new List<Integer>();
        if (headerRowNum1 != null && headerRowNum1 > 0) {
            rowNums.add(headerRowNum1);
        }
        if (templateDataRowNum1 != null && templateDataRowNum1 > 0 && templateDataRowNum1 != headerRowNum1) {
            rowNums.add(templateDataRowNum1);
        }
        for (Integer rowNum1 : rowNums) {
            String rowXml = extractRowXml(worksheetXml, rowNum1);
            if (String.isBlank(rowXml)) {
                continue;
            }
            Pattern cellPat = Pattern.compile('<c r="([A-Z]{1,3})' + rowNum1 + '"');
            Matcher cellMat = cellPat.matcher(rowXml);
            while (cellMat.find()) {
                Integer colIdx = columnLetterToIndex(cellMat.group(1));
                if (colIdx > maxIdx) {
                    maxIdx = colIdx;
                }
            }
        }
        return maxIdx;
    }

    private static Integer resolveMappedColumnsMaxIndex(List<Integer> mappedCols) {
        Integer maxIdx = -1;
        if (mappedCols == null) {
            return maxIdx;
        }
        for (Integer colIdx : mappedCols) {
            if (colIdx != null && colIdx > maxIdx) {
                maxIdx = colIdx;
            }
        }
        return maxIdx;
    }

    private static String rebuildSheetData(String xml, Integer lastHeaderRow1, List<String> dataRowXmlList) {
        Pattern p = Pattern.compile('(?s)(<sheetData>)(.*?)(</sheetData>)');
        Matcher m = p.matcher(xml);
        if (!m.find()) {
            return String.join(dataRowXmlList, FEC_ConstantCommon.STR_EMPTY);
        }
        String sheetDataBody = m.group(2);
        Pattern rowPat = Pattern.compile('(?s)<row r="(\\d+)"[^>]*>.*?</row>');
        Matcher rowMat = rowPat.matcher(sheetDataBody);
        List<String> keep = new List<String>();
        while (rowMat.find()) {
            Integer rn = Integer.valueOf(rowMat.group(1));
            if (rn <= lastHeaderRow1) {
                keep.add(rowMat.group(0));
            }
        }
        List<String> all = new List<String>();
        all.addAll(keep);
        all.addAll(dataRowXmlList);
        return String.join(all, FEC_ConstantCommon.STR_EMPTY);
    }

    private static String buildDataRowXml(
        String templateRowXml,
        Integer templateRowNum1,
        Integer targetRowNum1,
        List<Integer> mappedCols,
        List<String> values,
        ResultInsertColumnStyles resultColStyles,
        Integer insertBeforeColIndex,
        Integer insertedColumnCount
    ) {
        String rowXml = templateRowXml;
        rowXml = rowXml.replace('r="' + templateRowNum1 + '"', 'r="' + targetRowNum1 + '"');
        rowXml = remapRowCellReferences(rowXml, templateRowNum1, targetRowNum1);
        Integer valueIdx = 0;
        // 27/05/2026 13:15 linhdev - giữ thứ tự mappedColumnIndexes khớp dataRows (không dùng Set)
        List<Integer> orderedCols = mappedCols == null ? new List<Integer>() : mappedCols;
        for (Integer colIdx : orderedCols) {
            if (colIdx == null || colIdx < 0) {
                continue;
            }
            String colLetter = columnIndexToLetter(colIdx);
            String val = FEC_ConstantCommon.STR_EMPTY;
            if (values != null && valueIdx < values.size() && values[valueIdx] != null) {
                val = String.valueOf(values[valueIdx]);
            }
            valueIdx += 1;
            String styleAttr = resolveResultDataCellStyleAttr(
                resultColStyles,
                insertBeforeColIndex,
                insertedColumnCount,
                colIdx
            );
            if (String.isNotBlank(styleAttr)) {
                rowXml = removeCellAtAddress(rowXml, colLetter + String.valueOf(targetRowNum1));
            }
            rowXml = upsertCellInline(rowXml, colLetter, targetRowNum1, val, styleAttr);
        }
        return clearFixedRowHeight(rowXml);
    }

    private static String resolveResultDataCellStyleAttr(
        ResultInsertColumnStyles resultColStyles,
        Integer insertBeforeColIndex,
        Integer insertedColumnCount,
        Integer colIdx
    ) {
        if (
            resultColStyles == null ||
            insertBeforeColIndex == null ||
            insertedColumnCount == null ||
            insertedColumnCount < 2 ||
            colIdx == null
        ) {
            return null;
        }
        if (colIdx == insertBeforeColIndex) {
            return resultColStyles.dataStatusStyleAttr;
        }
        if (colIdx == insertBeforeColIndex + 1) {
            return resultColStyles.dataErrorsWrapStyleAttr;
        }
        return null;
    }

    private static List<Integer> shiftMappedColumnIndexes(
        List<Integer> mappedCols,
        Integer insertBefore,
        Integer insertCount
    ) {
        List<Integer> out = new List<Integer>();
        if (mappedCols == null) {
            return out;
        }
        //tungnm37 - chèn cột result/property đúng ngay vị trí insertBefore để thứ tự cột khớp thứ tự values
        List<Integer> beforeCols = new List<Integer>();
        List<Integer> afterCols = new List<Integer>();
        Integer safeInsertBefore = insertBefore == null ? 0 : insertBefore;
        Integer safeInsertCount = insertCount == null || insertCount < 0 ? 0 : insertCount;
        for (Integer colIdx : mappedCols) {
            if (colIdx == null || colIdx < 0) {
                continue;
            }
            if (safeInsertCount > 0 && colIdx >= safeInsertBefore) {
                afterCols.add(colIdx + safeInsertCount);
            } else {
                beforeCols.add(colIdx);
            }
        }
        out.addAll(beforeCols);
        for (Integer i = 0; i < safeInsertCount; i++) {
            out.add(safeInsertBefore + i);
        }
        out.addAll(afterCols);
        return out;
    }

    // 30/05/2026 11:30 linhdev - ghép __Status/__Errors đúng insertBefore (cuối sheet khi insertBefore == base.size())
    private static List<List<String>> mergeInsertColumnValues(
        List<List<String>> dataRows,
        List<List<String>> insertValues,
        Integer insertCount,
        Integer insertBefore
    ) {
        List<List<String>> out = new List<List<String>>();
        if (dataRows == null) {
            return out;
        }
        Integer safeInsertCount = insertCount == null || insertCount < 0 ? 0 : insertCount;
        for (Integer rowIdx = 0; rowIdx < dataRows.size(); rowIdx++) {
            List<String> base = dataRows[rowIdx] == null ? new List<String>() : dataRows[rowIdx];
            List<String> inserts = insertValues != null && rowIdx < insertValues.size()
                ? insertValues[rowIdx]
                : new List<String>();
            Integer splitIndex = base.size();
            if (insertBefore != null && insertBefore >= 0 && insertBefore <= base.size()) {
                splitIndex = insertBefore;
            }
            List<String> merged = new List<String>();
            for (Integer i = 0; i < splitIndex && i < base.size(); i++) {
                merged.add(base[i]);
            }
            for (Integer i = 0; i < safeInsertCount; i++) {
                merged.add(
                    i < inserts.size() && inserts[i] != null
                        ? inserts[i]
                        : FEC_ConstantCommon.STR_EMPTY
                );
            }
            for (Integer i = splitIndex; i < base.size(); i++) {
                merged.add(base[i]);
            }
            out.add(merged);
        }
        return out;
    }

    private static String insertPropertyColumnsInWorksheet(
        String xml,
        Integer headerRowNum1,
        Integer templateDataRowNum1,
        Integer insertBeforeColIndex,
        List<String> headers,
        ResultInsertColumnStyles resultColStyles
    ) {
        if (String.isBlank(xml) || headers == null || headers.isEmpty()) {
            return xml;
        }
        Integer shift = headers.size();
        String headerRowXml = extractRowXml(xml, headerRowNum1);
        if (String.isNotBlank(headerRowXml)) {
            headerRowXml = shiftRowCellsRight(headerRowXml, headerRowNum1, insertBeforeColIndex, shift);
            String headerStyleAttr = resultColStyles == null
                ? null
                : resultColStyles.headerCellStyleAttr;
            for (Integer i = 0; i < headers.size(); i++) {
                String hdrCol = columnIndexToLetter(insertBeforeColIndex + i);
                String hdrAddr = hdrCol + String.valueOf(headerRowNum1);
                if (String.isNotBlank(headerStyleAttr)) {
                    headerRowXml = removeCellAtAddress(headerRowXml, hdrAddr);
                }
                headerRowXml = upsertCellInline(
                    headerRowXml,
                    hdrCol,
                    headerRowNum1,
                    headers[i],
                    headerStyleAttr
                );
            }
            xml = replaceRowXml(xml, headerRowNum1, headerRowXml);
        }
        String templateRowXml = extractRowXml(xml, templateDataRowNum1);
        if (String.isNotBlank(templateRowXml)) {
            templateRowXml = shiftRowCellsRight(
                templateRowXml,
                templateDataRowNum1,
                insertBeforeColIndex,
                shift
            );
            xml = replaceRowXml(xml, templateDataRowNum1, templateRowXml);
        }
        xml = shiftWorksheetMergeCells(xml, insertBeforeColIndex, shift);
        xml = shiftWorksheetValidations(xml, insertBeforeColIndex, shift);
        xml = shiftWorksheetX14Sqrefs(xml, insertBeforeColIndex, shift);
        return shiftWorksheetRowSpans(xml, insertBeforeColIndex, shift);
    }

    private static String replaceRowXml(String xml, Integer rowNum1, String rowXml) {
        Pattern p = Pattern.compile('(?s)<row r="' + rowNum1 + '"[^>]*>.*?</row>');
        Matcher m = p.matcher(xml);
        if (!m.find()) {
            return xml;
        }
        return m.replaceFirst(Matcher.quoteReplacement(rowXml));
    }

    private static String shiftRowCellsRight(
        String rowXml,
        Integer rowNum1,
        Integer insertBeforeColIndex,
        Integer shift
    ) {
        if (String.isBlank(rowXml) || shift == null || shift < 1) {
            return rowXml;
        }
        Pattern cellPat = Pattern.compile('(?s)<c r="([A-Z]{1,3})' + rowNum1 + '"([^>]*)(?:>(.*?)</c>|/>)');
        Matcher cellMat = cellPat.matcher(rowXml);
        List<CellFragment> cells = new List<CellFragment>();
        while (cellMat.find()) {
            CellFragment frag = new CellFragment();
            frag.colLetter = cellMat.group(1);
            frag.colIndex = columnLetterToIndex(frag.colLetter);
            frag.fullXml = cellMat.group(0);
            cells.add(frag);
        }
        if (cells.isEmpty()) {
            return rowXml;
        }
        cells.sort(new CellIndexComparator());
        String out = rowXml;
        for (Integer i = cells.size() - 1; i >= 0; i--) {
            CellFragment frag = cells[i];
            if (frag.colIndex < insertBeforeColIndex) {
                continue;
            }
            String newLetter = columnIndexToLetter(frag.colIndex + shift);
            String newAddr = newLetter + String.valueOf(rowNum1);
            String updated = frag.fullXml.replace(
                'r="' + frag.colLetter + rowNum1 + '"',
                'r="' + newAddr + '"'
            );
            out = out.replace(frag.fullXml, updated);
        }
        return out;
    }

    private static String shiftWorksheetValidations(
        String xml,
        Integer insertBeforeColIndex,
        Integer shift
    ) {
        if (
            String.isBlank(xml) ||
            shift == null ||
            shift < 1 ||
            insertBeforeColIndex == null ||
            insertBeforeColIndex < 0
        ) {
            return xml;
        }
        Pattern sqrefPat = Pattern.compile('sqref="([^"]+)"');
        Matcher m = sqrefPat.matcher(xml);
        List<SqrefReplacement> replacements = new List<SqrefReplacement>();
        while (m.find()) {
            String shiftedSqref = shiftSqrefReferences(m.group(1), insertBeforeColIndex, shift);
            if (shiftedSqref == m.group(1)) {
                continue;
            }
            SqrefReplacement rep = new SqrefReplacement();
            rep.startPos = m.start();
            rep.endPos = m.end();
            rep.replacementText = 'sqref="' + shiftedSqref + '"';
            replacements.add(rep);
        }
        if (replacements.isEmpty()) {
            return xml;
        }
        String out = xml;
        for (Integer i = replacements.size() - 1; i >= 0; i--) {
            SqrefReplacement rep = replacements[i];
            out =
                out.substring(0, rep.startPos) +
                rep.replacementText +
                out.substring(rep.endPos);
        }
        return out;
    }

    // 29/05/2026 - Phone Update Result: dịch xm:sqref (x14 dataValidation) khi chèn __Status/__Errors
    @TestVisible
    private static String shiftWorksheetX14Sqrefs(
        String xml,
        Integer insertBeforeColIndex,
        Integer shift
    ) {
        if (
            String.isBlank(xml) ||
            shift == null ||
            shift < 1 ||
            insertBeforeColIndex == null ||
            insertBeforeColIndex < 0
        ) {
            return xml;
        }
        Pattern sqrefPat = Pattern.compile('<xm:sqref>([^<]+)</xm:sqref>');
        Matcher m = sqrefPat.matcher(xml);
        List<SqrefReplacement> replacements = new List<SqrefReplacement>();
        while (m.find()) {
            String shiftedSqref = shiftSqrefReferences(m.group(1), insertBeforeColIndex, shift);
            if (shiftedSqref == m.group(1)) {
                continue;
            }
            SqrefReplacement rep = new SqrefReplacement();
            rep.startPos = m.start();
            rep.endPos = m.end();
            rep.replacementText = '<xm:sqref>' + shiftedSqref + '</xm:sqref>';
            replacements.add(rep);
        }
        if (replacements.isEmpty()) {
            return xml;
        }
        String out = xml;
        for (Integer i = replacements.size() - 1; i >= 0; i--) {
            SqrefReplacement rep = replacements[i];
            out =
                out.substring(0, rep.startPos) +
                rep.replacementText +
                out.substring(rep.endPos);
        }
        return out;
    }

    @TestVisible
    private static String shiftWorksheetRowSpans(
        String xml,
        Integer insertBeforeColIndex,
        Integer shift
    ) {
        if (
            String.isBlank(xml) ||
            shift == null ||
            shift < 1 ||
            insertBeforeColIndex == null ||
            insertBeforeColIndex < 0
        ) {
            return xml;
        }
        Pattern spansPat = Pattern.compile('spans="(\\d+):(\\d+)"');
        Matcher m = spansPat.matcher(xml);
        List<SqrefReplacement> replacements = new List<SqrefReplacement>();
        while (m.find()) {
            Integer spanMin = Integer.valueOf(m.group(1));
            Integer spanMax = Integer.valueOf(m.group(2));
            Integer newMin = spanMin;
            Integer newMax = spanMax;
            if (spanMin - 1 >= insertBeforeColIndex) {
                newMin = spanMin + shift;
            }
            if (spanMax - 1 >= insertBeforeColIndex) {
                newMax = spanMax + shift;
            }
            if (newMin.equals(spanMin) && newMax.equals(spanMax)) {
                continue;
            }
            SqrefReplacement rep = new SqrefReplacement();
            rep.startPos = m.start();
            rep.endPos = m.end();
            rep.replacementText = 'spans="' + String.valueOf(newMin) + ':' + String.valueOf(newMax) + '"';
            replacements.add(rep);
        }
        if (replacements.isEmpty()) {
            return xml;
        }
        String out = xml;
        for (Integer i = replacements.size() - 1; i >= 0; i--) {
            SqrefReplacement rep = replacements[i];
            out =
                out.substring(0, rep.startPos) +
                rep.replacementText +
                out.substring(rep.endPos);
        }
        return out;
    }

    private static String shiftSqrefReferences(
        String sqref,
        Integer insertBeforeColIndex,
        Integer shift
    ) {
        if (String.isBlank(sqref)) {
            return sqref;
        }
        List<String> refs = sqref.split('\\s+');
        List<String> shiftedRefs = new List<String>();
        for (String refToken : refs) {
            if (String.isBlank(refToken)) {
                continue;
            }
            shiftedRefs.add(shiftRangeReference(refToken, insertBeforeColIndex, shift));
        }
        return shiftedRefs.isEmpty() ? sqref : String.join(shiftedRefs, ' ');
    }

    private static String shiftRangeReference(
        String refToken,
        Integer insertBeforeColIndex,
        Integer shift
    ) {
        if (String.isBlank(refToken)) {
            return refToken;
        }
        List<String> bounds = refToken.split(':');
        if (bounds.isEmpty()) {
            return refToken;
        }
        if (bounds.size() == 1) {
            return shiftCellReference(bounds[0], insertBeforeColIndex, shift);
        }
        String startRef = shiftCellReference(bounds[0], insertBeforeColIndex, shift);
        String endRef = shiftCellReference(bounds[1], insertBeforeColIndex, shift);
        return startRef + ':' + endRef;
    }

    private static String shiftCellReference(
        String cellRef,
        Integer insertBeforeColIndex,
        Integer shift
    ) {
        if (String.isBlank(cellRef)) {
            return cellRef;
        }
        Pattern cellRefPat = Pattern.compile('^([A-Z]{1,3})(\\d+)$');
        Matcher cellRefMat = cellRefPat.matcher(cellRef);
        if (!cellRefMat.find()) {
            return cellRef;
        }
        Integer colIdx = columnLetterToIndex(cellRefMat.group(1));
        if (colIdx < insertBeforeColIndex) {
            return cellRef;
        }
        return columnIndexToLetter(colIdx + shift) + cellRefMat.group(2);
    }

    private class SqrefReplacement {
        Integer startPos;
        Integer endPos;
        String replacementText;
    }

    private static Integer columnLetterToIndex(String colLetter) {
        if (String.isBlank(colLetter)) {
            return 0;
        }
        Integer result = 0;
        String upper = colLetter.toUpperCase();
        for (Integer i = 0; i < upper.length(); i++) {
            result = result * 26 + (upper.charAt(i) - 64);
        }
        return result - 1;
    }

    private class CellFragment {
        String colLetter;
        Integer colIndex;
        String fullXml;
    }

    private class CellIndexComparator implements System.Comparator<CellFragment> {
        public Integer compare(CellFragment a, CellFragment b) {
            if (a == null && b == null) {
                return 0;
            }
            if (a == null) {
                return 1;
            }
            if (b == null) {
                return -1;
            }
            if (a.colIndex == b.colIndex) {
                return 0;
            }
            return a.colIndex > b.colIndex ? 1 : -1;
        }
    }

    private static String remapRowCellReferences(String rowXml, Integer fromRow1, Integer toRow1) {
        if (fromRow1 == toRow1) {
            return rowXml;
        }
        Pattern p = Pattern.compile('r="([A-Z]+)' + fromRow1 + '"');
        Matcher m = p.matcher(rowXml);
        String out = FEC_ConstantCommon.STR_EMPTY;
        Integer last = 0;
        while (m.find()) {
            out += rowXml.substring(last, m.start()) + 'r="' + m.group(1) + toRow1 + '"';
            last = m.end();
        }
        return out + rowXml.substring(last);
    }

    private static String upsertCellInline(
        String rowXml,
        String colLetter,
        Integer rowNum1,
        String value
    ) {
        return upsertCellInline(rowXml, colLetter, rowNum1, value, null);
    }

    private static String upsertCellInline(
        String rowXml,
        String colLetter,
        Integer rowNum1,
        String value,
        String forcedStyleAttr
    ) {
        String addr = colLetter + String.valueOf(rowNum1);
        String escaped = escapeXml(value);
        Pattern selfClosing = Pattern.compile('<c r="' + Pattern.quote(addr) + '"([^/>]*)/>');
        Matcher mClose = selfClosing.matcher(rowXml);
        if (mClose.find()) {
            String styleAttr = String.isNotBlank(forcedStyleAttr)
                ? forcedStyleAttr
                : extractStyleAttr(mClose.group(1));
            String newCell = buildInlineCell(addr, styleAttr, escaped);
            return replaceFirstMatch(rowXml, selfClosing, newCell);
        }
        Pattern fullCell = Pattern.compile('<c r="' + Pattern.quote(addr) + '"[^>]*>.*?</c>');
        Matcher mFull = fullCell.matcher(rowXml);
        if (mFull.find()) {
            String styleAttr = String.isNotBlank(forcedStyleAttr)
                ? forcedStyleAttr
                : extractStyleAttr(mFull.group(0));
            String newCell = buildInlineCell(addr, styleAttr, escaped);
            return replaceFirstMatch(rowXml, fullCell, newCell);
        }
        Integer closeIdx = rowXml.lastIndexOf('</row>');
        if (closeIdx < 0) {
            return rowXml;
        }
        String styleAttr = String.isNotBlank(forcedStyleAttr)
            ? forcedStyleAttr
            : FEC_ConstantCommon.STR_EMPTY;
        String newCell = buildInlineCell(addr, styleAttr, escaped);
        return insertCellInRowOrder(rowXml, newCell, colLetter, rowNum1, closeIdx);
    }

    private static String insertCellInRowOrder(
        String rowXml,
        String newCell,
        String colLetter,
        Integer rowNum1,
        Integer closeIdx
    ) {
        if (String.isBlank(rowXml) || String.isBlank(newCell) || closeIdx == null || closeIdx < 0) {
            return rowXml;
        }
        Integer targetColIdx = columnLetterToIndex(colLetter);
        Pattern cellPat = Pattern.compile('(?s)<c r="([A-Z]{1,3})' + rowNum1 + '"[^>]*(?:/>|>.*?</c>)');
        Matcher cellMat = cellPat.matcher(rowXml);
        Integer insertPos = closeIdx;
        while (cellMat.find()) {
            Integer existingColIdx = columnLetterToIndex(cellMat.group(1));
            if (existingColIdx > targetColIdx) {
                insertPos = cellMat.start();
                break;
            }
        }
        return rowXml.substring(0, insertPos) + newCell + rowXml.substring(insertPos);
    }

    private static String extractStyleAttr(String cellFragment) {
        if (String.isBlank(cellFragment)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Pattern p = Pattern.compile(' s="(\\d+)"');
        Matcher m = p.matcher(cellFragment);
        return m.find() ? ' s="' + m.group(1) + '"' : FEC_ConstantCommon.STR_EMPTY;
    }

    // 30/05/2026 15:10 linhdev - tránh xml:space (Undeclared prefix xml) khi patch Result; xuống dòng dùng &#10;
    @TestVisible
    private static String buildInlineCell(String addr, String styleAttr, String escapedValue) {
        String safeStyle = styleAttr == null ? FEC_ConstantCommon.STR_EMPTY : styleAttr;
        String safeVal = encodeInlineStrLineBreaks(escapedValue);
        return '<c r="' + addr + '"' + safeStyle + ' t="inlineStr"><is><t>' + safeVal + '</t></is></c>';
    }

    // 30/05/2026 15:10 linhdev - encode LF/CR sau escapeXml để không cần xmlns:xml trên worksheet
    @TestVisible
    private static String encodeInlineStrLineBreaks(String escapedText) {
        if (escapedText == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String out = escapedText.replace('\r\n', '\n').replace('\r', '\n');
        while (out.contains('\n')) {
            out = out.replace('\n', '&#10;');
        }
        return out;
    }

    // 28/05/2026 22:00 linhdev - __Status/__Errors: style cột kề (header vàng); __Errors thêm wrap
    private static ResultInsertColumnStyles buildResultInsertColumnStyles(
        Map<String, Blob> entryByPath,
        String worksheetXml,
        Integer headerRowNum1,
        Integer templateDataRowNum1,
        Integer insertBeforeColIndex
    ) {
        ResultInsertColumnStyles out = new ResultInsertColumnStyles();
        if (String.isBlank(worksheetXml) || insertBeforeColIndex == null || insertBeforeColIndex < 0) {
            return out;
        }
        Integer neighborColIndex = insertBeforeColIndex > 0 ? insertBeforeColIndex - 1 : 0;
        Integer headerStyleIdx = extractStyleIndexFromRow(
            extractRowXml(worksheetXml, headerRowNum1),
            neighborColIndex,
            headerRowNum1
        );
        Integer dataStyleIdx = extractStyleIndexFromRow(
            extractRowXml(worksheetXml, templateDataRowNum1),
            neighborColIndex,
            templateDataRowNum1
        );
        if (dataStyleIdx == null) {
            dataStyleIdx = headerStyleIdx;
        }
        if (headerStyleIdx == null) {
            headerStyleIdx = dataStyleIdx;
        }
        out.headerCellStyleAttr = styleIndexToAttr(headerStyleIdx);
        out.dataStatusStyleAttr = styleIndexToAttr(dataStyleIdx);
        out.dataErrorsWrapStyleAttr = styleIndexToAttr(
            ensureDataWrapStyleIndex(entryByPath, dataStyleIdx)
        );
        return out;
    }

    private static Integer ensureDataWrapStyleIndex(
        Map<String, Blob> entryByPath,
        Integer baseStyleIndex
    ) {
        if (entryByPath == null || baseStyleIndex == null || baseStyleIndex < 0) {
            return baseStyleIndex;
        }
        if (!entryByPath.containsKey('xl/styles.xml')) {
            return baseStyleIndex;
        }
        String baseXf = extractCellXfByIndex(
            blobToUtf8(entryByPath.get('xl/styles.xml')),
            baseStyleIndex
        );
        if (String.isBlank(baseXf) || baseXf.contains('wrapText="1"')) {
            return baseStyleIndex;
        }
        Integer wrapIdx = appendNewCellXf(
            entryByPath,
            composeResultCellXf(
                extractXfIntAttribute(baseXf, 'fontId', 0),
                extractXfIntAttribute(baseXf, 'fillId', 0),
                extractXfIntAttribute(baseXf, 'borderId', 1),
                true
            )
        );
        return wrapIdx != null ? wrapIdx : baseStyleIndex;
    }

    private static Integer extractXfIntAttribute(String xfXml, String attrName, Integer defaultVal) {
        if (String.isBlank(xfXml) || String.isBlank(attrName)) {
            return defaultVal;
        }
        Pattern p = Pattern.compile(attrName + '="(\\d+)"');
        Matcher m = p.matcher(xfXml);
        if (m.find()) {
            try {
                return Integer.valueOf(m.group(1));
            } catch (Exception ex) {
                return defaultVal;
            }
        }
        return defaultVal;
    }

    private static String removeCellAtAddress(String rowXml, String addr) {
        if (String.isBlank(rowXml) || String.isBlank(addr)) {
            return rowXml;
        }
        Pattern cellPat = Pattern.compile(
            '(?s)<c r="' + Pattern.quote(addr) + '"[^>]*(?:/>|>.*?</c>)'
        );
        Matcher cellMat = cellPat.matcher(rowXml);
        if (!cellMat.find()) {
            return rowXml;
        }
        return cellMat.replaceFirst(FEC_ConstantCommon.STR_EMPTY);
    }

    private static Integer extractStyleIndexFromRow(
        String rowXml,
        Integer colIndex,
        Integer rowNum1
    ) {
        if (String.isBlank(rowXml) || colIndex == null || colIndex < 0 || rowNum1 == null || rowNum1 < 1) {
            return null;
        }
        String colLetter = columnIndexToLetter(colIndex);
        String addr = colLetter + String.valueOf(rowNum1);
        Pattern cellPat = Pattern.compile(
            '<c r="' + Pattern.quote(addr) + '"([^>]*)(?:>(.*?)</c>|/>)'
        );
        Matcher cellMat = cellPat.matcher(rowXml);
        if (!cellMat.find()) {
            return null;
        }
        String attrs = cellMat.group(1) == null ? FEC_ConstantCommon.STR_EMPTY : cellMat.group(1);
        String body = cellMat.group(2) == null ? FEC_ConstantCommon.STR_EMPTY : cellMat.group(2);
        Pattern stylePat = Pattern.compile(' s="(\\d+)"');
        Matcher styleMat = stylePat.matcher(attrs + body);
        if (!styleMat.find()) {
            return null;
        }
        try {
            return Integer.valueOf(styleMat.group(1));
        } catch (Exception ex) {
            return null;
        }
    }

    private static String styleIndexToAttr(Integer styleIndex) {
        return styleIndex == null ? FEC_ConstantCommon.STR_EMPTY : ' s="' + String.valueOf(styleIndex) + '"';
    }

    private static String clearFixedRowHeight(String rowXml) {
        if (String.isBlank(rowXml)) {
            return rowXml;
        }
        String out = rowXml;
        out = out.replace(' customHeight="1"', FEC_ConstantCommon.STR_EMPTY);
        out = out.replace(' customHeight="true"', FEC_ConstantCommon.STR_EMPTY);
        Pattern htPat = Pattern.compile(' ht="[0-9\\.]+"');
        Matcher htMat = htPat.matcher(out);
        out = htMat.replaceAll(FEC_ConstantCommon.STR_EMPTY);
        return out;
    }

    private static String shiftWorksheetMergeCells(
        String xml,
        Integer insertBeforeColIndex,
        Integer shift
    ) {
        if (String.isBlank(xml) || shift == null || shift < 1 || insertBeforeColIndex == null) {
            return xml;
        }
        Pattern mergePat = Pattern.compile(
            '(?s)(<mergeCell ref=")([A-Z]{1,3})(\\d+):([A-Z]{1,3})(\\d+)(")'
        );
        Matcher mergeMat = mergePat.matcher(xml);
        List<MergeRefReplacement> replacements = new List<MergeRefReplacement>();
        while (mergeMat.find()) {
            String startCol = mergeMat.group(2);
            String startRow = mergeMat.group(3);
            String endCol = mergeMat.group(4);
            String endRow = mergeMat.group(5);
            Integer startIdx = columnLetterToIndex(startCol);
            Integer endIdx = columnLetterToIndex(endCol);
            if (startIdx >= insertBeforeColIndex) {
                startCol = columnIndexToLetter(startIdx + shift);
            }
            if (endIdx >= insertBeforeColIndex) {
                endCol = columnIndexToLetter(endIdx + shift);
            }
            MergeRefReplacement rep = new MergeRefReplacement();
            rep.startPos = mergeMat.start();
            rep.endPos = mergeMat.end();
            rep.replacementText =
                mergeMat.group(1) + startCol + startRow + ':' + endCol + endRow + mergeMat.group(6);
            replacements.add(rep);
        }
        if (replacements.isEmpty()) {
            return xml;
        }
        String out = xml;
        for (Integer i = replacements.size() - 1; i >= 0; i--) {
            MergeRefReplacement rep = replacements[i];
            out =
                out.substring(0, rep.startPos) +
                rep.replacementText +
                out.substring(rep.endPos);
        }
        return out;
    }

    private class MergeRefReplacement {
        Integer startPos;
        Integer endPos;
        String replacementText;
    }

    private static String extractCellXfByIndex(String stylesXml, Integer styleIndex) {
        if (String.isBlank(stylesXml) || styleIndex == null || styleIndex < 0) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Pattern xfsBlockPat = Pattern.compile('(?s)<cellXfs count="(\\d+)">(.*?)</cellXfs>');
        Matcher xfsBlockMat = xfsBlockPat.matcher(stylesXml);
        if (!xfsBlockMat.find()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Pattern xfPat = Pattern.compile('(?s)<xf[^>]*(?:>.*?</xf>|/>)');
        Matcher xfMat = xfPat.matcher(xfsBlockMat.group(2));
        Integer idx = 0;
        while (xfMat.find()) {
            if (idx == styleIndex) {
                return xfMat.group(0);
            }
            idx += 1;
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    private static String composeResultCellXf(
        Integer fontId,
        Integer fillId,
        Integer borderId,
        Boolean wrapText
    ) {
        String alignment = wrapText == true
            ? '<alignment horizontal="left" vertical="center" wrapText="1"/>'
            : '<alignment horizontal="left" vertical="center"/>';
        return '<xf numFmtId="0" fontId="' +
            String.valueOf(fontId) +
            '" fillId="' +
            String.valueOf(fillId) +
            '" borderId="' +
            String.valueOf(borderId) +
            '" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">' +
            alignment +
            '</xf>';
    }

    private static Integer appendNewCellXf(Map<String, Blob> entryByPath, String newXfXml) {
        if (entryByPath == null || String.isBlank(newXfXml)) {
            return null;
        }
        String stylesPath = 'xl/styles.xml';
        if (!entryByPath.containsKey(stylesPath)) {
            return null;
        }
        String xml = blobToUtf8(entryByPath.get(stylesPath));
        if (String.isBlank(xml)) {
            return null;
        }
        Pattern xfsBlockPat = Pattern.compile('(?s)<cellXfs count="(\\d+)">(.*?)</cellXfs>');
        Matcher xfsBlockMat = xfsBlockPat.matcher(xml);
        if (!xfsBlockMat.find()) {
            return null;
        }
        String xfsInner = xfsBlockMat.group(2);
        Pattern xfPat = Pattern.compile('(?s)<xf[^>]*(?:>.*?</xf>|/>)');
        Matcher xfMat = xfPat.matcher(xfsInner);
        List<String> xfs = new List<String>();
        while (xfMat.find()) {
            xfs.add(xfMat.group(0));
        }
        Integer newIdx = xfs.size();
        xfs.add(newXfXml);
        String newInner = String.join(xfs, FEC_ConstantCommon.STR_EMPTY);
        String newBlock =
            '<cellXfs count="' +
            String.valueOf(xfs.size()) +
            '">' +
            newInner +
            '</cellXfs>';
        String newXml = xfsBlockMat.replaceFirst(Matcher.quoteReplacement(newBlock));
        entryByPath.put(stylesPath, Blob.valueOf(newXml));
        return newIdx;
    }

    private static String columnIndexToLetter(Integer colIndex) {
        Integer columnNumber = colIndex + 1;
        String columnName = FEC_ConstantCommon.STR_EMPTY;
        while (columnNumber > 0) {
            Integer rem = Math.mod(columnNumber - 1, 26);
            columnName = String.fromCharArray(new List<Integer>{ 65 + rem }) + columnName;
            columnNumber = (columnNumber - 1) / 26;
        }
        return columnName;
    }

    private static String sanitizeXmlText(String value) {
        if (value == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return value.replaceAll('[\\u0000-\\u0008\\u000B\\u000C\\u000E-\\u001F]', FEC_ConstantCommon.STR_EMPTY);
    }

    private static String escapeXml(String value) {
        if (value == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String sanitized = sanitizeXmlText(value);
        return sanitized.replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;');
    }

    private static Integer resolveLastPatchedColumnIndex(List<Integer> mappedCols) {
        Integer maxColIdx = null;
        if (mappedCols == null) {
            return null;
        }
        for (Integer colIdx : mappedCols) {
            if (colIdx == null || colIdx < 0) {
                continue;
            }
            if (maxColIdx == null || colIdx > maxColIdx) {
                maxColIdx = colIdx;
            }
        }
        return maxColIdx;
    }

    private static String updateDimensionRef(String xml, Integer lastRow1, Integer lastColIndex) {
        Pattern p = Pattern.compile('(<dimension ref=")([A-Z]+)(\\d+):([A-Z]+)(\\d+)(")');
        Matcher m = p.matcher(xml);
        if (!m.find()) {
            return xml;
        }
        String startCol = m.group(2);
        String startRow = m.group(3);
        String endCol = lastColIndex == null || lastColIndex < 0
            ? m.group(4)
            : columnIndexToLetter(lastColIndex);
        String endRow = lastRow1 == null || lastRow1 < 1
            ? m.group(5)
            : String.valueOf(lastRow1);
        return m.replaceFirst('$1' + startCol + startRow + ':' + endCol + endRow + '$6');
    }

}