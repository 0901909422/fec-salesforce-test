/**
 * FEC_CampaignValidator
 * Dedicated validation class for campaign data upload flow.
 * Replaces inline validateRow() in FEC_CampaignController with
 * detailed per-field error reporting instead of a generic MSG_FILE_ERR.
 */
public with sharing class FEC_CampaignValidator {

    /**
     * Validation result for a single row.
     */
    public class ValidationResult {
        public Boolean isValid;
        public Integer rowIndex;
        public List<String> errors;

        public ValidationResult(Integer rowIndex) {
            this.rowIndex = rowIndex;
            this.isValid = true;
            this.errors = new List<String>();
        }
    }

    /**
     * Validates all rows from an upload file.
     * Collects ALL errors across all rows (does not stop at first).
     * @param rows  List of row data maps parsed from Excel
     * @param expectedCampaignCode  The expected Campaign ID value
     * @return List of ValidationResult for invalid rows only
     */
    public static List<ValidationResult> validateUploadData(
        List<Map<String, Object>> rows, String expectedCampaignCode
    ) {
        List<ValidationResult> invalidResults = new List<ValidationResult>();
        if (rows == null || rows.isEmpty()) {
            return invalidResults;
        }

        for (Integer i = 0; i < rows.size(); i++) {
            ValidationResult result = validateRow(rows[i], expectedCampaignCode, i);
            if (!result.isValid) {
                invalidResults.add(result);
            }
        }
        return invalidResults;
    }

    /**
     * Validates a single row of upload data.
     * Checks: Campaign ID match, ProductLine, App ID, Account Number, Number 1-3.
     * Error messages include field name and reason.
     * @param row  Map of field name to value for one row
     * @param expectedCampaignCode  The expected Campaign ID
     * @param rowIndex  Zero-based index of the row in the file
     * @return ValidationResult with isValid flag and list of errors
     */
    public static ValidationResult validateRow(
        Map<String, Object> row, String expectedCampaignCode, Integer rowIndex
    ) {
        ValidationResult result = new ValidationResult(rowIndex);
        if (row == null) {
            result.isValid = false;
            result.errors.add('Row ' + (rowIndex + 1) + ': Row data is null');
            return result;
        }

        validateCampaignId(row, expectedCampaignCode, rowIndex, result);
        validateProductLine(row, rowIndex, result);
        validateAppId(row, rowIndex, result);
        validateAccountNumber(row, rowIndex, result);
        validateNumberFields(row, rowIndex, result);

        result.isValid = result.errors.isEmpty();
        return result;
    }

    /**
     * Checks for duplicate composite keys (ProductLine_AppID_AccountNumber).
     * @param rows  List of row data maps
     * @return List of error messages for duplicate keys
     */
    public static List<String> checkDuplicateKeys(List<Map<String, Object>> rows) {
        List<String> duplicateErrors = new List<String>();
        if (rows == null || rows.isEmpty()) {
            return duplicateErrors;
        }

        Map<String, List<Integer>> keyToRows = new Map<String, List<Integer>>();
        for (Integer i = 0; i < rows.size(); i++) {
            Map<String, Object> row = rows[i];
            String key = buildCompositeKey(row);
            if (!keyToRows.containsKey(key)) {
                keyToRows.put(key, new List<Integer>());
            }
            keyToRows.get(key).add(i + 1);
        }

        for (String key : keyToRows.keySet()) {
            List<Integer> rowNumbers = keyToRows.get(key);
            if (rowNumbers.size() > 1) {
                String rowList = String.join(rowNumbers, ', ');
                duplicateErrors.add('Row ' + rowList + ': Duplicate composite key \'' + key + '\'');
            }
        }
        return duplicateErrors;
    }

    // ─── Private Validation Helpers ────────────────────────────────

    private static void validateCampaignId(
        Map<String, Object> row, String expectedCode,
        Integer rowIndex, ValidationResult result
    ) {
        String campaignId = FEC_Util.toString(row.get('Campaign ID'));
        if (campaignId == null || !campaignId.equals(expectedCode)) {
            result.errors.add(
                'Row ' + (rowIndex + 1) + ': Field \'Campaign ID\' - '
                + 'value does not match expected campaign code \'' + expectedCode + '\''
            );
        }
    }

    private static void validateProductLine(
        Map<String, Object> row, Integer rowIndex, ValidationResult result
    ) {
        String productLine = FEC_Util.toString(row.get('ProductLine'));
        if (String.isBlank(productLine)) {
            result.errors.add(
                'Row ' + (rowIndex + 1) + ': Field \'ProductLine\' - must not be blank'
            );
            return;
        }
        if (productLine.length() > FEC_Constants.CAMPAIGN_PRODUCT_LINE_MAX_LENGTH) {
            result.errors.add(
                'Row ' + (rowIndex + 1) + ': Field \'ProductLine\' - '
                + 'exceeds max length of ' + FEC_Constants.CAMPAIGN_PRODUCT_LINE_MAX_LENGTH + ' characters'
            );
        }
        if (!productLine.equalsIgnoreCase(FEC_Constants.CAMPAIGN_PRODUCT_LOAN)
            && !productLine.equalsIgnoreCase(FEC_Constants.CAMPAIGN_PRODUCT_CARD)) {
            result.errors.add(
                'Row ' + (rowIndex + 1) + ': Field \'ProductLine\' - '
                + 'value \'' + productLine + '\' is invalid, only \'Loan\' or \'Card\' accepted'
            );
        }
    }

    private static void validateAppId(
        Map<String, Object> row, Integer rowIndex, ValidationResult result
    ) {
        String appId = FEC_Util.toString(row.get('App ID'));
        if (String.isBlank(appId)) {
            result.errors.add(
                'Row ' + (rowIndex + 1) + ': Field \'App ID\' - must not be blank'
            );
            return;
        }
        if (appId.length() > FEC_Constants.CAMPAIGN_APP_ID_MAX_LENGTH) {
            result.errors.add(
                'Row ' + (rowIndex + 1) + ': Field \'App ID\' - '
                + 'exceeds max length of ' + FEC_Constants.CAMPAIGN_APP_ID_MAX_LENGTH + ' characters'
            );
        }
    }

    private static void validateAccountNumber(
        Map<String, Object> row, Integer rowIndex, ValidationResult result
    ) {
        String accNum = FEC_Util.toString(row.get('Account or Contract number'));
        if (String.isBlank(accNum)) {
            result.errors.add(
                'Row ' + (rowIndex + 1) + ': Field \'Account or Contract number\' - must not be blank'
            );
            return;
        }
        if (accNum.length() > FEC_Constants.CAMPAIGN_ACCOUNT_NUMBER_MAX_LENGTH) {
            result.errors.add(
                'Row ' + (rowIndex + 1) + ': Field \'Account or Contract number\' - '
                + 'exceeds max length of ' + FEC_Constants.CAMPAIGN_ACCOUNT_NUMBER_MAX_LENGTH + ' characters'
            );
        }
    }

    private static void validateNumberFields(
        Map<String, Object> row, Integer rowIndex, ValidationResult result
    ) {
        validateSingleNumber(row, 'Number 1', rowIndex, result);
        validateSingleNumber(row, 'Number 2', rowIndex, result);
        validateSingleNumber(row, 'Number 3', rowIndex, result);
    }

    private static void validateSingleNumber(
        Map<String, Object> row, String fieldName,
        Integer rowIndex, ValidationResult result
    ) {
        Object val = row.get(fieldName);
        if (val == null || String.isBlank(String.valueOf(val))) {
            return; // Optional field — blank is valid
        }
        if (!FEC_Util.checkIsNumber(val)) {
            result.errors.add(
                'Row ' + (rowIndex + 1) + ': Field \'' + fieldName + '\' - '
                + 'value \'' + String.valueOf(val) + '\' is not a valid number'
            );
        }
    }

    private static String buildCompositeKey(Map<String, Object> row) {
        return FEC_Util.toString(row.get('ProductLine')) + '_'
            + FEC_Util.toString(row.get('App ID')) + '_'
            + FEC_Util.toString(row.get('Account or Contract number'));
    }
}
