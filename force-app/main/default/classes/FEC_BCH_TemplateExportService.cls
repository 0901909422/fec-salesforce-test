public without sharing class FEC_BCH_TemplateExportService {

    public class ExportRequest {
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public Integer headerRowIndex;
        @AuraEnabled public List<Integer> mappedColumnIndexes;
        @AuraEnabled public List<List<String>> dataRows;
    }

    public static String exportWorkbookBase64(String requestJson) {
        if (String.isBlank(requestJson)) {
            return null;
        }
        ExportRequest req = (ExportRequest) JSON.deserialize(requestJson, ExportRequest.class);
        if (req == null || req.contentVersionId == null) {
            return null;
        }
        List<ContentVersion> versions = [
            SELECT VersionData
            FROM ContentVersion
            WHERE Id = :req.contentVersionId
            LIMIT 1
        ];
        if (versions.isEmpty() || versions[0].VersionData == null) {
            return null;
        }
        Blob sourceBlob = versions[0].VersionData;
        Map<String, Blob> entryByPath = readZipEntries(sourceBlob);
        if (entryByPath.isEmpty()) {
            return null;
        }
        String workbookXml = blobToUtf8(entryByPath.get('xl/workbook.xml'));
        String workbookRelsXml = blobToUtf8(entryByPath.get('xl/_rels/workbook.xml.rels'));
        String worksheetPath = resolveMainWorksheetPath(workbookXml, workbookRelsXml);
        if (String.isBlank(worksheetPath) || !entryByPath.containsKey(worksheetPath)) {
            return null;
        }
        Integer headerRowIndex = req.headerRowIndex == null || req.headerRowIndex < 0 ? 0 : req.headerRowIndex;
        List<Integer> mappedCols = req.mappedColumnIndexes == null
            ? new List<Integer>()
            : req.mappedColumnIndexes;
        List<List<String>> dataRows = req.dataRows == null ? new List<List<String>>() : req.dataRows;
        String worksheetXml = blobToUtf8(entryByPath.get(worksheetPath));
        String patchedXml = patchWorksheetXml(worksheetXml, headerRowIndex, mappedCols, dataRows);
        entryByPath.put(worksheetPath, Blob.valueOf(patchedXml));
        Blob outBlob = writeZipEntries(entryByPath, sourceBlob);
        return outBlob == null ? null : EncodingUtil.base64Encode(outBlob);
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
                writer.addEntry(path, body);
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
        if (String.isBlank(chosenRid)) {
            return 'xl/worksheets/sheet1.xml';
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
        return 'xl/worksheets/sheet1.xml';
    }

    private static String patchWorksheetXml(
        String xml,
        Integer headerRowIndex,
        List<Integer> mappedCols,
        List<List<String>> dataRows
    ) {
        if (String.isBlank(xml)) {
            return xml;
        }
        Integer templateDataRow1 = headerRowIndex + 2;
        Integer rowCount = dataRows == null ? 0 : dataRows.size();
        if (rowCount < 1) {
            return xml;
        }
        String templateRowXml = extractRowXml(xml, templateDataRow1);
        if (String.isBlank(templateRowXml)) {
            templateDataRow1 = headerRowIndex + 1;
            templateRowXml = extractRowXml(xml, templateDataRow1);
        }
        if (String.isBlank(templateRowXml)) {
            return xml;
        }
        List<String> builtRows = new List<String>();
        for (Integer i = 0; i < rowCount; i++) {
            Integer rowNum1 = templateDataRow1 + i;
            List<String> values = dataRows[i];
            builtRows.add(buildDataRowXml(templateRowXml, templateDataRow1, rowNum1, mappedCols, values));
        }
        String sheetDataInner = rebuildSheetData(xml, headerRowIndex + 1, builtRows);
        String out = xml.replaceFirst(
            '(?s)<sheetData>.*?</sheetData>',
            '<sheetData>' + sheetDataInner + '</sheetData>'
        );
        Integer lastRow1 = templateDataRow1 + rowCount - 1;
        out = updateDimensionRef(out, lastRow1);
        out = extendAllListValidationSqrefs(out, templateDataRow1, lastRow1);
        return out;
    }

    private static String extractRowXml(String xml, Integer rowNum1) {
        Pattern p = Pattern.compile('(?s)(<row r="' + rowNum1 + '"[^>]*>.*?</row>)');
        Matcher m = p.matcher(xml);
        return m.find() ? m.group(1) : FEC_ConstantCommon.STR_EMPTY;
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
        List<String> values
    ) {
        String rowXml = templateRowXml;
        rowXml = rowXml.replace('r="' + templateRowNum1 + '"', 'r="' + targetRowNum1 + '"');
        rowXml = remapRowCellReferences(rowXml, templateRowNum1, targetRowNum1);
        Set<Integer> mapped = new Set<Integer>();
        if (mappedCols != null) {
            for (Integer c : mappedCols) {
                if (c != null && c >= 0) {
                    mapped.add(c);
                }
            }
        }
        for (Integer colIdx : mapped) {
            String colLetter = columnIndexToLetter(colIdx);
            String val = FEC_ConstantCommon.STR_EMPTY;
            if (values != null && colIdx < values.size() && values[colIdx] != null) {
                val = String.valueOf(values[colIdx]);
            }
            rowXml = upsertCellInline(rowXml, colLetter, targetRowNum1, val);
        }
        return rowXml;
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
        String addr = colLetter + String.valueOf(rowNum1);
        String escaped = escapeXml(value);
        Pattern selfClosing = Pattern.compile('<c r="' + addr + '"([^/>]*)/>');
        Matcher mClose = selfClosing.matcher(rowXml);
        if (mClose.find()) {
            String styleAttr = extractStyleAttr(mClose.group(1));
            String newCell = buildInlineCell(addr, styleAttr, escaped);
            return mClose.replaceFirst(Matcher.quoteReplacement(newCell));
        }
        Pattern fullCell = Pattern.compile('<c r="' + addr + '"[^>]*>.*?</c>');
        Matcher mFull = fullCell.matcher(rowXml);
        if (mFull.find()) {
            String styleAttr = extractStyleAttr(mFull.group(0));
            String newCell = buildInlineCell(addr, styleAttr, escaped);
            return mFull.replaceFirst(Matcher.quoteReplacement(newCell));
        }
        Integer closeIdx = rowXml.lastIndexOf('</row>');
        if (closeIdx < 0) {
            return rowXml;
        }
        String newCell = buildInlineCell(addr, FEC_ConstantCommon.STR_EMPTY, escaped);
        return rowXml.substring(0, closeIdx) + newCell + rowXml.substring(closeIdx);
    }

    private static String extractStyleAttr(String cellFragment) {
        if (String.isBlank(cellFragment)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Pattern p = Pattern.compile(' s="(\\d+)"');
        Matcher m = p.matcher(cellFragment);
        return m.find() ? ' s="' + m.group(1) + '"' : FEC_ConstantCommon.STR_EMPTY;
    }

    private static String buildInlineCell(String addr, String styleAttr, String escapedValue) {
        return '<c r="' + addr + '"' + styleAttr + ' t="inlineStr"><is><t>' + escapedValue + '</t></is></c>';
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

    private static String escapeXml(String value) {
        if (value == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return value.replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;');
    }

    private static String updateDimensionRef(String xml, Integer lastRow1) {
        Pattern p = Pattern.compile('(<dimension ref=")([A-Z]+\\d+):([A-Z]+)(\\d+)(")');
        Matcher m = p.matcher(xml);
        if (m.find()) {
            return m.replaceFirst('$1$2:$3' + String.valueOf(lastRow1) + '$5');
        }
        return xml;
    }

    private static String extendAllListValidationSqrefs(
        String xml,
        Integer templateDataRow1,
        Integer lastDataRow1
    ) {
        if (String.isBlank(xml) || templateDataRow1 == null || lastDataRow1 == null) {
            return xml;
        }
        Pattern sqrefPattern = Pattern.compile('<xm:sqref>([^<]+)</xm:sqref>');
        Matcher matcher = sqrefPattern.matcher(xml);
        String result = FEC_ConstantCommon.STR_EMPTY;
        Integer lastEnd = 0;
        while (matcher.find()) {
            result += xml.substring(lastEnd, matcher.start());
            String extendedSqref = extendSqrefForDataRows(
                matcher.group(1),
                templateDataRow1,
                lastDataRow1
            );
            result += '<xm:sqref>' + extendedSqref + '</xm:sqref>';
            lastEnd = matcher.end();
        }
        result += xml.substring(lastEnd);
        return result;
    }

    @TestVisible
    private static String extendSqrefForDataRows(
        String sqref,
        Integer templateDataRow1,
        Integer lastDataRow1
    ) {
        if (String.isBlank(sqref)) {
            return sqref;
        }
        List<String> updatedRanges = new List<String>();
        Pattern cellRefPattern = Pattern.compile('^\\$?([A-Z]{1,3})\\$?(\\d+)$');
        for (String rangeToken : sqref.split(' ')) {
            if (String.isBlank(rangeToken)) {
                continue;
            }
            String rangeValue = rangeToken.trim();
            List<String> parts = rangeValue.split(':');
            String startRef = parts[0].trim();
            String endRef = parts.size() > 1 ? parts[1].trim() : startRef;
            Matcher startMatcher = cellRefPattern.matcher(startRef);
            if (!startMatcher.find()) {
                updatedRanges.add(rangeValue);
                continue;
            }
            String startCol = startMatcher.group(1);
            Integer startRow = Integer.valueOf(startMatcher.group(2));
            String endCol = startCol;
            Integer endRow = startRow;
            Matcher endMatcher = cellRefPattern.matcher(endRef);
            if (endMatcher.find()) {
                endCol = endMatcher.group(1);
                endRow = Integer.valueOf(endMatcher.group(2));
            }
            if (endRow < templateDataRow1) {
                updatedRanges.add(rangeValue);
                continue;
            }
            Integer newEndRow = Math.max(endRow, lastDataRow1);
            if (startRow.equals(newEndRow) && startCol.equals(endCol)) {
                updatedRanges.add(startCol + String.valueOf(startRow));
            } else {
                updatedRanges.add(
                    startCol +
                    String.valueOf(startRow) +
                    ':' +
                    endCol +
                    String.valueOf(newEndRow)
                );
            }
        }
        return String.join(updatedRanges, ' ');
    }
}
