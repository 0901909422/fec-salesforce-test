/**
 * Selector: FEC_Sales_Logic__c — master bảng điều kiện Sales Channel.
 */
public with sharing class FEC_SalesLogicSelector {

    private static final List<String> BASE_FIELDS = new List<String>{
        'Id',
        'Name',
        'FEC_Sequence__c',
        'FEC_CC_Code__c',
        'FEC_DSA_Code__c',
        'FEC_TSA_Code__c',
        'FEC_Sales_Channel__c',
        'FEC_Sales_Sub_Channel__c'
    };

    public static List<FEC_Sales_Logic__c> selectAllOrdered() {
        if (!Schema.sObjectType.FEC_Sales_Logic__c.isAccessible()) {
            return new List<FEC_Sales_Logic__c>();
        }
        String soql = 'SELECT ' + String.join(BASE_FIELDS, ',') +
            ' FROM FEC_Sales_Logic__c' +
            ' ORDER BY FEC_Sequence__c ASC NULLS LAST, Name ASC';
        return Database.query(soql);
    }
}