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
        'FEC_Contract_Processing_Assessment_Type__c',
        'FEC_RD_Payment_Contract_Assessment__c'
    };

    private static final String SUBSECTION_PROPERTY_INFO = 'Property Info';
    private static final String OBJ_ADDITIONAL_INFO = 'FEC_Additional_Info__c';
    private static final List<String> RL0502_PROPERTY_FIELD_APIS = new List<String>{
        'FEC_Verify_Information__c',
        'FEC_Callback__c'
    };

    /** CN / CC / TLCN — mọi Contract Status → Reject (Chưa đủ điều kiện hỗ trợ). */
    private static final Set<String> MRC_STATUS_NOT_ELIGIBLE = new Set<String>{
        'CN',
        'CC',
        'TLCN'
    };

    private static final Set<String> MRC_STATUS_CP_ALWAYS = new Set<String>{
        'TLCCDTKH',
        'TLDN',
        'TLNB',
        'HT',
        'DTMRC_CTLHD'
    };

    /** LK, THDB, MN, … — Payment khi ACTIVE/CHARGE-OFF/N/A; CP khi CLOSED. */
    private static final Set<String> MRC_STATUS_MIXED = new Set<String>{
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
        /** Nhãn field Case (theo locale user) cho MRC UI. */
        @AuraEnabled
        public Map<String, String> caseFieldLabels;
    }

    public static MrcRl05UiContext buildUiContext(
        Case selectedCase,
        String subCategoryCode,
        String subCodeCode,
        String customerConfirmation,
        Boolean hasDupOpenCase
    ) {
        MrcRl05UiContext ctx = new MrcRl05UiContext();
        String resolvedSubCategoryCode = resolveSubCategoryCode(
            subCategoryCode,
            selectedCase,
            null
        );
        String resolvedSubCodeCode = resolveSubCodeCode(
            subCodeCode,
            selectedCase,
            null
        );
        ctx.isRl05Branch = isRl05Branch(resolvedSubCategoryCode, resolvedSubCodeCode);
        if (!ctx.isRl05Branch) {
            return ctx;
        }

        String subUpper = normalizeCode(resolvedSubCodeCode);
        ctx.isPhotoSubCode = isPhotoSubCode(subUpper);
        ctx.isReturnSubCode = isReturnSubCode(subUpper);
        // RL05: ẩn LWC fec_MRC (Original/Notarized MRC API). RL05.02 dùng subsection Property Info trên master data.
        ctx.hideMrcInfoLwc = true;
        ctx.hidePropertyInfo = false;

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
            ctx.showDeliveryForm = true;
            ctx.showCustomerConfirmation = false;
            return ctx;
        }

        if (ctx.isReturnSubCode) {
            ctx.processingFlow = resolveProcessingFlow(mrcStatusId, contractStatus);
            applyRoutingFlags(ctx);

            if (FLOW_NOT_ELIGIBLE.equals(ctx.processingFlow)) {
                ctx.showDeliveryForm = false;
                ctx.showCustomerConfirmation = false;
                ctx.showMrcDupBanner = cond1;
                return ctx;
            }

            // RL05.02: Xác nhận KH — luôn hiển thị trừ NOT_ELIGIBLE (CN/CC).
            ctx.showCustomerConfirmation =
                !FLOW_NOT_ELIGIBLE.equals(ctx.processingFlow);
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

    /**
     * Ma trận RL05.02 — MRC Status × Contract Status → luồng xử lý (design Batch 7).
     * ACTIVE/CHARGE-OFF: Group B → Payment, Group C → CP.
     * CLOSED: Group B/C → CP.
     * N/A (contract): Group B/C → Payment.
     */
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

        Boolean inGroupC = MRC_STATUS_CP_ALWAYS.contains(statusId);
        Boolean inGroupB = MRC_STATUS_MIXED.contains(statusId);
        if (!inGroupC && !inGroupB) {
            return null;
        }

        if (CONTRACT_CLOSED.contains(contract)) {
            return FLOW_CP_SUPPORT;
        }
        if (String.isBlank(contract) || 'N/A'.equals(contract)) {
            return FLOW_PAYMENT_SUPPORT;
        }
        if (inGroupC) {
            return FLOW_CP_SUPPORT;
        }
        return FLOW_PAYMENT_SUPPORT;
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

    public static String inferSubCodeFromStageName(String stageName) {
        if (String.isBlank(stageName)) {
            return null;
        }
        String upper = stageName.trim().toUpperCase();
        if (upper.contains('RL05.02')) {
            return 'RL05.02';
        }
        if (upper.contains('RL05.03')) {
            return 'RL05.03';
        }
        if (upper.contains('RL05.01')) {
            return 'RL05.01';
        }
        if (upper.contains('RL05')) {
            return 'RL05';
        }
        return null;
    }

    public static String inferSubCategoryFromStageName(String stageName) {
        if (String.isBlank(stageName)) {
            return null;
        }
        String upper = stageName.trim().toUpperCase();
        return upper.contains('RL05') ? 'RL05' : null;
    }

    public static String resolveSubCodeCode(
        String subCodeCode,
        Case selectedCase,
        String stageName
    ) {
        if (String.isNotBlank(subCodeCode)) {
            return subCodeCode.trim();
        }
        if (selectedCase?.FEC_SubCode__r != null &&
            String.isNotBlank(selectedCase.FEC_SubCode__r.FEC_Code__c)) {
            return selectedCase.FEC_SubCode__r.FEC_Code__c.trim();
        }
        if (String.isNotBlank(stageName)) {
            return inferSubCodeFromStageName(stageName);
        }
        if (selectedCase?.FEC_Current_Case_Stage__r != null &&
            String.isNotBlank(selectedCase.FEC_Current_Case_Stage__r.Name)) {
            return inferSubCodeFromStageName(
                selectedCase.FEC_Current_Case_Stage__r.Name
            );
        }
        return null;
    }

    public static String resolveSubCategoryCode(
        String subCategoryCode,
        Case selectedCase,
        String stageName
    ) {
        if (String.isNotBlank(subCategoryCode)) {
            return subCategoryCode.trim();
        }
        if (selectedCase?.FEC_SubCategory__r != null &&
            String.isNotBlank(selectedCase.FEC_SubCategory__r.FEC_Code__c)) {
            return selectedCase.FEC_SubCategory__r.FEC_Code__c.trim();
        }
        if (String.isNotBlank(stageName)) {
            return inferSubCategoryFromStageName(stageName);
        }
        if (selectedCase?.FEC_Current_Case_Stage__r != null &&
            String.isNotBlank(selectedCase.FEC_Current_Case_Stage__r.Name)) {
            return inferSubCategoryFromStageName(
                selectedCase.FEC_Current_Case_Stage__r.Name
            );
        }
        return null;
    }

    public static void applyRl05CodeFallbacks(
        FEC_CaseBusinessService.Business result,
        Case selectedCase,
        String stageName
    ) {
        if (result == null) {
            return;
        }
        String subCode = resolveSubCodeCode(
            result.subCodeCode,
            selectedCase,
            stageName
        );
        if (String.isNotBlank(subCode)) {
            result.subCodeCode = subCode;
        }
        String subCat = resolveSubCategoryCode(
            result.subCategoryCode,
            selectedCase,
            stageName
        );
        if (String.isNotBlank(subCat)) {
            result.subCategoryCode = subCat;
        }
    }

    /**
     * RL05 / MRC Return: ẩn Assessment trên master data chỉ Stage 1 trước Submit;
     * Xác nhận KH & Handling Option do fec_MrcReturnPanel quản lý (RL05.02 mọi stage sau Submit).
     */
    public static Boolean shouldSkipStage1Field(
        String businessProcessCode,
        String subCategoryCode,
        String subCodeCode,
        String stageName,
        String fieldApiName,
        MrcRl05UiContext ctx,
        Case selectedCase
    ) {
        if (String.isBlank(fieldApiName) || String.isBlank(stageName)) {
            return false;
        }

        Boolean isMrcReturnProcess =
            String.isNotBlank(businessProcessCode) &&
            MRC_RETURN.equalsIgnoreCase(businessProcessCode.trim());
        if (!isMrcReturnProcess && !isRl05Branch(subCategoryCode, subCodeCode)) {
            return false;
        }

        Boolean onStage1 = stageName.contains(FEC_ConstantCommon.STAGE_ONE);

        if (shouldHideAssessmentBeforeSubmit(stageName, selectedCase, fieldApiName)) {
            return true;
        }

        if ('FEC_Customer_Confirmation__c'.equals(fieldApiName)) {
            // RL05.02: panel fec_MrcReturnPanel quản lý — không render trên master data (Stage 1+).
            if (ctx != null && ctx.isReturnSubCode == true) {
                return true;
            }
            if (!onStage1) {
                return false;
            }
            return ctx == null || ctx.showCustomerConfirmation != true;
        }

        // RL05.02: không hiện picklist — dùng radio Noti-11 (fec_MrcReturnDupBanner).
        if ('FEC_MRC_Request_Handling_Option__c'.equals(fieldApiName)) {
            return ctx != null && ctx.isReturnSubCode == true;
        }

        return false;
    }

    /** @deprecated — giữ chữ ký cũ; gọi shouldSkipStage1Field(..., null, null). */
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
            null,
            null
        );
    }

    private static Boolean shouldHideAssessmentBeforeSubmit(
        String stageName,
        Case selectedCase,
        String fieldApiName
    ) {
        if (String.isBlank(fieldApiName) || String.isBlank(stageName)) {
            return false;
        }
        if (!stageName.contains(FEC_ConstantCommon.STAGE_ONE)) {
            return false;
        }
        if (selectedCase != null && selectedCase.FEC_Is_Submited__c == true) {
            return false;
        }
        return STAGE1_HIDDEN_ASSESSMENT.contains(fieldApiName);
    }

    public static Boolean shouldSkipMasterDataRow(
        String sectionName,
        String subSectionName,
        String lwcName,
        String fieldApiName,
        MrcRl05UiContext ctx
    ) {
        return shouldSkipMasterDataRow(
            sectionName,
            subSectionName,
            lwcName,
            fieldApiName,
            ctx,
            null
        );
    }

    public static Boolean shouldSkipMasterDataRow(
        String sectionName,
        String subSectionName,
        String lwcName,
        String fieldApiName,
        MrcRl05UiContext ctx,
        Case selectedCase
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
            'fec_MrcDeliveryForm'.equalsIgnoreCase(lwcName) &&
            shouldHideMrcDeliveryLwc(ctx, selectedCase)) {
            return true;
        }
        if (TYPE_LWC.equals(getRowType(lwcName, fieldApiName)) &&
            'fec_ContractClosureForm'.equalsIgnoreCase(lwcName) &&
            needsDeliveryLwc(ctx)) {
            return true;
        }
        if (String.isNotBlank(subSectionName) &&
            subSectionName.toLowerCase().contains('rd payment')) {
            return true;
        }
        return false;
    }

    public static Boolean needsDeliveryLwc(MrcRl05UiContext ctx) {
        return ctx != null && ctx.showDeliveryForm == true;
    }

    /** RL05.02: Đã xác nhận MRC → không hiện fec_MrcDeliveryForm trên MDM (trừ khi Case đã lưu Delivery). */
    public static Boolean shouldHideMrcDeliveryLwc(
        MrcRl05UiContext ctx,
        Case selectedCase
    ) {
        if (ctx == null || ctx.isRl05Branch != true) {
            return true;
        }
        if (ctx.isReturnSubCode == true) {
            if (selectedCase != null &&
                isCustomerReceivedMrcConfirmation(
                    selectedCase.FEC_Customer_Confirmation__c
                )) {
                return String.isBlank(selectedCase.FEC_Delivery_Option_2__c);
            }
            if (ctx.showDeliveryForm != true) {
                return true;
            }
            return false;
        }
        return !needsDeliveryLwc(ctx);
    }

    public static Boolean isCustomerReceivedMrcConfirmation(String conf) {
        if (String.isBlank(conf)) {
            return false;
        }
        String normalized = conf.trim().toLowerCase();
        if (normalized.contains('not received') ||
            normalized.contains('chưa nhận') ||
            normalized.contains('chưa xác nhận')) {
            return false;
        }
        return normalized == CONF_RECEIVED.toLowerCase() ||
            (normalized.contains('received') &&
            !normalized.contains('not received')) ||
            normalized.contains('đã nhận') ||
            normalized.contains('đã xác nhận');
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
        applyRl05CodeFallbacks(
            result,
            selectedCase,
            selectedCase?.FEC_Current_Case_Stage__r?.Name
        );
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

        applyRl05SubSectionVisibility(caseInfo, ctx, result.stageName, selectedCase);
        mergeInjectedPicklistOptions(result, ctx);

        if (ctx.isReturnSubCode != true) {
            ensureDeliveryLwcOnCaseInformation(result, ctx);
            caseInfo.sort();
            return;
        }

        // RL05.02: Property Info (Additional Info) — giữ trên mọi stage sau Submit (MDM stage 2+ thường không có subsection này).
        ensurePropertyInfoForRl0502(caseInfo, selectedCase, result);
        ensureRl0502PropertyPicklistOptions(result);
        hydratePropertyInfoFromFlowHistory(caseInfo, selectedCase.Id, result);
        // RL05.02: Xác nhận KH + Noti-11 + Delivery — chỉ fec_MrcReturnPanel (mọi stage, kể cả Review).
        ensureDeliveryLwcOnCaseInformation(result, ctx);
        caseInfo.sort();
    }

    /**
     * RL05.02: bổ sung subsection Property Info khi master data stage hiện tại không khai
     * FEC_Verify_Information__c / FEC_Callback__c (thường chỉ có ở Stage 1).
     */
    private static void ensurePropertyInfoForRl0502(
        FEC_CaseBusinessService.Section caseInfo,
        Case selectedCase,
        FEC_CaseBusinessService.Business result
    ) {
        if (caseInfo == null || selectedCase == null) {
            return;
        }

        FEC_CaseBusinessService.Section propSub = caseInfo.findSubSection(
            SUBSECTION_PROPERTY_INFO
        );
        if (propSub == null) {
            propSub = new FEC_CaseBusinessService.Section(
                SUBSECTION_PROPERTY_INFO,
                90,
                12
            );
            caseInfo.subSectionlst.add(propSub);
        }
        propSub.hideForMrcRl05 = false;

        FEC_Additional_Info__c aiRec = selectedCase.Id != null
            ? loadAdditionalInfoForCase(selectedCase.Id)
            : null;
        Decimal order = 1;
        for (String fieldApi : RL0502_PROPERTY_FIELD_APIS) {
            injectAdditionalInfoPropertyField(
                propSub,
                aiRec,
                fieldApi,
                order++,
                true,
                result
            );
        }
    }

    private static FEC_Additional_Info__c loadAdditionalInfoForCase(Id caseId) {
        if (caseId == null || !Schema.sObjectType.FEC_Additional_Info__c.isAccessible()) {
            return null;
        }
        List<FEC_Additional_Info__c> rows = [
            SELECT
                Id,
                FEC_Verify_Information__c,
                FEC_Callback__c
            FROM FEC_Additional_Info__c
            WHERE FEC_Case__c = :caseId
            WITH USER_MODE
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static void injectAdditionalInfoPropertyField(
        FEC_CaseBusinessService.Section propSub,
        FEC_Additional_Info__c aiRec,
        String fieldApiName,
        Decimal displayOrder,
        Boolean mandatory,
        FEC_CaseBusinessService.Business result
    ) {
        if (propSub == null || String.isBlank(fieldApiName)) {
            return;
        }

        FEC_CaseBusinessService.CObject aiObj = propSub.findObj(OBJ_ADDITIONAL_INFO);
        if (aiObj == null) {
            aiObj = new FEC_CaseBusinessService.CObject(OBJ_ADDITIONAL_INFO);
            propSub.objlst.add(aiObj);
        }
        if (aiRec != null && String.isBlank(aiObj.id)) {
            aiObj.id = aiRec.Id;
        }

        String rawVal = aiRec == null ? null : (String) aiRec.get(fieldApiName);
        Map<String, Map<String, List<FEC_CaseBusinessService.PicklistOptionDto>>> pickMap =
            result != null ? result.picklistOptionsMap : null;
        FEC_CaseBusinessService.Field existing = aiObj.findField(fieldApiName);
        if (existing != null) {
            if (String.isNotBlank(rawVal)) {
                existing.value = resolvePropertyPicklistStoredValue(
                    fieldApiName,
                    rawVal,
                    pickMap
                );
            }
            existing.hidden = false;
            return;
        }

        Schema.DescribeFieldResult dfr = Schema.SObjectType.FEC_Additional_Info__c.fields.getMap()
            .get(fieldApiName)
            ?.getDescribe();
        if (dfr == null) {
            return;
        }

        String resolvedVal = String.isNotBlank(rawVal)
            ? resolvePropertyPicklistStoredValue(fieldApiName, rawVal, pickMap)
            : rawVal;
        FEC_CaseBusinessService.Field injected = new FEC_CaseBusinessService.Field(
            fieldApiName,
            dfr.getLabel(),
            resolvedVal,
            false,
            true,
            mandatory,
            displayOrder,
            false,
            dfr.getInlineHelpText(),
            12,
            null
        );
        injected.hidden = false;
        aiObj.fieldlst.add(injected);
    }

    /**
     * Submit lưu Property Info vào FEC_Case_Flow_History__c (fieldListJson);
     * Additional_Info__c có thể vẫn null — đọc lại từ history để hiển thị Review.
     */
    private static void hydratePropertyInfoFromFlowHistory(
        FEC_CaseBusinessService.Section caseInfo,
        Id caseId,
        FEC_CaseBusinessService.Business result
    ) {
        if (caseInfo == null || caseId == null) {
            return;
        }
        FEC_CaseBusinessService.Section propSub = caseInfo.findSubSection(
            SUBSECTION_PROPERTY_INFO
        );
        if (propSub == null) {
            return;
        }
        FEC_CaseBusinessService.CObject aiObj = propSub.findObj(OBJ_ADDITIONAL_INFO);
        if (aiObj == null || aiObj.fieldlst == null || aiObj.fieldlst.isEmpty()) {
            return;
        }

        Map<String, String> fromHistory = parsePropertyFieldsFromFlowHistory(caseId);
        if (fromHistory.isEmpty()) {
            return;
        }

        Map<String, Map<String, List<FEC_CaseBusinessService.PicklistOptionDto>>> pickMap = result != null
            ? result.picklistOptionsMap
            : null;

        for (FEC_CaseBusinessService.Field field : aiObj.fieldlst) {
            if (
                field == null ||
                String.isBlank(field.apiName) ||
                !RL0502_PROPERTY_FIELD_APIS.contains(field.apiName)
            ) {
                continue;
            }
            if (String.isNotBlank(field.value)) {
                continue;
            }
            String raw = fromHistory.get(field.apiName);
            if (String.isBlank(raw)) {
                continue;
            }
            field.value = resolvePropertyPicklistStoredValue(
                field.apiName,
                raw,
                pickMap
            );
        }
    }

    private static Map<String, String> parsePropertyFieldsFromFlowHistory(Id caseId) {
        Map<String, String> out = new Map<String, String>();
        if (caseId == null) {
            return out;
        }
        List<FEC_Case_Flow_History__c> historyList = [
            SELECT FEC_Field_List__c
            FROM FEC_Case_Flow_History__c
            WHERE FEC_Case__c = :caseId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        String jsonBody = null;
        for (FEC_Case_Flow_History__c row : historyList) {
            if (String.isNotBlank(row.FEC_Field_List__c)) {
                jsonBody = row.FEC_Field_List__c;
                break;
            }
        }
        if (String.isBlank(jsonBody)) {
            return out;
        }
        try {
            Object parsed = JSON.deserializeUntyped(jsonBody);
            if (!(parsed instanceof List<Object>)) {
                return out;
            }
            for (Object item : (List<Object>) parsed) {
                if (!(item instanceof Map<String, Object>)) {
                    continue;
                }
                Map<String, Object> entry = (Map<String, Object>) item;
                String apiName = entry.containsKey('apiName')
                    ? String.valueOf(entry.get('apiName'))
                    : null;
                String value = entry.containsKey('value')
                    ? String.valueOf(entry.get('value'))
                    : null;
                if (
                    String.isBlank(apiName) ||
                    !RL0502_PROPERTY_FIELD_APIS.contains(apiName) ||
                    'null'.equalsIgnoreCase(value)
                ) {
                    continue;
                }
                if (!out.containsKey(apiName)) {
                    out.put(apiName, value.trim());
                }
            }
        } catch (Exception ex) {
            System.debug(
                LoggingLevel.WARN,
                'hydratePropertyInfoFromFlowHistory parse failed: ' + ex.getMessage()
            );
        }
        return out;
    }

    private static String resolvePropertyPicklistStoredValue(
        String fieldApiName,
        String rawFromHistory,
        Map<String, Map<String, List<FEC_CaseBusinessService.PicklistOptionDto>>> pickMap
    ) {
        if (String.isBlank(rawFromHistory)) {
            return rawFromHistory;
        }
        String raw = rawFromHistory.trim();
        if (pickMap == null || !pickMap.containsKey(OBJ_ADDITIONAL_INFO)) {
            return raw;
        }
        Map<String, List<FEC_CaseBusinessService.PicklistOptionDto>> objOpts = pickMap.get(
            OBJ_ADDITIONAL_INFO
        );
        if (objOpts == null || !objOpts.containsKey(fieldApiName)) {
            return raw;
        }
        for (FEC_CaseBusinessService.PicklistOptionDto opt : objOpts.get(fieldApiName)) {
            if (opt == null) {
                continue;
            }
            if (raw == opt.value || raw == opt.label) {
                return opt.value;
            }
        }
        return raw;
    }

    private static void ensureRl0502PropertyPicklistOptions(
        FEC_CaseBusinessService.Business result
    ) {
        if (result == null) {
            return;
        }
        if (result.picklistOptionsMap == null) {
            result.picklistOptionsMap = new Map<String, Map<String, List<FEC_CaseBusinessService.PicklistOptionDto>>>();
        }
        if (!result.picklistOptionsMap.containsKey(OBJ_ADDITIONAL_INFO)) {
            result.picklistOptionsMap.put(
                OBJ_ADDITIONAL_INFO,
                new Map<String, List<FEC_CaseBusinessService.PicklistOptionDto>>()
            );
        }
        Map<String, List<FEC_CaseBusinessService.PicklistOptionDto>> aiOpts = result.picklistOptionsMap.get(
            OBJ_ADDITIONAL_INFO
        );
        for (String apiName : RL0502_PROPERTY_FIELD_APIS) {
            if (aiOpts.containsKey(apiName)) {
                continue;
            }
            Schema.DescribeFieldResult dfr = Schema.SObjectType.FEC_Additional_Info__c.fields.getMap()
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
            aiOpts.put(apiName, opts);
        }
    }

    private static void applyRl05SubSectionVisibility(
        FEC_CaseBusinessService.Section caseInfo,
        MrcRl05UiContext ctx,
        String stageName,
        Case selectedCase
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
                    String apiName = obj.fieldlst[i].apiName;
                    if (
                        shouldHideAssessmentBeforeSubmit(
                            stageName,
                            selectedCase,
                            apiName
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
        String rawVal = (String) selectedCase.get(fieldApiName);
        FEC_CaseBusinessService.Field existing = caseObj.findField(fieldApiName);
        if (existing != null) {
            if (String.isNotBlank(rawVal)) {
                existing.value = rawVal;
            }
            if (forceHidden) {
                existing.hidden = true;
            }
            return;
        }

        Schema.DescribeFieldResult dfr = Schema.SObjectType.Case.fields.getMap()
            .get(fieldApiName)
            ?.getDescribe();
        if (dfr == null) {
            return;
        }

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

    public static void enrichRl05PicklistOptions(
        FEC_CaseBusinessService.Business result,
        MrcRl05UiContext ctx
    ) {
        mergeInjectedPicklistOptions(result, ctx);
    }

    private static void mergeInjectedPicklistOptions(
        FEC_CaseBusinessService.Business result,
        MrcRl05UiContext ctx
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
        if (ctx != null && ctx.caseFieldLabels == null) {
            ctx.caseFieldLabels = new Map<String, String>();
        }
        for (String apiName : new List<String>{
            'FEC_Customer_Confirmation__c',
            'FEC_MRC_Request_Handling_Option__c'
        }) {
            Schema.DescribeFieldResult dfr = Schema.SObjectType.Case.fields.getMap()
                .get(apiName)
                ?.getDescribe();
            if (dfr == null) {
                continue;
            }
            if (ctx != null) {
                ctx.caseFieldLabels.put(apiName, dfr.getLabel());
            }
            if (caseOpts.containsKey(apiName)) {
                continue;
            }
            List<FEC_CaseBusinessService.PicklistOptionDto> opts = new List<FEC_CaseBusinessService.PicklistOptionDto>();
            if ('FEC_Customer_Confirmation__c'.equals(apiName)) {
                opts.add(
                    new FEC_CaseBusinessService.PicklistOptionDto(
                        CONF_NOT_RECEIVED,
                        'Khách hàng chưa xác nhận MRC',
                        false
                    )
                );
                opts.add(
                    new FEC_CaseBusinessService.PicklistOptionDto(
                        CONF_RECEIVED,
                        'Khách hàng đã xác nhận MRC',
                        false
                    )
                );
                caseOpts.put(apiName, opts);
                continue;
            }
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
        if (ctx != null) {
            result.mrcRl05Ui = ctx;
        }
    }

    public static void ensureDeliveryLwcOnCaseInformation(
        FEC_CaseBusinessService.Business result,
        MrcRl05UiContext ctx
    ) {
        if (result == null) {
            return;
        }
        Boolean needPanel = false;
        if (ctx != null && ctx.isReturnSubCode == true) {
            needPanel = true;
        } else {
            Boolean needDelivery = needsDeliveryLwc(ctx);
            if (
                !needDelivery &&
                isPhotoSubCode(normalizeCode(result.subCodeCode))
            ) {
                needDelivery = true;
            }
            needPanel = needDelivery;
        }
        if (!needPanel) {
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

    /**
     * Stage 1 RL05: org chưa config FEC_Stage_Screen — fallback routing từ stage mẫu cùng nhánh.
     * RL05.01/.03 → RL05.01 Stage 1; RL05.02 → RL05.02 Stage 1, fallback RL05.01.
     */
    public static void supplementStage1RoutingActionsIfEmpty(
        FEC_CaseBusinessService.Business result,
        String stageName,
        List<String> rolelst,
        Boolean isRevert
    ) {
        if (
            result == null ||
            result.routingActionlst == null ||
            !result.routingActionlst.isEmpty() ||
            String.isBlank(stageName) ||
            !stageName.contains(FEC_ConstantCommon.STAGE_ONE) ||
            !isRl05Branch(result.subCategoryCode, result.subCodeCode)
        ) {
            return;
        }

        String subCode = normalizeCode(result.subCodeCode);
        List<String> templatePatterns = new List<String>();
        if (isPhotoSubCode(subCode)) {
            if (subCode != null && subCode.contains('RL05.03')) {
                templatePatterns.add('RL05.03%Stage 1');
            }
            templatePatterns.add('RL05.01%Stage 1');
        } else if (isReturnSubCode(subCode)) {
            templatePatterns.add('RL05.02%Stage 1');
            templatePatterns.add('RL05.01%Stage 1');
        } else {
            return;
        }

        for (String pattern : templatePatterns) {
            appendStage1RoutingActionsFromTemplate(
                result,
                pattern,
                rolelst,
                isRevert
            );
            if (!result.routingActionlst.isEmpty()) {
                return;
            }
        }
    }

    private static void appendStage1RoutingActionsFromTemplate(
        FEC_CaseBusinessService.Business result,
        String stageNamePattern,
        List<String> rolelst,
        Boolean isRevert
    ) {
        List<FEC_Case_Stage__c> templateStages = [
            SELECT Id
            FROM FEC_Case_Stage__c
            WHERE FEC_Active__c = TRUE AND Name LIKE :stageNamePattern
            LIMIT 1
        ];
        if (templateStages.isEmpty()) {
            return;
        }

        String query =
            'SELECT Id, FEC_Action_Button__c, ' +
            'FEC_Action_Button__r.Name, ' +
            'FEC_Action_Button__r.FEC_Type__c, ' +
            'FEC_Action_Button__r.FEC_Code__c, ' +
            'FEC_Custom_Action_Button_Label__c, ' +
            'FEC_Field_Type__c ' +
            'FROM FEC_Stage_Screen__c ' +
            'WHERE FEC_Action_Button__c != NULL AND FEC_Active__c = TRUE ' +
            'AND FEC_Action_Button__r.FEC_Type__c = \'Routing Action\' ' +
            'AND FEC_Case_Stage__c = \'' +
            String.escapeSingleQuotes(String.valueOf(templateStages[0].Id)) +
            '\' ' +
            'AND FEC_User_Group__c INCLUDES (\'' +
            String.join(rolelst, '\',\'') +
            '\')';

        for (FEC_Stage_Screen__c item : (List<FEC_Stage_Screen__c>) Database.query(query)) {
            if (!'Routing Action'.equals(item.FEC_Action_Button__r.FEC_Type__c)) {
                continue;
            }
            FEC_CaseBusinessService.Action act = new FEC_CaseBusinessService.Action(
                item.FEC_Action_Button__c,
                String.isNotBlank(item.FEC_Custom_Action_Button_Label__c)
                    ? item.FEC_Custom_Action_Button_Label__c
                    : item.FEC_Action_Button__r.FEC_Code__c,
                String.isNotBlank(item.FEC_Custom_Action_Button_Label__c)
                    ? item.FEC_Custom_Action_Button_Label__c
                    : item.FEC_Action_Button__r.Name,
                item.FEC_Action_Button__r.FEC_Code__c
            );
            if (item.FEC_Field_Type__c == 'All') {
                result.routingActionlst.add(act);
            } else if (item.FEC_Field_Type__c == 'New' && isRevert != true) {
                result.routingActionlst.add(act);
            } else if (item.FEC_Field_Type__c == 'Revert' && isRevert == true) {
                result.routingActionlst.add(act);
            }
        }
    }

    /**
     * MRC Return (Batch 7): chặn nhập Case Information khi không đủ điều kiện (giống pattern Phone Update).
     * Áp khi FEC_SubCategory__r.FEC_Code__c chứa RL05; kiểm tra Product Code TW và DPD cho RL05.03.
     */
    public static FEC_CaseBusinessService.Error mrcReturnCaseInformationValidate(
        Case selectedCase,
        String subCategoryCode,
        String subCodeCode
    ) {
        List<String> errorlst = new List<String>();

        if (String.isBlank(subCategoryCode)) {
            return new FEC_CaseBusinessService.Error();
        }
        Boolean isMrcRl05Branch = subCategoryCode.toUpperCase().contains('RL05');
        if (!isMrcRl05Branch) {
            return new FEC_CaseBusinessService.Error();
        }

        if (
            selectedCase == null ||
            selectedCase.FEC_Account_or_Contract__c == null ||
            selectedCase.FEC_Account_or_Contract__r == null
        ) {
            return new FEC_CaseBusinessService.Error();
        }

        String productCode = selectedCase.FEC_Account_or_Contract__r.FEC_Product_Code__c;
        if (String.isNotBlank(productCode)) {
            if (!'TW'.equalsIgnoreCase(productCode.trim())) {
                errorlst.add(System.Label.FEC_MRC_Return_Msg_Product_Not_TW);
            }
        }

        if (
            errorlst.isEmpty() &&
            String.isNotBlank(subCodeCode) &&
            subCodeCode.toUpperCase().contains(FEC_ConstantCommon.SUB_CODE_RL0503)
        ) {
            Decimal daysPastDue = selectedCase.FEC_Account_or_Contract__r.FEC_Days_Past_Due__c;
            if (daysPastDue != null && daysPastDue >= 15) {
                errorlst.add(System.Label.FEC_MRC_Return_Msg_DPD_RL0503);
            }
        }

        if (errorlst.isEmpty()) {
            return new FEC_CaseBusinessService.Error();
        }
        return new FEC_CaseBusinessService.Error(
            System.Label.FEC_MRC_Return_Case_Info_Block_Title,
            errorlst
        );
    }

    /** Chỉ cảnh báo DPD RL05.03 — không chặn master data / fec_ContractClosureForm. */
    public static Boolean isRl0503DpdOnlyValidation(
        FEC_CaseBusinessService.Error mrcErr,
        String subCodeCode
    ) {
        if (
            mrcErr == null ||
            mrcErr.errorlst == null ||
            mrcErr.errorlst.isEmpty() ||
            String.isBlank(subCodeCode) ||
            !subCodeCode.toUpperCase().contains(FEC_ConstantCommon.SUB_CODE_RL0503)
        ) {
            return false;
        }
        String dpdMsg = System.Label.FEC_MRC_Return_Msg_DPD_RL0503;
        Boolean hasDpd = false;
        for (String line : mrcErr.errorlst) {
            if (String.isBlank(line)) {
                continue;
            }
            if (line == dpdMsg) {
                hasDpd = true;
            } else {
                return false;
            }
        }
        return hasDpd;
    }

    /**
     * RL05.02 Submit: lưu Property Info lên FEC_Additional_Info__c (client gọi trước Route to).
     */
    @AuraEnabled
    public static void saveRl0502PropertyInfo(
        Id additionalInfoId,
        String verifyInformation,
        String callback
    ) {
        if (additionalInfoId == null) {
            return;
        }
        if (!Schema.sObjectType.FEC_Additional_Info__c.isUpdateable()) {
            throw new AuraHandledException('No permission to update Additional Info');
        }
        FEC_Additional_Info__c rec = new FEC_Additional_Info__c(Id = additionalInfoId);
        if (String.isNotBlank(verifyInformation)) {
            rec.FEC_Verify_Information__c = verifyInformation.trim();
        }
        if (String.isNotBlank(callback)) {
            rec.FEC_Callback__c = callback.trim();
        }
        if (
            String.isBlank(rec.FEC_Verify_Information__c) &&
            String.isBlank(rec.FEC_Callback__c)
        ) {
            return;
        }
        update as user rec;
    }
}