public without sharing class FEC_BCH_TemplateExportService {

    private static final String DBG = 'FEC_BCH_EXPORT';
    private static final Integer MAX_EXPORT_DATA_ROWS = 5000;

    public class ExportRequest {
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public Integer headerRowIndex;
        @AuraEnabled public List<Integer> mappedColumnIndexes;
        @AuraEnabled public List<List<String>> dataRows;
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
            String worksheetPath = resolveMainWorksheetPath(workbookXml, workbookRelsXml);
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
            Integer templateDataRow1 = resolveTemplateDataRowFromValidations(worksheetXml);
            if (templateDataRow1 == null || templateDataRow1 < 1) {
                templateDataRow1 = headerRowIndex + 2;
            }
            if (String.isBlank(extractRowXml(worksheetXml, templateDataRow1))) {
                templateDataRow1 = headerRowIndex + 1;
            }
            if (String.isBlank(extractRowXml(worksheetXml, templateDataRow1))) {
                return fail(out, 'TEMPLATE_ROW_MISSING', 'headerRow=' + headerRowIndex);
            }
            dbg('PATCH', 'sheet=' + worksheetPath + ';rows=' + dataRows.size() + ';dataRow=' + templateDataRow1);
            String patchedXml = patchWorksheetXml(
                worksheetXml,
                headerRowIndex,
                mappedCols,
                dataRows,
                entryByPath,
                workbookXml,
                workbookRelsXml
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

    private class ValidationHeaderPair {
        List<String> mainMustContain;
        List<String> mainMustNotContain;
        List<String> lookupMustContain;
        Boolean mainMatchAny;
        Boolean lookupMatchAny;
    }

    private static String patchWorksheetXml(
        String xml,
        Integer headerRowIndex,
        List<Integer> mappedCols,
        List<List<String>> dataRows,
        Map<String, Blob> entryByPath,
        String workbookXml,
        String workbookRelsXml
    ) {
        if (String.isBlank(xml)) {
            return xml;
        }
        Integer templateDataRow1 = resolveTemplateDataRowFromValidations(xml);
        if (templateDataRow1 == null || templateDataRow1 < 1) {
            templateDataRow1 = headerRowIndex + 2;
        }
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
        out = updateDimensionRef(out, lastRow1);
        out = applyHeaderBasedListValidations(
            out,
            entryByPath,
            workbookXml,
            workbookRelsXml,
            headerRowIndex,
            templateDataRow1,
            lastRow1
        );
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
            Pattern tPat = Pattern.compile('<t[^>]*>([^<]*)</t>');
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

    private static String resolveCellDisplayText(String cellXml, List<String> sharedStrings) {
        if (String.isBlank(cellXml)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Pattern inlinePat = Pattern.compile('(?s)<is>.*?<t[^>]*>([^<]*)</t>');
        Matcher inlineMat = inlinePat.matcher(cellXml);
        if (inlineMat.find()) {
            return inlineMat.group(1);
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
        Integer lastDataRow1
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
        String x14Block =
            '<x14:dataValidations count="' +
            String.valueOf(x14ValidationNodes.size()) +
            '" xmlns:xm="http://schemas.microsoft.com/office/excel/2006/main">' +
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
        String extTag =
            '<ext uri="{CCE6A557-97BC-4b89-ADB6-D9C93CAAB3DF}" xmlns:x14="http://schemas.microsoft.com/office/spreadsheetml/2009/9/main">' +
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
            return replaceFirstMatch(rowXml, selfClosing, newCell);
        }
        Pattern fullCell = Pattern.compile('<c r="' + addr + '"[^>]*>.*?</c>');
        Matcher mFull = fullCell.matcher(rowXml);
        if (mFull.find()) {
            String styleAttr = extractStyleAttr(mFull.group(0));
            String newCell = buildInlineCell(addr, styleAttr, escaped);
            return replaceFirstMatch(rowXml, fullCell, newCell);
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

    private static String updateDimensionRef(String xml, Integer lastRow1) {
        Pattern p = Pattern.compile('(<dimension ref=")([A-Z]+\\d+):([A-Z]+)(\\d+)(")');
        Matcher m = p.matcher(xml);
        if (m.find()) {
            return m.replaceFirst('$1$2:$3' + String.valueOf(lastRow1) + '$5');
        }
        return xml;
    }

}
