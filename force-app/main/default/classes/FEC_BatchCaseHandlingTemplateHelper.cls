public without sharing class FEC_BatchCaseHandlingTemplateHelper {

    private static final String TEMPLATE_OBJECT_API_NAME = 'FEC_Template_Import__c';

    public static final List<String> ALLOWED_BUSINESS_PROCESS_NAMES = new List<String>{
        'COF - General Flow',
        'GSR - General Flow',
        'Address Update',
        'Phone Update',
        'Document Request',
        'Original MRC Return',
        'Refund Request (Loan)',
        'Incorrect Payment Handling',
        'IPP Closure',
        'Card Unblock',
        'Contract Closure',
        'Card Closure & Refund Request (Card)',
        'Card Replacement',
        'IPP Conversion',
        'Point Redemption',
        'PIN Replacement'
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

    private static Set<String> cachedAllowedBusinessProcessCodes;
    private static Set<String> cachedAllowedBusinessProcessNames;

    public static Set<String> queryAllowedBusinessProcessCodes() {
        if (cachedAllowedBusinessProcessCodes != null) {
            return cachedAllowedBusinessProcessCodes;
        }
        Set<String> codes = new Set<String>();
        for (SObject tr : queryActiveBatchCaseHandlingTemplates()) {
            SObject bp = tr.getSObject('FEC_Business_Process__r');
            if (bp == null || bp.get('FEC_Code__c') == null) {
                continue;
            }
            String code = String.valueOf(bp.get('FEC_Code__c')).trim();
            if (String.isNotBlank(code)) {
                codes.add(code);
            }
        }
        if (codes.isEmpty()) {
            for (FEC_Business_Process__c bp : [
                SELECT FEC_Code__c
                FROM FEC_Business_Process__c
                WHERE Name IN :ALLOWED_BUSINESS_PROCESS_NAMES
                AND FEC_Code__c != null
            ]) {
                codes.add(bp.FEC_Code__c.trim());
            }
        }
        cachedAllowedBusinessProcessCodes = codes;
        return codes;
    }

    public static Set<String> queryAllowedBusinessProcessNames() {
        if (cachedAllowedBusinessProcessNames != null) {
            return cachedAllowedBusinessProcessNames;
        }
        Set<String> names = new Set<String>();
        for (SObject tr : queryActiveBatchCaseHandlingTemplates()) {
            SObject bp = tr.getSObject('FEC_Business_Process__r');
            if (bp == null || bp.get('Name') == null) {
                continue;
            }
            String name = String.valueOf(bp.get('Name')).trim();
            if (String.isNotBlank(name)) {
                names.add(name);
            }
        }
        if (names.isEmpty()) {
            names.addAll(ALLOWED_BUSINESS_PROCESS_NAMES);
        }
        cachedAllowedBusinessProcessNames = names;
        return names;
    }

    public static String buildAllowedBusinessProcessNameInClause() {
        return buildAllowedStageBusinessProcessWhereClause();
    }

    public static String buildAllowedStageBusinessProcessWhereClause() {
        Set<String> codes = queryAllowedBusinessProcessCodes();
        if (!codes.isEmpty()) {
            List<String> codeLiterals = new List<String>();
            for (String c : codes) {
                codeLiterals.add('\'' + String.escapeSingleQuotes(c) + '\'');
            }
            return 'FEC_Current_Case_Stage__r.FEC_Business_Process__r.FEC_Code__c IN (' + String.join(codeLiterals, ',') + ')';
        }
        List<String> literals = new List<String>();
        for (String n : ALLOWED_BUSINESS_PROCESS_NAMES) {
            literals.add('\'' + String.escapeSingleQuotes(n) + '\'');
        }
        return 'FEC_Current_Case_Stage__r.FEC_Business_Process__r.FEC_Code__c != null AND FEC_Current_Case_Stage__r.FEC_Business_Process__r.Name IN (' + String.join(literals, ',') + ')';
    }

    public static List<String> buildCaseStageBusinessProcessSelectFields() {
        return new List<String>{
            'FEC_Current_Case_Stage__r.FEC_Business_Process__c',
            'FEC_Current_Case_Stage__r.FEC_Business_Process__r.FEC_Code__c',
            'FEC_Current_Case_Stage__r.FEC_Business_Process__r.Name'
        };
    }

    public static void applyStageBusinessProcessToExportRow(FEC_BatchCaseHandlingExportRow row, Case caseRecord) {
        if (row == null || caseRecord == null) {
            return;
        }
        SObject stage = caseRecord.getSObject('FEC_Current_Case_Stage__r');
        if (stage == null) {
            row.businessProcessCode = null;
            row.businessProcessName = null;
            return;
        }
        SObject bp = stage.getSObject('FEC_Business_Process__r');
        if (bp == null) {
            row.businessProcessCode = null;
            row.businessProcessName = null;
            return;
        }
        row.businessProcessCode = bp.get('FEC_Code__c') == null ? null : String.valueOf(bp.get('FEC_Code__c')).trim();
        row.businessProcessName = bp.get('Name') == null ? null : String.valueOf(bp.get('Name')).trim();
    }

    public static Boolean isAllowedBusinessProcessForExport(String businessProcessCode, String businessProcessName) {
        Set<String> allowedCodes = queryAllowedBusinessProcessCodes();
        if (String.isNotBlank(businessProcessCode)) {
            String codeNorm = businessProcessCode.trim();
            for (String allowedCode : allowedCodes) {
                if (allowedCode != null && allowedCode.equalsIgnoreCase(codeNorm)) {
                    return true;
                }
            }
        }
        if (String.isNotBlank(businessProcessName)) {
            String nameNorm = businessProcessName.trim();
            for (String allowedName : queryAllowedBusinessProcessNames()) {
                if (allowedName != null && allowedName.equalsIgnoreCase(nameNorm)) {
                    return true;
                }
            }
            if (isAllowedBusinessProcessName(nameNorm)) {
                return true;
            }
        }
        String bpKey = String.isNotBlank(businessProcessCode) ? businessProcessCode : businessProcessName;
        return mapBusinessProcessToTemplatePrefix(bpKey) != null;
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
        return resolveTemplateByBusinessProcessAndUserGroup(businessProcessCode, null, userGroup, activeTemplates);
    }

    public static SObject resolveTemplateByBusinessProcessAndUserGroup(
        String businessProcessCode,
        String businessProcessName,
        String userGroup,
        List<SObject> activeTemplates
    ) {
        if (activeTemplates == null || activeTemplates.isEmpty()) {
            return null;
        }
        SObject bothFieldsMatch = resolveTemplateByFields(businessProcessCode, businessProcessName, userGroup, activeTemplates, true);
        if (bothFieldsMatch != null) {
            return bothFieldsMatch;
        }
        SObject nameExactMatch = resolveTemplateByName(businessProcessCode, businessProcessName, userGroup, activeTemplates);
        if (nameExactMatch != null) {
            return nameExactMatch;
        }
        return resolveTemplateByFields(businessProcessCode, businessProcessName, userGroup, activeTemplates, false);
    }

    private static SObject resolveTemplateByFields(
        String businessProcessCode,
        String businessProcessName,
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
            if (!businessProcessFieldMatches(tr, businessProcessCode, businessProcessName)) {
                continue;
            }
            if (hasUgField && !userGroupFieldMatches(tr, businessProcessCode, businessProcessName, userGroup)) {
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

    private static Boolean businessProcessFieldMatches(SObject templateRow, String businessProcessCode, String businessProcessName) {
        // 27/05/2026 13:15 linhdev - template không gán BP không được match mọi case (tránh lấy nhầm Address/Phone)
        if (templateRow.get('FEC_Business_Process__c') == null) {
            return false;
        }
        if (String.isBlank(businessProcessCode) && String.isBlank(businessProcessName)) {
            return false;
        }
        SObject bpRel = templateRow.getSObject('FEC_Business_Process__r');
        if (bpRel != null) {
            String templateBpCode = bpRel.get('FEC_Code__c') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(bpRel.get('FEC_Code__c')).trim();
            String templateBpName = bpRel.get('Name') == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(bpRel.get('Name')).trim();
            if (String.isNotBlank(businessProcessCode) && String.isNotBlank(templateBpCode)
                && businessProcessCode.trim().equalsIgnoreCase(templateBpCode)) {
                return true;
            }
            if (String.isNotBlank(businessProcessName) && String.isNotBlank(templateBpName)
                && businessProcessName.trim().equalsIgnoreCase(templateBpName)) {
                return true;
            }
            String casePrefix = mapBusinessProcessToTemplatePrefix(
                String.isNotBlank(businessProcessCode) ? businessProcessCode : businessProcessName
            );
            String templatePrefix = mapBusinessProcessToTemplatePrefix(
                String.isNotBlank(templateBpCode) ? templateBpCode : templateBpName
            );
            if (String.isNotBlank(casePrefix) && String.isNotBlank(templatePrefix)
                && casePrefix.equalsIgnoreCase(templatePrefix)) {
                return true;
            }
        }
        return false;
    }

    private static Boolean userGroupFieldMatches(
        SObject templateRow,
        String businessProcessCode,
        String businessProcessName,
        String userGroupInput
    ) {
        String templateUg = templateRow.get('FEC_User_Group__c') == null
            ? FEC_ConstantCommon.STR_EMPTY
            : String.valueOf(templateRow.get('FEC_User_Group__c')).trim();
        if (String.isBlank(templateUg)) {
            return false;
        }
        if (String.isBlank(userGroupInput)) {
            return false;
        }
        if (userGroupContainedInTemplateField(templateUg, userGroupInput)) {
            return true;
        }
        String bpKey = String.isNotBlank(businessProcessCode) ? businessProcessCode : businessProcessName;
        for (String suffix : mapUserGroupToTemplateSuffixes(bpKey, userGroupInput)) {
            if (String.isNotBlank(suffix) && templateUg.toUpperCase() == suffix.toUpperCase()) {
                return true;
            }
        }
        for (String suffix : mapUserGroupToTemplateSuffixes(bpKey, templateUg)) {
            if (String.isNotBlank(suffix) && suffix.equalsIgnoreCase(userGroupInput.trim())) {
                return true;
            }
        }
        return false;
    }

    private static Boolean userGroupContainedInTemplateField(String templateUg, String userGroupInput) {
        if (String.isBlank(templateUg) || String.isBlank(userGroupInput)) {
            return false;
        }
        String inputNorm = userGroupInput.trim().toUpperCase();
        if (templateUg.trim().toUpperCase() == inputNorm) {
            return true;
        }
        for (String token : templateUg.split(',')) {
            if (String.isNotBlank(token) && token.trim().toUpperCase() == inputNorm) {
                return true;
            }
        }
        return false;
    }

    private static SObject resolveTemplateByName(
        String businessProcessCode,
        String businessProcessName,
        String userGroup,
        List<SObject> activeTemplates
    ) {
        String bpKey = String.isNotBlank(businessProcessCode) ? businessProcessCode : businessProcessName;
        String namePrefix = mapBusinessProcessToTemplatePrefix(bpKey);
        if (String.isBlank(namePrefix)) {
            return null;
        }
        List<String> suffixCandidates = mapUserGroupToTemplateSuffixes(bpKey, userGroup);
        if (suffixCandidates.isEmpty()) {
            return null;
        }
        String prefixLower = namePrefix.toLowerCase();
        for (SObject tr : activeTemplates) {
            if (tr.get('FEC_Business_Process__c') != null && !businessProcessFieldMatches(tr, businessProcessCode, businessProcessName)) {
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

    public static String mapBusinessProcessToTemplatePrefix(String businessProcessCode) {
        if (String.isBlank(businessProcessCode)) {
            return null;
        }
        String key = businessProcessCode.trim().toUpperCase();
        Map<String, String> bpToPrefix = new Map<String, String>{
            'COF' => 'COF',
            'COF (COMPLAINT OR FEEDBACK)' => 'COF',
            'COF - GENERAL FLOW' => 'COF',
            'GSR' => 'GSR',
            'GSR (GENERAL SERVICE REQUEST)' => 'GSR',
            'GSR - GENERAL FLOW' => 'GSR',
            'ADDRESS UPDATE' => 'AddressUpdate',
            'PHONE UPDATE' => 'PhoneUpdate',
            'DOCUMENT REQUEST' => 'DocumentRequest',
            'MRC RETURN' => 'MRCReturn',
            'ORIGINAL MRC RETURN' => 'MRCReturn',
            'REFUND REQUEST (LOAN)' => 'RefundLoan',
            'INCORRECT PAYMENT HANDLING (LOAN)' => 'IncorrectPayment',
            'INCORRECT PAYMENT HANDLING' => 'IncorrectPayment',
            'IPP CLOSURE' => 'IPPClosure',
            'IPP CONVERSION' => 'IPPConversion',
            'CARD UNBLOCK' => 'CardUnblock',
            'CARD BLOCK' => 'CardUnblock',
            'CONTRACT CLOSURE' => 'ContractClosure',
            'CARD CLOSURE & REFUND REQUEST (CARD)' => 'CardClosure',
            'CARD REPLACEMENT' => 'CardReplacement',
            'POINTS REDEMPTION' => 'PointsRedemption',
            'POINT REDEMPTION' => 'PointsRedemption',
            'PIN REPLACEMENT' => 'PinReplacement'
        };
        String mapped = bpToPrefix.get(key);
        if (String.isNotBlank(mapped)) {
            return mapped;
        }
        if (key.startsWith('COF')) {
            return 'COF';
        }
        if (key.startsWith('GSR')) {
            return 'GSR';
        }
        return null;
    }

    public static List<String> mapUserGroupToTemplateSuffixes(String businessProcessCode, String userGroup) {
        String bp = String.isBlank(businessProcessCode) ? FEC_ConstantCommon.STR_EMPTY : businessProcessCode.trim().toUpperCase();
        String ug = String.isBlank(userGroup) ? FEC_ConstantCommon.STR_EMPTY : userGroup.trim().toUpperCase();
        List<String> out = new List<String>();
        if (bp.startsWith('COF')) {
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
        if (bp.startsWith('GSR')) {
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

    public class TemplateExportBinding {
        public String templateName;
        public Id templateContentVersionId;
        public String templateDownloadUrl;
    }

    public static TemplateExportBinding resolveExportTemplateBinding(
        String businessProcessCode,
        String businessProcessName,
        String userGroup,
        List<SObject> activeTemplates,
        Map<Id, Id> versionIdByTemplateId,
        Map<Id, String> urlByTemplateId
    ) {
        TemplateExportBinding out = new TemplateExportBinding();
        out.templateName = FEC_ConstantCommon.STR_EMPTY;
        out.templateDownloadUrl = FEC_ConstantCommon.STR_EMPTY;
        out.templateContentVersionId = null;
        if (activeTemplates == null || activeTemplates.isEmpty()) {
            return out;
        }
        SObject matched = resolveTemplateByBusinessProcessAndUserGroup(
            businessProcessCode,
            businessProcessName,
            userGroup,
            activeTemplates
        );
        if (matched != null && hasTemplateFile(matched, versionIdByTemplateId)) {
            return fillTemplateExportBinding(out, matched, versionIdByTemplateId, urlByTemplateId);
        }
        // 27/05/2026 13:15 linhdev - fallback chỉ khi match BP chặt (prefix/code), không lấy template đầu tiên trong list
        SObject withFile = findBestTemplateWithFileForBusinessProcess(
            businessProcessCode,
            businessProcessName,
            activeTemplates,
            versionIdByTemplateId
        );
        if (withFile != null) {
            return fillTemplateExportBinding(out, withFile, versionIdByTemplateId, urlByTemplateId);
        }
        if (matched != null) {
            out.templateName = matched.get('Name') == null
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(matched.get('Name'));
        }
        return out;
    }

    private static Boolean hasTemplateFile(SObject templateRow, Map<Id, Id> versionIdByTemplateId) {
        if (templateRow == null || versionIdByTemplateId == null || versionIdByTemplateId.isEmpty()) {
            return false;
        }
        return versionIdByTemplateId.containsKey((Id) templateRow.get('Id'));
    }

    private static final Integer TEMPLATE_BP_MATCH_MIN_SCORE = 70;

    private static SObject findBestTemplateWithFileForBusinessProcess(
        String businessProcessCode,
        String businessProcessName,
        List<SObject> activeTemplates,
        Map<Id, Id> versionIdByTemplateId
    ) {
        if (activeTemplates == null || activeTemplates.isEmpty() || versionIdByTemplateId == null || versionIdByTemplateId.isEmpty()) {
            return null;
        }
        SObject bestMatch;
        Integer bestScore = -1;
        for (SObject tr : activeTemplates) {
            if (!businessProcessFieldMatches(tr, businessProcessCode, businessProcessName)) {
                continue;
            }
            if (!versionIdByTemplateId.containsKey((Id) tr.get('Id'))) {
                continue;
            }
            Integer score = scoreTemplateBusinessProcessMatch(tr, businessProcessCode, businessProcessName);
            if (score > bestScore) {
                bestScore = score;
                bestMatch = tr;
            }
        }
        return bestScore >= TEMPLATE_BP_MATCH_MIN_SCORE ? bestMatch : null;
    }

    private static Integer scoreTemplateBusinessProcessMatch(
        SObject templateRow,
        String businessProcessCode,
        String businessProcessName
    ) {
        if (templateRow == null) {
            return 0;
        }
        SObject bpRel = templateRow.getSObject('FEC_Business_Process__r');
        if (bpRel != null) {
            String templateBpCode = bpRel.get('FEC_Code__c') == null
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(bpRel.get('FEC_Code__c')).trim();
            String templateBpName = bpRel.get('Name') == null
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(bpRel.get('Name')).trim();
            if (String.isNotBlank(businessProcessCode) && String.isNotBlank(templateBpCode)
                && businessProcessCode.trim().equalsIgnoreCase(templateBpCode)) {
                return 100;
            }
            if (String.isNotBlank(businessProcessName) && String.isNotBlank(templateBpName)
                && businessProcessName.trim().equalsIgnoreCase(templateBpName)) {
                return 90;
            }
            String casePrefix = mapBusinessProcessToTemplatePrefix(
                String.isNotBlank(businessProcessCode) ? businessProcessCode : businessProcessName
            );
            String templatePrefix = mapBusinessProcessToTemplatePrefix(
                String.isNotBlank(templateBpCode) ? templateBpCode : templateBpName
            );
            if (String.isNotBlank(casePrefix) && String.isNotBlank(templatePrefix)
                && casePrefix.equalsIgnoreCase(templatePrefix)) {
                return 80;
            }
        }
        String bpKey = String.isNotBlank(businessProcessCode) ? businessProcessCode : businessProcessName;
        String namePrefix = mapBusinessProcessToTemplatePrefix(bpKey);
        if (String.isBlank(namePrefix)) {
            return 0;
        }
        String templateName = templateRow.get('Name') == null
            ? FEC_ConstantCommon.STR_EMPTY
            : String.valueOf(templateRow.get('Name'));
        if (String.isNotBlank(templateName)
            && templateName.toLowerCase().startsWith(namePrefix.toLowerCase() + 'temp')) {
            return 70;
        }
        return 0;
    }

    private static TemplateExportBinding fillTemplateExportBinding(
        TemplateExportBinding out,
        SObject templateRow,
        Map<Id, Id> versionIdByTemplateId,
        Map<Id, String> urlByTemplateId
    ) {
        Id templateId = (Id) templateRow.get('Id');
        out.templateName = templateRow.get('Name') == null
            ? FEC_ConstantCommon.STR_EMPTY
            : String.valueOf(templateRow.get('Name'));
        out.templateContentVersionId = versionIdByTemplateId == null ? null : versionIdByTemplateId.get(templateId);
        out.templateDownloadUrl = urlByTemplateId == null ? FEC_ConstantCommon.STR_EMPTY : urlByTemplateId.get(templateId);
        if (out.templateDownloadUrl == null) {
            out.templateDownloadUrl = FEC_ConstantCommon.STR_EMPTY;
        }
        return out;
    }

    public static void populateTemplateContentVersionMaps(
        Set<Id> templateIds,
        Map<Id, Id> versionIdByTemplateId,
        Map<Id, String> urlByTemplateId
    ) {
        if (templateIds == null || templateIds.isEmpty()) {
            return;
        }
        Map<Id, Id> versionMap = versionIdByTemplateId == null ? new Map<Id, Id>() : versionIdByTemplateId;
        Map<Id, String> urlMap = urlByTemplateId == null ? new Map<Id, String>() : urlByTemplateId;
        Set<Id> unresolved = new Set<Id>();
        for (Id templateId : templateIds) {
            if (!versionMap.containsKey(templateId)) {
                unresolved.add(templateId);
            }
        }
        if (unresolved.isEmpty()) {
            return;
        }
        for (ContentVersion cv : [
            SELECT Id, FirstPublishLocationId, FileExtension, PathOnClient, Title
            FROM ContentVersion
            WHERE FirstPublishLocationId IN :unresolved
            AND IsLatest = true
            ORDER BY FirstPublishLocationId, CreatedDate DESC
        ]) {
            Id templateId = cv.FirstPublishLocationId;
            if (templateId == null || versionMap.containsKey(templateId)) {
                continue;
            }
            if (!isTemplateXlsxContentVersion(cv)) {
                continue;
            }
            versionMap.put(templateId, cv.Id);
            urlMap.put(templateId, FEC_ConstantCommon.CONTENT_VERSION_DOWNLOAD_URL_PREFIX + String.valueOf(cv.Id));
            unresolved.remove(templateId);
        }
        if (unresolved.isEmpty()) {
            return;
        }
        for (ContentDocumentLink link : [
            SELECT LinkedEntityId, ContentDocument.LatestPublishedVersionId, ContentDocument.FileExtension, ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :unresolved
            ORDER BY LinkedEntityId, SystemModstamp DESC
        ]) {
            Id templateId = link.LinkedEntityId;
            if (templateId == null || versionMap.containsKey(templateId)) {
                continue;
            }
            if (link.ContentDocument == null) {
                continue;
            }
            if (!isTemplateXlsxContentDocument(link.ContentDocument)) {
                continue;
            }
            Id versionId = link.ContentDocument.LatestPublishedVersionId;
            if (versionId == null) {
                continue;
            }
            versionMap.put(templateId, versionId);
            urlMap.put(templateId, FEC_ConstantCommon.CONTENT_VERSION_DOWNLOAD_URL_PREFIX + String.valueOf(versionId));
            unresolved.remove(templateId);
        }
    }

    private static Boolean isTemplateXlsxContentVersion(ContentVersion cv) {
        if (cv == null) {
            return false;
        }
        String fileExt = cv.FileExtension == null
            ? FEC_ConstantCommon.STR_EMPTY
            : String.valueOf(cv.FileExtension).trim().toLowerCase();
        if (fileExt == 'xlsx') {
            return true;
        }
        if (String.isNotBlank(fileExt) && fileExt != 'xlsx') {
            return false;
        }
        return hasXlsxPathExtension(cv.PathOnClient == null ? cv.Title : cv.PathOnClient);
    }

    private static Boolean isTemplateXlsxContentDocument(ContentDocument doc) {
        if (doc == null) {
            return false;
        }
        String fileExt = doc.FileExtension == null
            ? FEC_ConstantCommon.STR_EMPTY
            : String.valueOf(doc.FileExtension).trim().toLowerCase();
        if (fileExt == 'xlsx') {
            return true;
        }
        if (String.isNotBlank(fileExt) && fileExt != 'xlsx') {
            return false;
        }
        return hasXlsxPathExtension(doc.Title);
    }

    private static Boolean hasXlsxPathExtension(String pathOrTitle) {
        if (String.isBlank(pathOrTitle)) {
            return false;
        }
        return pathOrTitle.trim().toLowerCase().endsWith('.xlsx');
    }

    // 27/05/2026 18:45 linhdev - lỗi khi user import template không thuộc role/user group
    public static final String ERR_ROLE_TEMPLATE_MISMATCH = 'role/template không phù hợp';

    public static String resolveTemplateNameFromUploadedFileName(
        String fileName,
        String userGroup,
        List<SObject> activeTemplates
    ) {
        if (String.isBlank(fileName) || activeTemplates == null || activeTemplates.isEmpty()) {
            return null;
        }
        String bestName;
        Integer bestScore = -1;
        for (SObject tr : activeTemplates) {
            String name = tr.get('Name') == null
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(tr.get('Name')).trim();
            if (String.isBlank(name) || validateUploadedTemplateFileName(fileName, name) != null) {
                continue;
            }
            // 27/05/2026 18:45 linhdev - chỉ resolve template khớp user group (tránh nhận nhầm CSSupport khi user khác CS SP)
            if (!templateRowMatchesUserGroup(tr, userGroup)) {
                continue;
            }
            Integer score = scoreTemplateFileNameMatch(fileName, name);
            if (bestName == null || score > bestScore) {
                bestName = name;
                bestScore = score;
            }
        }
        return bestName;
    }

    private static Integer scoreTemplateFileNameMatch(String fileName, String templateName) {
        String fileCore = fileName.trim().toLowerCase().replace('.xlsx', FEC_ConstantCommon.STR_EMPTY);
        String expectedCore = templateName.trim().toLowerCase().replace('.xlsx', FEC_ConstantCommon.STR_EMPTY);
        if (fileCore == expectedCore) {
            return 100 + expectedCore.length();
        }
        if (fileCore.contains(expectedCore)) {
            return expectedCore.length();
        }
        return 0;
    }

    private static Boolean templateRowMatchesUserGroup(SObject templateRow, String userGroup) {
        if (String.isBlank(userGroup)) {
            return true;
        }
        SObject bpRel = templateRow.getSObject('FEC_Business_Process__r');
        String bpCode = bpRel == null || bpRel.get('FEC_Code__c') == null
            ? FEC_ConstantCommon.STR_EMPTY
            : String.valueOf(bpRel.get('FEC_Code__c')).trim();
        String bpName = bpRel == null || bpRel.get('Name') == null
            ? FEC_ConstantCommon.STR_EMPTY
            : String.valueOf(bpRel.get('Name')).trim();
        return userGroupFieldMatches(templateRow, bpCode, bpName, userGroup);
    }

    // 27/05/2026 18:45 linhdev - validate suffix template (vd. _CSSupport) khớp role/user group khi import
    public static String validateUploadedTemplateForUserGroup(
        String templateOrFileName,
        String businessProcessCode,
        String userGroup
    ) {
        if (String.isBlank(templateOrFileName)) {
            return null;
        }
        if (String.isBlank(userGroup)) {
            return ERR_ROLE_TEMPLATE_MISMATCH;
        }
        String templateSuffix = extractTemplateTeamSuffix(templateOrFileName);
        if (String.isBlank(templateSuffix)) {
            return null;
        }
        List<String> allowedSuffixes = mapUserGroupToTemplateSuffixes(
            businessProcessCode,
            userGroup
        );
        if (allowedSuffixes == null || allowedSuffixes.isEmpty()) {
            return ERR_ROLE_TEMPLATE_MISMATCH;
        }
        for (String allowed : allowedSuffixes) {
            if (String.isNotBlank(allowed) && allowed.trim().equalsIgnoreCase(templateSuffix)) {
                return null;
            }
        }
        return ERR_ROLE_TEMPLATE_MISMATCH;
    }

    public static String extractTemplateTeamSuffix(String templateOrFileName) {
        if (String.isBlank(templateOrFileName)) {
            return null;
        }
        String core = templateOrFileName.trim().toLowerCase().replace('.xlsx', FEC_ConstantCommon.STR_EMPTY);
        Integer underscoreIdx = core.lastIndexOf('_');
        if (underscoreIdx < 0 || underscoreIdx >= core.length() - 1) {
            return null;
        }
        return core.substring(underscoreIdx + 1);
    }

    public static String validateUploadedTemplateFileName(String fileName, String expectedTemplateName) {
        if (String.isBlank(expectedTemplateName)) {
            return null;
        }
        if (String.isBlank(fileName)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String expectedCore = expectedTemplateName.trim().toLowerCase().replace('.xlsx', FEC_ConstantCommon.STR_EMPTY);
        String fileCore = fileName.trim().toLowerCase().replace('.xlsx', FEC_ConstantCommon.STR_EMPTY);
        if (fileCore == expectedCore || fileCore.contains(expectedCore)) {
            return null;
        }
        return 'TEMPLATE_MISMATCH';
    }
}