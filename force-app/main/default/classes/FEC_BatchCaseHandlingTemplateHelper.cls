public without sharing class FEC_BatchCaseHandlingTemplateHelper {

    private static final String TEMPLATE_OBJECT_API_NAME = 'FEC_Template_Import__c';

    public static final List<String> ALLOWED_BUSINESS_PROCESS_NAMES = new List<String>{
        'COF (Complaint or Feedback)',
        'GSR (General Service Request)',
        'Address Update',
        'Phone Update',
        'Document Request',
        'MRC Return',
        'Refund Request (Loan)',
        'Incorrect Payment Handling (Loan)',
        'IPP Closure',
        'Card Unblock',
        'Contract Closure',
        'Card Closure & Refund Request (Card)',
        'Card Replacement',
        'IPP Conversion',
        'Points Redemption'
    };

    public static List<SObject> queryActiveBatchCaseHandlingTemplates() {
        Schema.SObjectType templateType = Schema.getGlobalDescribe().get(TEMPLATE_OBJECT_API_NAME);
        if (templateType == null) {
            return new List<SObject>();
        }
        Map<String, Schema.SObjectField> templateFields = templateType.getDescribe().fields.getMap();
        List<String> selectParts = new List<String>{ 'Id', 'Name' };
        List<String> whereParts = new List<String>{ 'Name != null' };
        if (templateFields.containsKey('FEC_Applicable_for__c')) {
            selectParts.add('FEC_Applicable_for__c');
            whereParts.add('FEC_Applicable_for__c = \'Batch Case Handling\'');
        }
        if (templateFields.containsKey('FEC_Active__c')) {
            selectParts.add('FEC_Active__c');
            whereParts.add('FEC_Active__c = TRUE');
        }
        String soql =
            'SELECT ' + String.join(selectParts, ', ') +
            ' FROM ' + TEMPLATE_OBJECT_API_NAME +
            ' WHERE ' + String.join(whereParts, ' AND ') +
            ' ORDER BY Name ASC';
        return Database.query(soql);
    }

    public static SObject resolveTemplateByBusinessProcessAndUserGroup(
        String businessProcessCode,
        String userGroup,
        List<SObject> activeTemplates
    ) {
        if (activeTemplates == null || activeTemplates.isEmpty()) {
            return null;
        }
        String namePrefix = mapBusinessProcessToTemplatePrefix(businessProcessCode);
        if (String.isBlank(namePrefix)) {
            return null;
        }
        List<String> suffixCandidates = mapUserGroupToTemplateSuffixes(businessProcessCode, userGroup);
        String prefixLower = namePrefix.toLowerCase();
        SObject prefixFallback;
        for (SObject tr : activeTemplates) {
            String name = tr.get('Name') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(tr.get('Name'));
            if (String.isBlank(name)) {
                continue;
            }
            String nameLower = name.toLowerCase();
            if (!nameLower.startsWith(prefixLower + 'temp')) {
                continue;
            }
            for (String suffix : suffixCandidates) {
                if (String.isNotBlank(suffix) && nameLower.endsWith('_' + suffix.toLowerCase())) {
                    return tr;
                }
            }
            if (prefixFallback == null) {
                prefixFallback = tr;
            }
        }
        return prefixFallback;
    }

    private static String mapBusinessProcessToTemplatePrefix(String businessProcessCode) {
        if (String.isBlank(businessProcessCode)) {
            return null;
        }
        String key = businessProcessCode.trim().toUpperCase();
        Map<String, String> bpToPrefix = new Map<String, String>{
            'COF' => 'COF',
            'COF (COMPLAINT OR FEEDBACK)' => 'COF',
            'GSR' => 'GSR',
            'GSR (GENERAL SERVICE REQUEST)' => 'GSR',
            'ADDRESS UPDATE' => 'AddressUpdate',
            'PHONE UPDATE' => 'PhoneUpdate',
            'DOCUMENT REQUEST' => 'DocumentRequest',
            'MRC RETURN' => 'MRCReturn',
            'REFUND REQUEST (LOAN)' => 'RefundLoan',
            'INCORRECT PAYMENT HANDLING (LOAN)' => 'IncorrectPayment',
            'IPP CLOSURE' => 'IPPClosure',
            'IPP CONVERSION' => 'IPPConversion',
            'CARD UNBLOCK' => 'CardUnblock',
            'CONTRACT CLOSURE' => 'ContractClosure',
            'CARD CLOSURE & REFUND REQUEST (CARD)' => 'CardClosure',
            'CARD REPLACEMENT' => 'CardReplacement',
            'POINTS REDEMPTION' => 'PointsRedemption'
        };
        return bpToPrefix.get(key);
    }

    private static List<String> mapUserGroupToTemplateSuffixes(String businessProcessCode, String userGroup) {
        String bp = String.isBlank(businessProcessCode) ? FEC_ConstantCommon.STR_EMPTY : businessProcessCode.trim().toUpperCase();
        String ug = String.isBlank(userGroup) ? FEC_ConstantCommon.STR_EMPTY : userGroup.trim().toUpperCase();
        List<String> out = new List<String>();
        if (bp == 'COF' || bp == 'COF (COMPLAINT OR FEEDBACK)') {
            if (ug == 'CC') { out.add('CSCustomerCare'); }
            else if (ug == 'CO') { out.add('CO'); }
            else if (ug == 'CL') { out.add('CL'); }
            else if (ug == 'CP') { out.add('CP'); }
            else if (ug == 'PM') { out.add('PM'); }
            else if (ug == 'CA') { out.add('CA'); }
            else if (ug == 'DS' || ug == 'TS') { out.add('Sales'); }
            else { out.add('OtherCS'); }
            return out;
        }
        if (bp == 'GSR' || bp == 'GSR (GENERAL SERVICE REQUEST)') {
            if (ug == 'SP') { out.add('CSSupport'); }
            else if (ug == 'CO') { out.add('CO'); }
            else if (ug == 'CL') { out.add('CL'); }
            else if (ug == 'CP') { out.add('CP'); }
            else if (ug == 'PM') { out.add('PM'); }
            else if (ug == 'CA') { out.add('CA'); }
            else if (ug == 'DS' || ug == 'TS') { out.add('Sales'); }
            else { out.add('OtherCS'); }
            return out;
        }
        if (String.isNotBlank(ug)) {
            String generic;
            if (ug == 'SP') { generic = 'CSSupport'; }
            else if (ug == 'OM') { generic = 'CSD2C'; }
            else if (ug == 'CC') { generic = 'CSCustomerCare'; }
            else if (ug == 'DS' || ug == 'TS') { generic = 'Sales'; }
            else if (ug == 'CO' || ug == 'CL' || ug == 'CP' || ug == 'PM' || ug == 'CA') { generic = ug; }
            if (String.isNotBlank(generic)) {
                out.add(generic);
            }
        }
        return out;
    }
}