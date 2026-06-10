public without sharing class FEC_TeamGroupCodeUtil {

    private static final Map<String, String> LONG_NAME_TO_CODE = new Map<String, String>{
        'ContractProcessing' => 'CP',
        'CSCustomerCare' => 'CC',
        'CSCustomerCareDept' => 'CC',
        'CSInbound' => 'IB',
        'CSSupport' => 'SP',
        'CSD2C' => 'OM',
        'Sales' => 'DS',
        'CreditAssessment' => 'CA',
        'CardOperations' => 'CO',
        'Collections' => 'CL',
        'DirectSales' => 'DS',
        'Telesales' => 'TS',
        'Payment' => 'PM'
    };

    public static String normalizeForReport(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String trimmed = raw.trim();
        if (LONG_NAME_TO_CODE.containsKey(trimmed)) {
            return LONG_NAME_TO_CODE.get(trimmed);
        }
        return trimmed;
    }
}
