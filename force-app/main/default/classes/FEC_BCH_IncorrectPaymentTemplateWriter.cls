public without sharing class FEC_BCH_IncorrectPaymentTemplateWriter {

    private static final String TARGET_TEMPLATE_FILE = 'incorrectpaymenttemp1_pm.xlsx';

    // tungnm37 - dedicated header mapping for Incorrect Payment template export
    private static final Map<String, String> HEADER_FIELD_MAP = new Map<String, String>{
        'customername' => 'customerName',
        'accountcontractnumber' => 'accountContractNumber',
        'accountandcontractnumber' => 'accountContractNumber',
        'accountcontractno' => 'accountContractNumber',
        'accountcontract' => 'accountContractNumber',
        'appid' => 'appId',
        'applicationid' => 'appId',
        'interactionid' => 'interactionId',
        'interactionchannel' => 'interactionChannel',
        'interactionsubchannel' => 'interactionSubChannel',
        'interactionphone' => 'interactionPhone',
        'interactionemail' => 'interactionEmail',
        'casestatus' => 'caseStatus',
        'casecreatedon' => 'caseCreatedOnLabel',
        'lastupdatedon' => 'lastUpdatedOnLabel',
        'producttype' => 'productType',
        'producttypecode' => 'productType',
        'category' => 'categoryCode',
        'updatedcategory' => 'categoryCode',
        'subcategory' => 'subCategoryCode',
        'updatedsubcategory' => 'subCategoryCode',
        'subcode' => 'subCodeCode',
        'updatedsubcode' => 'subCodeCode',
        'caseremarks' => 'caseRemarks',
        'caseremarksenteredby' => 'caseRemarksEnteredBy',
        'caseremarksenteredbyrole' => 'caseRemarksEnteredByRole',
        'caseremarksenteredon' => 'caseRemarksEnteredOn',
        'incorrectcontractnumber' => 'incorrectContractNumber',
        'paymentmethod' => 'paymentMethod',
        'billdate' => 'billDate',
        'billamount' => 'billAmount',
        'paymentdate' => 'paymentDate',
        'excessamount' => 'excessAmount',
        'selectedcontractnumber' => 'selectedContractNumber',
        'correctcontractnumber' => 'correctContractNumber',
        'correctaccountcontract' => 'correctAccountContract',
        'correctaccountandcontract' => 'correctAccountContract',
        'adjustedamount' => 'adjustedAmount'
    };

    private static final Set<String> USER_FILL_HEADERS = new Set<String>{
        'no',
        'num',
        'stt',
        'result',
        'status',
        'note',
        'remarks',
        'checkerremarks',
        'makerremarks'
    };

    private static final List<String> CASE_ID_HEADERS = new List<String>{
        'caseid',
        'caseidsearch'
    };

    public static Boolean shouldHandle(Id contentVersionId) {
        if (contentVersionId == null) {
            return false;
        }
        List<ContentVersion> versions = [
            SELECT Id, Title, PathOnClient, FileExtension
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];
        if (versions.isEmpty()) {
            return false;
        }
        return isTargetTemplateFileName(resolveTemplateFileName(versions[0]));
    }

    public static FEC_BCH_TemplateExportService.ExportWorkbookResponse exportWorkbook(String requestJson) {
        FEC_BCH_TemplateExportService.ExportWorkbookResponse out = new FEC_BCH_TemplateExportService.ExportWorkbookResponse();
        out.success = false;
        out.base64Body = null;
        out.errorCode = 'UNSUPPORTED_TEMPLATE';
        out.errorMessage = 'Incorrect Payment template writer can only handle IncorrectPaymentTemp1_PM.xlsx';

        if (String.isBlank(requestJson)) {
            out.errorCode = 'EMPTY_REQUEST';
            out.errorMessage = 'requestJson is blank';
            return out;
        }

        FEC_BCH_TemplateExportService.ExportRequest req =
            (FEC_BCH_TemplateExportService.ExportRequest) JSON.deserialize(
                requestJson,
                FEC_BCH_TemplateExportService.ExportRequest.class
            );
        if (req == null || req.contentVersionId == null) {
            out.errorCode = 'INVALID_REQUEST';
            out.errorMessage = 'contentVersionId is required';
            return out;
        }
        if (!shouldHandle(req.contentVersionId)) {
            return out;
        }

        // tungnm37 - rebuild Incorrect Payment rows from queried export payload instead of trusting generic header match
        FEC_BCH_TemplateExportService.ExportRequest rewrittenReq = rebuildExportRequest(req);
        if (rewrittenReq == null) {
            out.errorCode = 'REBUILD_REQUEST_FAILED';
            out.errorMessage = 'Unable to rebuild Incorrect Payment export request';
            return out;
        }
        return FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(rewrittenReq));
    }

    // tungnm37 - derive row values by template headers and fresh export-row payload from Apex
    private static FEC_BCH_TemplateExportService.ExportRequest rebuildExportRequest(
        FEC_BCH_TemplateExportService.ExportRequest req
    ) {
        TemplateContext ctx = loadTemplateContext(req.contentVersionId, req.headerRowIndex);
        if (ctx == null || ctx.headerCells == null || ctx.headerCells.isEmpty()) {
            return req;
        }

        Integer caseIdIndex = findCaseIdColumnIndex(ctx.headerCells);
        if (caseIdIndex < 0) {
            return req;
        }

        Set<String> caseIdSearchValues = new Set<String>();
        List<List<String>> sourceRows = req.dataRows == null ? new List<List<String>>() : req.dataRows;
        for (List<String> row : sourceRows) {
            String caseIdSearch = getCell(row, caseIdIndex);
            if (String.isNotBlank(caseIdSearch)) {
                caseIdSearchValues.add(caseIdSearch.trim());
            }
        }
        if (caseIdSearchValues.isEmpty()) {
            return req;
        }

        Map<String, IncorrectPaymentExportBundle> exportBundleByCaseIdSearch = queryExportRows(caseIdSearchValues); // tungnm37
        if (exportBundleByCaseIdSearch.isEmpty()) {
            return req;
        }

        List<List<String>> rebuiltRows = new List<List<String>>();
        Integer columnCount = ctx.headerCells.size();
        for (List<String> sourceRow : sourceRows) {
            String caseIdSearch = getCell(sourceRow, caseIdIndex);
            IncorrectPaymentExportBundle exportBundle = String.isBlank(caseIdSearch)
                ? null
                : exportBundleByCaseIdSearch.get(caseIdSearch.trim());
            rebuiltRows.add(buildTemplateRow(ctx.headerCells, exportBundle, sourceRow, columnCount));
        }

        FEC_BCH_TemplateExportService.ExportRequest rewrittenReq = new FEC_BCH_TemplateExportService.ExportRequest();
        rewrittenReq.contentVersionId = req.contentVersionId;
        rewrittenReq.headerRowIndex = req.headerRowIndex;
        rewrittenReq.mappedColumnIndexes = buildSequentialIndexes(columnCount);
        rewrittenReq.dataRows = rebuiltRows;
        return rewrittenReq;
    }

    private static Map<String, IncorrectPaymentExportBundle> queryExportRows(Set<String> caseIdSearchValues) {
        Map<String, IncorrectPaymentExportBundle> out = new Map<String, IncorrectPaymentExportBundle>();
        if (caseIdSearchValues == null || caseIdSearchValues.isEmpty()) {
            return out;
        }
        String soql =
            'SELECT ' + String.join(FEC_BatchCaseHandlingExportService.buildCaseExportSelectFields(), ', ') +
            ' FROM Case WHERE FEC_ID_Search__c IN :caseIdSearchValues';
        List<Case> cases = Database.query(soql);
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, cases);
        cases = (List<Case>) decision.getRecords();
        List<FEC_BatchCaseHandlingExportRow> rows = new List<FEC_BatchCaseHandlingExportRow>();
        for (Case c : cases) {
            rows.add(FEC_BatchCaseHandlingExportService.mapCaseToExportRow(c));
        }
        FEC_BatchCaseHandlingExportService.applyVisibleAttachmentFlags(rows);
        FEC_BatchCaseHandlingExportService.enrichExportRows(rows);
        Map<Id, List<IncorrectPaymentAdjustmentRow>> adjustmentsByCaseId = loadIncorrectPaymentAdjustments(rows); // tungnm37
        for (FEC_BatchCaseHandlingExportRow row : rows) {
            if (row != null && String.isNotBlank(row.caseIdSearch)) {
                IncorrectPaymentExportBundle bundle = new IncorrectPaymentExportBundle();
                bundle.exportRow = row;
                bundle.adjustmentRows = row.caseId == null || !adjustmentsByCaseId.containsKey(row.caseId)
                    ? new List<IncorrectPaymentAdjustmentRow>()
                    : adjustmentsByCaseId.get(row.caseId);
                out.put(row.caseIdSearch.trim(), bundle);
            }
        }
        return out;
    }

    private static List<String> buildTemplateRow(
        List<String> headerCells,
        IncorrectPaymentExportBundle exportBundle,
        List<String> sourceRow,
        Integer columnCount
    ) {
        List<String> out = new List<String>();
        for (Integer i = 0; i < columnCount; i++) {
            String header = i < headerCells.size() ? headerCells[i] : null;
            String normalizedHeader = normalizeHeader(header);
            String fieldKey = resolveExportFieldKey(normalizedHeader);
            String value = getCell(sourceRow, i);
            if (exportBundle != null) {
                String adjustmentValue = resolveAdjustmentColumnValue(exportBundle, normalizedHeader); // tungnm37
                if (adjustmentValue != null) {
                    value = adjustmentValue;
                } else if (exportBundle.exportRow != null && String.isNotBlank(fieldKey)) {
                    value = stringifyFieldValue(exportBundle.exportRow, fieldKey);
                }
            }
            out.add(value);
        }
        return out;
    }

    private static List<Integer> buildSequentialIndexes(Integer size) {
        List<Integer> out = new List<Integer>();
        Integer count = size == null || size < 0 ? 0 : size;
        for (Integer i = 0; i < count; i++) {
            out.add(i);
        }
        return out;
    }

    private static Integer findCaseIdColumnIndex(List<String> headerCells) {
        if (headerCells == null) {
            return -1;
        }
        for (Integer i = 0; i < headerCells.size(); i++) {
            String normalized = normalizeHeader(headerCells[i]);
            if (CASE_ID_HEADERS.contains(normalized)) {
                return i;
            }
        }
        return -1;
    }

    private static String resolveExportFieldKey(String normalizedHeader) {
        if (String.isBlank(normalizedHeader)) {
            return null;
        }
        if (USER_FILL_HEADERS.contains(normalizedHeader)) {
            return null;
        }
        if (CASE_ID_HEADERS.contains(normalizedHeader)) {
            return 'caseIdSearch';
        }
        return HEADER_FIELD_MAP.get(normalizedHeader);
    }

    private static String resolveAdjustmentColumnValue(IncorrectPaymentExportBundle exportBundle, String normalizedHeader) {
        if (exportBundle == null || String.isBlank(normalizedHeader)) {
            return null;
        }
        if (normalizedHeader == 'correctcontractamountlessthan1greaterthan' || normalizedHeader == 'correctcontractamount1') {
            return resolveAdjustmentRowField(exportBundle.adjustmentRows, 0, true);
        }
        if (normalizedHeader == 'adjustedamountlessthan1greaterthan' || normalizedHeader == 'adjustedamount1') {
            return resolveAdjustmentRowField(exportBundle.adjustmentRows, 0, false);
        }
        Matcher correctMat = Pattern.compile('^correctcontractamount([0-9]+)$').matcher(normalizedHeader);
        if (correctMat.find()) {
            Integer idx = Integer.valueOf(correctMat.group(1)) - 1;
            return resolveAdjustmentRowField(exportBundle.adjustmentRows, idx, true);
        }
        Matcher adjustedMat = Pattern.compile('^adjustedamount([0-9]+)$').matcher(normalizedHeader);
        if (adjustedMat.find()) {
            Integer idx = Integer.valueOf(adjustedMat.group(1)) - 1;
            return resolveAdjustmentRowField(exportBundle.adjustmentRows, idx, false);
        }
        return null;
    }

    private static String resolveAdjustmentRowField(List<IncorrectPaymentAdjustmentRow> rows, Integer index, Boolean useCorrectAccountContract) {
        if (rows == null || index == null || index < 0 || index >= rows.size()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        IncorrectPaymentAdjustmentRow row = rows[index];
        if (row == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return useCorrectAccountContract ? row.correctAccountContract : row.adjustedAmount;
    }

    private static String stringifyFieldValue(FEC_BatchCaseHandlingExportRow row, String fieldName) {
        if (row == null || String.isBlank(fieldName)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Map<String, Object> rowMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(row));
        Object val = rowMap == null ? null : rowMap.get(fieldName);
        return val == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(val);
    }

    private static String getCell(List<String> row, Integer idx) {
        if (row == null || idx == null || idx < 0 || idx >= row.size()) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return row[idx] == null ? FEC_ConstantCommon.STR_EMPTY : row[idx];
    }

    private static TemplateContext loadTemplateContext(Id contentVersionId, Integer headerRowIndex) {
        List<ContentVersion> versions = [
            SELECT VersionData
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];
        if (versions.isEmpty() || versions[0].VersionData == null) {
            return null;
        }
        Compression.ZipReader reader = new Compression.ZipReader(versions[0].VersionData);
        Map<String, Blob> entryByPath = new Map<String, Blob>();
        for (String entryName : reader.getEntryNames()) {
            if (String.isBlank(entryName) || entryName.endsWith('/')) {
                continue;
            }
            entryByPath.put(normalizeZipPath(entryName), reader.extract(entryName));
        }
        String workbookXml = blobToUtf8(entryByPath.get('xl/workbook.xml'));
        String workbookRelsXml = blobToUtf8(entryByPath.get('xl/_rels/workbook.xml.rels'));
        String worksheetPath = resolveMainWorksheetPath(workbookXml, workbookRelsXml);
        String worksheetXml = blobToUtf8(entryByPath.get(worksheetPath));
        Integer headerRow1 = (headerRowIndex == null || headerRowIndex < 0 ? 0 : headerRowIndex) + 1;
        List<String> sharedStrings = parseSharedStrings(blobToUtf8(entryByPath.get('xl/sharedStrings.xml')));
        TemplateContext ctx = new TemplateContext();
        ctx.headerCells = parseHeaderCells(worksheetXml, headerRow1, sharedStrings);
        return ctx;
    }

    private class TemplateContext {
        List<String> headerCells;
    }

    private class IncorrectPaymentExportBundle {
        FEC_BatchCaseHandlingExportRow exportRow;
        List<IncorrectPaymentAdjustmentRow> adjustmentRows;
    }

    private class IncorrectPaymentAdjustmentRow {
        String correctAccountContract;
        String adjustedAmount;
    }

    private static Map<Id, List<IncorrectPaymentAdjustmentRow>> loadIncorrectPaymentAdjustments(
        List<FEC_BatchCaseHandlingExportRow> rows
    ) {
        Map<Id, List<IncorrectPaymentAdjustmentRow>> out = new Map<Id, List<IncorrectPaymentAdjustmentRow>>();
        Set<Id> caseIds = new Set<Id>();
        for (FEC_BatchCaseHandlingExportRow row : rows) {
            if (row != null && row.caseId != null) {
                caseIds.add(row.caseId);
            }
        }
        if (caseIds.isEmpty()) {
            return out;
        }
        Schema.SObjectType infoType = Schema.getGlobalDescribe().get('FEC_Incorrect_Payment_Info__c');
        if (infoType == null) {
            return out;
        }
        Map<String, Schema.SObjectField> fieldMap = infoType.getDescribe().fields.getMap();
        String correctFieldApi = null;
        if (fieldMap.containsKey('fec_correct_account_contract__c')) {
            correctFieldApi = 'FEC_Correct_Account_Contract__c';
        } else if (fieldMap.containsKey('fec_correct_contract_number__c')) {
            correctFieldApi = 'FEC_Correct_Contract_Number__c';
        }
        String soql = 'SELECT FEC_Case__c, FEC_Adjusted_Amount__c';
        if (String.isNotBlank(correctFieldApi)) {
            soql += ', ' + correctFieldApi;
        }
        soql += ' FROM FEC_Incorrect_Payment_Info__c WHERE FEC_Case__c IN :caseIds ORDER BY FEC_Case__c, CreatedDate ASC, Id ASC';
        for (SObject item : Database.query(soql)) {
            Id caseId = (Id) item.get('FEC_Case__c');
            if (caseId == null) {
                continue;
            }
            if (!out.containsKey(caseId)) {
                out.put(caseId, new List<IncorrectPaymentAdjustmentRow>());
            }
            IncorrectPaymentAdjustmentRow row = new IncorrectPaymentAdjustmentRow();
            row.correctAccountContract = String.isNotBlank(correctFieldApi) && item.get(correctFieldApi) != null
                ? String.valueOf(item.get(correctFieldApi))
                : FEC_ConstantCommon.STR_EMPTY;
            row.adjustedAmount = item.get('FEC_Adjusted_Amount__c') == null
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(((Decimal) item.get('FEC_Adjusted_Amount__c')).setScale(0));
            out.get(caseId).add(row);
        }
        return out;
    }

    private static List<String> parseHeaderCells(String worksheetXml, Integer rowNum1, List<String> sharedStrings) {
        List<String> out = new List<String>();
        String rowXml = extractRowXml(worksheetXml, rowNum1);
        if (String.isBlank(rowXml)) {
            return out;
        }
        Pattern cellPat = Pattern.compile('(?s)<c([^>]*)r="([A-Z]+)' + String.valueOf(rowNum1) + '"([^>]*)>(.*?)</c>');
        Matcher cellMat = cellPat.matcher(rowXml);
        Integer maxIndex = -1;
        Map<Integer, String> byIndex = new Map<Integer, String>();
        while (cellMat.find()) {
            String colLetters = cellMat.group(2);
            Integer idx = columnLettersToIndex(colLetters);
            String attrs = (cellMat.group(1) == null ? FEC_ConstantCommon.STR_EMPTY : cellMat.group(1)) +
                (cellMat.group(3) == null ? FEC_ConstantCommon.STR_EMPTY : cellMat.group(3));
            String body = cellMat.group(4) == null ? FEC_ConstantCommon.STR_EMPTY : cellMat.group(4);
            byIndex.put(idx, resolveCellDisplayText(attrs + body, sharedStrings));
            if (idx > maxIndex) {
                maxIndex = idx;
            }
        }
        for (Integer i = 0; i <= maxIndex; i++) {
            out.add(byIndex.containsKey(i) ? byIndex.get(i) : FEC_ConstantCommon.STR_EMPTY);
        }
        return out;
    }

    private static String extractRowXml(String xml, Integer rowNum1) {
        if (String.isBlank(xml) || rowNum1 == null || rowNum1 < 1) {
            return null;
        }
        Pattern p = Pattern.compile('(?s)<row[^>]*r="' + String.valueOf(rowNum1) + '"[^>]*>.*?</row>');
        Matcher m = p.matcher(xml);
        return m.find() ? m.group(0) : null;
    }

    private static List<String> parseSharedStrings(String sharedStringsXml) {
        List<String> out = new List<String>();
        if (String.isBlank(sharedStringsXml)) {
            return out;
        }
        Pattern siPat = Pattern.compile('(?s)<si>(.*?)</si>');
        Matcher siMat = siPat.matcher(sharedStringsXml);
        while (siMat.find()) {
            String body = siMat.group(1);
            String text = body == null ? FEC_ConstantCommon.STR_EMPTY : body.replaceAll('(?s)</?r[^>]*>', FEC_ConstantCommon.STR_EMPTY);
            text = text.replaceAll('(?s)</?t[^>]*>', FEC_ConstantCommon.STR_EMPTY);
            out.add(unescapeXml(text));
        }
        return out;
    }

    private static String resolveCellDisplayText(String cellXml, List<String> sharedStrings) {
        if (String.isBlank(cellXml)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Pattern sharedPat = Pattern.compile('(?s)t="s"[^>]*>[\r\n\t ]*<v>([0-9]+)</v>');
        Matcher sharedMat = sharedPat.matcher(cellXml);
        if (sharedMat.find() && sharedStrings != null && !sharedStrings.isEmpty()) {
            Integer idx = Integer.valueOf(sharedMat.group(1));
            if (idx >= 0 && idx < sharedStrings.size()) {
                return sharedStrings[idx];
            }
        }
        Pattern inlinePat = Pattern.compile('(?s)<is>.*?<t[^>]*>(.*?)</t>.*?</is>');
        Matcher inlineMat = inlinePat.matcher(cellXml);
        if (inlineMat.find()) {
            return unescapeXml(inlineMat.group(1));
        }
        Pattern valuePat = Pattern.compile('(?s)<v>(.*?)</v>');
        Matcher valueMat = valuePat.matcher(cellXml);
        return valueMat.find() ? unescapeXml(valueMat.group(1)) : FEC_ConstantCommon.STR_EMPTY;
    }

    private static Integer columnLettersToIndex(String letters) {
        Integer out = 0;
        if (String.isBlank(letters)) {
            return -1;
        }
        String src = letters.trim().toUpperCase();
        for (Integer i = 0; i < src.length(); i++) {
            out = (out * 26) + (src.substring(i, i + 1).charAt(0) - 64);
        }
        return out - 1;
    }

    private static String normalizeHeader(String cell) {
        return (cell == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(cell))
            .replaceAll('[ _/\\-]+', FEC_ConstantCommon.STR_EMPTY)
            .replaceAll('[()]', FEC_ConstantCommon.STR_EMPTY)
            .replace('.', FEC_ConstantCommon.STR_EMPTY)
            .replace(':', FEC_ConstantCommon.STR_EMPTY)
            .replace(',', FEC_ConstantCommon.STR_EMPTY)
            .replace('<', 'lessthan')
            .replace('>', 'greaterthan')
            .replace('&', 'and')
            .toLowerCase();
    }

    private static String resolveTemplateFileName(ContentVersion cv) {
        if (cv == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String name = cv.PathOnClient;
        if (String.isBlank(name)) {
            name = cv.Title;
            if (String.isNotBlank(name) && String.isNotBlank(cv.FileExtension) && !name.toLowerCase().endsWith('.' + cv.FileExtension.toLowerCase())) {
                name += '.' + cv.FileExtension;
            }
        }
        if (String.isBlank(name)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Integer slashIdx = Math.max(name.lastIndexOf('/'), name.lastIndexOf('\\'));
        if (slashIdx >= 0 && slashIdx + 1 < name.length()) {
            name = name.substring(slashIdx + 1);
        }
        return name.trim().toLowerCase();
    }

    private static String normalizeZipPath(String path) {
        if (String.isBlank(path)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return path.replace('\\', '/');
    }

    private static String blobToUtf8(Blob body) {
        return body == null ? FEC_ConstantCommon.STR_EMPTY : body.toString();
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
        Pattern relPat = Pattern.compile('Id="' + Pattern.quote(chosenRid) + '"[^>]+Target="([^"]+)"');
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

    private static String unescapeXml(String value) {
        if (value == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String out = value;
        out = out.replace('<', '<');
        out = out.replace('>', '>');
        out = out.replace('"', '"');
        out = out.replace('&', '&');
        return out;
    }

    private static Boolean isTargetTemplateFileName(String fileName) {
        if (String.isBlank(fileName)) {
            return false;
        }
        return fileName == TARGET_TEMPLATE_FILE;
    }
}