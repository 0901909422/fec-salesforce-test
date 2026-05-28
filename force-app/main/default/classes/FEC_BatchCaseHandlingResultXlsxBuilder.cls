/**
 * Builds minimal OOXML .xlsx workbooks for Batch Case Handling import result files.
 * Uses inlineStr cells so Vietnamese and other Unicode text render correctly in Excel.
 */
public with sharing class FEC_BatchCaseHandlingResultXlsxBuilder {

    private static final String SHEET_NAME = 'Result';
    private static final String XML_DECL_STANDALONE = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
    private static final String XML_DECL = '<?xml version="1.0" encoding="UTF-8"?>';
    private static final String NS_PACKAGE_RELATIONSHIPS = 'http://schemas.openxmlformats.org/package/2006/relationships';
    private static final String REL_OFFICE_DOCUMENT = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument';
    private static final String REL_WORKSHEET = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet';
    private static final String REL_STYLES = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles';
    private static final String NS_SPREADSHEET_MAIN = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
    private static final String NS_CONTENT_TYPES = 'http://schemas.openxmlformats.org/package/2006/content-types';
    private static final String CT_RELS = 'application/vnd.openxmlformats-package.relationships+xml';
    private static final String CT_XML = 'application/xml';
    private static final String CT_WORKBOOK = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml';
    private static final String CT_WORKSHEET = 'application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml';
    private static final String CT_STYLES = 'application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml';

    public static Blob buildWorkbookBlob(List<List<String>> sheetRows) {
        return buildWorkbookBlob(sheetRows, null);
    }

    /**
     * @param textColumnIndices Cột zero-based format Text (@) — account/contract, phone.
     */
    public static Blob buildWorkbookBlob(List<List<String>> sheetRows, Set<Integer> textColumnIndices) {
        if (sheetRows == null || sheetRows.isEmpty()) {
            return null;
        }
        Integer maxCols = 0;
        for (List<String> row : sheetRows) {
            if (row != null && row.size() > maxCols) {
                maxCols = row.size();
            }
        }
        if (maxCols < 1) {
            return null;
        }
        Integer rowCount = sheetRows.size();
        String lastCol = columnLetter(maxCols - 1);
        String dimensionRef = 'A1:' + lastCol + String.valueOf(rowCount);
        List<String> rowXmlParts = new List<String>();
        for (Integer rowIdx = 0; rowIdx < sheetRows.size(); rowIdx++) {
            rowXmlParts.add(buildRowXml(rowIdx + 1, sheetRows[rowIdx], maxCols, textColumnIndices));
        }
        String sheetXml =
            XML_DECL_STANDALONE +
            '<worksheet xmlns="' +
            NS_SPREADSHEET_MAIN +
            '">' +
            '<dimension ref="' +
            dimensionRef +
            '"/>' +
            '<sheetViews><sheetView workbookViewId="0"/></sheetViews>' +
            '<sheetFormatPr defaultRowHeight="15"/>' +
            '<sheetData>' +
            String.join(rowXmlParts, '') +
            '</sheetData>' +
            '</worksheet>';
        Compression.ZipWriter writer = new Compression.ZipWriter();
        writer.addEntry(
            '[Content_Types].xml',
            Blob.valueOf(
                XML_DECL_STANDALONE +
                    '<Types xmlns="' +
                    NS_CONTENT_TYPES +
                    '">' +
                    '<Default Extension="rels" ContentType="' +
                    CT_RELS +
                    '"/>' +
                    '<Default Extension="xml" ContentType="' +
                    CT_XML +
                    '"/>' +
                    '<Override PartName="/xl/workbook.xml" ContentType="' +
                    CT_WORKBOOK +
                    '"/>' +
                    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="' +
                    CT_WORKSHEET +
                    '"/>' +
                    '<Override PartName="/xl/styles.xml" ContentType="' +
                    CT_STYLES +
                    '"/>' +
                    '</Types>'
            )
        );
        writer.addEntry(
            '_rels/.rels',
            Blob.valueOf(
                XML_DECL_STANDALONE +
                    '<Relationships xmlns="' +
                    NS_PACKAGE_RELATIONSHIPS +
                    '">' +
                    '<Relationship Id="rId1" Type="' +
                    REL_OFFICE_DOCUMENT +
                    '" Target="xl/workbook.xml"/>' +
                    '</Relationships>'
            )
        );
        writer.addEntry(
            'xl/_rels/workbook.xml.rels',
            Blob.valueOf(
                XML_DECL_STANDALONE +
                    '<Relationships xmlns="' +
                    NS_PACKAGE_RELATIONSHIPS +
                    '">' +
                    '<Relationship Id="rId1" Type="' +
                    REL_WORKSHEET +
                    '" Target="worksheets/sheet1.xml"/>' +
                    '<Relationship Id="rId2" Type="' +
                    REL_STYLES +
                    '" Target="styles.xml"/>' +
                    '</Relationships>'
            )
        );
        writer.addEntry(
            'xl/workbook.xml',
            Blob.valueOf(
                XML_DECL_STANDALONE +
                    '<workbook xmlns="' +
                    NS_SPREADSHEET_MAIN +
                    '" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
                    '<sheets><sheet name="' +
                    xmlEscape(SHEET_NAME) +
                    '" sheetId="1" r:id="rId1"/></sheets>' +
                    '</workbook>'
            )
        );
        writer.addEntry(
            'xl/styles.xml',
            Blob.valueOf(
                XML_DECL +
                    '<styleSheet xmlns="' +
                    NS_SPREADSHEET_MAIN +
                    '">' +
                    '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>' +
                    '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>' +
                    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>' +
                    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
                    '<cellXfs count="3">' +
                    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' +
                    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1">' +
                    '<alignment wrapText="1" vertical="top"/>' +
                    '</xf>' +
                    '<xf numFmtId="49" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>' +
                    '</cellXfs>' +
                    '</styleSheet>'
            )
        );
        writer.addEntry('xl/worksheets/sheet1.xml', Blob.valueOf(sheetXml));
        return writer.getArchive();
    }

    private static String buildRowXml(
        Integer rowNumber,
        List<String> values,
        Integer maxCols,
        Set<Integer> textColumnIndices
    ) {
        List<String> cellParts = new List<String>();
        for (Integer colIdx = 0; colIdx < maxCols; colIdx++) {
            String cellValue = FEC_ConstantCommon.STR_EMPTY;
            if (values != null && colIdx < values.size() && values[colIdx] != null) {
                cellValue = values[colIdx];
            }
            Boolean isErrorsCol = colIdx == maxCols - 1;
            String styleAttr = FEC_ConstantCommon.STR_EMPTY;
            if (isErrorsCol) {
                styleAttr = ' s="1"';
            } else if (textColumnIndices != null && textColumnIndices.contains(colIdx)) {
                styleAttr = ' s="2"';
            }
            String tTagOpen =
                cellValue.contains('\n') || cellValue.contains('\r')
                    ? '<t xml:space="preserve">'
                    : '<t>';
            cellParts.add(
                '<c r="' +
                    columnLetter(colIdx) +
                    String.valueOf(rowNumber) +
                    '"' +
                    styleAttr +
                    ' t="inlineStr"><is>' +
                    tTagOpen +
                    xmlEscape(cellValue) +
                    '</t></is></c>'
            );
        }
        return '<row r="' + String.valueOf(rowNumber) + '">' + String.join(cellParts, '') + '</row>';
    }

    private static String columnLetter(Integer zeroBasedCol) {
        Integer dividend = zeroBasedCol + 1;
        String columnName = FEC_ConstantCommon.STR_EMPTY;
        while (dividend > 0) {
            Integer modulo = Math.mod(dividend - 1, 26);
            columnName =
                String.fromCharArray(new List<Integer>{ 65 + modulo }) + columnName;
            dividend = (dividend - modulo) / 26;
        }
        return columnName;
    }

    private static String xmlEscape(String value) {
        if (value == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return value
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;');
    }
}