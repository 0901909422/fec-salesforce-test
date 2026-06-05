/****************************************************************************************
 * File Name    : FEC_PointsRedemptionCaseController.cls
 * Description  : Points Redemption — Case Information (RC33.01–03): eligibility callout +
 *                tier options (Products/Type), redeem via FEC_CMSRewardRedeemService.
 * Note         : Full Product/Type parsing is done here (not in FEC_GetRewardEligibility).
 ****************************************************************************************/
public without sharing class FEC_PointsRedemptionCaseController {
    private static final Decimal MIN_AVAILABLE_POINTS = 100000;
    private static final String NS = 'http://esbservice.fecredit.org/CMS_RewardWS/';
    private static final String MSG_NOT_ELIGIBLE = 'Không đủ điều kiện đổi điểm thưởng.';

    //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394 — Sub Code: param UI → Case → FEC_Nature_of_Case__c
    private static String resolveEffectiveSubCode(Case c, String paramSubCode) {
        if (String.isNotBlank(paramSubCode)) {
            return paramSubCode.trim();
        }
        if (c.FEC_SubCode__r != null && String.isNotBlank(c.FEC_SubCode__r.FEC_Code__c)) {
            return c.FEC_SubCode__r.FEC_Code__c.trim();
        }
        return resolveSubCodeFromNatureOfCase(c);
    }

    private static String resolveEffectiveSubCategory(Case c, String paramSubCategoryCode) {
        if (String.isNotBlank(paramSubCategoryCode)) {
            return paramSubCategoryCode.trim();
        }
        if (c.FEC_SubCategory__r != null && String.isNotBlank(c.FEC_SubCategory__r.FEC_Code__c)) {
            return c.FEC_SubCategory__r.FEC_Code__c.trim();
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    private static Case loadCase(Id caseId) {
        if (caseId == null) {
            return null;
        }
        List<Case> cases = [
            SELECT Id, CaseNumber,
                FEC_Product_Type__c, FEC_Product_Type__r.Name,
                FEC_Category__c, FEC_SubCategory__c,                 FEC_SubCode__c,
                FEC_SubCode__r.FEC_Code__c,
                FEC_SubCategory__r.FEC_Code__c,
                FEC_Account_or_Contract__c,
                FEC_Account_or_Contract__r.FEC_Account_Number__c,
                FEC_Account_or_Contract__r.FEC_Contract_Number__c,
                FEC_Account_Number__c,
                FEC_Account_Contract_Number_Text__c,
                //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
                FEC_Redeemed_Points__c,
                FEC_CMS_Phone__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        return cases.isEmpty() ? null : cases[0];
    }

    private static String resolveSubCodeFromNatureOfCase(Case c) {
        if (c == null || c.FEC_Product_Type__c == null || c.FEC_Category__c == null || c.FEC_SubCategory__c == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Id subCodeId = c.FEC_SubCode__c;
        List<FEC_Nature_of_Case__c> nocs = [
            SELECT FEC_Sub_Code__r.FEC_Code__c
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Product_Type__c = :c.FEC_Product_Type__c
                AND FEC_Category__c = :c.FEC_Category__c
                AND FEC_Sub_Category__c = :c.FEC_SubCategory__c
                AND FEC_Sub_Code__c = :subCodeId
            LIMIT 1
        ];
        if (!nocs.isEmpty() && nocs[0].FEC_Sub_Code__r != null && String.isNotBlank(nocs[0].FEC_Sub_Code__r.FEC_Code__c)) {
            return nocs[0].FEC_Sub_Code__r.FEC_Code__c.trim();
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394 — Customer History: Case.FEC_Account_or_Contract__c (lookup) hoặc FEC_Case__c (MD)
    private static FEC_Customer_History__c loadCustomerHistoryById(Id customerHistoryId) {
        if (customerHistoryId == null) {
            return null;
        }
        List<FEC_Customer_History__c> rows = [
            SELECT FEC_Account_Number__c, FEC_Contract_Number__c, FEC_Available_Points__c, FEC_Product_Code__c
            FROM FEC_Customer_History__c
            WHERE Id = :customerHistoryId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static FEC_Customer_History__c loadFirstCustomerHistoryByCase(Id caseId) {
        if (caseId == null) {
            return null;
        }
        List<FEC_Customer_History__c> rows = [
            SELECT FEC_Account_Number__c, FEC_Contract_Number__c, FEC_Available_Points__c, FEC_Product_Code__c
            FROM FEC_Customer_History__c
            WHERE FEC_Case__c = :caseId
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static FEC_Customer_History__c resolveCustomerHistoryForCase(Case c) {
        if (c == null) {
            return null;
        }
        if (c.FEC_Account_or_Contract__c != null) {
            FEC_Customer_History__c linked = loadCustomerHistoryById(c.FEC_Account_or_Contract__c);
            if (linked != null) {
                return linked;
            }
        }
        return loadFirstCustomerHistoryByCase(c.Id);
    }

    private static String resolveAccountNumberFromCustomerHistory(Case c, FEC_Customer_History__c ch) {
        if (ch == null) {
            return null;
        }
        String productTypeName = c.FEC_Product_Type__r != null ? c.FEC_Product_Type__r.Name : null;
        if (String.isBlank(productTypeName) && String.isNotBlank(ch.FEC_Product_Code__c)) {
            productTypeName = ch.FEC_Product_Code__c;
        }
        String resolved = FEC_CommonUltils.resolveAccountNumber(
            productTypeName,
            ch.FEC_Account_Number__c,
            ch.FEC_Contract_Number__c
        );
        return String.isNotBlank(resolved) ? resolved.trim() : null;
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394 — Account number: CH (lookup/FEC_Case__c) rồi field Case
    private static String resolveAccountNumberForCase(Case c) {
        return resolveAccountNumberForCase(c, resolveCustomerHistoryForCase(c));
    }

    private static String resolveAccountNumberForCase(Case c, FEC_Customer_History__c ch) {
        if (c == null) {
            return null;
        }
        String fromHistory = resolveAccountNumberFromCustomerHistory(c, ch);
        if (String.isNotBlank(fromHistory)) {
            return fromHistory;
        }
        if (String.isNotBlank(c.FEC_Account_Number__c)) {
            return c.FEC_Account_Number__c.trim();
        }
        if (String.isNotBlank(c.FEC_Account_Contract_Number_Text__c)) {
            return c.FEC_Account_Contract_Number_Text__c.trim();
        }
        return null;
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394 — C360 Available Points từ FEC_Customer_History__c
    private static Decimal resolveC360AvailablePointsFromCustomerHistory(String accountNumber, FEC_Customer_History__c ch) {
        if (ch != null && ch.FEC_Available_Points__c != null) {
            return ch.FEC_Available_Points__c;
        }
        if (String.isNotBlank(accountNumber)) {
            List<FEC_Customer_History__c> rows = [
                SELECT FEC_Available_Points__c
                FROM FEC_Customer_History__c
                WHERE FEC_Account_Number__c = :accountNumber
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
            if (!rows.isEmpty()) {
                return rows[0].FEC_Available_Points__c;
            }
        }
        return null;
    }

    /** Nhánh đổi điểm thưởng (SRS RC33): Sub Category RC33 hoặc Sub Code RC33.x. */
    private static Boolean isPointsRedemptionRc33Branch(String subCategoryCode, String subCodeCode) {
        if (String.isNotBlank(subCategoryCode) && subCategoryCode.toUpperCase().contains('RC33')) {
            return true;
        }
        return String.isNotBlank(subCodeCode) && subCodeCode.toUpperCase().contains('RC33');
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394 — mọi trường hợp không đủ điều kiện: chỉ 1 reason UI
    private static void applyNotEligibleBelowMinPoints(InitResult r, Decimal points) {
        r.availablePoints = points;
        r.notEligibleMessage = MSG_NOT_ELIGIBLE;
        r.notEligibleReason = System.Label.FEC_Points_Redemption_Available_Points_Below_Min;
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394 — API lỗi: fallback Available Points từ Case.FEC_Redeemed_Points__c
    private static Decimal parseCaseRedeemedPointsField(Case c) {
        if (c == null || String.isBlank(c.FEC_Redeemed_Points__c)) {
            return null;
        }
        String raw = c.FEC_Redeemed_Points__c.trim();
        Integer semiIdx = raw.indexOf(';');
        if (semiIdx > 0) {
            raw = raw.substring(0, semiIdx).trim();
        }
        raw = raw.replace(',', '');
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return Decimal.valueOf(raw);
        } catch (Exception ignore) {
            return null;
        }
    }

    private static void applyApiFailureNotEligible(InitResult r, Case c, EligibilityParse el) {
        Decimal fallbackPoints = parseCaseRedeemedPointsField(c);
        Decimal displayPoints = el != null && el.availablePoints != null ? el.availablePoints : fallbackPoints;
        applyNotEligibleBelowMinPoints(r, displayPoints);
    }

    /** RC33.01–03: hiển thị form Redeem Points; RC33.04 và NOC chưa có Sub Code redeem thì không. */
    private static Boolean isPointsRedemptionRedeemSubCode(String subCodeCode) {
        if (String.isBlank(subCodeCode)) {
            return false;
        }
        String s = subCodeCode.trim().toUpperCase();
        return s.contains('RC33.01') || s.contains('RC33.02') || s.contains('RC33.03');
    }

    private static Boolean parseEligibleFlag(String raw) {
        if (String.isBlank(raw)) {
            return true;
        }
        String v = raw.trim();
        return 'true'.equalsIgnoreCase(v) || '1'.equals(v);
    }

    private static String normalizeProductType(String productType) {
        if (String.isBlank(productType)) {
            return null;
        }
        String t = productType.trim();
        if (t.equalsIgnoreCase(FEC_ConstantCommon.PRODUCT_TYPE_CASHBACK)) {
            return FEC_ConstantCommon.PRODUCT_TYPE_CASHBACK;
        }
        if (t.equalsIgnoreCase(FEC_ConstantCommon.PRODUCT_TYPE_EVOUCHER)) {
            return FEC_ConstantCommon.PRODUCT_TYPE_EVOUCHER;
        }
        if (t.equalsIgnoreCase(FEC_ConstantCommon.PRODUCT_TYPE_MVOUCHER)) {
            return FEC_ConstantCommon.PRODUCT_TYPE_MVOUCHER;
        }
        return t;
    }

    private static Boolean isBelowMinAvailablePoints(Decimal points) {
        return points == null || points < MIN_AVAILABLE_POINTS;
    }

    public class TierOption {
        @AuraEnabled public String valueJson;
        @AuraEnabled public String label;
    }

    public class InitResult {
        @AuraEnabled public Boolean showRedemptionUi;
        @AuraEnabled public String notEligibleMessage;
        //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394
        @AuraEnabled public String notEligibleReason;
        @AuraEnabled public String cmsPhone;
        @AuraEnabled public List<TierOption> tierOptions;
        @AuraEnabled public String subCodeCode;
        @AuraEnabled public String expectedProductType;
        @AuraEnabled public Decimal availablePoints;
        @AuraEnabled public String subCategoryCode;
        //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
        @AuraEnabled public String savedRedeemedPoints;
    }

    public class TierPayload {
        @AuraEnabled public String productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productType;
        @AuraEnabled public String priceId;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Decimal cashback;
        @AuraEnabled public Decimal redeemTypeId;
    }

    @AuraEnabled
    public static InitResult initData(Id caseId, String subCodeCode, String subCategoryCode) {
        InitResult r = new InitResult();
        r.showRedemptionUi = false;
        r.tierOptions = new List<TierOption>();
        if (caseId == null) {
            r.notEligibleMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' });
            return r;
        }
        Case c = loadCase(caseId);
        if (c == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case' }));
        }
        String effectiveSub = resolveEffectiveSubCode(c, subCodeCode);
        String effectiveSubCat = resolveEffectiveSubCategory(c, subCategoryCode);
        r.subCodeCode = effectiveSub;
        r.subCategoryCode = effectiveSubCat;
        if (!isPointsRedemptionRc33Branch(effectiveSubCat, effectiveSub)) {
            return r;
        }
        FEC_Customer_History__c customerHistory = resolveCustomerHistoryForCase(c);
        String accountNumber = resolveAccountNumberForCase(c, customerHistory);
        if (String.isBlank(accountNumber)) {
            applyNotEligibleBelowMinPoints(r, null);
            return r;
        }
        EligibilityParse el = callAndParseEligibility(accountNumber);
        if (el == null || el.sysCode == null || el.sysCode != 0) {
            applyApiFailureNotEligible(r, c, el);
            return r;
        }
        if (isBelowMinAvailablePoints(el.availablePoints)) {
            applyNotEligibleBelowMinPoints(r, el.availablePoints);
            return r;
        }
        if (!isPointsRedemptionRedeemSubCode(effectiveSub)) {
            return r;
        }
        r.expectedProductType = resolveProductType(effectiveSub);
        if (String.isBlank(r.expectedProductType)) {
            applyNotEligibleBelowMinPoints(r, el.availablePoints);
            return r;
        }
        if (!isTypeEligible(r.expectedProductType, el)) {
            applyNotEligibleBelowMinPoints(r, el.availablePoints);
            return r;
        }
        r.cmsPhone = el.customerMobile;
        applyCmsPhoneToCase(caseId, el.customerMobile);
        for (ProductTier t : el.tiers) {
            if (t == null || normalizeProductType(t.productType) != r.expectedProductType) {
                continue;
            }
            TierPayload p = new TierPayload();
            p.productId = t.productId;
            p.productName = t.productName;
            p.productType = normalizeProductType(t.productType);
            p.priceId = t.priceId;
            p.price = t.price;
            p.cashback = t.cashback != null ? t.cashback : 0;
            p.redeemTypeId = t.redeemTypeId != null ? Decimal.valueOf(t.redeemTypeId) : null;
            TierOption o = new TierOption();
            o.valueJson = JSON.serialize(p);
            o.label = formatTierLabel(t);
            r.tierOptions.add(o);
        }
        if (r.tierOptions.isEmpty()) {
            applyNotEligibleBelowMinPoints(r, el.availablePoints);
            return r;
        }
        r.showRedemptionUi = true;
        r.availablePoints = el.availablePoints;
        //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
        if (c != null && String.isNotBlank(c.FEC_Redeemed_Points__c)) {
            r.savedRedeemedPoints = c.FEC_Redeemed_Points__c.trim();
        }
        return r;
    }

    @AuraEnabled
    public static FEC_CMSRewardRedeemService.RedeemResult redeem(Id caseId, String tierJson, String subCodeCode) {
        if (caseId == null || String.isBlank(tierJson)) {
            throw new AuraHandledException(System.Label.FEC_MISSING_REQUIRED_FIELDS_MSG);
        }
        TierPayload tier = (TierPayload) JSON.deserialize(tierJson, TierPayload.class);
        if (tier == null || String.isBlank(tier.productType) || tier.redeemTypeId == null || tier.price == null) {
            throw new AuraHandledException(System.Label.FEC_MISSING_REQUIRED_FIELDS_MSG);
        }
        Case c = loadCase(caseId);
        if (c == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case' }));
        }
        String effectiveSub = resolveEffectiveSubCode(c, subCodeCode);
        String expectedType = resolveProductType(effectiveSub);
        if (String.isBlank(expectedType) || expectedType != tier.productType) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Sub Code' }));
        }
        String accountNumber = resolveAccountNumberForCase(c);
        if (String.isBlank(accountNumber)) {
            throw new AuraHandledException(System.Label.FEC_MISSING_REQUIRED_FIELDS_MSG);
        }
        EligibilityParse el = callAndParseEligibility(accountNumber.trim());
        if (el == null || el.sysCode == null || el.sysCode != 0 || el.availablePoints == null ||
            el.availablePoints < MIN_AVAILABLE_POINTS) {
            throw new AuraHandledException(MSG_NOT_ELIGIBLE);
        }
        FEC_CMSRewardRedeemService.RedeemRequest req = new FEC_CMSRewardRedeemService.RedeemRequest();
        req.transId = FEC_CommonUltils.generateTransactionUUID();
        req.requestorId = FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN;
        req.dateTimeStr = Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT_GMT);
        req.accountNumber = accountNumber.trim();
        req.customerName = FEC_CommonUltils.defaultToEmpty(el.customerName);
        req.customerMobile = FEC_CommonUltils.defaultToEmpty(el.customerMobile);
        req.ticketId = c.CaseNumber != null ? c.CaseNumber : String.valueOf(c.Id);
        req.ticketPoint = tier.price;
        req.adjustmentIndicator = '+';
        req.productId = tier.productId;
        req.productName = tier.productName;
        req.productType = tier.productType;
        req.priceId = tier.priceId;
        req.price = tier.price;
        req.cashback = tier.cashback != null ? tier.cashback : 0;
        req.redeemTypeId = Integer.valueOf(String.valueOf(tier.redeemTypeId.longValue()));
        FEC_CMSRewardRedeemService.RedeemResult res;
        if (tier.productType == FEC_ConstantCommon.PRODUCT_TYPE_CASHBACK) {
            res = FEC_CMSRewardRedeemService.generateCashback(req);
        } else if (tier.productType == FEC_ConstantCommon.PRODUCT_TYPE_EVOUCHER) {
            res = FEC_CMSRewardRedeemService.generateEvoucher(req);
        } else if (tier.productType == FEC_ConstantCommon.PRODUCT_TYPE_MVOUCHER) {
            res = FEC_CMSRewardRedeemService.generateMvoucher(req);
        } else {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'ProductType' }));
        }
        if (res != null && res.success == true) {
            persistRedeemedPoints(caseId, tier.price);
        }
        return res;
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — Lưu nháp FEC_Redeemed_Points__c khi Save & Close / Submit
    @AuraEnabled
    public static void saveDraftSelection(Id caseId, String tierJson, String subCodeCode) {
        if (caseId == null || String.isBlank(tierJson)) {
            return;
        }
        TierPayload tier = (TierPayload) JSON.deserialize(tierJson, TierPayload.class);
        if (tier == null || tier.price == null || String.isBlank(tier.productType)) {
            return;
        }
        Case c = loadCase(caseId);
        if (c == null) {
            return;
        }
        String effectiveSub = resolveEffectiveSubCode(c, subCodeCode);
        String expectedType = resolveProductType(effectiveSub);
        if (String.isBlank(expectedType) || expectedType != tier.productType) {
            return;
        }
        persistRedeemedPoints(caseId, tier.price);
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
    private static void persistRedeemedPoints(Id caseId, Decimal pts) {
        if (caseId == null || !Schema.sObjectType.Case.fields.FEC_Redeemed_Points__c.isUpdateable()) {
            return;
        }
        Case row = new Case(Id = caseId);
        row.FEC_Redeemed_Points__c = pts != null ? String.valueOf(pts.longValue()) : null;
        SObjectAccessDecision d = Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ row });
        List<SObject> toSave = d.getRecords();
        if (toSave.isEmpty()) {
            return;
        }
        Case stripped = (Case) toSave[0];
        if (!stripped.getPopulatedFieldsAsMap().containsKey('FEC_Redeemed_Points__c')) {
            return;
        }
        update stripped;
    }

    private static void applyCmsPhoneToCase(Id caseId, String phone) {
        if (String.isBlank(phone)) {
            return;
        }
        try {
            Case row = new Case(Id = caseId);
            row.put('FEC_CMS_Phone__c', phone);
            SObjectAccessDecision d = Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ row });
            List<SObject> toSave = d.getRecords();
            if (!toSave.isEmpty()) {
                update toSave;
            }
        } catch (Exception ignore) {
        }
    }

    private static String resolveProductType(String subCode) {
        if (String.isBlank(subCode)) {
            return null;
        }
        String s = subCode.trim();
        if (s.contains('RC33.01')) {
            return FEC_ConstantCommon.PRODUCT_TYPE_CASHBACK;
        }
        if (s.contains('RC33.02')) {
            return FEC_ConstantCommon.PRODUCT_TYPE_EVOUCHER;
        }
        if (s.contains('RC33.03')) {
            return FEC_ConstantCommon.PRODUCT_TYPE_MVOUCHER;
        }
        return null;
    }

    private static Boolean isTypeEligible(String productType, EligibilityParse el) {
        if (el.redemptionOptions == null) {
            return true;
        }
        if (productType == FEC_ConstantCommon.PRODUCT_TYPE_CASHBACK) {
            return el.redemptionOptions.cashbackEligible != false;
        }
        if (productType == FEC_ConstantCommon.PRODUCT_TYPE_EVOUCHER) {
            return el.redemptionOptions.evoucherEligible != false;
        }
        if (productType == FEC_ConstantCommon.PRODUCT_TYPE_MVOUCHER) {
            return el.redemptionOptions.mvoucherEligible != false;
        }
        return false;
    }

    private static String formatTierLabel(ProductTier t) {
        if (t == null || t.price == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return String.valueOf(t.price.longValue());
    }

    private class RedemptionOpts {
        Boolean evoucherEligible;
        Boolean cashbackEligible;
        Boolean mvoucherEligible;
    }

    private class ProductTier {
        String productId;
        String productName;
        String productType;
        String priceId;
        Decimal price;
        Decimal cashback;
        Integer redeemTypeId;
    }

    private class EligibilityParse {
        Integer sysCode;
        String sysDescription;
        Decimal availablePoints;
        String customerMobile;
        String customerName;
        RedemptionOpts redemptionOptions;
        List<ProductTier> tiers;
    }

    private static EligibilityParse callAndParseEligibility(String accountNumber) {
        String soap = buildGetRewardSoap(
            FEC_CommonUltils.generateTransactionId(),
            FEC_ConstantCommon.REQUESTOR_CRM,
            Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
            accountNumber
        );
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Reward_Eligibility');
        String endpoint = (apiSetting != null ? apiSetting.FEC_Endpoint__c : FEC_ConstantCommon.STR_EMPTY) +
            (apiConfig != null ? apiConfig.FEC_Endpoint__c : FEC_ConstantCommon.STR_EMPTY);
        if (String.isBlank(endpoint)) {
            return null;
        }
        HttpResponse res = FEC_CommonUltils.calloutApi(
            endpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            FEC_ConstantCommon.API_CONTENT_TYPE,
            apiConfig != null ? apiConfig.FEC_SOAP_Action__c : null,
            null,
            soap
        );
        if (res == null || res.getStatusCode() != FEC_ConstantCommon.SUCCESS_CODE_200_NUM || String.isBlank(res.getBody())) {
            return null;
        }
        return parseEligibilityXml(FEC_CommonUltils.cleanResponseBody(res.getBody()));
    }

    private static String buildGetRewardSoap(String transId, String requestorId, String dateTimeStr, String accountNumber) {
        Dom.Document doc = new Dom.Document();
        Dom.XmlNode envelope = doc.createRootElement('soapenv:Envelope', null, null);
        envelope.setAttribute('xmlns:soapenv', FEC_ConstantCommon.SOAP_ENV);
        envelope.setAttribute('xmlns:ns1', NS);
        envelope.addChildElement('soapenv:Header', null, null);
        Dom.XmlNode body = envelope.addChildElement('soapenv:Body', null, null);
        Dom.XmlNode action = body.addChildElement('ns1:GetRewardEligibility', null, null);
        action.setAttribute('xmlns:ns1', NS);
        Dom.XmlNode sys = action.addChildElement('SysRequest', null, null);
        sys.addChildElement('TransID', null, null).addTextNode(transId);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);
        action.addChildElement('AccountNumber', null, null).addTextNode(accountNumber);
        return doc.toXmlString();
    }

    private static EligibilityParse parseEligibilityXml(String xml) {
        EligibilityParse out = new EligibilityParse();
        out.tiers = new List<ProductTier>();
        try {
            Dom.Document doc = new Dom.Document();
            doc.load(xml);
            Dom.XmlNode root = doc.getRootElement();
            Dom.XmlNode bodyNode = root.getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);
            if (bodyNode == null) {
                return out;
            }
            Dom.XmlNode resp = FEC_CommonUltils.findChildByName(bodyNode, 'GetRewardEligibilityResponse');
            if (resp == null) {
                return out;
            }
            Dom.XmlNode sysNode = FEC_CommonUltils.findChildByName(resp, 'SysResponse');
            if (sysNode != null) {
                out.sysCode = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(sysNode, 'Status'));
                out.sysDescription = FEC_CommonUltils.getValueSafe(sysNode, 'Description');
            }
            out.availablePoints = FEC_CommonUltils.xmlValToDecimal(resp, 'AvailablePoints');
            out.customerMobile = FEC_CommonUltils.getXmlValue(resp, 'CustomerMobile');
            out.customerName = FEC_CommonUltils.getXmlValue(resp, 'CustomerName');
            Dom.XmlNode redNode = FEC_CommonUltils.findChildByName(resp, 'RedemptionOptions');
            if (redNode != null) {
                out.redemptionOptions = new RedemptionOpts();
                String ev = FEC_CommonUltils.getValueSafe(redNode, 'EvoucherEligible');
                String cb = FEC_CommonUltils.getValueSafe(redNode, 'CashbackEligible');
                String mv = FEC_CommonUltils.getValueSafe(redNode, 'MvoucherEligible');
                out.redemptionOptions.evoucherEligible = parseEligibleFlag(ev);
                out.redemptionOptions.cashbackEligible = parseEligibleFlag(cb);
                out.redemptionOptions.mvoucherEligible = parseEligibleFlag(mv);
            }
            Dom.XmlNode productsNode = FEC_CommonUltils.findChildByName(resp, 'Products');
            if (productsNode == null) {
                return out;
            }
            for (Dom.XmlNode ch : productsNode.getChildElements()) {
                if (ch == null) {
                    continue;
                }
                String nodeNm = ch.getName();
                if (nodeNm != 'Product' && !nodeNm.endsWith(':Product')) {
                    continue;
                }
                ProductTier t = new ProductTier();
                t.productId = firstVal(ch, new List<String>{ 'ID', 'ProductCode', 'Id' });
                t.productName = firstVal(ch, new List<String>{ 'Name', 'ProductName' });
                t.productType = normalizeProductType(FEC_CommonUltils.getValueSafe(ch, 'Type'));
                t.priceId = FEC_CommonUltils.getValueSafe(ch, 'PriceID');
                String priceStr = FEC_CommonUltils.getValueSafe(ch, 'Price');
                t.price = String.isBlank(priceStr) ? null : Decimal.valueOf(priceStr.trim());
                String cbStr = FEC_CommonUltils.getValueSafe(ch, 'Cashback');
                t.cashback = String.isBlank(cbStr) ? 0 : Decimal.valueOf(cbStr.trim());
                t.redeemTypeId = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(ch, 'RedeemTypeID'));
                if (String.isNotBlank(t.productType) && t.price != null && t.redeemTypeId != null) {
                    out.tiers.add(t);
                }
            }
        } catch (Exception ex) {
            return out;
        }
        return out;
    }

    private static String firstVal(Dom.XmlNode p, List<String> names) {
        for (String n : names) {
            String v = FEC_CommonUltils.getValueSafe(p, n);
            if (String.isNotBlank(v)) {
                return v.trim();
            }
        }
        return null;
    }

    @TestVisible
    static Integer testParseTierCount(String eligibilityXml) {
        EligibilityParse p = parseEligibilityXml(eligibilityXml);
        return (p == null || p.tiers == null) ? 0 : p.tiers.size();
    }

    @TestVisible
    static String testResolveProductType(String subCode) {
        return resolveProductType(subCode);
    }
}