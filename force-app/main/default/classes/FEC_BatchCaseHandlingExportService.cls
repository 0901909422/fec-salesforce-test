public without sharing class FEC_BatchCaseHandlingExportService {

    public static List<String> buildCaseExportSelectFields() {
        List<String> selectFields = new List<String>{
            'Id',
            'FEC_Customer_Type__c',
            'FEC_Customer_Name__c',
            'FEC_Account_Contract_Number_Text__c',
            'FEC_Application_ID__c',
            'FEC_ID_Search__c',
            'FEC_Final_Status__c',
            'FEC_Case_Created_On__c',
            'FEC_Last_Updated_On__c',
            'FEC_Complain_Type__c',
            'FEC_Complaint_Source__c',
            'FEC_Channel__c',
            'FEC_Interaction_Subchannel__c',
            'FEC_Interaction_Masked_Phone__c',
            'FEC_Interaction_Masked_Email__c',
            'FEC_IPP_To_Close__r.FEC_IPP_Record_No__c', // Toannd 28/5/2026
            'FEC_IPP_To_Close__r.FEC_IPP_Plan__c', // Toannd 28/5/2026
            'FEC_IPP_To_Close__r.FEC_IPP_Open_Date__c', // Toannd 28/5/2026
            'FEC_IPP_To_Close__r.FEC_IPP_First_Due_Date__c', // Toannd 28/5/2026
            'FEC_IPP_To_Close__r.FEC_IPP_Mature_Date__c', // Toannd 28/5/2026
            'FEC_IPP_To_Close__r.FEC_IPP_Balance__c', // Toannd 28/5/2026
            'FEC_IPP_To_Close__r.FEC_IPP_Current_Balance__c', // Toannd 28/5/2026
            'FEC_IPP_To_Close__r.FEC_IPP_Interest_Rate__c', // Toannd 28/5/2026
            'FEC_IPP_To_Close__r.FEC_IPP_Term__c', // Toannd 28/5/2026
            'FEC_IPP_To_Close__r.FEC_IPP_Insurance__c', // Toannd 28/5/2026
            'FEC_IPP_To_Close__r.FEC_IPP_Current_Term__c', // Toannd 28/5/2026
            'FEC_Product_Type__r.Name',
            'FEC_Product_Type__r.FEC_Code__c',
            'FEC_Category__r.Name',
            'FEC_Category__r.FEC_Code__c',
            'FEC_SubCategory__r.FEC_Code__c',
            'FEC_SubCategory__r.FEC_Name_VN__c',
            'FEC_SubCategory__r.Name',
            'FEC_SubCode__r.FEC_Code__c',
            'FEC_SubCode__r.FEC_Name_VN__c',
            'FEC_SubCode__r.Name',
            'FEC_Original_Category__r.Name',
            'FEC_Original_Category__r.FEC_Code__c',
            'FEC_Original_Sub_Category__r.FEC_Code__c',
            'FEC_Original_Sub_Category__r.FEC_Name_VN__c',
            'FEC_Original_Sub_Category__r.Name',
            'FEC_Original_Sub_Code__r.FEC_Code__c',
            'FEC_Original_Sub_Code__r.FEC_Name_VN__c',
            'FEC_Original_Sub_Code__r.Name',
            'FEC_Interaction__r.FEC_ID_Search__c',
            'FEC_Interaction__r.FEC_Channel__c',
            'FEC_Interaction__r.FEC_Interaction_Subchannel__c',
            'FEC_Interaction__r.FEC_Phone_Number__c',
            'FEC_Interaction__r.FEC_Interaction_Email__c',
            'FEC_CS_Check_Block_Limit_Date__c',
            'FEC_CS_Check_Block_Limit_Amount__c',
            'FEC_CS_Check_Classification_by_CS__c',
            'FEC_CS_Check_Evaluation_by_CS__c',
            'FEC_CS_Check_Final_Product__c',
            'FEC_RD_Payment_Contract_Assessment__c', // Toannd 28/5/2026
            'FEC_Sales_Check_Evaluation_by_Sales__c',
            'FEC_Sales_Check_Discipline_Result__c',
            'FEC_Sales_Check_Contact_Point__c',
            'FEC_Sales_Check_Team_Leader__c',
            'FEC_Sales_Check_Supervisor__c',
            'FEC_Account_or_Contract__r.FEC_CC_Code__c',
            'FEC_Account_or_Contract__r.FEC_CC_Name__c',
            'FEC_Account_or_Contract__r.FEC_DSA_Code__c',
            'FEC_Account_or_Contract__r.FEC_DSA_Name__c',
            'FEC_Account_or_Contract__r.FEC_TSA_Code__c',
            'FEC_Account_or_Contract__r.FEC_TSA_Name__c',
            'FEC_Account_or_Contract__r.FEC_Contract_Status__c', // Toannd 28/5/2026
            'FEC_Account_or_Contract__r.FEC_Product_Code__c', // Toannd 28/5/2026
            'FEC_Account_or_Contract__r.FEC_Loan_Amount__c', // Toannd 28/5/2026
            'FEC_Account_or_Contract__r.FEC_Tenure__c', // Toannd 28/5/2026
            'FEC_Account_or_Contract__r.FEC_Sales_Channel__c',
            'FEC_Account_or_Contract__r.FEC_Sales_Sub_Channel__c',
            'FEC_Account_or_Contract__r.FEC_Customer_Name__c',
            'FEC_Account_or_Contract__r.Name',
            'FEC_Account_or_Contract__r.FEC_Application_ID__c',
            'FEC_Incorrect_Contract_Number__c',
            'FEC_Payment_Method__c',
            'FEC_Bill_Date__c',
            'FEC_Bill_Amount__c',
            'FEC_Selected_Contract_Number__c'
        };
        selectFields.addAll(FEC_BatchCaseHandlingTemplateHelper.buildCaseStageBusinessProcessSelectFields());
        return selectFields;
    }


    public static void applyVisibleAttachmentFlags(List<FEC_BatchCaseHandlingExportRow> rows) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        Set<Id> caseIds = new Set<Id>();
        for (FEC_BatchCaseHandlingExportRow r : rows) {
            if (r != null && r.caseId != null) {
                caseIds.add(r.caseId);
            }
        }
        if (caseIds.isEmpty()) {
            return;
        }
        Set<Id> caseIdsWithAttachment = new CaseAttachmentVisibility().resolveCaseIdsWithAttachments(caseIds);
        for (FEC_BatchCaseHandlingExportRow r : rows) {
            if (r == null) {
                continue;
            }
            r.hasAttachment = r.caseId != null && caseIdsWithAttachment.contains(r.caseId);
            r.hasAttachmentLabel = r.hasAttachment ? 'Has attachment' : FEC_ConstantCommon.STR_EMPTY;
        }
    }

    public static Set<Id> resolveVisibleCaseIdsWithAttachments(Set<Id> caseIds) {
        return new CaseAttachmentVisibility().resolveCaseIdsWithAttachments(caseIds);
    }

    private with sharing class CaseAttachmentVisibility {
        Set<Id> resolveCaseIdsWithAttachments(Set<Id> caseIds) {
            Set<Id> out = new Set<Id>();
            if (caseIds == null || caseIds.isEmpty()) {
                return out;
            }
            for (ContentDocumentLink cdl : [
                SELECT LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :caseIds
            ]) {
                if (cdl.LinkedEntityId != null) {
                    out.add(cdl.LinkedEntityId);
                }
            }
            return out;
        }
    }

    public static void enrichExportRows(List<FEC_BatchCaseHandlingExportRow> rows) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        Set<Id> caseIds = new Set<Id>();
        for (FEC_BatchCaseHandlingExportRow r : rows) {
            if (r != null && r.caseId != null) {
                caseIds.add(r.caseId);
            }
        }
        if (caseIds.isEmpty()) {
            return;
        }

        Map<Id, RemarkBlocks> caseRemarkBlocksByCaseId = loadCaseRemarkBlocks(caseIds);
        Map<Id, AssignmentExportData> assignmentByCaseId = loadPrimaryAssignmentExportData(caseIds);
        Map<Id, RemarkBlocks> assignmentRemarkBlocksByAssignmentId = loadAssignmentRemarkBlocks(assignmentByCaseId);
        Map<Id, IncorrectPaymentAdjustmentBundle> incorrectPaymentAdjustmentsByCaseId =
            loadIncorrectPaymentAdjustmentBundles(caseIds); // tungnm37

        for (FEC_BatchCaseHandlingExportRow r : rows) {
            if (r == null || r.caseId == null) {
                continue;
            }
            RemarkBlocks caseRemarks = caseRemarkBlocksByCaseId.get(r.caseId);
            if (caseRemarks != null) {
                r.caseRemarks = caseRemarks.remarks;
                r.caseRemarksEnteredBy = caseRemarks.enteredBy;
                r.caseRemarksEnteredByRole = caseRemarks.enteredByRole;
                r.caseRemarksEnteredOn = caseRemarks.enteredOn;
            }
            AssignmentExportData asg = assignmentByCaseId.get(r.caseId);
            if (asg != null) {
                r.assignmentId = asg.assignmentId;
                r.assignmentOwner = asg.assignmentOwner;
                RemarkBlocks asgRemarks = assignmentRemarkBlocksByAssignmentId.get(asg.assignmentRecordId);
                if (asgRemarks != null) {
                    r.assignmentRemarks = asgRemarks.remarks;
                    r.assignmentRemarksEnteredBy = asgRemarks.enteredBy;
                    r.assignmentRemarksEnteredByRole = asgRemarks.enteredByRole;
                    r.assignmentRemarksEnteredOn = asgRemarks.enteredOn;
                }
            }
            IncorrectPaymentAdjustmentBundle incorrectPaymentBundle = incorrectPaymentAdjustmentsByCaseId.get(r.caseId); // tungnm37
            if (incorrectPaymentBundle != null) {
                r.correctAccountContract = incorrectPaymentBundle.firstCorrectAccountContract;
                r.adjustedAmount = incorrectPaymentBundle.firstAdjustedAmount;
            }
        }
        enrichApplicationListExportFields(rows);
        enrichPendingCsSupportLabels(rows);
    }

    private static SObject safeRelatedSObject(SObject row, String relationshipApiName) {
        if (row == null || String.isBlank(relationshipApiName)) {
            return null;
        }
        if (!row.getPopulatedFieldsAsMap().containsKey(relationshipApiName)) {
            return null;
        }
        try {
            return row.getSObject(relationshipApiName);
        } catch (SObjectException ex) {
            return null;
        }
    }

    public static FEC_BatchCaseHandlingExportRow mapCaseToExportRow(Case c) {
        FEC_BatchCaseHandlingExportRow r = new FEC_BatchCaseHandlingExportRow();
        r.caseId = c.Id;
        r.customerType = c.FEC_Customer_Type__c;
        SObject ch = safeRelatedSObject(c, 'FEC_Account_or_Contract__r');
        r.customerName = ch != null && String.isNotBlank((String) ch.get('FEC_Customer_Name__c'))
            ? (String) ch.get('FEC_Customer_Name__c')
            : c.FEC_Customer_Name__c;
        r.accountContractNumber = ch != null && String.isNotBlank((String) ch.get('Name'))
            ? (String) ch.get('Name')
            : c.FEC_Account_Contract_Number_Text__c;
        r.appId = ch != null && String.isNotBlank((String) ch.get('FEC_Application_ID__c'))
            ? (String) ch.get('FEC_Application_ID__c')
            : c.FEC_Application_ID__c;
        r.caseIdSearch = c.FEC_ID_Search__c;
        r.caseStatus = c.FEC_Final_Status__c;
        r.caseCreatedOn = c.FEC_Case_Created_On__c;
        r.lastUpdatedOn = c.FEC_Last_Updated_On__c;
        r.caseCreatedOnLabel = formatExportDatetime(c.FEC_Case_Created_On__c);
        r.lastUpdatedOnLabel = formatExportDatetime(c.FEC_Last_Updated_On__c);
        r.complaintType = c.FEC_Complain_Type__c;
        r.complaintSource = c.FEC_Complaint_Source__c;
        r.interactionChannel = c.FEC_Channel__c;
        r.interactionSubChannel = c.FEC_Interaction_Subchannel__c;
        r.interactionPhone = c.FEC_Interaction_Masked_Phone__c;
        r.interactionEmail = c.FEC_Interaction_Masked_Email__c;
        SObject ipp = safeRelatedSObject(c, 'FEC_IPP_To_Close__r'); // Toannd 28/5/2026
        if (ipp != null) { // Toannd 28/5/2026
            r.ippRecordNo = (String) ipp.get('FEC_IPP_Record_No__c'); // Toannd 28/5/2026
            r.ippPlan = (String) ipp.get('FEC_IPP_Plan__c'); // Toannd 28/5/2026
            r.ippOpenDate = ipp.get('FEC_IPP_Open_Date__c') == null // Toannd 28/5/2026
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(ipp.get('FEC_IPP_Open_Date__c'));
            r.ippFirstDueDate = ipp.get('FEC_IPP_First_Due_Date__c') == null // Toannd 28/5/2026
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(ipp.get('FEC_IPP_First_Due_Date__c'));
            r.ippMatureDate = ipp.get('FEC_IPP_Mature_Date__c') == null // Toannd 28/5/2026
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(ipp.get('FEC_IPP_Mature_Date__c'));
            r.ippBalance = ipp.get('FEC_IPP_Balance__c') == null // Toannd 28/5/2026
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(ipp.get('FEC_IPP_Balance__c'));
            r.ippCurrentBalance = ipp.get('FEC_IPP_Current_Balance__c') == null // Toannd 28/5/2026
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(ipp.get('FEC_IPP_Current_Balance__c'));
            r.ippInterestRate = ipp.get('FEC_IPP_Interest_Rate__c') == null // Toannd 28/5/2026
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(ipp.get('FEC_IPP_Interest_Rate__c'));
            r.ippTerm = (String) ipp.get('FEC_IPP_Term__c'); // Toannd 28/5/2026
            r.ippInsurance = (String) ipp.get('FEC_IPP_Insurance__c'); // Toannd 28/5/2026
            r.ippCurrentTerm = (String) ipp.get('FEC_IPP_Current_Term__c'); // Toannd 28/5/2026
        }
        r.interactionId = c.FEC_Interaction__r == null ? FEC_ConstantCommon.STR_EMPTY : c.FEC_Interaction__r.FEC_ID_Search__c;
        r.productType = c.FEC_Product_Type__r == null
            ? FEC_ConstantCommon.STR_EMPTY
            : String.isNotBlank(c.FEC_Product_Type__r.FEC_Code__c)
                ? c.FEC_Product_Type__r.FEC_Code__c
                : c.FEC_Product_Type__r.Name;
        r.categoryCode = c.FEC_Category__r == null ? null : c.FEC_Category__r.FEC_Code__c;
        r.subCategoryCode = c.FEC_SubCategory__r == null ? null : c.FEC_SubCategory__r.FEC_Code__c;
        r.subCodeCode = c.FEC_SubCode__r == null ? null : c.FEC_SubCode__r.FEC_Code__c;
        r.categoryDisplay = formatCategoryDisplay(c.FEC_Category__r);
        r.subCategoryDisplay = formatSubDisplay(c.FEC_SubCategory__r);
        r.subCodeDisplay = formatSubDisplay(c.FEC_SubCode__r);
        r.originalCategoryDisplay = formatCategoryDisplay(c.FEC_Original_Category__r);
        r.originalSubCategoryDisplay = formatSubDisplay(c.FEC_Original_Sub_Category__r);
        r.originalSubCodeDisplay = formatSubDisplay(c.FEC_Original_Sub_Code__r);
        r.caseReviewUrl = '/lightning/r/Case/' + String.valueOf(c.Id) + '/view';
        FEC_BatchCaseHandlingTemplateHelper.applyStageBusinessProcessToExportRow(r, c);
        r.blockLimitDateLabel = formatExportDate(c.FEC_CS_Check_Block_Limit_Date__c);
        r.blockLimitAmount = formatExportCurrency(c.FEC_CS_Check_Block_Limit_Amount__c);
        r.classificationByCs = c.FEC_CS_Check_Classification_by_CS__c;
        r.evaluationByCs = c.FEC_CS_Check_Evaluation_by_CS__c;
        r.finalProduct = c.FEC_CS_Check_Final_Product__c;
        r.paymentContractAssessment = c.FEC_RD_Payment_Contract_Assessment__c; // Toannd 28/5/2026
        r.evaluationBySales = c.FEC_Sales_Check_Evaluation_by_Sales__c;
        r.disciplineResult = c.FEC_Sales_Check_Discipline_Result__c;
        r.contactPoint = c.FEC_Sales_Check_Contact_Point__c;
        r.teamLeader = c.FEC_Sales_Check_Team_Leader__c;
        r.supervisor = c.FEC_Sales_Check_Supervisor__c;
        r.incorrectContractNumber = c.FEC_Incorrect_Contract_Number__c;
        r.paymentMethod = c.FEC_Payment_Method__c;
        r.billDate = formatExportDate(c.FEC_Bill_Date__c);
        r.billAmount = formatExportCurrency(c.FEC_Bill_Amount__c);
        r.paymentDate = r.billDate;
        r.excessAmount = r.billAmount;
        r.selectedContractNumber = c.FEC_Selected_Contract_Number__c; // tungnm37
        r.correctContractNumber = FEC_ConstantCommon.STR_EMPTY; // tungnm37
        r.correctAccountContract = FEC_ConstantCommon.STR_EMPTY; // tungnm37
        r.adjustedAmount = FEC_ConstantCommon.STR_EMPTY; // tungnm37
        if (ch != null) {
            r.ccCode = (String) ch.get('FEC_CC_Code__c');
            r.ccName = (String) ch.get('FEC_CC_Name__c');
            r.dsaCode = (String) ch.get('FEC_DSA_Code__c');
            r.dsaName = (String) ch.get('FEC_DSA_Name__c');
            r.tsaCode = (String) ch.get('FEC_TSA_Code__c');
            r.tsaName = (String) ch.get('FEC_TSA_Name__c');
            r.contractStatus = (String) ch.get('FEC_Contract_Status__c'); // Toannd 28/5/2026
            r.productCode = (String) ch.get('FEC_Product_Code__c'); // Toannd 28/5/2026
            r.loanAmount = ch.get('FEC_Loan_Amount__c') == null // Toannd 28/5/2026
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(ch.get('FEC_Loan_Amount__c'));
            r.tenure = ch.get('FEC_Tenure__c') == null // Toannd 28/5/2026
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(ch.get('FEC_Tenure__c'));
            r.salesChannel = (String) ch.get('FEC_Sales_Channel__c');
            r.salesSubChannel = (String) ch.get('FEC_Sales_Sub_Channel__c');
        }
        return r;
    }

    private static void enrichApplicationListExportFields(List<FEC_BatchCaseHandlingExportRow> rows) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        Set<String> appIdsNeedingLookup = new Set<String>();
        for (FEC_BatchCaseHandlingExportRow r : rows) {
            if (r == null || String.isBlank(r.appId) || !String.isBlank(r.ccCode)) {
                continue;
            }
            appIdsNeedingLookup.add(r.appId.trim());
        }
        if (!appIdsNeedingLookup.isEmpty()) {
            Map<String, FEC_Application_List__c> latestByAppId = new Map<String, FEC_Application_List__c>();
            for (FEC_Application_List__c al : [
                SELECT FEC_Application_ID__c, FEC_CC_Code__c, FEC_CC_Name__c, FEC_DSA_Code__c, FEC_DSA_Name__c,
                    FEC_TSA_Code__c, FEC_TSA_Name__c, CreatedDate
                FROM FEC_Application_List__c
                WHERE FEC_Application_ID__c IN :appIdsNeedingLookup
                ORDER BY FEC_Application_ID__c, CreatedDate DESC
            ]) {
                if (String.isBlank(al.FEC_Application_ID__c) || latestByAppId.containsKey(al.FEC_Application_ID__c)) {
                    continue;
                }
                latestByAppId.put(al.FEC_Application_ID__c, al);
            }
            for (FEC_BatchCaseHandlingExportRow r : rows) {
                if (r == null || String.isBlank(r.appId) || !String.isBlank(r.ccCode)) {
                    continue;
                }
                FEC_Application_List__c al = latestByAppId.get(r.appId.trim());
                if (al == null) {
                    continue;
                }
                r.ccCode = al.FEC_CC_Code__c;
                r.ccName = al.FEC_CC_Name__c;
                r.dsaCode = al.FEC_DSA_Code__c;
                r.dsaName = al.FEC_DSA_Name__c;
                r.tsaCode = al.FEC_TSA_Code__c;
                r.tsaName = al.FEC_TSA_Name__c;
            }
        }
        for (FEC_BatchCaseHandlingExportRow r : rows) {
            if (r == null || !String.isBlank(r.salesChannel)) {
                continue;
            }
            if (String.isBlank(r.ccCode) && String.isBlank(r.dsaCode) && String.isBlank(r.tsaCode)) {
                continue;
            }
            FEC_SalesChannelFromApplicationService.SalesChannelResult channelResult =
                FEC_SalesChannelFromApplicationService.resolveSalesChannelFromApplicationCodes(
                    r.ccCode,
                    r.dsaCode,
                    r.tsaCode
                );
            if (channelResult != null) {
                r.salesChannel = channelResult.channel;
                r.salesSubChannel = channelResult.subChannel;
            }
        }
    }

    private static void enrichPendingCsSupportLabels(List<FEC_BatchCaseHandlingExportRow> rows) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        Set<Id> caseIds = new Set<Id>();
        for (FEC_BatchCaseHandlingExportRow r : rows) {
            if (r != null && r.caseId != null) {
                caseIds.add(r.caseId);
            }
        }
        if (caseIds.isEmpty()) {
            return;
        }

        Map<Id, Case> caseById = new Map<Id, Case>([
            SELECT Id, Status, FEC_Team__c
            FROM Case
            WHERE Id IN :caseIds
        ]);

        Set<Id> pendingCaseIds = new Set<Id>();
        for (Id caseId : caseIds) {
            Case c = caseById.get(caseId);
            if (c != null && c.Status == FEC_ConstantCommon.CASE_STATUS_PENDING) {
                pendingCaseIds.add(caseId);
            }
        }

        Map<Id, FEC_Routing_Action_History__c> latestChangeOwnerByCaseId =
            loadLatestChangeOwnerHistoryByCaseId(pendingCaseIds);

        Map<Id, String> teamByOwnerId = new Map<Id, String>();
        if (!latestChangeOwnerByCaseId.isEmpty()) {
            teamByOwnerId = FEC_RoutingActionHistoryTriggerHandler.getTeamsFromIds(
                FEC_RoutingActionHistoryTriggerHandler.collectOwnerIdsFromRouteHistory(
                    latestChangeOwnerByCaseId.values()
                )
            );
        }

        for (FEC_BatchCaseHandlingExportRow r : rows) {
            if (r == null || r.caseId == null) {
                continue;
            }
            Case c = caseById.get(r.caseId);
            if (c == null || c.Status != FEC_ConstantCommon.CASE_STATUS_PENDING) {
                r.pendingCsSupportLabel = FEC_ConstantCommon.STR_EMPTY;
                continue;
            }
            FEC_Routing_Action_History__c hist = latestChangeOwnerByCaseId.get(r.caseId);
            String compactPending;
            if (hist != null) {
                compactPending = FEC_RoutingActionHistoryTriggerHandler.buildPendingStatusFromRouteHistoryRow(
                    hist,
                    teamByOwnerId
                );
            } else if (String.isNotBlank(c.FEC_Team__c)) {
                compactPending = FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX + c.FEC_Team__c;
            } else {
                compactPending = FEC_ConstantCommon.CASE_STATUS_PENDING;
            }
            r.pendingCsSupportLabel = formatPendingStatusForExport(compactPending);
        }
    }

    private static Map<Id, FEC_Routing_Action_History__c> loadLatestChangeOwnerHistoryByCaseId(Set<Id> caseIds) {
        Map<Id, FEC_Routing_Action_History__c> out = new Map<Id, FEC_Routing_Action_History__c>();
        if (caseIds == null || caseIds.isEmpty()) {
            return out;
        }
        for (FEC_Routing_Action_History__c hist : [
            SELECT FEC_Case__c, FEC_Routing_Action__c, FEC_Original_User_Queue_ID__c, FEC_Updated_User_Queue_ID__c, CreatedDate
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c IN :caseIds
            AND FEC_Routing_Action__c = :FEC_ConstantCommon.FEC_ROUTING_ACTION_CHANGE_OWNER
            ORDER BY FEC_Case__c, CreatedDate DESC, Id DESC
        ]) {
            if (hist.FEC_Case__c != null && !out.containsKey(hist.FEC_Case__c)) {
                out.put(hist.FEC_Case__c, hist);
            }
        }
        return out;
    }

    /**
     * Chuỗi export GSR cột Pending-CSSupport: Pending - {Team} (có dấu cách quanh dấu -),
     * khớp FEC_Final_Status__c / hiển thị UI, không dùng Pending-{Team} nội bộ.
     */
    private static String formatPendingStatusForExport(String compactPending) {
        if (String.isBlank(compactPending)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (compactPending == FEC_ConstantCommon.CASE_STATUS_PENDING) {
            return FEC_ConstantCommon.CASE_STATUS_PENDING;
        }
        if (compactPending.startsWith(FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX)) {
            String teams = compactPending.substring(FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX.length());
            if (String.isBlank(teams)) {
                return FEC_ConstantCommon.CASE_STATUS_PENDING;
            }
            teams = teams.replace(
                FEC_ConstantCommon.DELIMITER_UNDERSCORE,
                ' - '
            );
            return 'Pending - ' + teams;
        }
        return compactPending;
    }

    private static String formatExportDate(Date d) {
        if (d == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return Datetime.newInstance(d.year(), d.month(), d.day()).format('dd/MM/yyyy');
    }

    private static String formatExportCurrency(Decimal amount) {
        if (amount == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return String.valueOf(amount.setScale(0));
    }

    private static String formatExportDatetime(Datetime dt) {
        if (dt == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return dt.format('dd/MM/yyyy hh:mm:ss a');
    }

    private static String formatCategoryDisplay(SObject rel) {
        if (rel == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String name = (String) rel.get('Name');
        return String.isBlank(name) ? FEC_ConstantCommon.STR_EMPTY : name;
    }

    private static String formatSubDisplay(SObject rel) {
        if (rel == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String code = (String) rel.get('FEC_Code__c');
        String nameVn = (String) rel.get('FEC_Name_VN__c');
        String name = String.isNotBlank(nameVn) ? nameVn : (String) rel.get('Name');
        if (String.isNotBlank(code) && String.isNotBlank(name)) {
            return code + '-' + name;
        }
        if (String.isNotBlank(name)) {
            return name;
        }
        return String.isBlank(code) ? FEC_ConstantCommon.STR_EMPTY : code;
    }

    private static Map<Id, RemarkBlocks> loadCaseRemarkBlocks(Set<Id> caseIds) {
        Map<Id, RemarkBlocks> out = new Map<Id, RemarkBlocks>();
        for (FEC_Case_Remarks__c remark : [
            SELECT FEC_Case__c, FEC_Case_Remarks__c, FEC_User__c, FEC_User_Role__c, CreatedDate
            FROM FEC_Case_Remarks__c
            WHERE FEC_Case__c IN :caseIds
            ORDER BY FEC_Case__c, CreatedDate ASC
        ]) {
            if (remark.FEC_Case__c == null) {
                continue;
            }
            if (!out.containsKey(remark.FEC_Case__c)) {
                out.put(remark.FEC_Case__c, new RemarkBlocks());
            }
            out.get(remark.FEC_Case__c).add(
                remark.FEC_Case_Remarks__c,
                remark.FEC_User__c,
                remark.FEC_User_Role__c,
                remark.CreatedDate
            );
        }
        return out;
    }

    private static Map<Id, AssignmentExportData> loadPrimaryAssignmentExportData(Set<Id> caseIds) {
        Map<Id, AssignmentExportData> out = new Map<Id, AssignmentExportData>();
        for (FEC_Assignment__c asg : [
            SELECT Id, Name, FEC_Case__c, FEC_Team__c, FEC_Assignment_Owner_Text__c, FEC_Assignment_Status__c, CreatedDate
            FROM FEC_Assignment__c
            WHERE FEC_Case__c IN :caseIds
            ORDER BY FEC_Case__c, CreatedDate DESC
        ]) {
            if (asg.FEC_Case__c == null || out.containsKey(asg.FEC_Case__c)) {
                continue;
            }
            if (String.isNotBlank(asg.FEC_Assignment_Status__c) && asg.FEC_Assignment_Status__c.startsWith('Resolved-')) {
                continue;
            }
            AssignmentExportData item = new AssignmentExportData();
            item.assignmentRecordId = asg.Id;
            item.assignmentId = asg.Name;
            item.assignmentOwner = String.isNotBlank(asg.FEC_Team__c)
                ? asg.FEC_Team__c
                : asg.FEC_Assignment_Owner_Text__c;
            out.put(asg.FEC_Case__c, item);
        }
        return out;
    }

    private static Map<Id, RemarkBlocks> loadAssignmentRemarkBlocks(Map<Id, AssignmentExportData> assignmentByCaseId) {
        Map<Id, RemarkBlocks> out = new Map<Id, RemarkBlocks>();
        Set<Id> assignmentIds = new Set<Id>();
        for (AssignmentExportData item : assignmentByCaseId.values()) {
            if (item != null && item.assignmentRecordId != null) {
                assignmentIds.add(item.assignmentRecordId);
            }
        }
        if (assignmentIds.isEmpty()) {
            return out;
        }
        for (FEC_Routing_Action_History__c hist : [
            SELECT FEC_Assignment__c, FEC_Description__c, FEC_User__c, FEC_User_Role__c, FEC_Date_Time__c, CreatedDate
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Assignment__c IN :assignmentIds
            AND FEC_Routing_Action_Type__c = :FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT
            ORDER BY FEC_Assignment__c, CreatedDate ASC
        ]) {
            if (hist.FEC_Assignment__c == null) {
                continue;
            }
            if (!out.containsKey(hist.FEC_Assignment__c)) {
                out.put(hist.FEC_Assignment__c, new RemarkBlocks());
            }
            Datetime remarkDt = hist.FEC_Date_Time__c != null ? hist.FEC_Date_Time__c : hist.CreatedDate;
            out.get(hist.FEC_Assignment__c).add(
                hist.FEC_Description__c,
                hist.FEC_User__c,
                hist.FEC_User_Role__c,
                remarkDt
            );
        }
        return out;
    }

    private class AssignmentExportData {
        public Id assignmentRecordId;
        public String assignmentId;
        public String assignmentOwner;
    }

    // tungnm37 - first incorrect payment detail row is used for base columns, repeated columns handled by dedicated writer
    private class IncorrectPaymentAdjustmentBundle {
        public String firstCorrectAccountContract = FEC_ConstantCommon.STR_EMPTY;
        public String firstAdjustedAmount = FEC_ConstantCommon.STR_EMPTY;
    }

    private static Map<Id, IncorrectPaymentAdjustmentBundle> loadIncorrectPaymentAdjustmentBundles(Set<Id> caseIds) {
        Map<Id, IncorrectPaymentAdjustmentBundle> out = new Map<Id, IncorrectPaymentAdjustmentBundle>();
        if (caseIds == null || caseIds.isEmpty()) {
            return out;
        }
        Schema.SObjectType infoType = Schema.getGlobalDescribe().get('FEC_Incorrect_Payment_Info__c');
        if (infoType == null) {
            return out;
        }
        Map<String, Schema.SObjectField> fieldMap = infoType.getDescribe().fields.getMap();
        String correctFieldApi = null;
        if (fieldMap.containsKey('fec_correct_account_contract__c')) {
            correctFieldApi = 'FEC_Correct_Account_Contract__c';
        } else if (fieldMap.containsKey('fec_correct_contract_number__c')) {
            correctFieldApi = 'FEC_Correct_Contract_Number__c';
        }
        String soql = 'SELECT FEC_Case__c, FEC_Adjusted_Amount__c';
        if (String.isNotBlank(correctFieldApi)) {
            soql += ', ' + correctFieldApi;
        }
        soql += ' FROM FEC_Incorrect_Payment_Info__c WHERE FEC_Case__c IN :caseIds ORDER BY CreatedDate ASC, Id ASC';
        for (SObject row : Database.query(soql)) {
            Id caseId = (Id) row.get('FEC_Case__c');
            if (caseId == null || out.containsKey(caseId)) {
                continue;
            }
            IncorrectPaymentAdjustmentBundle bundle = new IncorrectPaymentAdjustmentBundle();
            bundle.firstCorrectAccountContract = String.isNotBlank(correctFieldApi)
                ? String.valueOf(row.get(correctFieldApi))
                : FEC_ConstantCommon.STR_EMPTY;
            bundle.firstAdjustedAmount = formatExportCurrency((Decimal) row.get('FEC_Adjusted_Amount__c'));
            out.put(caseId, bundle);
        }
        return out;
    }

    private class RemarkBlocks {
        public String remarks = FEC_ConstantCommon.STR_EMPTY;
        public String enteredBy = FEC_ConstantCommon.STR_EMPTY;
        public String enteredByRole = FEC_ConstantCommon.STR_EMPTY;
        public String enteredOn = FEC_ConstantCommon.STR_EMPTY;
        private Integer lineIndex = 0;

        public void add(String remarkText, String userText, String roleText, Datetime createdDt) {
            lineIndex += 1;
            String prefix = '#' + String.valueOf(lineIndex) + ': ';
            remarks = appendLine(remarks, prefix + safeText(remarkText));
            enteredBy = appendLine(enteredBy, prefix + safeText(userText));
            enteredByRole = appendLine(enteredByRole, prefix + safeText(roleText));
            enteredOn = appendLine(enteredOn, prefix + formatExportDatetime(createdDt));
        }

        private String appendLine(String current, String incoming) {
            if (String.isBlank(incoming)) {
                return current;
            }
            if (String.isBlank(current)) {
                return incoming;
            }
            return current + '\n' + incoming;
        }

        private String safeText(String value) {
            return value == null ? FEC_ConstantCommon.STR_EMPTY : value;
        }
    }
}