/**
 * MRC Return (RL05) — quy tắc hiển thị UI Case Business & phân luồng RL05.02.
 * FECREDIT_CSM_2025_KH-1269 / Batch 7
 */
public without sharing class FEC_MrcReturnCaseService {
    public static final String MRC_RETURN = 'MRC Return';

    public static final String FLOW_NOT_ELIGIBLE = 'NOT_ELIGIBLE';
    public static final String FLOW_PAYMENT_SUPPORT = 'PAYMENT_SUPPORT';
    public static final String FLOW_CP_SUPPORT = 'CP_SUPPORT';

    public static final String CONF_RECEIVED = 'Customer received MRC';
    public static final String CONF_NOT_RECEIVED = 'Customer has not received MRC';

    private static final Set<String> STAGE1_HIDDEN_ASSESSMENT = new Set<String>{
        'FEC_Contract_Processing_Assessment_Type__c'
    };

    private static final Set<String> MRC_STATUS_NOT_ELIGIBLE = new Set<String>{
        'CN',
        'CC'
    };

    private static final Set<String> MRC_STATUS_CP_ALWAYS = new Set<String>{
        'TLCCDTKH',
        'TLDN',
        'TLNB',
        'HT',
        'DTMRC_CTLHD'
    };

    private static final Set<String> MRC_STATUS_MIXED = new Set<String>{
        'TLCN',
        'LK',
        'THDB',
        'THĐB',
        'MN',
        'MN-INTERNAL',
        'OTHERS',
        'N/A'
    };

    private static final Set<String> MRC_STATUS_CONDITION_2 = new Set<String>{
        'TLCCDTKH',
        'TLDN',
        'TLNB',
        'DTMRC_CTLHD'
    };

    private static final Set<String> CONTRACT_CLOSED = new Set<String>{
        'CLOSED'
    };

    public class MrcRl05UiContext {
        @AuraEnabled
        public Boolean isRl05Branch;
        @AuraEnabled
        public Boolean isPhotoSubCode;
        @AuraEnabled
        public Boolean isReturnSubCode;
        @AuraEnabled
        public Boolean hidePropertyInfo;
        @AuraEnabled
        public Boolean hideMrcInfoLwc;
        @AuraEnabled
        public Boolean showDeliveryForm;
        @AuraEnabled
        public Boolean showCustomerConfirmation;
        @AuraEnabled
        public Boolean dupCaseOnly;
        /** Tình huống 2: chỉ Điều kiện 1 — Noti-11 + radio, không dropdown Xác nhận KH. */
        @AuraEnabled
        public Boolean showMrcDupBanner;
        @AuraEnabled
        public Boolean meetsCondition2;
        @AuraEnabled
        public String processingFlow;
        @AuraEnabled
        public Boolean autoRouteReject;
        @AuraEnabled
        public Boolean autoRoutePayment;
        @AuraEnabled
        public Boolean autoRouteCp;
        /** TH1 | TH2 | TH3 | TH4 — phân nhánh RL05.02 theo Cond1/Cond2. */
        @AuraEnabled
        public String rl05Scenario;
        /** TH3: sau Chưa nhận MRC — hiện radio Noti-11 (không có Case trùng). */
        @AuraEnabled
        public Boolean showHandlingRadioOnNotReceived;
    }

    public static MrcRl05UiContext buildUiContext(
        Case selectedCase,
        String subCategoryCode,
        String subCodeCode,
        String customerConfirmation,
        Boolean hasDupOpenCase
    ) {
        MrcRl05UiContext ctx = new MrcRl05UiContext();
        ctx.isRl05Branch = isRl05Branch(subCategoryCode, subCodeCode);
        if (!ctx.isRl05Branch) {
            return ctx;
        }

        String subUpper = normalizeCode(subCodeCode);
        if (String.isBlank(subUpper) && selectedCase?.FEC_SubCode__r != null) {
            subUpper = normalizeCode(selectedCase.FEC_SubCode__r.FEC_Code__c);
        }
        ctx.isPhotoSubCode = isPhotoSubCode(subUpper);
        ctx.isReturnSubCode = isReturnSubCode(subUpper);

        String mrcStatusId = null;
        if (selectedCase != null && selectedCase.FEC_Account_or_Contract__r != null) {
            mrcStatusId = normalizeCode(
                selectedCase.FEC_Account_or_Contract__r.FEC_MRC_Status__c
            );
            if (String.isBlank(mrcStatusId)) {
                mrcStatusId = normalizeCode(
                    selectedCase.FEC_Account_or_Contract__r.FEC_Status_ID__c
                );
            }
        }
        String contractStatus = selectedCase != null &&
            selectedCase.FEC_Account_or_Contract__r != null
            ? normalizeCode(
                  selectedCase.FEC_Account_or_Contract__r.FEC_Contract_Status__c
              )
            : null;

        ctx.meetsCondition2 = meetsCondition2(mrcStatusId);
        Boolean cond1 = hasDupOpenCase == true;
        Boolean cond2 = ctx.meetsCondition2;
        ctx.dupCaseOnly = ctx.isReturnSubCode && cond1 && !cond2;
        ctx.showMrcDupBanner = ctx.isReturnSubCode && cond1;
        ctx.showHandlingRadioOnNotReceived = false;
        ctx.rl05Scenario = null;

        if (ctx.isPhotoSubCode) {
            ctx.hideMrcInfoLwc = true;
            ctx.showDeliveryForm = true;
            ctx.showCustomerConfirmation = false;
            return ctx;
        }

        if (ctx.isReturnSubCode) {
            ctx.hideMrcInfoLwc = true;
            ctx.processingFlow = resolveProcessingFlow(mrcStatusId, contractStatus);
            applyRoutingFlags(ctx);

            if (FLOW_NOT_ELIGIBLE.equals(ctx.processingFlow)) {
                ctx.showDeliveryForm = false;
                ctx.showCustomerConfirmation = false;
                ctx.showMrcDupBanner = cond1;
                return ctx;
            }

            // TH1/TH3: Cond2 → Xác nhận KH; TH2/TH4: không hiện combobox.
            ctx.showCustomerConfirmation = cond2;
            String conf = customerConfirmation != null
                ? customerConfirmation.trim()
                : null;

            if (cond1 && cond2) {
                ctx.rl05Scenario = 'TH1';
                // Delivery sau Noti-11 + Option 2 — LWC điều khiển.
                ctx.showDeliveryForm = false;
            } else if (cond1) {
                ctx.rl05Scenario = 'TH2';
                ctx.showDeliveryForm = false;
            } else if (cond2) {
                ctx.rl05Scenario = 'TH3';
                // TH3: Chưa nhận MRC → Noti-11 radio → Option 2 → Delivery (LWC).
                ctx.showHandlingRadioOnNotReceived = true;
                ctx.showDeliveryForm = false;
            } else {
                ctx.rl05Scenario = 'TH4';
                ctx.showDeliveryForm = true;
            }
            return ctx;
        }

        return ctx;
    }

    public static String resolveProcessingFlow(
        String mrcStatusId,
        String contractStatus
    ) {
        String statusId = normalizeCode(mrcStatusId);
        String contract = normalizeCode(contractStatus);

        if (String.isBlank(statusId)) {
            return null;
        }
        if (MRC_STATUS_NOT_ELIGIBLE.contains(statusId)) {
            return FLOW_NOT_ELIGIBLE;
        }
        if (MRC_STATUS_CP_ALWAYS.contains(statusId)) {
            return FLOW_CP_SUPPORT;
        }
        if (MRC_STATUS_MIXED.contains(statusId)) {
            if (CONTRACT_CLOSED.contains(contract)) {
                return FLOW_CP_SUPPORT;
            }
            return FLOW_PAYMENT_SUPPORT;
        }
        return null;
    }

    public static Boolean meetsCondition2(String mrcStatusId) {
        return MRC_STATUS_CONDITION_2.contains(normalizeCode(mrcStatusId));
    }

    public static Boolean isPhotoSubCode(String subCodeUpper) {
        if (String.isBlank(subCodeUpper)) {
            return false;
        }
        return subCodeUpper.contains('RL05.01') || subCodeUpper.contains('RL05.03');
    }

    public static Boolean isReturnSubCode(String subCodeUpper) {
        return String.isNotBlank(subCodeUpper) && subCodeUpper.contains('RL05.02');
    }

    public static Boolean isRl05Branch(String subCategoryCode, String subCodeCode) {
        if (String.isNotBlank(subCategoryCode) &&
            subCategoryCode.toUpperCase().contains('RL05')) {
            return true;
        }
        return String.isNotBlank(subCodeCode) &&
            subCodeCode.toUpperCase().contains('RL05');
    }

    /**
     * Stage 1 RL05: ẩn Assessment Type; Customer Confirmation chỉ khi context cho phép.
     */
    public static Boolean shouldSkipStage1Field(
        String businessProcessCode,
        String subCategoryCode,
        String subCodeCode,
        String stageName,
        String fieldApiName,
        MrcRl05UiContext ctx
    ) {
        if (String.isBlank(fieldApiName) || String.isBlank(stageName)) {
            return false;
        }
        if (!stageName.contains(FEC_ConstantCommon.STAGE_ONE)) {
            return false;
        }

        Boolean isMrcReturnProcess =
            String.isNotBlank(businessProcessCode) &&
            MRC_RETURN.equalsIgnoreCase(businessProcessCode.trim());
        if (!isMrcReturnProcess && !isRl05Branch(subCategoryCode, subCodeCode)) {
            return false;
        }

        if (STAGE1_HIDDEN_ASSESSMENT.contains(fieldApiName)) {
            return true;
        }

        if ('FEC_Customer_Confirmation__c'.equals(fieldApiName)) {
            if (ctx != null && ctx.showCustomerConfirmation == true) {
                return false;
            }
            return true;
        }

        // RL05.02: không hiện picklist — dùng radio Noti-11 (fec_MrcReturnDupBanner).
        if ('FEC_MRC_Request_Handling_Option__c'.equals(fieldApiName)) {
            return ctx != null && ctx.isReturnSubCode == true;
        }

        return false;
    }

    /** @deprecated — giữ chữ ký cũ; gọi shouldSkipStage1Field(..., null). */
    public static Boolean shouldSkipStage1Field(
        String businessProcessCode,
        String subCategoryCode,
        String stageName,
        String fieldApiName
    ) {
        return shouldSkipStage1Field(
            businessProcessCode,
            subCategoryCode,
            null,
            stageName,
            fieldApiName,
            null
        );
    }

    public static Boolean shouldSkipMasterDataRow(
        String sectionName,
        String subSectionName,
        String lwcName,
        String fieldApiName,
        MrcRl05UiContext ctx
    ) {
        if (ctx == null || ctx.isRl05Branch != true) {
            return false;
        }
        if (TYPE_LWC.equals(getRowType(lwcName, fieldApiName)) &&
            'fec_MRC'.equalsIgnoreCase(lwcName) &&
            ctx.hideMrcInfoLwc == true) {
            return true;
        }
        if (TYPE_LWC.equals(getRowType(lwcName, fieldApiName)) &&
            'fec_ContractClosureForm'.equalsIgnoreCase(lwcName) &&
            needsDeliveryLwc(ctx)) {
            return true;
        }
        return false;
    }

    public static Boolean needsDeliveryLwc(MrcRl05UiContext ctx) {
        return ctx != null && ctx.showDeliveryForm == true;
    }

    public static final String RL05_CASE_INFO_SUBSECTION = 'MRC Return';

    /**
     * Sau master data: ẩn subsection/field RL05, inject Customer Confirmation & Handling Option
     * khi chưa có trong FEC_Master_Data_Setting__c.
     */
    /**
     * Không có Case Stage (MRC Return): vẫn dựng Case Information + fec_ContractClosureForm.
     * RL05.01 và RL05.03 dùng chung luồng photo; RL05.03 thêm Email trên LWC.
     */
    public static void supplementMrcRl05CaseInformationWhenStageMissing(
        FEC_CaseBusinessService.Business result,
        Case selectedCase
    ) {
        if (result == null || selectedCase == null) {
            return;
        }
        String subCat = result.subCategoryCode;
        String subCode = result.subCodeCode;
        if (!isRl05Branch(subCat, subCode)) {
            return;
        }

        MrcRl05UiContext ctx = buildUiContext(
            selectedCase,
            subCat,
            subCode,
            selectedCase.FEC_Customer_Confirmation__c,
            false
        );
        result.mrcRl05Ui = ctx;

        FEC_CaseBusinessService.Section caseInfo = result.findSection(
            'Case Information'
        );
        if (caseInfo == null) {
            caseInfo = new FEC_CaseBusinessService.Section('Case Information');
            result.sectionlst.add(caseInfo);
        }

        finalizeCaseInformationForRl05(result, ctx, selectedCase);
        ensureDeliveryLwcOnCaseInformation(result, ctx);
    }

    public static void finalizeCaseInformationForRl05(
        FEC_CaseBusinessService.Business result,
        MrcRl05UiContext ctx,
        Case selectedCase
    ) {
        if (ctx == null || ctx.isRl05Branch != true || result == null) {
            return;
        }
        FEC_CaseBusinessService.Section caseInfo = result.findSection(
            'Case Information'
        );
        if (caseInfo == null) {
            caseInfo = new FEC_CaseBusinessService.Section('Case Information');
            result.sectionlst.add(caseInfo);
        }

        applyRl05SubSectionVisibility(caseInfo, ctx);

        if (ctx.isReturnSubCode != true) {
            caseInfo.sort();
            return;
        }

        mergeInjectedPicklistOptions(result);

        if (ctx.showCustomerConfirmation == true) {
            injectCaseInformationField(
                caseInfo,
                selectedCase,
                'FEC_Customer_Confirmation__c',
                10,
                true,
                false
            );
        }
        if (ctx.showMrcDupBanner == true) {
            injectCaseInformationField(
                caseInfo,
                selectedCase,
                'FEC_MRC_Request_Handling_Option__c',
                20,
                false,
                true
            );
        }

        caseInfo.sort();
    }

    private static void applyRl05SubSectionVisibility(
        FEC_CaseBusinessService.Section caseInfo,
        MrcRl05UiContext ctx
    ) {
        for (FEC_CaseBusinessService.Section sub : caseInfo.subSectionlst) {
            if (sub.objlst == null) {
                continue;
            }
            for (FEC_CaseBusinessService.CObject obj : sub.objlst) {
                if (obj.fieldlst == null) {
                    continue;
                }
                for (Integer i = obj.fieldlst.size() - 1; i >= 0; i--) {
                    if (
                        STAGE1_HIDDEN_ASSESSMENT.contains(
                            obj.fieldlst[i].apiName
                        )
                    ) {
                        obj.fieldlst.remove(i);
                    }
                }
            }
        }
    }

    private static void injectCaseInformationField(
        FEC_CaseBusinessService.Section caseInfo,
        Case selectedCase,
        String fieldApiName,
        Decimal displayOrder,
        Boolean mandatory,
        Boolean forceHidden
    ) {
        if (selectedCase == null || String.isBlank(fieldApiName)) {
            return;
        }

        FEC_CaseBusinessService.Section sub = caseInfo.findSubSection(
            RL05_CASE_INFO_SUBSECTION
        );
        if (sub == null) {
            sub = new FEC_CaseBusinessService.Section(
                RL05_CASE_INFO_SUBSECTION,
                0,
                12
            );
            caseInfo.subSectionlst.add(sub);
        }

        FEC_CaseBusinessService.CObject caseObj = sub.findObj('Case');
        if (caseObj == null) {
            caseObj = new FEC_CaseBusinessService.CObject('Case');
            caseObj.id = selectedCase.Id;
            sub.objlst.add(caseObj);
        }
        if (caseObj.findField(fieldApiName) != null) {
            return;
        }

        Schema.DescribeFieldResult dfr = Schema.SObjectType.Case.fields.getMap()
            .get(fieldApiName)
            ?.getDescribe();
        if (dfr == null) {
            return;
        }

        String rawVal = (String) selectedCase.get(fieldApiName);
        FEC_CaseBusinessService.Field injected = new FEC_CaseBusinessService.Field(
            fieldApiName,
            dfr.getLabel(),
            rawVal,
            false,
            true,
            mandatory,
            displayOrder,
            false,
            dfr.getInlineHelpText(),
            12,
            null
        );
        if (forceHidden) {
            injected.hidden = true;
        }
        caseObj.fieldlst.add(injected);
    }

    private static void mergeInjectedPicklistOptions(
        FEC_CaseBusinessService.Business result
    ) {
        if (result.picklistOptionsMap == null) {
            result.picklistOptionsMap = new Map<String, Map<String, List<FEC_CaseBusinessService.PicklistOptionDto>>>();
        }
        if (!result.picklistOptionsMap.containsKey('Case')) {
            result.picklistOptionsMap.put(
                'Case',
                new Map<String, List<FEC_CaseBusinessService.PicklistOptionDto>>()
            );
        }
        Map<String, List<FEC_CaseBusinessService.PicklistOptionDto>> caseOpts = result.picklistOptionsMap.get(
            'Case'
        );
        for (String apiName : new List<String>{
            'FEC_Customer_Confirmation__c',
            'FEC_MRC_Request_Handling_Option__c'
        }) {
            if (caseOpts.containsKey(apiName)) {
                continue;
            }
            Schema.DescribeFieldResult dfr = Schema.SObjectType.Case.fields.getMap()
                .get(apiName)
                ?.getDescribe();
            if (dfr == null) {
                continue;
            }
            List<FEC_CaseBusinessService.PicklistOptionDto> opts = new List<FEC_CaseBusinessService.PicklistOptionDto>();
            for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
                if (entry.isActive()) {
                    opts.add(
                        new FEC_CaseBusinessService.PicklistOptionDto(
                            entry.getValue(),
                            entry.getLabel(),
                            entry.isDefaultValue()
                        )
                    );
                }
            }
            caseOpts.put(apiName, opts);
        }
    }

    public static void ensureDeliveryLwcOnCaseInformation(
        FEC_CaseBusinessService.Business result,
        MrcRl05UiContext ctx
    ) {
        if (result == null) {
            return;
        }
        Boolean needDelivery = needsDeliveryLwc(ctx);
        if (
            !needDelivery &&
            isPhotoSubCode(normalizeCode(result.subCodeCode))
        ) {
            needDelivery = true;
        }
        if (!needDelivery) {
            return;
        }
        FEC_CaseBusinessService.Section caseInfo = result.findSection(
            'Case Information'
        );
        if (caseInfo == null) {
            caseInfo = new FEC_CaseBusinessService.Section('Case Information');
            result.sectionlst.add(caseInfo);
        }
        for (FEC_CaseBusinessService.DynamicLwcComponent slot : caseInfo.componentlst) {
            if (slot != null &&
                ('fec_MrcDeliveryForm'.equalsIgnoreCase(slot.componentName) ||
                'fec_MrcReturnPanel'.equalsIgnoreCase(slot.componentName))) {
                return;
            }
        }
        FEC_CaseBusinessService.DynamicLwcComponent deliverySlot = new FEC_CaseBusinessService.DynamicLwcComponent();
        deliverySlot.componentName = 'fec_MrcReturnPanel';
        deliverySlot.order = 1;
        deliverySlot.fieldLayout = 12;
        deliverySlot.subSectionName = null;
        deliverySlot.fecMasterDataSettingIsEdit = true;
        caseInfo.componentlst.add(deliverySlot);
    }

    private static void applyRoutingFlags(MrcRl05UiContext ctx) {
        ctx.autoRouteReject = FLOW_NOT_ELIGIBLE.equals(ctx.processingFlow);
        ctx.autoRoutePayment = FLOW_PAYMENT_SUPPORT.equals(ctx.processingFlow);
        ctx.autoRouteCp = FLOW_CP_SUPPORT.equals(ctx.processingFlow);
    }

    private static String normalizeCode(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        return raw.trim().toUpperCase();
    }

    private static String getRowType(String lwcName, String fieldApiName) {
        if (String.isNotBlank(lwcName)) {
            return 'LWC';
        }
        if (String.isNotBlank(fieldApiName)) {
            return 'Field';
        }
        return null;
    }

    private static final String TYPE_LWC = 'LWC';
}