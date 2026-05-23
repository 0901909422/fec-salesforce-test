public with sharing class FEC_BatchCaseCreationService {
    private class ParsedCaseRow {
        String fileType;
        String layout;
        String contractNumber;
        String interactionPhone;
        String productType;
        String category;
        String subCategory;
        String subCode;
        String caseStatus;
        String caseRemarks;
        String interactionChannel;
        String interactionSubChannel;
        String interactionEmail;
    }

    private class LookupMaps {
        Map<String, String> productMap;
        Map<String, String> categoryMap;
        Map<String, String> subCategoryMap;
        Map<String, String> subCodeMap;
    }

    public static List<FEC_BatchCaseCreationController.CaseRowResult> processImportRows(
        List<Object> inputRows,
        String templateName
    ) {
        List<ParsedCaseRow> parsed = parseInputRows(inputRows);
        Boolean isWelcomeFlow = isWelcomeCallInput(parsed);
        List<FEC_BatchCaseCreationController.CaseRowResult> rowResults = validateAndBuildCases(
            parsed,
            isWelcomeFlow
        );
        if (isWelcomeFlow) {
            insertWelcomeCallCases(parsed, rowResults);
        } else {
            insertStandardCasesWithInteraction(parsed, rowResults);
        }
        return rowResults;
    }
private static List<ParsedCaseRow> parseInputRows(List<Object> inputRows) {
        List<ParsedCaseRow> out = new List<ParsedCaseRow>();
        for (Object rowObj : inputRows) {
            Map<String, Object> m = (Map<String, Object>) rowObj;
            ParsedCaseRow r = new ParsedCaseRow();
            r.fileType = FEC_BatchImportCommon.normalizeText(m.get('fileType'));
            r.layout = FEC_BatchImportCommon.normalizeText(m.get('layout'));
            r.contractNumber = FEC_BatchImportCommon.normalizeText(m.get('contractNumber'));
            r.interactionPhone = FEC_BatchImportCommon.normalizeText(m.get('interactionPhone'));
            r.productType = FEC_BatchImportCommon.normalizeText(m.get('productType'));
            r.category = FEC_BatchImportCommon.normalizeText(m.get('category'));
            r.subCategory = FEC_BatchImportCommon.normalizeText(m.get('subCategory'));
            r.subCode = FEC_BatchImportCommon.normalizeText(m.get('subCode'));
            r.caseStatus = FEC_BatchImportCommon.normalizeText(m.get('caseStatus'));
            r.caseRemarks = FEC_BatchImportCommon.normalizeText(m.get('caseRemarks'));
            r.interactionChannel = FEC_BatchImportCommon.normalizeText(m.get('interactionChannel'));
            r.interactionSubChannel = FEC_BatchImportCommon.normalizeText(m.get('interactionSubChannel'));
            r.interactionEmail = FEC_BatchImportCommon.normalizeText(m.get('interactionEmail'));
            out.add(r);
        }
        return out;
    }

    private static List<FEC_BatchCaseCreationController.CaseRowResult> validateAndBuildCases(
        List<ParsedCaseRow> parsed,
        Boolean welcome
    ) {
        LookupMaps maps = loadLookupMaps(parsed);

        Schema.DescribeFieldResult channelDfr = Case.FEC_Channel__c.getDescribe();
        Schema.DescribeFieldResult subChannelDfr = Case.FEC_Interaction_Subchannel__c.getDescribe();
        Schema.DescribeFieldResult statusDfr = Case.Status.getDescribe();

        List<FEC_BatchCaseCreationController.CaseRowResult> rowResults = new List<FEC_BatchCaseCreationController.CaseRowResult>();

        for (ParsedCaseRow r : parsed) {
            FEC_BatchCaseCreationController.CaseRowResult rr = toRowResultShell(r);
            List<String> errs = new List<String>();

            Boolean extended = 'extended'.equalsIgnoreCase(r.layout);
            if (!extended && !'simple'.equalsIgnoreCase(r.layout)) {
                errs.add(System.Label.FEC_Batch_Import_Invalid_Layout);
            }

            if (String.isBlank(r.contractNumber)) {
                errs.add(
                    welcome
                        ? System.Label.FEC_Batch_Import_Required_Contract_Number
                        : System.Label.FEC_Batch_Import_Required_Account_Contract_Number
                );
            } else {
                appendContractNumberFormatRules(r.contractNumber, welcome, errs);
            }
            if (String.isBlank(r.interactionPhone)) {
                errs.add(System.Label.FEC_Batch_Import_Required_Interaction_Phone);
            }
            if (String.isBlank(r.productType)) {
                errs.add(System.Label.FEC_Batch_Import_Required_Product_Type);
            }
            if (String.isBlank(r.category)) {
                errs.add(System.Label.FEC_Batch_Import_Required_Category);
            }
            if (String.isBlank(r.subCategory)) {
                errs.add(System.Label.FEC_Batch_Import_Required_Sub_Category);
            }
            if (!welcome && String.isBlank(r.caseStatus)) {
                errs.add(System.Label.FEC_Batch_Import_Required_Case_Status);
            }
            if (welcome) {
                appendWelcomeCaseStatusRules(r, statusDfr, errs);
            }

            if (extended) {
                if (String.isBlank(r.interactionChannel)) {
                    errs.add(System.Label.FEC_Batch_Import_Required_Interaction_Channel);
                }
                if (String.isBlank(r.interactionSubChannel)) {
                    errs.add(System.Label.FEC_Batch_Import_Required_Interaction_Sub_Channel);
                }
            }

            Id productId = lookupFromMap(r.productType, maps.productMap);
            Id categoryId = lookupFromMap(r.category, maps.categoryMap);
            Id subCategoryId = lookupFromMap(r.subCategory, maps.subCategoryMap);
            Id subCodeId = lookupFromMap(r.subCode, maps.subCodeMap);

            if (String.isNotBlank(r.productType) && productId == null) {
                errs.add(System.Label.FEC_Batch_Import_Lookup_Product_Type_Not_Found);
            }
            if (String.isNotBlank(r.category) && categoryId == null) {
                errs.add(System.Label.FEC_Batch_Import_Lookup_Category_Not_Found);
            }
            if (String.isNotBlank(r.subCategory) && subCategoryId == null) {
                errs.add(System.Label.FEC_Batch_Import_Lookup_Sub_Category_Not_Found);
            }
            if (String.isNotBlank(r.subCode) && subCodeId == null) {
                errs.add(System.Label.FEC_Batch_Import_Lookup_Sub_Code_Not_Found);
            }

            if (!welcome) {
                String statusApi = matchCaseStatus(statusDfr, r.caseStatus);
                if (String.isBlank(statusApi)) {
                    errs.add(System.Label.FEC_Batch_Import_Invalid_Case_Status);
                }
            }

            if (extended) {
                String channelApi = matchPicklist(channelDfr, r.interactionChannel);
                String subChannelApi = matchPicklist(subChannelDfr, r.interactionSubChannel);
                if (String.isNotBlank(r.interactionChannel) && channelApi == null) {
                    errs.add(System.Label.FEC_Batch_Import_Invalid_Interaction_Channel);
                }
                if (String.isNotBlank(r.interactionSubChannel) && subChannelApi == null) {
                    errs.add(System.Label.FEC_Batch_Import_Invalid_Interaction_Sub_Channel);
                }
            }

            if (String.isNotBlank(r.interactionEmail) && !Pattern.matches(FEC_ConstantCommon.PATTERN_EMAIL, r.interactionEmail)) {
                errs.add(System.Label.FEC_Batch_Import_Invalid_Interaction_Email);
            }

            rr.status = errs.isEmpty() ? 'Succeeded' : 'Failed';
            rr.errors = errs.isEmpty() ? '' : String.join(errs, ' ');
            rowResults.add(rr);
        }

        return rowResults;
    }

    private static List<Case> buildCasesFromResults(List<ParsedCaseRow> parsed) {
        Id rtId = FEC_BatchImportCommon.getCustomerCaseRecordTypeId();
        if (rtId == null) {
            throw new AuraHandledException(System.Label.FEC_Batch_Import_RT_Customer_Case_Not_Found);
        }

        LookupMaps maps = loadLookupMaps(parsed);
        Schema.DescribeFieldResult channelDfr = Case.FEC_Channel__c.getDescribe();
        Schema.DescribeFieldResult subChannelDfr = Case.FEC_Interaction_Subchannel__c.getDescribe();
        Schema.DescribeFieldResult statusDfr = Case.Status.getDescribe();

        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < parsed.size(); i++) {
            ParsedCaseRow r = parsed[i];
            String statusApi = matchCaseStatus(statusDfr, r.caseStatus);

            Case c = new Case();
            c.RecordTypeId = rtId;
            c.Subject = buildSubject(r.contractNumber);
            c.Status = statusApi;
            applyNatureFields(c, r, maps, channelDfr, subChannelDfr);

            cases.add(c);
        }
        return cases;
    }

    private static LookupMaps loadLookupMaps(List<ParsedCaseRow> parsed) {
        Set<String> prodKeys = new Set<String>();
        Set<String> catKeys = new Set<String>();
        Set<String> subCatKeys = new Set<String>();
        Set<String> subCodeKeys = new Set<String>();
        for (ParsedCaseRow r : parsed) {
            addLookupKeys(prodKeys, r.productType);
            addLookupKeys(catKeys, r.category);
            addLookupKeys(subCatKeys, r.subCategory);
            addLookupKeys(subCodeKeys, r.subCode);
        }
        LookupMaps lm = new LookupMaps();
        lm.productMap = loadProductTypeMap(prodKeys);
        lm.categoryMap = loadCategoryMap(catKeys);
        lm.subCategoryMap = loadSubCategoryMap(subCatKeys);
        lm.subCodeMap = loadSubCodeMap(subCodeKeys);
        return lm;
    }

    private static void applyNatureFields(
        Case c,
        ParsedCaseRow r,
        LookupMaps maps,
        Schema.DescribeFieldResult channelDfr,
        Schema.DescribeFieldResult subChannelDfr
    ) {
        Boolean extended = 'extended'.equalsIgnoreCase(r.layout);
        Id productId = lookupFromMap(r.productType, maps.productMap);
        Id categoryId = lookupFromMap(r.category, maps.categoryMap);
        Id subCategoryId = lookupFromMap(r.subCategory, maps.subCategoryMap);
        Id subCodeId = lookupFromMap(r.subCode, maps.subCodeMap);
        c.FEC_Contract_Number__c = r.contractNumber;
        c.FEC_Phone_Number__c = r.interactionPhone;
        c.FEC_Remarks__c = r.caseRemarks;
        c.FEC_Product_Type__c = productId;
        c.FEC_Category__c = categoryId;
        c.FEC_SubCategory__c = subCategoryId;
        c.FEC_SubCode__c = subCodeId;
        if (extended) {
            c.FEC_Channel__c = matchPicklist(channelDfr, r.interactionChannel);
            c.FEC_Interaction_Subchannel__c = matchPicklist(subChannelDfr, r.interactionSubChannel);
            if (String.isNotBlank(r.interactionEmail)) {
                c.FEC_Interaction_Email__c = r.interactionEmail;
            }
        }
    }

    private static Boolean isWelcomeCallInput(List<ParsedCaseRow> parsed) {
        return 'welcome'.equalsIgnoreCase(resolveConsistentImportFileType(parsed));
    }

    private static String resolveConsistentImportFileType(List<ParsedCaseRow> parsed) {
        if (parsed == null || parsed.isEmpty()) {
            return null;
        }
        String resolved = null;
        for (ParsedCaseRow r : parsed) {
            if (r == null || String.isBlank(r.fileType)) {
                continue;
            }
            String ft = r.fileType.trim().toLowerCase();
            if (resolved == null) {
                resolved = ft;
            } else if (!resolved.equals(ft)) {
                return null;
            }
        }
        return resolved;
    }

    private static void appendContractNumberFormatRules(
        String contractNumber,
        Boolean welcome,
        List<String> errs
    ) {
        if (String.isBlank(contractNumber) || errs == null) {
            return;
        }
        Boolean dashed = contractNumber.contains('-');
        if (welcome && !dashed) {
            errs.add(System.Label.FEC_Batch_Import_Welcome_Contract_Number_Requires_Dash);
        } else if (!welcome && dashed) {
            errs.add(System.Label.FEC_Batch_Import_Other_Contract_Number_No_Dash);
        }
    }

    private static void appendWelcomeCaseStatusRules(
        ParsedCaseRow r,
        Schema.DescribeFieldResult statusDfr,
        List<String> errs
    ) {
        if (r == null || errs == null || String.isBlank(r.caseStatus)) {
            return;
        }
        String statusApi = matchCaseStatus(statusDfr, r.caseStatus);
        if (statusApi != FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED) {
            errs.add(System.Label.FEC_Batch_Import_Welcome_Case_Status_Only_Resolved_Completed);
        }
    }

    private static String formatSaveResultErrors(Database.SaveResult sr) {
        List<String> parts = new List<String>();
        for (Database.Error err : sr.getErrors()) {
            parts.add(err.getMessage());
        }
        return String.join(parts, ' ');
    }

    private static String truncateWelcomeSubject(String prefix, String contractNumber) {
        String base = prefix + (String.isNotBlank(contractNumber) ? contractNumber : 'Unknown');
        if (base.length() > 255) {
            return base.substring(0, 255);
        }
        return base;
    }

    private static void applyWelcomeInteractionDefaults(Case interactionCase) {
        // Welcome Call chỉ ép theo custom status field theo yêu cầu nghiệp vụ.
        Map<String, Schema.SObjectField> caseFieldMap = Case.SObjectType.getDescribe().fields.getMap();
        FEC_BatchImportCommon.putIfFieldExists(caseFieldMap, interactionCase, new List<String>{ 'FEC_Interaction_Status__c' }, FEC_ConstantCommon.INTERACTION_STATUS_CLOSED);
    }

    private static void applyWelcomeCustomerDefaults(Case customerCase) {
        // Welcome Call chỉ ép theo custom status field theo yêu cầu nghiệp vụ.
        Map<String, Schema.SObjectField> caseFieldMap = Case.SObjectType.getDescribe().fields.getMap();
        FEC_BatchImportCommon.putIfFieldExists(caseFieldMap, customerCase, new List<String>{ 'FEC_Case_Status__c' }, FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED);
    }

    private static void applyWelcomeChannelDefaults(
        Case caseToFill,
        Schema.DescribeFieldResult channelDfr,
        Schema.DescribeFieldResult subChannelDfr
    ) {
        String channelApi = matchPicklist(channelDfr, FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME);
        String subChannelApi = matchPicklist(subChannelDfr, FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME);
        caseToFill.FEC_Channel__c = String.isNotBlank(channelApi) ? channelApi : FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME;
        caseToFill.FEC_Interaction_Subchannel__c = String.isNotBlank(subChannelApi) ? subChannelApi : FEC_ConstantCommon.CHANNEL_OUTBOUND_SUBCHANNEL_NAME;
    }

    private static void insertWelcomeCallCases(List<ParsedCaseRow> parsed, List<FEC_BatchCaseCreationController.CaseRowResult> rowResults) {
        Id intRt = FEC_CommonUltils.getRecordTypeIdByDev(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);
        Id custRt = FEC_BatchImportCommon.getCustomerCaseRecordTypeId();
        if (intRt == null) {
            throw new AuraHandledException(System.Label.FEC_Batch_Import_RT_Interaction_Not_Found);
        }
        if (custRt == null) {
            throw new AuraHandledException(System.Label.FEC_Batch_Import_RT_Customer_Case_Not_Found);
        }

        LookupMaps maps = loadLookupMaps(parsed);
        Schema.DescribeFieldResult channelDfr = Case.FEC_Channel__c.getDescribe();
        Schema.DescribeFieldResult subChannelDfr = Case.FEC_Interaction_Subchannel__c.getDescribe();

        // Chỉ build & insert những dòng pass validation; dòng Failed bỏ qua, không insert.
        List<Case> interactionCases = new List<Case>();
        List<Integer> interactionOrigRowIndex = new List<Integer>();
        for (Integer i = 0; i < parsed.size(); i++) {
            if (!'Succeeded'.equals(rowResults[i].status)) {
                continue;
            }
            ParsedCaseRow r = parsed[i];
            Case ic = new Case();
            ic.RecordTypeId = intRt;
            applyWelcomeInteractionDefaults(ic);
            ic.Subject = truncateWelcomeSubject('Welcome Call Interaction - ', r.contractNumber);
            applyNatureFields(ic, r, maps, channelDfr, subChannelDfr);
            applyWelcomeChannelDefaults(ic, channelDfr, subChannelDfr);
            interactionCases.add(ic);
            interactionOrigRowIndex.add(i);
        }

        if (interactionCases.isEmpty()) {
            return;
        }

        Database.SaveResult[] srInt = Database.insert(interactionCases, false);

        List<Case> customerCases = new List<Case>();
        List<Integer> customerOrigRowIndex = new List<Integer>();
        for (Integer k = 0; k < srInt.size(); k++) {
            Integer origIdx = interactionOrigRowIndex[k];
            if (!srInt[k].isSuccess()) {
                FEC_BatchCaseCreationController.CaseRowResult rr = rowResults[origIdx];
                rr.status = 'Failed';
                rr.recordId = '';
                rr.errors = formatSaveResultErrors(srInt[k]);
                continue;
            }
            ParsedCaseRow r = parsed[origIdx];
            Case cc = new Case();
            cc.RecordTypeId = custRt;
            cc.FEC_Interaction__c = srInt[k].getId();
            applyWelcomeCustomerDefaults(cc);
            cc.Subject = truncateWelcomeSubject('Welcome Call Case - ', r.contractNumber);
            applyNatureFields(cc, r, maps, channelDfr, subChannelDfr);
            applyWelcomeChannelDefaults(cc, channelDfr, subChannelDfr);
            customerCases.add(cc);
            customerOrigRowIndex.add(origIdx);
        }

        Database.SaveResult[] srCust = customerCases.isEmpty() ? null : Database.insert(customerCases, false);
        if (srCust != null) {
            for (Integer k = 0; k < srCust.size(); k++) {
                Integer origIdx = customerOrigRowIndex[k];
                FEC_BatchCaseCreationController.CaseRowResult rr = rowResults[origIdx];
                if (srCust[k].isSuccess()) {
                    rr.recordId = srCust[k].getId();
                    rr.status = 'Succeeded';
                    rr.errors = '';
                } else {
                    rr.status = 'Failed';
                    rr.recordId = '';
                    rr.errors =
                        String.format(
                            System.Label.FEC_Batch_Import_Welcome_Customer_Case_Failed,
                            new List<String>{ formatSaveResultErrors(srCust[k]) }
                        );
                }
            }
        }
    }

    private static void insertStandardCasesWithInteraction(List<ParsedCaseRow> parsed, List<FEC_BatchCaseCreationController.CaseRowResult> rowResults) {
        Id intRt = FEC_CommonUltils.getRecordTypeIdByDev(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME);
        Id custRt = FEC_BatchImportCommon.getCustomerCaseRecordTypeId();
        if (intRt == null) {
            throw new AuraHandledException(System.Label.FEC_Batch_Import_RT_Interaction_Not_Found);
        }
        if (custRt == null) {
            throw new AuraHandledException(System.Label.FEC_Batch_Import_RT_Customer_Case_Not_Found);
        }

        LookupMaps maps = loadLookupMaps(parsed);
        Schema.DescribeFieldResult channelDfr = Case.FEC_Channel__c.getDescribe();
        Schema.DescribeFieldResult subChannelDfr = Case.FEC_Interaction_Subchannel__c.getDescribe();
        Schema.DescribeFieldResult statusDfr = Case.Status.getDescribe();

        List<Case> interactionCases = new List<Case>();
        List<Integer> interactionOrigRowIndex = new List<Integer>();
        for (Integer i = 0; i < parsed.size(); i++) {
            if (!'Succeeded'.equals(rowResults[i].status)) {
                continue;
            }
            ParsedCaseRow r = parsed[i];
            Case ic = new Case();
            ic.RecordTypeId = intRt;
            ic.Subject = truncateWelcomeSubject('Batch Interaction - ', r.contractNumber);
            applyNatureFields(ic, r, maps, channelDfr, subChannelDfr);
            interactionCases.add(ic);
            interactionOrigRowIndex.add(i);
        }

        if (interactionCases.isEmpty()) {
            return;
        }

        Database.SaveResult[] srInt = Database.insert(interactionCases, false);
        List<Case> customerCases = new List<Case>();
        List<Integer> customerOrigRowIndex = new List<Integer>();

        for (Integer k = 0; k < srInt.size(); k++) {
            Integer origIdx = interactionOrigRowIndex[k];
            if (!srInt[k].isSuccess()) {
                FEC_BatchCaseCreationController.CaseRowResult rr = rowResults[origIdx];
                rr.status = 'Failed';
                rr.recordId = '';
                rr.errors = formatSaveResultErrors(srInt[k]);
                continue;
            }
            ParsedCaseRow r = parsed[origIdx];
            String statusApi = matchCaseStatus(statusDfr, r.caseStatus);
            Case cc = new Case();
            cc.RecordTypeId = custRt;
            cc.FEC_Interaction__c = srInt[k].getId();
            cc.Subject = buildSubject(r.contractNumber);
            cc.Status = statusApi;
            applyNatureFields(cc, r, maps, channelDfr, subChannelDfr);
            customerCases.add(cc);
            customerOrigRowIndex.add(origIdx);
        }

        Database.SaveResult[] srCust = customerCases.isEmpty() ? null : Database.insert(customerCases, false);
        if (srCust != null) {
            for (Integer k = 0; k < srCust.size(); k++) {
                Integer origIdx = customerOrigRowIndex[k];
                FEC_BatchCaseCreationController.CaseRowResult rr = rowResults[origIdx];
                if (srCust[k].isSuccess()) {
                    rr.recordId = srCust[k].getId();
                    rr.status = 'Succeeded';
                    rr.errors = '';
                } else {
                    rr.status = 'Failed';
                    rr.recordId = '';
                    rr.errors = String.format(
                        System.Label.FEC_Batch_Import_Welcome_Customer_Case_Failed,
                        new List<String>{ formatSaveResultErrors(srCust[k]) }
                    );
                }
            }
        }
    }

    private static String buildSubject(String contractNumber) {
        String base = 'Batch Case Creation';
        if (String.isNotBlank(contractNumber)) {
            base += ' - ' + contractNumber;
        }
        if (base.length() > 255) {
            return base.substring(0, 255);
        }
        return base;
    }

    private static FEC_BatchCaseCreationController.CaseRowResult toRowResultShell(ParsedCaseRow r) {
        FEC_BatchCaseCreationController.CaseRowResult rr = new FEC_BatchCaseCreationController.CaseRowResult();
        rr.layout = r.layout;
        rr.contractNumber = r.contractNumber;
        rr.interactionPhone = r.interactionPhone;
        rr.productType = r.productType;
        rr.category = r.category;
        rr.subCategory = r.subCategory;
        rr.subCode = r.subCode;
        rr.caseStatus = r.caseStatus;
        rr.caseRemarks = r.caseRemarks;
        rr.interactionChannel = r.interactionChannel;
        rr.interactionSubChannel = r.interactionSubChannel;
        rr.interactionEmail = r.interactionEmail;
        rr.recordId = '';
        rr.finalStatus = '';
        rr.interactionId = '';
        rr.caseBusinessId = '';
        return rr;
    }

    private static void addLookupKeys(Set<String> keys, String raw) {
        if (String.isBlank(raw)) {
            return;
        }
        keys.add(raw.trim().toLowerCase());
        keys.add(extractCodeKey(raw).toLowerCase());
    }

    private static Id lookupFromMap(String raw, Map<String, String> m) {
        if (String.isBlank(raw) || m == null || m.isEmpty()) {
            return null;
        }
        String t = raw.trim();
        String s1 = m.get(t.toLowerCase());
        if (String.isNotBlank(s1)) {
            return (Id) s1;
        }
        String k = extractCodeKey(t);
        String s2 = m.get(k.toLowerCase());
        return String.isNotBlank(s2) ? (Id) s2 : null;
    }

    private static String extractCodeKey(String raw) {
        if (String.isBlank(raw)) {
            return '';
        }
        String t = raw.trim();
        Integer dash = t.indexOf('-');
        if (dash > 0) {
            return t.substring(0, dash).trim();
        }
        return t;
    }

    private static Map<String, String> loadProductTypeMap(Set<String> keys) {
        Map<String, String> idByKey = new Map<String, String>();
        if (keys == null || keys.isEmpty()) {
            return idByKey;
        }
        Set<String> candidates = new Set<String>();
        for (String k : keys) {
            if (String.isNotBlank(k)) {
                candidates.add(k);
            }
        }
        for (FEC_Product_Type__c rec : [
            SELECT Id, Name, FEC_Code__c
            FROM FEC_Product_Type__c
            WHERE FEC_Active__c = true AND (Name IN :candidates OR FEC_Code__c IN :candidates)
        ]) {
            String rid = String.valueOf(rec.Id);
            if (rec.Name != null) {
                idByKey.put(rec.Name.toLowerCase(), rid);
            }
            if (rec.FEC_Code__c != null) {
                idByKey.put(rec.FEC_Code__c.toLowerCase(), rid);
            }
        }
        return idByKey;
    }

    private static Map<String, String> loadCategoryMap(Set<String> keys) {
        Map<String, String> idByKey = new Map<String, String>();
        if (keys == null || keys.isEmpty()) {
            return idByKey;
        }
        Set<String> candidates = new Set<String>();
        for (String k : keys) {
            if (String.isNotBlank(k)) {
                candidates.add(k);
            }
        }
        for (FEC_Category__c rec : [
            SELECT Id, Name, FEC_Code__c
            FROM FEC_Category__c
            WHERE FEC_Active__c = true AND (Name IN :candidates OR FEC_Code__c IN :candidates)
        ]) {
            String rid = String.valueOf(rec.Id);
            if (rec.Name != null) {
                idByKey.put(rec.Name.toLowerCase(), rid);
            }
            if (rec.FEC_Code__c != null) {
                idByKey.put(rec.FEC_Code__c.toLowerCase(), rid);
            }
        }
        return idByKey;
    }

    private static Map<String, String> loadSubCategoryMap(Set<String> keys) {
        Map<String, String> idByKey = new Map<String, String>();
        if (keys == null || keys.isEmpty()) {
            return idByKey;
        }
        Set<String> candidates = new Set<String>();
        for (String k : keys) {
            if (String.isNotBlank(k)) {
                candidates.add(k);
            }
        }
        for (FEC_Sub_Category__c rec : [
            SELECT Id, Name, FEC_Code__c
            FROM FEC_Sub_Category__c
            WHERE FEC_Active__c = true AND (Name IN :candidates OR FEC_Code__c IN :candidates)
        ]) {
            String rid = String.valueOf(rec.Id);
            if (rec.Name != null) {
                idByKey.put(rec.Name.toLowerCase(), rid);
            }
            if (rec.FEC_Code__c != null) {
                idByKey.put(rec.FEC_Code__c.toLowerCase(), rid);
            }
        }
        return idByKey;
    }

    private static Map<String, String> loadSubCodeMap(Set<String> keys) {
        Map<String, String> idByKey = new Map<String, String>();
        if (keys == null || keys.isEmpty()) {
            return idByKey;
        }
        Set<String> candidates = new Set<String>();
        for (String k : keys) {
            if (String.isNotBlank(k)) {
                candidates.add(k);
            }
        }
        for (FEC_Sub_Code__c rec : [
            SELECT Id, Name, FEC_Code__c
            FROM FEC_Sub_Code__c
            WHERE FEC_Active__c = true AND (Name IN :candidates OR FEC_Code__c IN :candidates)
        ]) {
            String rid = String.valueOf(rec.Id);
            if (rec.Name != null) {
                idByKey.put(rec.Name.toLowerCase(), rid);
            }
            if (rec.FEC_Code__c != null) {
                idByKey.put(rec.FEC_Code__c.toLowerCase(), rid);
            }
        }
        return idByKey;
    }

    private static String matchPicklist(Schema.DescribeFieldResult dfr, String raw) {
        if (String.isBlank(raw) || dfr == null) {
            return null;
        }
        String t = raw.trim();
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (!pe.isActive()) {
                continue;
            }
            if (t.equalsIgnoreCase(pe.getValue()) || t.equalsIgnoreCase(pe.getLabel())) {
                return pe.getValue();
            }
        }
        return null;
    }

    private static String matchCaseStatus(Schema.DescribeFieldResult statusDfr, String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String t = raw.trim();
        String direct = matchPicklist(statusDfr, t);
        if (String.isNotBlank(direct)) {
            return direct;
        }
        for (String allowed : FEC_ConstantCommon.CUSTOMER_CASE_IMPORT_STATUS_VALUES) {
            if (t.equalsIgnoreCase(allowed)) {
                return allowed;
            }
        }
        return null;
    }

}

