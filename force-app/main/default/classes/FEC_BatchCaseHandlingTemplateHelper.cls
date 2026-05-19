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

    public static Boolean isAllowedBusinessProcessName(String businessProcessName) {
        if (String.isBlank(businessProcessName)) {
            return false;
        }
        String trimmed = businessProcessName.trim();
        for (String allowed : ALLOWED_BUSINESS_PROCESS_NAMES) {
            if (allowed.equalsIgnoreCase(trimmed)) {
                return true;
            }
        }
        return false;
    }

    public static String buildAllowedBusinessProcessNameInClause() {
        List<String> literals = new List<String>();
        for (String n : ALLOWED_BUSINESS_PROCESS_NAMES) {
            literals.add('\'' + String.escapeSingleQuotes(n) + '\'');
        }
        return 'FEC_Business_Process__r.Name IN (' + String.join(literals, ',') + ')';
    }

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
        if (templateFields.containsKey('FEC_Business_Process__c')) {
            selectParts.add('FEC_Business_Process__c');
            selectParts.add('FEC_Business_Process__r.Name');
            selectParts.add('FEC_Business_Process__r.FEC_Code__c');
        }
        if (templateFields.containsKey('FEC_User_Group__c')) {
            selectParts.add('FEC_User_Group__c');
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
        SObject bothFieldsMatch = resolveTemplateByFields(businessProcessCode, userGroup, activeTemplates, true);
        if (bothFieldsMatch != null) {
            return bothFieldsMatch;
        }
        SObject nameExactMatch = resolveTemplateByName(businessProcessCode, userGroup, activeTemplates);
        if (nameExactMatch != null) {
            return nameExactMatch;
        }
        return resolveTemplateByFields(businessProcessCode, userGroup, activeTemplates, false);
    }

    private static SObject resolveTemplateByFields(
        String businessProcessCode,
        String userGroup,
        List<SObject> activeTemplates,
        Boolean requireBothFields
    ) {
        SObject bestMatch;
        Integer bestScore = -1;
        for (SObject tr : activeTemplates) {
            Boolean hasBpField = tr.get('FEC_Business_Process__c') != null;
            if (!hasBpField) {
                continue;
            }
            String templateUg = tr.get('FEC_User_Group__c') == null
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(tr.get('FEC_User_Group__c')).trim();
            Boolean hasUgField = String.isNotBlank(templateUg);
            if (requireBothFields && !hasUgField) {
                continue;
            }
            if (!requireBothFields && hasUgField) {
                continue;
            }
            if (!businessProcessFieldMatches(tr, businessProcessCode)) {
                continue;
            }
            if (hasUgField && !userGroupFieldMatches(tr, businessProcessCode, userGroup)) {
                continue;
            }
            Integer score = hasUgField ? 3 : 1;
            if (bestMatch == null || score > bestScore) {
                bestMatch = tr;
                bestScore = score;
            }
        }
        return bestMatch;
    }

    private static Boolean businessProcessFieldMatches(SObject templateRow, String businessProcessInput) {
        if (templateRow.get('FEC_Business_Process__c') == null) {
            return true;
        }
        if (String.isBlank(businessProcessInput)) {
            return false;
        }
        String inputNorm = businessProcessInput.trim().toUpperCase();
        SObject bpRel = templateRow.getSObject('FEC_Business_Process__r');
        if (bpRel != null) {
            String bpName = bpRel.get('Name') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(bpRel.get('Name')).trim();
            if (String.isNotBlank(bpName) && bpName.trim().toUpperCase() == inputNorm) {
                return true;
            }
            String bpCode = bpRel.get('FEC_Code__c') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(bpRel.get('FEC_Code__c')).trim();
            if (String.isNotBlank(bpCode) && bpCode.trim().toUpperCase() == inputNorm) {
                return true;
            }
        }
        String namePrefix = mapBusinessProcessToTemplatePrefix(businessProcessInput);
        if (String.isNotBlank(namePrefix) && bpRel != null) {
            String bpName = bpRel.get('Name') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(bpRel.get('Name')).trim();
            String bpPrefix = mapBusinessProcessToTemplatePrefix(bpName);
            if (String.isNotBlank(bpPrefix) && bpPrefix.equalsIgnoreCase(namePrefix)) {
                return true;
            }
        }
        return false;
    }

    private static Boolean userGroupFieldMatches(SObject templateRow, String businessProcessCode, String userGroupInput) {
        String templateUg = templateRow.get('FEC_User_Group__c') == null
            ? FEC_ConstantCommon.STR_EMPTY
            : String.valueOf(templateRow.get('FEC_User_Group__c')).trim();
        if (String.isBlank(templateUg)) {
            return true;
        }
        if (String.isBlank(userGroupInput)) {
            return false;
        }
        String inputNorm = userGroupInput.trim().toUpperCase();
        String templateNorm = templateUg.toUpperCase();
        if (templateNorm == inputNorm) {
            return true;
        }
        for (String suffix : mapUserGroupToTemplateSuffixes(businessProcessCode, userGroupInput)) {
            if (String.isNotBlank(suffix) && templateNorm == suffix.toUpperCase()) {
                return true;
            }
        }
        for (String suffix : mapUserGroupToTemplateSuffixes(businessProcessCode, templateUg)) {
            if (String.isNotBlank(suffix) && suffix.toUpperCase() == inputNorm) {
                return true;
            }
        }
        return false;
    }

    private static SObject resolveTemplateByName(
        String businessProcessCode,
        String userGroup,
        List<SObject> activeTemplates
    ) {
        String namePrefix = mapBusinessProcessToTemplatePrefix(businessProcessCode);
        if (String.isBlank(namePrefix)) {
            return null;
        }
        List<String> suffixCandidates = mapUserGroupToTemplateSuffixes(businessProcessCode, userGroup);
        if (suffixCandidates.isEmpty()) {
            return null;
        }
        String prefixLower = namePrefix.toLowerCase();
        for (SObject tr : activeTemplates) {
            if (tr.get('FEC_Business_Process__c') != null && !businessProcessFieldMatches(tr, businessProcessCode)) {
                continue;
            }
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
        }
        return null;
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