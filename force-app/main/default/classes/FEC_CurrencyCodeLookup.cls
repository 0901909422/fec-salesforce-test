/**
 * Maps numeric currency unit codes (e.g. TRNXCurrencyCode "971") to display "971-AFN"
 * using master rows on FEC_Currency_Code__c (match field FEC_Currency_Code__c; append Name).
 */
public with sharing class FEC_CurrencyCodeLookup {

    /**
     * @param rawCodes values as returned by host (trimmed for match)
     * @return map rawCode -> "rawCode-Name" for rows found in FEC_Currency_Code__c
     */
    public static Map<String, String> buildNumericCodeToDisplayMap(Set<String> rawCodes) {
        Map<String, String> result = new Map<String, String>();
        if (rawCodes == null || rawCodes.isEmpty()) {
            return result;
        }
        Set<String> normalized = new Set<String>();
        for (String c : rawCodes) {
            if (!String.isBlank(c)) {
                normalized.add(c.trim());
            }
        }
        if (normalized.isEmpty()) {
            return result;
        }
        for (FEC_Currency_Code__c row : [
            SELECT Name, FEC_Currency_Code__c
            FROM FEC_Currency_Code__c
            WHERE FEC_Currency_Code__c IN :normalized
        ]) {
            if (String.isBlank(row.FEC_Currency_Code__c)) {
                continue;
            }
            String key = row.FEC_Currency_Code__c.trim();
            result.put(key, key + '-' + row.Name);
        }
        return result;
    }
}
