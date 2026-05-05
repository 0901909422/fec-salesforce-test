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

    /** Sub Code từ UI (param) ưu tiên khi User vừa chọn NOC chưa Save Case. */
    private static String mergeSubCode(String caseSubCode, String paramSubCode) {
        if (String.isNotBlank(paramSubCode)) {
            return paramSubCode.trim();
        }
        return caseSubCode != null ? caseSubCode.trim() : FEC_ConstantCommon.STR_EMPTY;
    }

    /** Nhánh đổi điểm thưởng (SRS RC33): sau khi chọn NOC cần gọi GetRewardEligibility để lấy AvailablePoints. */
    private static Boolean isPointsRedemptionNoc(String subCode) {
        return String.isNotBlank(subCode) && subCode.contains('RC33');
    }

    public class TierOption {
        @AuraEnabled public String valueJson;
        @AuraEnabled public String label;
    }

    public class InitResult {
        @AuraEnabled public Boolean showRedemptionUi;
        @AuraEnabled public String notEligibleMessage;
        @AuraEnabled public String cmsPhone;
        @AuraEnabled public List<TierOption> tierOptions;
        @AuraEnabled public String subCodeCode;
        @AuraEnabled public String expectedProductType;
        @AuraEnabled public Decimal availablePoints;
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
    public static InitResult initData(Id caseId, String subCodeCode) {
        InitResult r = new InitResult();
        r.showRedemptionUi = false;
        r.tierOptions = new List<TierOption>();
        if (caseId == null) {
            r.notEligibleMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' });
            return r;
        }
        List<Case> cases = [
            SELECT Id, CaseNumber, FEC_SubCode__r.FEC_Code__c, FEC_Account_or_Contract__c,
                FEC_Account_or_Contract__r.FEC_Account_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case' }));
        }
        Case c = cases[0];
        String codeFromCase = c.FEC_SubCode__r != null && c.FEC_SubCode__r.FEC_Code__c != null ? c.FEC_SubCode__r.FEC_Code__c : FEC_ConstantCommon.STR_EMPTY;
        String effectiveSub = mergeSubCode(codeFromCase, subCodeCode);
        r.subCodeCode = String.isNotBlank(effectiveSub) ? effectiveSub : codeFromCase;
        if (!isPointsRedemptionNoc(effectiveSub)) {
            return r;
        }
        if (c.FEC_Account_or_Contract__c == null || c.FEC_Account_or_Contract__r == null ||
            String.isBlank(c.FEC_Account_or_Contract__r.FEC_Account_Number__c)) {
            r.notEligibleMessage = MSG_NOT_ELIGIBLE;
            return r;
        }
        String accountNumber = c.FEC_Account_or_Contract__r.FEC_Account_Number__c.trim();
        EligibilityParse el = callAndParseEligibility(accountNumber);
        if (el == null || el.sysCode == null || el.sysCode != 0) {
            r.notEligibleMessage = MSG_NOT_ELIGIBLE;
            return r;
        }
        r.availablePoints = el.availablePoints;
        if (el.availablePoints == null || el.availablePoints < MIN_AVAILABLE_POINTS) {
            r.notEligibleMessage = MSG_NOT_ELIGIBLE;
            return r;
        }
        r.expectedProductType = resolveProductType(effectiveSub);
        if (String.isBlank(r.expectedProductType)) {
            r.cmsPhone = el.customerMobile;
            applyCmsPhoneToCase(caseId, el.customerMobile);
            return r;
        }
        if (!isTypeEligible(r.expectedProductType, el)) {
            r.notEligibleMessage = MSG_NOT_ELIGIBLE;
            return r;
        }
        r.cmsPhone = el.customerMobile;
        applyCmsPhoneToCase(caseId, el.customerMobile);
        for (ProductTier t : el.tiers) {
            if (t == null || t.productType != r.expectedProductType) {
                continue;
            }
            TierPayload p = new TierPayload();
            p.productId = t.productId;
            p.productName = t.productName;
            p.productType = t.productType;
            p.priceId = t.priceId;
            p.price = t.price;
            p.cashback = t.cashback != null ? t.cashback : 0;
            p.redeemTypeId = t.redeemTypeId != null ? Decimal.valueOf(t.redeemTypeId) : null;
            TierOption o = new TierOption();
            o.valueJson = JSON.serialize(p);
            o.label = formatTierLabel(t);
            r.tierOptions.add(o);
        }
        r.showRedemptionUi = !r.tierOptions.isEmpty();
        if (!r.showRedemptionUi) {
            r.notEligibleMessage = MSG_NOT_ELIGIBLE;
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
        List<Case> cases = [
            SELECT Id, CaseNumber, FEC_SubCode__r.FEC_Code__c, FEC_Account_or_Contract__c,
                FEC_Account_or_Contract__r.FEC_Account_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case' }));
        }
        Case c = cases[0];
        String codeFromCase = c.FEC_SubCode__r != null && c.FEC_SubCode__r.FEC_Code__c != null ? c.FEC_SubCode__r.FEC_Code__c : FEC_ConstantCommon.STR_EMPTY;
        String effectiveSub = mergeSubCode(codeFromCase, subCodeCode);
        String expectedType = resolveProductType(effectiveSub);
        if (String.isBlank(expectedType) || expectedType != tier.productType) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Sub Code' }));
        }
        if (c.FEC_Account_or_Contract__r == null || String.isBlank(c.FEC_Account_or_Contract__r.FEC_Account_Number__c)) {
            throw new AuraHandledException(System.Label.FEC_MISSING_REQUIRED_FIELDS_MSG);
        }
        EligibilityParse el = callAndParseEligibility(c.FEC_Account_or_Contract__r.FEC_Account_Number__c.trim());
        if (el == null || el.sysCode == null || el.sysCode != 0 || el.availablePoints == null ||
            el.availablePoints < MIN_AVAILABLE_POINTS) {
            throw new AuraHandledException(MSG_NOT_ELIGIBLE);
        }
        FEC_CMSRewardRedeemService.RedeemRequest req = new FEC_CMSRewardRedeemService.RedeemRequest();
        req.accountNumber = c.FEC_Account_or_Contract__r.FEC_Account_Number__c.trim();
        req.customerName = FEC_CommonUltils.defaultToEmpty(el.customerName);
        req.customerMobile = FEC_CommonUltils.defaultToEmpty(el.customerMobile);
        req.ticketId = c.CaseNumber != null ? c.CaseNumber : String.valueOf(c.Id);
        req.ticketPoint = tier.price;
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

    /**
     * Lưu nháp mệnh giá đã chọn (FEC_Redeemed_Points__c) khi chưa bấm Redeem — gọi từ Save & Close / Submit.
     */
    @AuraEnabled
    public static void saveDraftSelection(Id caseId, String tierJson, String subCodeCode) {
        if (caseId == null || String.isBlank(tierJson)) {
            return;
        }
        TierPayload tier = (TierPayload) JSON.deserialize(tierJson, TierPayload.class);
        if (tier == null || tier.price == null || String.isBlank(tier.productType)) {
            return;
        }
        List<Case> cases = [
            SELECT Id, FEC_SubCode__r.FEC_Code__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            return;
        }
        String codeFromCase = cases[0].FEC_SubCode__r != null && cases[0].FEC_SubCode__r.FEC_Code__c != null
            ? cases[0].FEC_SubCode__r.FEC_Code__c
            : FEC_ConstantCommon.STR_EMPTY;
        String effectiveSub = mergeSubCode(codeFromCase, subCodeCode);
        String expectedType = resolveProductType(effectiveSub);
        if (String.isBlank(expectedType) || expectedType != tier.productType) {
            return;
        }
        persistRedeemedPoints(caseId, tier.price);
    }

    private static void persistRedeemedPoints(Id caseId, Decimal pts) {
        try {
            Case row = new Case(Id = caseId);
            row.put('FEC_Redeemed_Points__c', pts != null ? String.valueOf(pts.longValue()) : null);
            SObjectAccessDecision d = Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ row });
            List<SObject> toSave = d.getRecords();
            if (!toSave.isEmpty()) {
                update toSave;
            }
        } catch (Exception ignore) {
        }
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
                out.redemptionOptions.evoucherEligible = String.isBlank(ev) ? true : Boolean.valueOf(ev);
                out.redemptionOptions.cashbackEligible = String.isBlank(cb) ? true : Boolean.valueOf(cb);
                out.redemptionOptions.mvoucherEligible = String.isBlank(mv) ? true : Boolean.valueOf(mv);
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
                t.productType = FEC_CommonUltils.getValueSafe(ch, 'Type');
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
