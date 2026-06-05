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

    private class NatureOfCaseResolveMaps {
        Map<String, Id> nocIdByCompositeKey = new Map<String, Id>();
        Map<String, Id> nocIdByFullTextKey = new Map<String, Id>();
        Map<String, Id> nocIdByTripleTextKey = new Map<String, Id>();
        Map<Id, Id> defaultCaseStageIdByNocId = new Map<Id, Id>();
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
        if (hasAnySucceededRowResult(rowResults)) {
            runImportedInteractionBatchAfterCaseImport();
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
        Map<String, Set<String>> subChannelsByChannel = buildSubChannelsByChannelMap(channelDfr, subChannelDfr);

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
            if (welcome) {
                if (String.isBlank(r.interactionPhone)) {
                    errs.add(System.Label.FEC_Batch_Import_Required_Interaction_Phone);
                } else if (!Pattern.matches(FEC_ConstantCommon.PATTERN_PHONE_NUMBER, r.interactionPhone)) {
                    errs.add(System.Label.FEC_Batch_Import_Invalid_Interaction_Phone_Format);
                }
            } else if (
                String.isNotBlank(r.interactionPhone) &&
                !Pattern.matches(FEC_ConstantCommon.PATTERN_PHONE_NUMBER, r.interactionPhone)
            ) {
                errs.add(System.Label.FEC_Batch_Import_Invalid_Interaction_Phone_Format);
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
            if (String.isBlank(r.caseRemarks)) {
                errs.add(System.Label.FEC_Batch_Import_Required_Case_Remarks);
            }
            if (String.isBlank(r.caseStatus)) {
                errs.add(System.Label.FEC_Batch_Import_Required_Case_Status);
            } else if (welcome) {
                appendWelcomeCaseStatusRules(r, statusDfr, errs);
            }

            if (extended && welcome) {
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
                String otherImportStatusApi = matchBatchImportCaseStatus(statusDfr, r.caseStatus);
                if (String.isBlank(otherImportStatusApi)) {
                    errs.add(System.Label.FEC_Batch_Import_Invalid_Case_Status);
                } else if (String.isBlank(resolveOtherInteractionStatusApi(statusDfr, r.caseStatus))) {
                    errs.add(System.Label.FEC_Batch_Import_Invalid_Case_Status);
                }
                appendOtherInteractionChannelValidation(
                    r,
                    extended,
                    channelDfr,
                    subChannelDfr,
                    subChannelsByChannel,
                    errs
                );
            } else if (extended) {
                String channelApi = matchPicklist(channelDfr, r.interactionChannel);
                String subChannelApi = matchPicklist(subChannelDfr, r.interactionSubChannel);
                if (String.isNotBlank(r.interactionChannel) && channelApi == null) {
                    errs.add(System.Label.FEC_Batch_Import_Invalid_Interaction_Channel);
                }
                if (String.isNotBlank(r.interactionSubChannel) && subChannelApi == null) {
                    errs.add(System.Label.FEC_Batch_Import_Invalid_Interaction_Sub_Channel);
                }
                if (
                    String.isNotBlank(channelApi) &&
                    String.isNotBlank(subChannelApi) &&
                    !isSubChannelValidForChannel(channelApi, subChannelApi, subChannelsByChannel)
                ) {
                    errs.add(System.Label.FEC_Batch_Import_Invalid_Sub_Channel_For_Channel);
                }
            }

            if (String.isNotBlank(r.interactionEmail) && !Pattern.matches(FEC_ConstantCommon.PATTERN_EMAIL, r.interactionEmail)) {
                errs.add(System.Label.FEC_Batch_Import_Invalid_Interaction_Email);
            }

            rr.status = errs.isEmpty() ? 'Succeeded' : 'Failed';
            rr.errors = errs.isEmpty() ? '' : FEC_BatchImportCommon.joinRowErrors(errs);
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
        applyNatureFields(c, r, maps, channelDfr, subChannelDfr, true);
    }

    private static void applyNatureFields(
        Case c,
        ParsedCaseRow r,
        LookupMaps maps,
        Schema.DescribeFieldResult channelDfr,
        Schema.DescribeFieldResult subChannelDfr,
        Boolean includeRemarks
    ) {
        Boolean extended = 'extended'.equalsIgnoreCase(r.layout);
        Id productId = lookupFromMap(r.productType, maps.productMap);
        Id categoryId = lookupFromMap(r.category, maps.categoryMap);
        Id subCategoryId = lookupFromMap(r.subCategory, maps.subCategoryMap);
        Id subCodeId = lookupFromMap(r.subCode, maps.subCodeMap);
        c.FEC_Contract_Number__c = r.contractNumber;
        c.FEC_Phone_Number__c = r.interactionPhone;
        if (includeRemarks == true) {
            c.FEC_Remarks__c = r.caseRemarks;
        }
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
        if (String.isBlank(contractNumber) || errs == null || !welcome) {
            return;
        }
        if (!contractNumber.contains('-')) {
            errs.add(System.Label.FEC_Batch_Import_Welcome_Contract_Number_Requires_Dash);
        }
    }

    private static void appendWelcomeCaseStatusRules(
        ParsedCaseRow r,
        Schema.DescribeFieldResult statusDfr,
        List<String> errs
    ) {
        if (r == null || errs == null) {
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

    private static Boolean contractNumberContainsLetter(String contractNumber) {
        if (String.isBlank(contractNumber)) {
            return false;
        }
        return Pattern.compile('[A-Za-z]').matcher(contractNumber).find();
    }

    private static Boolean isOtherCasesContractNumber(String contractNumber) {
        if (String.isBlank(contractNumber)) {
            return false;
        }
        return contractNumberContainsLetter(contractNumber) || contractNumber.contains('-');
    }

    private static void applyOtherAccountOrContractNumber(Case c, String contractNumber) {
        if (c == null || String.isBlank(contractNumber)) {
            return;
        }
        if (isOtherCasesContractNumber(contractNumber)) {
            c.FEC_Contract_Number__c = contractNumber;
            c.FEC_Account_Number__c = null;
        } else {
            c.FEC_Account_Number__c = contractNumber;
            c.FEC_Contract_Number__c = null;
        }
    }

    private static void applyOtherInteractionFields(
        Case c,
        ParsedCaseRow r,
        LookupMaps maps,
        Schema.DescribeFieldResult channelDfr,
        Schema.DescribeFieldResult subChannelDfr
    ) {
        if (c == null || r == null) {
            return;
        }
        applyOtherAccountOrContractNumber(c, r.contractNumber);
        if (String.isNotBlank(r.interactionPhone)) {
            c.FEC_Phone_Number__c = r.interactionPhone;
        }
        c.FEC_Product_Type__c = lookupFromMap(r.productType, maps.productMap);
        Boolean extended = 'extended'.equalsIgnoreCase(r.layout);
        if (extended) {
            c.FEC_Channel__c = matchPicklist(channelDfr, r.interactionChannel);
            c.FEC_Interaction_Subchannel__c = matchPicklist(subChannelDfr, r.interactionSubChannel);
        } else {
            applyOutboundChannelDefaults(c, channelDfr, subChannelDfr);
        }
        if (String.isNotBlank(r.interactionEmail)) {
            c.FEC_Interaction_Email__c = r.interactionEmail;
        }
    }

    private static void applyOutboundChannelDefaults(
        Case caseToFill,
        Schema.DescribeFieldResult channelDfr,
        Schema.DescribeFieldResult subChannelDfr
    ) {
        applyWelcomeChannelDefaults(caseToFill, channelDfr, subChannelDfr);
    }

    private static String resolveOtherInteractionStatusApi(
        Schema.DescribeFieldResult statusDfr,
        String rawCaseStatus
    ) {
        String importStatusApi = matchBatchImportCaseStatus(statusDfr, rawCaseStatus);
        if (String.isBlank(importStatusApi)) {
            return null;
        }
        if (importStatusApi.equalsIgnoreCase(FEC_ConstantCommon.CASE_STATUS_OPEN)) {
            String openApi = matchPicklist(statusDfr, FEC_ConstantCommon.CASE_STATUS_OPEN);
            return String.isNotBlank(openApi) ? openApi : FEC_ConstantCommon.CASE_STATUS_OPEN;
        }
        if (importStatusApi.equalsIgnoreCase(FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED)) {
            String closedApi = matchPicklist(statusDfr, FEC_ConstantCommon.CASE_STATUS_CLOSED);
            return String.isNotBlank(closedApi) ? closedApi : FEC_ConstantCommon.CASE_STATUS_CLOSED;
        }
        return null;
    }

    private static void applyOtherInteractionCaseDefaults(Case interactionCase, String interactionStatusApi) {
        if (interactionCase == null) {
            return;
        }
        interactionCase.Status = interactionStatusApi;
        interactionCase.FEC_Customer_Type__c = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER;
        interactionCase.FEC_Assigment_Mode__c = FEC_ConstantCommon.INTERACTION_REVIEW_MODE;
        interactionCase.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_REVIEW_MODE;
    }

    private static void applyOtherCustomerCaseDefaults(Case customerCase) {
        if (customerCase == null) {
            return;
        }
        customerCase.FEC_Customer_Type__c = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER;
        customerCase.FEC_Assigment_Mode__c = FEC_ConstantCommon.INTERACTION_REVIEW_MODE;
        customerCase.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_REVIEW_MODE;
    }

    private static void appendOtherInteractionChannelValidation(
        ParsedCaseRow r,
        Boolean extended,
        Schema.DescribeFieldResult channelDfr,
        Schema.DescribeFieldResult subChannelDfr,
        Map<String, Set<String>> subChannelsByChannel,
        List<String> errs
    ) {
        if (r == null || errs == null || !extended) {
            return;
        }
        if (String.isBlank(r.interactionChannel)) {
            errs.add(System.Label.FEC_Batch_Import_Required_Interaction_Channel);
        } else if (matchPicklist(channelDfr, r.interactionChannel) == null) {
            errs.add(System.Label.FEC_Batch_Import_Invalid_Interaction_Channel);
        }
        if (String.isBlank(r.interactionSubChannel)) {
            errs.add(System.Label.FEC_Batch_Import_Required_Interaction_Sub_Channel);
        } else if (matchPicklist(subChannelDfr, r.interactionSubChannel) == null) {
            errs.add(System.Label.FEC_Batch_Import_Invalid_Interaction_Sub_Channel);
        }
        String channelApi = matchPicklist(channelDfr, r.interactionChannel);
        String subChannelApi = matchPicklist(subChannelDfr, r.interactionSubChannel);
        if (
            String.isNotBlank(channelApi) &&
            String.isNotBlank(subChannelApi) &&
            !isSubChannelValidForChannel(channelApi, subChannelApi, subChannelsByChannel)
        ) {
            errs.add(System.Label.FEC_Batch_Import_Invalid_Sub_Channel_For_Channel);
        }
    }

    private static void applyWelcomeInteractionDefaults(Case interactionCase) {
        if (interactionCase == null) {
            return;
        }
        interactionCase.Status = FEC_ConstantCommon.CASE_STATUS_CLOSED;
        interactionCase.FEC_Customer_Type__c = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER;
        interactionCase.FEC_Assigment_Mode__c = FEC_ConstantCommon.INTERACTION_REVIEW_MODE;
        interactionCase.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_REVIEW_MODE;
    }

    private static void applyWelcomeCustomerCaseDefaults(Case customerCase) {
        if (customerCase == null) {
            return;
        }
        customerCase.FEC_Customer_Type__c = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER;
        customerCase.FEC_Assigment_Mode__c = FEC_ConstantCommon.INTERACTION_REVIEW_MODE;
        customerCase.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_REVIEW_MODE;
    }

    private static String insertWelcomeCaseRemark(Id customerCaseId, String remarksText) {
        if (customerCaseId == null || String.isBlank(remarksText)) {
            return null;
        }
        List<Case> caseRows = [
            SELECT Id, FEC_Stage_Name__c
            FROM Case
            WHERE Id = :customerCaseId
            LIMIT 1
        ];
        if (caseRows.isEmpty()) {
            return null;
        }
        String remarkUser;
        String remarkRole;
        List<User> importUsers = [
            SELECT Email, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (!importUsers.isEmpty()) {
            remarkUser = String.isNotBlank(importUsers[0].Email)
                ? importUsers[0].Email.substringBefore('@')
                : null;
            remarkRole = importUsers[0].UserRole?.Name;
        }
        FEC_Case_Remarks__c remark = new FEC_Case_Remarks__c();
        remark.FEC_Case__c = customerCaseId;
        remark.FEC_Case_Remarks__c = remarksText;
        remark.FEC_Stage_Name__c = caseRows[0].FEC_Stage_Name__c;
        remark.FEC_User__c = remarkUser;
        remark.FEC_User_Role__c = remarkRole;
        Database.SaveResult sr = Database.insert(remark, false);
        if (sr.isSuccess()) {
            return null;
        }
        return formatSaveResultErrors(sr);
    }

    private static String resolveWelcomeProductCode(String productTypeText, Id productTypeId) {
        if (productTypeId != null) {
            List<FEC_Product_Type__c> productTypes = [
                SELECT Name
                FROM FEC_Product_Type__c
                WHERE Id = :productTypeId
                LIMIT 1
            ];
            if (!productTypes.isEmpty() && String.isNotBlank(productTypes[0].Name)) {
                return productTypes[0].Name;
            }
        }
        String codeKey = '';
        if (String.isNotBlank(productTypeText)) {
            String t = productTypeText.trim();
            Integer dash = t.indexOf('-');
            codeKey = dash > 0 ? t.substring(0, dash).trim() : t;
        }
        return String.isNotBlank(codeKey) ? codeKey : FEC_ConstantCommon.PRODUCT_TYPE_LOAN_CASE;
    }

    private class WelcomeHistoryLinkResult {
        Id historyId;
        String errorMessage;
    }

    private static WelcomeHistoryLinkResult linkWelcomeCustomerHistory(
        Id interactionCaseId,
        ParsedCaseRow r,
        Id productTypeId
    ) {
        return linkImportedCustomerHistory(interactionCaseId, r, productTypeId, false);
    }

    private static WelcomeHistoryLinkResult linkOtherCustomerHistory(
        Id interactionCaseId,
        ParsedCaseRow r,
        Id productTypeId
    ) {
        return linkImportedCustomerHistory(interactionCaseId, r, productTypeId, true);
    }

    private static void applyHistoryAccountOrContractFromImport(
        FEC_Customer_History__c history,
        String contractNumber,
        String productCodeLower,
        Boolean otherCasesFlow
    ) {
        if (history == null || String.isBlank(contractNumber)) {
            return;
        }
        if (otherCasesFlow) {
            if (isOtherCasesContractNumber(contractNumber)) {
                history.FEC_Contract_Number__c = contractNumber;
            } else {
                history.FEC_Account_Number__c = contractNumber;
            }
            return;
        }
        if (
            productCodeLower == FEC_ConstantCommon.PRODUCT_TYPE_LOAN.toLowerCase() ||
            productCodeLower == FEC_ConstantCommon.PRODUCT_TYPE_INSURANCE.toLowerCase() ||
            productCodeLower == FEC_ConstantCommon.PRODUCT_TYPE_LOAN_CASE.toLowerCase() ||
            productCodeLower == FEC_ConstantCommon.PRODUCT_TYPE_INSURANCE_CASE.toLowerCase()
        ) {
            history.FEC_Contract_Number__c = contractNumber;
        } else if (
            productCodeLower == FEC_ConstantCommon.PRODUCT_TYPE_CARD.toLowerCase() ||
            productCodeLower == FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE.toLowerCase()
        ) {
            history.FEC_Account_Number__c = contractNumber;
        } else {
            history.FEC_Contract_Number__c = contractNumber;
        }
    }

    private static WelcomeHistoryLinkResult linkImportedCustomerHistory(
        Id interactionCaseId,
        ParsedCaseRow r,
        Id productTypeId,
        Boolean otherCasesFlow
    ) {
        WelcomeHistoryLinkResult out = new WelcomeHistoryLinkResult();
        if (interactionCaseId == null || r == null) {
            out.errorMessage = 'Interaction case is required to link customer history.';
            return out;
        }
        try {
            String productCode = resolveWelcomeProductCode(r.productType, productTypeId);
            String productCodeLower = productCode == null ? '' : productCode.toLowerCase();

            FEC_Customer_History__c history = new FEC_Customer_History__c();
            history.Name = r.contractNumber;
            history.FEC_Case__c = interactionCaseId;
            history.FEC_Product_Code__c = productCode;
            history.FEC_Customer_Type__c = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER;
            if (String.isNotBlank(r.interactionPhone)) {
                history.FEC_Primary_Phone__c = r.interactionPhone;
            }
            applyHistoryAccountOrContractFromImport(
                history,
                r.contractNumber,
                productCodeLower,
                otherCasesFlow
            );
            insert history;

            FEC_CaseTriggerHandler.isExecuting = true;
            update new Case(
                Id = interactionCaseId,
                FEC_Account_or_Contract__c = history.Id
            );
            FEC_CaseTriggerHandler.isExecuting = false;

            out.historyId = history.Id;
            return out;
        } catch (Exception ex) {
            out.errorMessage = ex.getMessage();
            return out;
        }
    }

    private static void insertWelcomeAdditionalInfo(Id customerCaseId) {
        if (customerCaseId == null) {
            return;
        }
        try {
            insert new FEC_Additional_Info__c(FEC_Case__c = customerCaseId);
        } catch (Exception ex) {
        }
    }

    private static void applyBatchImportedCaseFlag(Case caseRecord) {
        if (caseRecord == null) {
            return;
        }
        caseRecord.FEC_IsImported__c = true;
    }

    private static Boolean hasAnySucceededRowResult(
        List<FEC_BatchCaseCreationController.CaseRowResult> rowResults
    ) {
        if (rowResults == null || rowResults.isEmpty()) {
            return false;
        }
        for (FEC_BatchCaseCreationController.CaseRowResult rr : rowResults) {
            if (rr != null && 'Succeeded'.equals(rr.status)) {
                return true;
            }
        }
        return false;
    }

    private static void runImportedInteractionBatchAfterCaseImport() {
        try {
            FEC_ImportedInteractionBatch.run();
        } catch (Exception ex) {
            // Không rollback import nếu batch sync không enqueue được.
        }
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
        Schema.DescribeFieldResult statusDfr = Case.Status.getDescribe();

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
            applyBatchImportedCaseFlag(ic);
            ic.Subject = truncateWelcomeSubject('Welcome Call Interaction - ', r.contractNumber);
            applyNatureFields(ic, r, maps, channelDfr, subChannelDfr, false);
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
            Id productTypeId = lookupFromMap(r.productType, maps.productMap);
            WelcomeHistoryLinkResult historyLink = linkWelcomeCustomerHistory(
                srInt[k].getId(),
                r,
                productTypeId
            );
            if (historyLink.historyId == null) {
                FEC_BatchCaseCreationController.CaseRowResult rr = rowResults[origIdx];
                rr.status = 'Failed';
                rr.recordId = '';
                rr.errors = String.isNotBlank(historyLink.errorMessage)
                    ? historyLink.errorMessage
                    : 'Không thể liên kết Customer History.';
                continue;
            }
            String statusApi = matchCaseStatus(statusDfr, r.caseStatus);
            Case cc = new Case();
            cc.RecordTypeId = custRt;
            cc.FEC_Interaction__c = srInt[k].getId();
            cc.FEC_Account_or_Contract__c = historyLink.historyId;
            cc.Status = statusApi;
            applyWelcomeCustomerCaseDefaults(cc);
            cc.Subject = truncateWelcomeSubject('Welcome Call Case - ', r.contractNumber);
            applyNatureFields(cc, r, maps, channelDfr, subChannelDfr, false);
            applyBatchImportedCaseFlag(cc);
            customerCases.add(cc);
            customerOrigRowIndex.add(origIdx);
        }

        Database.SaveResult[] srCust = customerCases.isEmpty() ? null : Database.insert(customerCases, false);
        if (srCust != null) {
            for (Integer k = 0; k < srCust.size(); k++) {
                Integer origIdx = customerOrigRowIndex[k];
                FEC_BatchCaseCreationController.CaseRowResult rr = rowResults[origIdx];
                ParsedCaseRow r = parsed[origIdx];
                if (srCust[k].isSuccess()) {
                    Id customerCaseId = srCust[k].getId();
                    rr.recordId = customerCaseId;
                    rr.status = 'Succeeded';
                    rr.errors = '';
                    insertWelcomeAdditionalInfo(customerCaseId);
                    String remarkError = insertWelcomeCaseRemark(customerCaseId, r.caseRemarks);
                    if (String.isNotBlank(remarkError)) {
                        rr.status = 'Failed';
                        rr.recordId = '';
                        rr.errors = remarkError;
                    }
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
        NatureOfCaseResolveMaps nocResolveMaps = loadNatureOfCaseResolveMaps(parsed, maps);
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
            String interactionStatusApi = resolveOtherInteractionStatusApi(statusDfr, r.caseStatus);
            applyOtherInteractionCaseDefaults(ic, interactionStatusApi);
            applyBatchImportedCaseFlag(ic);
            ic.Subject = truncateWelcomeSubject('Batch Interaction - ', r.contractNumber);
            applyOtherInteractionFields(ic, r, maps, channelDfr, subChannelDfr);
            interactionCases.add(ic);
            interactionOrigRowIndex.add(i);
        }

        if (interactionCases.isEmpty()) {
            return;
        }

        Database.SaveResult[] srInt = FEC_BatchImportCommon.insertImportCases(interactionCases, false);
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
            Id productTypeId = lookupFromMap(r.productType, maps.productMap);
            WelcomeHistoryLinkResult historyLink = linkOtherCustomerHistory(
                srInt[k].getId(),
                r,
                productTypeId
            );
            if (historyLink.historyId == null) {
                FEC_BatchCaseCreationController.CaseRowResult rr = rowResults[origIdx];
                rr.status = 'Failed';
                rr.recordId = '';
                rr.errors = String.isNotBlank(historyLink.errorMessage)
                    ? historyLink.errorMessage
                    : 'Không thể liên kết Customer History.';
                continue;
            }
            String statusApi = matchBatchImportCaseStatus(statusDfr, r.caseStatus);
            Case cc = new Case();
            cc.RecordTypeId = custRt;
            cc.FEC_Interaction__c = srInt[k].getId();
            cc.FEC_Account_or_Contract__c = historyLink.historyId;
            cc.Subject = buildSubject(r.contractNumber);
            cc.Status = statusApi;
            applyOtherCustomerCaseDefaults(cc);
            applyNatureFields(cc, r, maps, channelDfr, subChannelDfr, false);
            applyOtherAccountOrContractNumber(cc, r.contractNumber);
            applyOtherDefaultCaseStageFromNature(cc, r, maps, nocResolveMaps);
            applyBatchImportedCaseFlag(cc);
            customerCases.add(cc);
            customerOrigRowIndex.add(origIdx);
        }

        Database.SaveResult[] srCust = customerCases.isEmpty()
            ? null
            : FEC_BatchImportCommon.insertImportCases(customerCases, false);
        if (srCust != null) {
            for (Integer k = 0; k < srCust.size(); k++) {
                Integer origIdx = customerOrigRowIndex[k];
                FEC_BatchCaseCreationController.CaseRowResult rr = rowResults[origIdx];
                ParsedCaseRow r = parsed[origIdx];
                if (srCust[k].isSuccess()) {
                    Id customerCaseId = srCust[k].getId();
                    applyCustomerCaseSuccessResult(rr, customerCases[k], customerCaseId);
                    String remarkError = insertWelcomeCaseRemark(customerCaseId, r.caseRemarks);
                    if (String.isNotBlank(remarkError)) {
                        rr.status = 'Failed';
                        rr.recordId = '';
                        rr.fecIdSearch = '';
                        rr.errors = remarkError;
                    }
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

    private static String buildNatureOfCaseCompositeKey(
        Id productTypeId,
        Id categoryId,
        Id subCategoryId,
        Id subCodeId
    ) {
        return String.valueOf(productTypeId) +
            '|' +
            String.valueOf(categoryId) +
            '|' +
            String.valueOf(subCategoryId) +
            '|' +
            (subCodeId == null ? '' : String.valueOf(subCodeId));
    }

    private static NatureOfCaseResolveMaps loadNatureOfCaseResolveMaps(
        List<ParsedCaseRow> parsed,
        LookupMaps maps
    ) {
        NatureOfCaseResolveMaps out = new NatureOfCaseResolveMaps();
        if (parsed == null || parsed.isEmpty() || maps == null) {
            return out;
        }

        Set<Id> productIds = new Set<Id>();
        for (ParsedCaseRow row : parsed) {
            Id productId = lookupFromMap(row.productType, maps.productMap);
            if (productId != null) {
                productIds.add(productId);
            }
        }
        if (productIds.isEmpty()) {
            return out;
        }

        Set<Id> nocIds = new Set<Id>();
        for (FEC_Nature_of_Case__c noc : [
            SELECT
                Id,
                FEC_Product_Type__c,
                FEC_Category__c,
                FEC_Sub_Category__c,
                FEC_Sub_Code__c,
                FEC_Category__r.Name,
                FEC_Category__r.FEC_Code__c,
                FEC_Sub_Category__r.Name,
                FEC_Sub_Category__r.FEC_Code__c,
                FEC_Sub_Code__r.Name,
                FEC_Sub_Code__r.FEC_Code__c
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Active__c = true AND FEC_Product_Type__c IN :productIds
        ]) {
            registerNatureOfCaseLookupKeys(out, noc);
            nocIds.add(noc.Id);
        }

        if (!nocIds.isEmpty()) {
            for (FEC_Case_Stage__c stage : [
                SELECT Id, FEC_Nature_of_Cases__c, FEC_Active__c
                FROM FEC_Case_Stage__c
                WHERE FEC_Nature_of_Cases__c IN :nocIds AND FEC_Default_Stage__c = true
            ]) {
                if (stage.FEC_Nature_of_Cases__c == null) {
                    continue;
                }
                Id nocId = stage.FEC_Nature_of_Cases__c;
                if (!out.defaultCaseStageIdByNocId.containsKey(nocId)) {
                    out.defaultCaseStageIdByNocId.put(nocId, stage.Id);
                } else if (stage.FEC_Active__c == true) {
                    out.defaultCaseStageIdByNocId.put(nocId, stage.Id);
                }
            }
        }
        return out;
    }

    private static Set<String> natureTextAliases(String name, String code) {
        Set<String> aliases = new Set<String>();
        if (String.isNotBlank(name)) {
            aliases.add(name.trim().toLowerCase());
        }
        if (String.isNotBlank(code)) {
            aliases.add(code.trim().toLowerCase());
        }
        return aliases;
    }

    private static void registerNatureOfCaseLookupKeys(
        NatureOfCaseResolveMaps out,
        FEC_Nature_of_Case__c noc
    ) {
        if (out == null || noc == null || noc.FEC_Product_Type__c == null || noc.FEC_Category__c == null) {
            return;
        }
        String compositeKey = buildNatureOfCaseCompositeKey(
            noc.FEC_Product_Type__c,
            noc.FEC_Category__c,
            noc.FEC_Sub_Category__c,
            noc.FEC_Sub_Code__c
        );
        out.nocIdByCompositeKey.put(compositeKey, noc.Id);

        String productIdKey = String.valueOf(noc.FEC_Product_Type__c);
        Set<String> categoryAliases = natureTextAliases(
            noc.FEC_Category__r == null ? null : noc.FEC_Category__r.Name,
            noc.FEC_Category__r == null ? null : noc.FEC_Category__r.FEC_Code__c
        );
        Set<String> subCategoryAliases = natureTextAliases(
            noc.FEC_Sub_Category__r == null ? null : noc.FEC_Sub_Category__r.Name,
            noc.FEC_Sub_Category__r == null ? null : noc.FEC_Sub_Category__r.FEC_Code__c
        );
        Set<String> subCodeAliases = natureTextAliases(
            noc.FEC_Sub_Code__r == null ? null : noc.FEC_Sub_Code__r.Name,
            noc.FEC_Sub_Code__r == null ? null : noc.FEC_Sub_Code__r.FEC_Code__c
        );

        for (String categoryAlias : categoryAliases) {
            for (String subCategoryAlias : subCategoryAliases) {
                if (noc.FEC_Sub_Code__c == null || subCodeAliases.isEmpty()) {
                    out.nocIdByTripleTextKey.put(
                        productIdKey + '|' + categoryAlias + '|' + subCategoryAlias,
                        noc.Id
                    );
                } else {
                    for (String subCodeAlias : subCodeAliases) {
                        out.nocIdByFullTextKey.put(
                            productIdKey +
                                '|' +
                                categoryAlias +
                                '|' +
                                subCategoryAlias +
                                '|' +
                                subCodeAlias,
                            noc.Id
                        );
                    }
                }
            }
        }
    }

    private static List<String> importNatureTextCandidates(String raw) {
        List<String> candidates = new List<String>();
        if (String.isBlank(raw)) {
            return candidates;
        }
        String trimmed = raw.trim().toLowerCase();
        candidates.add(trimmed);
        String codeKey = extractCodeKey(raw);
        if (String.isNotBlank(codeKey)) {
            String codeLower = codeKey.toLowerCase();
            if (!candidates.contains(codeLower)) {
                candidates.add(codeLower);
            }
        }
        return candidates;
    }

    private static Id resolveNatureOfCaseIdForImportRow(
        ParsedCaseRow r,
        LookupMaps maps,
        NatureOfCaseResolveMaps nocResolveMaps
    ) {
        if (r == null || maps == null || nocResolveMaps == null) {
            return null;
        }
        Id productId = lookupFromMap(r.productType, maps.productMap);
        if (productId == null || String.isBlank(r.category) || String.isBlank(r.subCategory)) {
            return null;
        }
        String productIdKey = String.valueOf(productId);

        Id categoryId = lookupFromMap(r.category, maps.categoryMap);
        Id subCategoryId = lookupFromMap(r.subCategory, maps.subCategoryMap);
        Id subCodeId = lookupFromMap(r.subCode, maps.subCodeMap);
        if (categoryId != null && subCategoryId != null) {
            Id nocFromIds = nocResolveMaps.nocIdByCompositeKey.get(
                buildNatureOfCaseCompositeKey(productId, categoryId, subCategoryId, subCodeId)
            );
            if (nocFromIds != null) {
                return nocFromIds;
            }
        }

        List<String> categoryCandidates = importNatureTextCandidates(r.category);
        List<String> subCategoryCandidates = importNatureTextCandidates(r.subCategory);
        List<String> subCodeCandidates = String.isBlank(r.subCode)
            ? new List<String>()
            : importNatureTextCandidates(r.subCode);

        for (String categoryAlias : categoryCandidates) {
            for (String subCategoryAlias : subCategoryCandidates) {
                if (!subCodeCandidates.isEmpty()) {
                    for (String subCodeAlias : subCodeCandidates) {
                        Id nocId = nocResolveMaps.nocIdByFullTextKey.get(
                            productIdKey + '|' + categoryAlias + '|' + subCategoryAlias + '|' + subCodeAlias
                        );
                        if (nocId != null) {
                            return nocId;
                        }
                    }
                } else {
                    Id nocId = nocResolveMaps.nocIdByTripleTextKey.get(
                        productIdKey + '|' + categoryAlias + '|' + subCategoryAlias
                    );
                    if (nocId != null) {
                        return nocId;
                    }
                }
            }
        }
        return null;
    }

    private static void applyOtherDefaultCaseStageFromNature(
        Case customerCase,
        ParsedCaseRow r,
        LookupMaps maps,
        NatureOfCaseResolveMaps nocResolveMaps
    ) {
        if (customerCase == null || r == null || maps == null || nocResolveMaps == null) {
            return;
        }
        Id nocId = resolveNatureOfCaseIdForImportRow(r, maps, nocResolveMaps);
        if (nocId == null) {
            return;
        }
        Id defaultStageId = nocResolveMaps.defaultCaseStageIdByNocId.get(nocId);
        if (defaultStageId != null) {
            customerCase.FEC_Current_Case_Stage__c = defaultStageId;
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

    private static String matchBatchImportCaseStatus(Schema.DescribeFieldResult statusDfr, String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String direct = matchPicklist(statusDfr, raw);
        if (String.isNotBlank(direct)) {
            if (
                direct.equalsIgnoreCase(FEC_ConstantCommon.CASE_STATUS_OPEN) ||
                direct.equalsIgnoreCase(FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED)
            ) {
                return direct;
            }
            return null;
        }
        String trimmed = raw.trim();
        if (trimmed.equalsIgnoreCase(FEC_ConstantCommon.CASE_STATUS_OPEN)) {
            String openApi = matchPicklist(statusDfr, FEC_ConstantCommon.CASE_STATUS_OPEN);
            return String.isNotBlank(openApi) ? openApi : FEC_ConstantCommon.CASE_STATUS_OPEN;
        }
        if (trimmed.equalsIgnoreCase(FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED)) {
            String resolvedApi = matchPicklist(statusDfr, FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED);
            return String.isNotBlank(resolvedApi)
                ? resolvedApi
                : FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED;
        }
        return null;
    }

    private static Map<String, Set<String>> buildSubChannelsByChannelMap(
        Schema.DescribeFieldResult channelDfr,
        Schema.DescribeFieldResult subChannelDfr
    ) {
        Map<String, Set<String>> subChannelsByChannel = new Map<String, Set<String>>();
        if (channelDfr == null || subChannelDfr == null) {
            return subChannelsByChannel;
        }
        List<Schema.PicklistEntry> channelEntries = channelDfr.getPicklistValues();
        List<Schema.PicklistEntry> subChannelEntries = subChannelDfr.getPicklistValues();
        Schema.SObjectField controllerFieldRef = subChannelDfr.getController();
        String controllerFieldApi =
            controllerFieldRef == null ? null : controllerFieldRef.getDescribe().getName();
        Boolean dependent =
            String.isNotBlank(controllerFieldApi) &&
            controllerFieldApi.equalsIgnoreCase(String.valueOf(channelDfr.getName()));
        if (!dependent) {
            return subChannelsByChannel;
        }

        for (Integer channelIndex = 0; channelIndex < channelEntries.size(); channelIndex++) {
            Schema.PicklistEntry channelEntry = channelEntries[channelIndex];
            if (channelEntry == null || !channelEntry.isActive()) {
                continue;
            }
            registerChannelSubChannelKey(subChannelsByChannel, channelEntry.getValue());
            registerChannelSubChannelKey(subChannelsByChannel, channelEntry.getLabel());

            for (Schema.PicklistEntry subEntry : subChannelEntries) {
                if (subEntry == null || !subEntry.isActive()) {
                    continue;
                }
                if (dependent && !isPicklistEntryValidForControllerIndex(subEntry, channelIndex)) {
                    continue;
                }
                addSubChannelForChannelKey(subChannelsByChannel, channelEntry.getValue(), subEntry.getValue());
                addSubChannelForChannelKey(subChannelsByChannel, channelEntry.getValue(), subEntry.getLabel());
                addSubChannelForChannelKey(subChannelsByChannel, channelEntry.getLabel(), subEntry.getValue());
                addSubChannelForChannelKey(subChannelsByChannel, channelEntry.getLabel(), subEntry.getLabel());
            }
        }
        return subChannelsByChannel;
    }

    private static void registerChannelSubChannelKey(Map<String, Set<String>> subChannelsByChannel, String channelKey) {
        if (String.isBlank(channelKey)) {
            return;
        }
        String normalized = channelKey.trim().toLowerCase();
        if (!subChannelsByChannel.containsKey(normalized)) {
            subChannelsByChannel.put(normalized, new Set<String>());
        }
    }

    private static void addSubChannelForChannelKey(
        Map<String, Set<String>> subChannelsByChannel,
        String channelKey,
        String subChannelKey
    ) {
        if (String.isBlank(channelKey) || String.isBlank(subChannelKey)) {
            return;
        }
        registerChannelSubChannelKey(subChannelsByChannel, channelKey);
        subChannelsByChannel.get(channelKey.trim().toLowerCase()).add(subChannelKey.trim().toLowerCase());
    }

    private static String readPicklistEntryValidFor(Schema.PicklistEntry entry) {
        if (entry == null) {
            return null;
        }
        Map<String, Object> entryMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(entry));
        Object validForObj = entryMap == null ? null : entryMap.get('validFor');
        return validForObj == null ? null : String.valueOf(validForObj);
    }

    private static Boolean isPicklistEntryValidForControllerIndex(Schema.PicklistEntry entry, Integer controllerIndex) {
        if (entry == null || controllerIndex == null || controllerIndex < 0) {
            return false;
        }
        String validForBits = readPicklistEntryValidFor(entry);
        if (String.isBlank(validForBits)) {
            return true;
        }
        String hexString = EncodingUtil.convertToHex(EncodingUtil.base64Decode(validForBits));
        Integer controlByteIndex = controllerIndex / 8;
        Integer controlBitIndex = Math.mod(controllerIndex, 8);
        Integer startChar = controlByteIndex * 2;
        if (hexString.length() <= startChar + 1) {
            return false;
        }
        Integer byteValue = hexStringToInt(hexString.substring(startChar, startChar + 2));
        return (byteValue & (1 << controlBitIndex)) != 0;
    }

    private static Integer hexStringToInt(String hex) {
        if (String.isBlank(hex)) {
            return 0;
        }
        Integer result = 0;
        String hexChars = '0123456789ABCDEF';
        String normalized = hex.toUpperCase();
        for (Integer i = 0; i < normalized.length(); i++) {
            String ch = normalized.substring(i, i + 1);
            Integer digit = hexChars.indexOf(ch);
            if (digit < 0) {
                continue;
            }
            result = (result << 4) + digit;
        }
        return result;
    }

    private static Boolean isSubChannelValidForChannel(
        String channelApi,
        String subChannelApi,
        Map<String, Set<String>> subChannelsByChannel
    ) {
        if (String.isBlank(channelApi) || String.isBlank(subChannelApi) || subChannelsByChannel == null) {
            return true;
        }
        Set<String> allowed = subChannelsByChannel.get(channelApi.trim().toLowerCase());
        if (allowed == null || allowed.isEmpty()) {
            return true;
        }
        return allowed.contains(subChannelApi.trim().toLowerCase());
    }

    private static void applyCustomerCaseSuccessResult(
        FEC_BatchCaseCreationController.CaseRowResult rr,
        Case insertedCustomer,
        Id insertedId
    ) {
        rr.recordId = String.valueOf(insertedId);
        rr.fecIdSearch = insertedCustomer == null ? '' : String.valueOf(insertedCustomer.FEC_ID_Search__c);
        rr.status = 'Succeeded';
        rr.errors = '';
    }

}

