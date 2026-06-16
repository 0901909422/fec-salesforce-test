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
            // Cũ: interaction copy/masked trên Case — export dùng FEC_Interaction__r (dưới)
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
            'FEC_Selected_Contract_Number__c',
            // 15/06/2026 14:30 linhdev - Phone Update export (PhoneUpdateTemp1/Temp2)
            'FEC_Original_Info_Phone_Number__c',
            'FEC_Updated_Info_Phone_Number__c',
            // 16/06/2026 toannd - Contract Closure export (ContractClosureTemp2_CSSupport)
            'FEC_Delivery_Option_2__c',
            'FEC_Recipient_Name__c',
            'FEC_Recipient_Phone_Number__c',
            'FEC_Selected_Address__c',
            'FEC_Selected_Address__r.FEC_Full_Address__c',
            'FEC_Account_or_Contract__r.FEC_Email__c'
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

        Map<Id, RemarkBlocks> strictCaseRemarkBlocksByCaseId = loadCaseRemarkBlocks(caseIds, false);
        Map<Id, RemarkBlocks> extendedCaseRemarkBlocksByCaseId = loadCaseRemarkBlocks(caseIds, true);
        Map<Id, AssignmentExportData> assignmentByCaseId = loadPrimaryAssignmentExportData(caseIds);
        // 03/06/2026 - Assignment remarks: FEC_Case_Remarks__c (thay FEC_Routing_Action_History__c) — FEC_BCH_ExportAssignmentRemarkLoader
        Map<Id, FEC_BCH_ExportAssignmentRemarkLoader.AssignmentRemarkExportBundle> assignmentRemarkByCaseId =
            FEC_BCH_ExportAssignmentRemarkLoader.loadByCaseId(caseIds);
        // Cũ: Map<Id, RemarkBlocks> assignmentRemarkBlocksByAssignmentId = loadAssignmentRemarkBlocks(assignmentByCaseId);
        Map<Id, IncorrectPaymentAdjustmentBundle> incorrectPaymentAdjustmentsByCaseId =
            loadIncorrectPaymentAdjustmentBundles(caseIds); // tungnm37

        for (FEC_BatchCaseHandlingExportRow r : rows) {
            if (r == null || r.caseId == null) {
                continue;
            }
            RemarkBlocks strictCaseRemarks = strictCaseRemarkBlocksByCaseId.get(r.caseId);
            RemarkBlocks extendedCaseRemarks = extendedCaseRemarkBlocksByCaseId.get(r.caseId);
            // Toannd 11/06/2026 - strict: template thường; extended: GSR/COF Temp2/Temp8_CA/OtherCS
            if (strictCaseRemarks != null) {
                applyStrictCaseRemarkBlocksToRow(r, strictCaseRemarks);
            }
            if (extendedCaseRemarks != null) {
                applyExtendedCaseRemarkBlocksToRow(r, extendedCaseRemarks);
            }
            // 03/06/2026 - Ưu tiên assignment remark từ FEC_Case_Remarks__c; không có remark thì fallback FEC_Assignment__c (ID/Owner)
            FEC_BCH_ExportAssignmentRemarkLoader.AssignmentRemarkExportBundle asgRemarkBundle =
                assignmentRemarkByCaseId.get(r.caseId);
            if (asgRemarkBundle != null && asgRemarkBundle.hasData()) {
                asgRemarkBundle.applyTo(r);
            } else {
                AssignmentExportData asg = assignmentByCaseId.get(r.caseId);
                if (asg != null) {
                    r.assignmentId = asg.assignmentId;
                    r.assignmentOwner = asg.assignmentOwner;
                }
            }
            // Cũ (03/06/2026): assignment remarks từ Routing History theo primary assignment
            // AssignmentExportData asg = assignmentByCaseId.get(r.caseId);
            // if (asg != null) {
            //     r.assignmentId = asg.assignmentId;
            //     r.assignmentOwner = asg.assignmentOwner;
            //     RemarkBlocks asgRemarks = assignmentRemarkBlocksByAssignmentId.get(asg.assignmentRecordId);
            //     if (asgRemarks != null) {
            //         r.assignmentRemarks = asgRemarks.remarks;
            //         r.assignmentRemarksEnteredBy = asgRemarks.enteredBy;
            //         r.assignmentRemarksEnteredByRole = asgRemarks.enteredByRole;
            //         r.assignmentRemarksEnteredOn = asgRemarks.enteredOn;
            //     }
            // }
            IncorrectPaymentAdjustmentBundle incorrectPaymentBundle = incorrectPaymentAdjustmentsByCaseId.get(r.caseId); // tungnm37
            if (incorrectPaymentBundle != null) {
                r.correctAccountContract = incorrectPaymentBundle.firstCorrectAccountContract;
                r.adjustedAmount = incorrectPaymentBundle.firstAdjustedAmount;
            }
        }
        enrichApplicationListExportFields(rows);
        enrichPendingCsSupportLabels(rows);
        enrichAddressUpdateExportFields(rows);
        enrichContractClosureExportFields(rows);
    }

    // 15/06/2026 linhdev - Address Update export: Updated = Address Info gắn Case có Parent; Original = parent record
    private static void enrichAddressUpdateExportFields(List<FEC_BatchCaseHandlingExportRow> rows) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        if (!Schema.sObjectType.FEC_Address_Info__c.isAccessible()) {
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
        List<FEC_Address_Info__c> caseAddresses = [
            SELECT
                Id,
                FEC_Case__c,
                FEC_Parent_Address__c,
                FEC_Address_Type__c,
                FEC_Full_Address__c,
                FEC_Mailing_Address__c,
                LastModifiedDate
            FROM FEC_Address_Info__c
            WHERE FEC_Case__c IN :caseIds
            AND FEC_Parent_Address__c != NULL
            ORDER BY LastModifiedDate DESC
        ];
        SObjectAccessDecision caseAddrDecision = Security.stripInaccessible(
            AccessType.READABLE,
            caseAddresses
        );
        caseAddresses = (List<FEC_Address_Info__c>) caseAddrDecision.getRecords();
        Map<Id, FEC_Address_Info__c> updatedByCaseId = new Map<Id, FEC_Address_Info__c>();
        Set<Id> parentIds = new Set<Id>();
        for (FEC_Address_Info__c addr : caseAddresses) {
            if (addr == null || addr.FEC_Case__c == null || addr.FEC_Parent_Address__c == null) {
                continue;
            }
            if (!updatedByCaseId.containsKey(addr.FEC_Case__c)) {
                updatedByCaseId.put(addr.FEC_Case__c, addr);
                parentIds.add(addr.FEC_Parent_Address__c);
            }
        }
        Map<Id, FEC_Address_Info__c> originalById = new Map<Id, FEC_Address_Info__c>();
        if (!parentIds.isEmpty()) {
            List<FEC_Address_Info__c> parents = [
                SELECT Id, FEC_Address_Type__c, FEC_Full_Address__c, FEC_Mailing_Address__c
                FROM FEC_Address_Info__c
                WHERE Id IN :parentIds
            ];
            SObjectAccessDecision parentDecision = Security.stripInaccessible(
                AccessType.READABLE,
                parents
            );
            parents = (List<FEC_Address_Info__c>) parentDecision.getRecords();
            for (FEC_Address_Info__c parentRow : parents) {
                originalById.put(parentRow.Id, parentRow);
            }
        }
        for (FEC_BatchCaseHandlingExportRow r : rows) {
            if (r == null || r.caseId == null) {
                continue;
            }
            FEC_Address_Info__c updated = updatedByCaseId.get(r.caseId);
            if (updated == null) {
                continue;
            }
            FEC_Address_Info__c original = originalById.get(updated.FEC_Parent_Address__c);
            applyAddressInfoExportFields(r, original, updated);
        }
    }

    private static void applyAddressInfoExportFields(
        FEC_BatchCaseHandlingExportRow r,
        FEC_Address_Info__c original,
        FEC_Address_Info__c updated
    ) {
        r.updatedInfoAddressType = formatAddressInfoType(updated);
        r.updatedInfoAddress = formatAddressInfoAddress(updated);
        r.updatedInfoMailingAddress = formatAddressInfoMailing(updated);
        r.originalInfoAddressType = formatAddressInfoType(original);
        r.originalInfoAddress = formatAddressInfoAddress(original);
        r.originalInfoMailingAddress = formatAddressInfoMailing(original);
    }

    private static String formatAddressInfoType(FEC_Address_Info__c row) {
        if (row == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String val = row.FEC_Address_Type__c;
        return String.isBlank(val) ? FEC_ConstantCommon.STR_EMPTY : val;
    }

    private static String formatAddressInfoAddress(FEC_Address_Info__c row) {
        if (row == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String val = row.FEC_Full_Address__c;
        return String.isBlank(val) ? FEC_ConstantCommon.STR_EMPTY : val;
    }

    private static String formatAddressInfoMailing(FEC_Address_Info__c row) {
        if (row == null || row.FEC_Mailing_Address__c == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return row.FEC_Mailing_Address__c ? 'true' : 'false';
    }

    // 16/06/2026 toannd - Contract Closure export: Temporary Address + Temporary Email (Level Case info)
    private static void enrichContractClosureExportFields(List<FEC_BatchCaseHandlingExportRow> rows) {
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

        Map<Id, String> temporaryAddressByCaseId = new Map<Id, String>();
        if (Schema.sObjectType.FEC_Address_Info__c.isAccessible()) {
            List<FEC_Address_Info__c> tempAddresses = [
                SELECT FEC_Case__c, FEC_Full_Address__c, LastModifiedDate
                FROM FEC_Address_Info__c
                WHERE FEC_Case__c IN :caseIds
                AND FEC_Address_Type__c = :FEC_ConstantCommon.CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY
                ORDER BY LastModifiedDate DESC
            ];
            SObjectAccessDecision tempAddrDecision = Security.stripInaccessible(
                AccessType.READABLE,
                tempAddresses
            );
            tempAddresses = (List<FEC_Address_Info__c>) tempAddrDecision.getRecords();
            for (FEC_Address_Info__c addr : tempAddresses) {
                if (addr == null || addr.FEC_Case__c == null || temporaryAddressByCaseId.containsKey(addr.FEC_Case__c)) {
                    continue;
                }
                temporaryAddressByCaseId.put(addr.FEC_Case__c, formatAddressInfoAddress(addr));
            }
        }

        Map<Id, String> temporaryEmailByCaseId = loadContractClosureTemporaryEmailsByCaseId(caseIds);

        for (FEC_BatchCaseHandlingExportRow r : rows) {
            if (r == null || r.caseId == null) {
                continue;
            }
            if (temporaryAddressByCaseId.containsKey(r.caseId)) {
                r.temporaryAddress = temporaryAddressByCaseId.get(r.caseId);
            }
            if (temporaryEmailByCaseId.containsKey(r.caseId)) {
                r.temporaryEmail = temporaryEmailByCaseId.get(r.caseId);
            }
        }
    }

    private static Map<Id, String> loadContractClosureTemporaryEmailsByCaseId(Set<Id> caseIds) {
        Map<Id, String> out = new Map<Id, String>();
        if (caseIds == null || caseIds.isEmpty()) {
            return out;
        }
        String caseFieldApi = resolveContactListCaseFieldApiForExport();
        if (String.isBlank(caseFieldApi)) {
            return out;
        }
        Map<String, Schema.SObjectField> clf = Schema.SObjectType.FEC_Contact_List__c.fields.getMap();
        String contactStringApi = 'FEC_Contact_String__c'.toLowerCase();
        String commTypeApi = 'FEC_Communication_Type__c'.toLowerCase();
        if (!clf.containsKey(contactStringApi) || !clf.containsKey(commTypeApi) || !clf.containsKey(caseFieldApi.toLowerCase())) {
            return out;
        }
        String emailCommType = FEC_ConstantCommon.EMAIL;
        List<SObject> contactRows = Database.queryWithBinds(
            'SELECT ' + caseFieldApi + ', FEC_Contact_String__c, LastModifiedDate' +
                ' FROM FEC_Contact_List__c' +
                ' WHERE ' + caseFieldApi + ' IN :caseIds' +
                ' AND FEC_Communication_Type__c = :emailCommType' +
                ' ORDER BY LastModifiedDate DESC',
            new Map<String, Object>{
                'caseIds' => caseIds,
                'emailCommType' => emailCommType
            },
            AccessLevel.SYSTEM_MODE
        );
        for (SObject row : contactRows) {
            Id caseIdRef = (Id) row.get(caseFieldApi);
            if (caseIdRef == null || out.containsKey(caseIdRef)) {
                continue;
            }
            String emailVal = (String) row.get('FEC_Contact_String__c');
            out.put(caseIdRef, emailVal == null ? FEC_ConstantCommon.STR_EMPTY : emailVal);
        }
        return out;
    }

    private static String resolveContactListCaseFieldApiForExport() {
        Map<String, Schema.SObjectField> fm = Schema.SObjectType.FEC_Contact_List__c.fields.getMap();
        for (String api : new List<String>{ 'FEC_Case__c', 'Case__c', 'FEC_Interaction__c' }) {
            String apiLower = api.toLowerCase();
            if (!fm.containsKey(apiLower)) {
                continue;
            }
            Schema.DescribeFieldResult d = fm.get(apiLower).getDescribe();
            if (d.getType() == DisplayType.REFERENCE) {
                for (Schema.SObjectType refType : d.getReferenceTo()) {
                    if (refType.getDescribe().getName() == 'Case') {
                        return d.getName();
                    }
                }
            }
        }
        for (String apiLower : fm.keySet()) {
            Schema.DescribeFieldResult d = fm.get(apiLower).getDescribe();
            if (d.getType() != DisplayType.REFERENCE) {
                continue;
            }
            for (Schema.SObjectType refType : d.getReferenceTo()) {
                if (refType.getDescribe().getName() == 'Case') {
                    return d.getName();
                }
            }
        }
        return null;
    }

    private static String safeRelatedFieldString(SObject row, String fieldApiName) {
        if (row == null || String.isBlank(fieldApiName)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String value = FEC_BatchCaseHandlingSObjectUtil.asString(row.get(fieldApiName));
        return value == null ? FEC_ConstantCommon.STR_EMPTY : value;
    }

    // 14/06/2026 Toannd - trả về chuỗi ngày YYYY-MM-DD, bỏ phần thời gian 00:00:00 với trường DateTime
    private static String safeRelatedFieldDateString(SObject row, String fieldApiName) {
        if (row == null || String.isBlank(fieldApiName)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        Object val = row.get(fieldApiName);
        if (val == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (val instanceof DateTime) {
            return String.valueOf(((DateTime) val).dateGmt());
        }
        if (val instanceof Date) {
            return String.valueOf((Date) val);
        }
        return String.valueOf(val);
    }

    // 01/06/2026 12:00 linhdev - stripInaccessible có thể bỏ relationship: không gọi getSObject khi chưa populated
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
        Map<String, Object> populated = c.getPopulatedFieldsAsMap();
        r.caseId = c.Id;
        r.customerType = populated.containsKey('FEC_Customer_Type__c') ? c.FEC_Customer_Type__c : null;
        SObject ch = safeRelatedSObject(c, 'FEC_Account_or_Contract__r');
        String chCustomerName = safeRelatedFieldString(ch, 'FEC_Customer_Name__c');
        r.customerName = String.isNotBlank(chCustomerName) ? chCustomerName : (populated.containsKey('FEC_Customer_Name__c') ? c.FEC_Customer_Name__c : null);
        String chAccountName = safeRelatedFieldString(ch, 'Name');
        r.accountContractNumber = String.isNotBlank(chAccountName)
            ? chAccountName
            : (populated.containsKey('FEC_Account_Contract_Number_Text__c') ? c.FEC_Account_Contract_Number_Text__c : null);
        String chAppId = safeRelatedFieldString(ch, 'FEC_Application_ID__c');
        r.appId = String.isNotBlank(chAppId) ? chAppId : (populated.containsKey('FEC_Application_ID__c') ? c.FEC_Application_ID__c : null);
        r.caseIdSearch = populated.containsKey('FEC_ID_Search__c') ? c.FEC_ID_Search__c : null;
        r.caseStatus = populated.containsKey('FEC_Final_Status__c') ? c.FEC_Final_Status__c : null;
        r.caseCreatedOn = populated.containsKey('FEC_Case_Created_On__c') ? c.FEC_Case_Created_On__c : null;
        r.lastUpdatedOn = populated.containsKey('FEC_Last_Updated_On__c') ? c.FEC_Last_Updated_On__c : null;
        r.caseCreatedOnLabel = populated.containsKey('FEC_Case_Created_On__c') ? formatExportDatetime(c.FEC_Case_Created_On__c) : FEC_ConstantCommon.STR_EMPTY;
        r.lastUpdatedOnLabel = populated.containsKey('FEC_Last_Updated_On__c') ? formatExportDatetime(c.FEC_Last_Updated_On__c) : FEC_ConstantCommon.STR_EMPTY;
        r.complaintType = populated.containsKey('FEC_Complain_Type__c') ? c.FEC_Complain_Type__c : null;
        r.complaintSource = populated.containsKey('FEC_Complaint_Source__c') ? c.FEC_Complaint_Source__c : null;
        SObject interaction = safeRelatedSObject(c, 'FEC_Interaction__r');
        // Export interaction: lấy từ FEC_Interaction__r theo design (Interaction ID đã đúng ở dưới)
        r.interactionChannel = safeRelatedFieldString(interaction, 'FEC_Channel__c');
        r.interactionSubChannel = safeRelatedFieldString(interaction, 'FEC_Interaction_Subchannel__c');
        r.interactionPhone = safeRelatedFieldString(interaction, 'FEC_Phone_Number__c');
        r.interactionEmail = safeRelatedFieldString(interaction, 'FEC_Interaction_Email__c');
        // 15/06/2026 14:30 linhdev - Phone Update export: map cột Original/Updated Info - Phone Number
        r.originalInfoPhoneNumber = populated.containsKey('FEC_Original_Info_Phone_Number__c')
            ? c.FEC_Original_Info_Phone_Number__c
            : null;
        r.updatedInfoPhoneNumber = populated.containsKey('FEC_Updated_Info_Phone_Number__c')
            ? c.FEC_Updated_Info_Phone_Number__c
            : null;
        // 16/06/2026 toannd - Contract Closure export (ContractClosureTemp2_CSSupport Level Case info)
        r.deliveryOption = populated.containsKey('FEC_Delivery_Option_2__c')
            ? c.FEC_Delivery_Option_2__c
            : null;
        r.recipientName = populated.containsKey('FEC_Recipient_Name__c')
            ? c.FEC_Recipient_Name__c
            : null;
        r.recipientPhoneNumber = populated.containsKey('FEC_Recipient_Phone_Number__c')
            ? c.FEC_Recipient_Phone_Number__c
            : null;
        SObject selectedAddressRel = safeRelatedSObject(c, 'FEC_Selected_Address__r');
        r.closureAddress = selectedAddressRel == null
            ? FEC_ConstantCommon.STR_EMPTY
            : safeRelatedFieldString(selectedAddressRel, 'FEC_Full_Address__c');
        r.closureEmail = ch == null
            ? FEC_ConstantCommon.STR_EMPTY
            : safeRelatedFieldString(ch, 'FEC_Email__c');
        // Cũ: field trên Case (masked / copy) — không khớp design export
        // r.interactionChannel = c.FEC_Channel__c;
        // r.interactionSubChannel = c.FEC_Interaction_Subchannel__c;
        // r.interactionPhone = c.FEC_Interaction_Masked_Phone__c;
        // r.interactionEmail = c.FEC_Interaction_Masked_Email__c;
        SObject ipp = safeRelatedSObject(c, 'FEC_IPP_To_Close__r'); // Toannd 28/5/2026
        if (ipp != null) { // Toannd 28/5/2026
            r.ippRecordNo = safeRelatedFieldString(ipp, 'FEC_IPP_Record_No__c'); // Toannd 28/5/2026
            r.ippPlan = safeRelatedFieldString(ipp, 'FEC_IPP_Plan__c'); // Toannd 28/5/2026
            r.ippOpenDate = safeRelatedFieldDateString(ipp, 'FEC_IPP_Open_Date__c'); // Toannd 14/06/2026
            r.ippFirstDueDate = safeRelatedFieldDateString(ipp, 'FEC_IPP_First_Due_Date__c'); // Toannd 14/06/2026
            r.ippMatureDate = safeRelatedFieldDateString(ipp, 'FEC_IPP_Mature_Date__c'); // Toannd 14/06/2026
            r.ippBalance = ipp.get('FEC_IPP_Balance__c') == null // Toannd 28/5/2026
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(ipp.get('FEC_IPP_Balance__c'));
            r.ippCurrentBalance = ipp.get('FEC_IPP_Current_Balance__c') == null // Toannd 28/5/2026
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(ipp.get('FEC_IPP_Current_Balance__c'));
            r.ippInterestRate = ipp.get('FEC_IPP_Interest_Rate__c') == null // Toannd 28/5/2026
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(ipp.get('FEC_IPP_Interest_Rate__c'));
            r.ippTerm = safeRelatedFieldString(ipp, 'FEC_IPP_Term__c'); // Toannd 28/5/2026
            r.ippInsurance = safeRelatedFieldString(ipp, 'FEC_IPP_Insurance__c'); // Toannd 28/5/2026
            r.ippCurrentTerm = safeRelatedFieldString(ipp, 'FEC_IPP_Current_Term__c'); // Toannd 28/5/2026
        }
        SObject interactionRel = safeRelatedSObject(c, 'FEC_Interaction__r');
        r.interactionId = interactionRel == null ? FEC_ConstantCommon.STR_EMPTY : safeRelatedFieldString(interactionRel, 'FEC_ID_Search__c');
        SObject productTypeRel = safeRelatedSObject(c, 'FEC_Product_Type__r');
        // 12/06/2026 19:20 linhdev - export Product Type theo design: FEC_Product_Type__r.Name
        r.productType = productTypeRel == null
            ? FEC_ConstantCommon.STR_EMPTY
            : safeRelatedFieldString(productTypeRel, 'Name');
        SObject categoryRel = safeRelatedSObject(c, 'FEC_Category__r');
        SObject subCategoryRel = safeRelatedSObject(c, 'FEC_SubCategory__r');
        SObject subCodeRel = safeRelatedSObject(c, 'FEC_SubCode__r');
        // 12/06/2026 19:20 linhdev - export Category/Sub Category/Sub Code theo design: __r.Name
        r.categoryCode = categoryRel == null ? null : safeRelatedFieldString(categoryRel, 'Name');
        r.subCategoryCode = subCategoryRel == null ? null : safeRelatedFieldString(subCategoryRel, 'Name');
        r.subCodeCode = subCodeRel == null ? null : safeRelatedFieldString(subCodeRel, 'Name');
        r.categoryDisplay = formatCategoryDisplay(categoryRel);
        r.subCategoryDisplay = formatSubDisplay(subCategoryRel);
        r.subCodeDisplay = formatSubDisplay(subCodeRel);
        r.originalCategoryDisplay = formatCategoryDisplay(safeRelatedSObject(c, 'FEC_Original_Category__r'));
        r.originalSubCategoryDisplay = formatSubDisplay(safeRelatedSObject(c, 'FEC_Original_Sub_Category__r'));
        r.originalSubCodeDisplay = formatSubDisplay(safeRelatedSObject(c, 'FEC_Original_Sub_Code__r'));
        r.caseReviewUrl = '/lightning/r/Case/' + String.valueOf(c.Id) + '/view';
        FEC_BatchCaseHandlingTemplateHelper.applyStageBusinessProcessToExportRow(r, c);
        r.blockLimitDateLabel = populated.containsKey('FEC_CS_Check_Block_Limit_Date__c') ? formatExportDate(c.FEC_CS_Check_Block_Limit_Date__c) : FEC_ConstantCommon.STR_EMPTY;
        r.blockLimitAmount = populated.containsKey('FEC_CS_Check_Block_Limit_Amount__c') ? formatExportCurrency(c.FEC_CS_Check_Block_Limit_Amount__c) : FEC_ConstantCommon.STR_EMPTY;
        r.classificationByCs = populated.containsKey('FEC_CS_Check_Classification_by_CS__c') ? c.FEC_CS_Check_Classification_by_CS__c : null;
        r.evaluationByCs = populated.containsKey('FEC_CS_Check_Evaluation_by_CS__c') ? c.FEC_CS_Check_Evaluation_by_CS__c : null;
        r.finalProduct = populated.containsKey('FEC_CS_Check_Final_Product__c') ? c.FEC_CS_Check_Final_Product__c : null;
        r.paymentContractAssessment = populated.containsKey('FEC_RD_Payment_Contract_Assessment__c') ? c.FEC_RD_Payment_Contract_Assessment__c : null;
        r.evaluationBySales = populated.containsKey('FEC_Sales_Check_Evaluation_by_Sales__c') ? c.FEC_Sales_Check_Evaluation_by_Sales__c : null;
        r.disciplineResult = populated.containsKey('FEC_Sales_Check_Discipline_Result__c') ? c.FEC_Sales_Check_Discipline_Result__c : null;
        r.contactPoint = populated.containsKey('FEC_Sales_Check_Contact_Point__c') ? c.FEC_Sales_Check_Contact_Point__c : null;
        r.teamLeader = populated.containsKey('FEC_Sales_Check_Team_Leader__c') ? c.FEC_Sales_Check_Team_Leader__c : null;
        r.supervisor = populated.containsKey('FEC_Sales_Check_Supervisor__c') ? c.FEC_Sales_Check_Supervisor__c : null;
        r.incorrectContractNumber = populated.containsKey('FEC_Incorrect_Contract_Number__c') ? c.FEC_Incorrect_Contract_Number__c : null;
        r.paymentMethod = populated.containsKey('FEC_Payment_Method__c') ? c.FEC_Payment_Method__c : null;
        r.billDate = populated.containsKey('FEC_Bill_Date__c') ? formatExportDate(c.FEC_Bill_Date__c) : FEC_ConstantCommon.STR_EMPTY;
        r.billAmount = populated.containsKey('FEC_Bill_Amount__c') ? formatExportCurrency(c.FEC_Bill_Amount__c) : FEC_ConstantCommon.STR_EMPTY;
        r.paymentDate = r.billDate;
        r.excessAmount = r.billAmount;
        r.selectedContractNumber = populated.containsKey('FEC_Selected_Contract_Number__c') ? c.FEC_Selected_Contract_Number__c : null;
        r.correctContractNumber = FEC_ConstantCommon.STR_EMPTY; // tungnm37
        r.correctAccountContract = FEC_ConstantCommon.STR_EMPTY; // tungnm37
        r.adjustedAmount = FEC_ConstantCommon.STR_EMPTY; // tungnm37
        if (ch != null) {
            r.ccCode = safeRelatedFieldString(ch, 'FEC_CC_Code__c');
            r.ccName = safeRelatedFieldString(ch, 'FEC_CC_Name__c');
            r.dsaCode = safeRelatedFieldString(ch, 'FEC_DSA_Code__c');
            r.dsaName = safeRelatedFieldString(ch, 'FEC_DSA_Name__c');
            r.tsaCode = safeRelatedFieldString(ch, 'FEC_TSA_Code__c');
            r.tsaName = safeRelatedFieldString(ch, 'FEC_TSA_Name__c');
            r.contractStatus = safeRelatedFieldString(ch, 'FEC_Contract_Status__c'); // Toannd 28/5/2026
            r.productCode = safeRelatedFieldString(ch, 'FEC_Product_Code__c'); // Toannd 28/5/2026
            r.loanAmount = ch.get('FEC_Loan_Amount__c') == null // Toannd 28/5/2026
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(ch.get('FEC_Loan_Amount__c'));
            r.tenure = ch.get('FEC_Tenure__c') == null // Toannd 28/5/2026
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(ch.get('FEC_Tenure__c'));
            r.salesChannel = safeRelatedFieldString(ch, 'FEC_Sales_Channel__c');
            r.salesSubChannel = safeRelatedFieldString(ch, 'FEC_Sales_Sub_Channel__c');
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

    // 12/06/2026 19:20 linhdev - export Category display theo design: __r.Name
    private static String formatCategoryDisplay(SObject rel) {
        if (rel == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String name = safeRelatedFieldString(rel, 'Name');
        return String.isBlank(name) ? FEC_ConstantCommon.STR_EMPTY : name;
    }

    // 12/06/2026 19:20 linhdev - export Sub Category/Sub Code display theo design: __r.Name
    private static String formatSubDisplay(SObject rel) {
        if (rel == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        String name = safeRelatedFieldString(rel, 'Name');
        return String.isBlank(name) ? FEC_ConstantCommon.STR_EMPTY : name;
    }

    // Toannd 11/06/2026 - Case Remarks gom (1 ô) cho template thường — loại Assignment remark
    private static void applyStrictCaseRemarkBlocksToRow(
        FEC_BatchCaseHandlingExportRow row,
        RemarkBlocks caseRemarks
    ) {
        if (row == null || caseRemarks == null) {
            return;
        }
        row.caseRemarks = caseRemarks.remarks;
        row.caseRemarksEnteredBy = caseRemarks.enteredBy;
        row.caseRemarksEnteredByRole = caseRemarks.enteredByRole;
        row.caseRemarksEnteredOn = caseRemarks.enteredOn;
    }

    // Toannd 11/06/2026 - Case Remarks extended cho GSR/COF Temp2/Temp8_CA/OtherCS
    private static void applyExtendedCaseRemarkBlocksToRow(
        FEC_BatchCaseHandlingExportRow row,
        RemarkBlocks caseRemarks
    ) {
        if (row == null || caseRemarks == null) {
            return;
        }
        row.caseRemarksExtended = caseRemarks.remarks;
        row.caseRemarksEnteredByExtended = caseRemarks.enteredBy;
        row.caseRemarksEnteredByRoleExtended = caseRemarks.enteredByRole;
        row.caseRemarksEnteredOnExtended = caseRemarks.enteredOn;
        row.caseRemarks1 = caseRemarks.remarkAt(1);
        row.caseRemarksEnteredBy1 = caseRemarks.enteredByAt(1);
        row.caseRemarksEnteredByRole1 = caseRemarks.enteredByRoleAt(1);
        row.caseRemarksEnteredOn1 = caseRemarks.enteredOnAt(1);
        row.caseRemarks2 = caseRemarks.remarkAt(2);
        row.caseRemarksEnteredBy2 = caseRemarks.enteredByAt(2);
        row.caseRemarksEnteredByRole2 = caseRemarks.enteredByRoleAt(2);
        row.caseRemarksEnteredOn2 = caseRemarks.enteredOnAt(2);
        row.caseRemarks3 = caseRemarks.remarkAt(3);
        row.caseRemarksEnteredBy3 = caseRemarks.enteredByAt(3);
        row.caseRemarksEnteredByRole3 = caseRemarks.enteredByRoleAt(3);
        row.caseRemarksEnteredOn3 = caseRemarks.enteredOnAt(3);
    }

    // Toannd 11/06/2026 - template thường: loại toàn bộ Assignment remark (03/06/2026 jira 1726)
    @TestVisible
    private static Boolean includeCaseRemarkInStrictExport(FEC_Case_Remarks__c remark) {
        if (remark == null) {
            return false;
        }
        return remark.FEC_Remark_Type__c != FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT;
    }

    // Toannd 11/06/2026 - GSR/COF Temp2/Temp8: khớp fec_CaseDetail_Customer.loadRemarkHistory
    @TestVisible
    private static Boolean includeCaseRemarkInExtendedExport(FEC_Case_Remarks__c remark) {
        if (remark == null) {
            return false;
        }
        if (remark.FEC_Remark_Type__c != FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT) {
            return true;
        }
        String stageName = remark.FEC_Stage_Name__c;
        if (String.isBlank(stageName)) {
            return true;
        }
        return !Pattern.compile('(?i).*stage\\s*1.*').matcher(stageName).matches();
    }

    private static Map<Id, RemarkBlocks> loadCaseRemarkBlocks(Set<Id> caseIds, Boolean useExtendedFilter) {
        Map<Id, RemarkBlocks> out = new Map<Id, RemarkBlocks>();
        for (FEC_Case_Remarks__c remark : [
            SELECT
                FEC_Case__c,
                FEC_Case_Remarks__c,
                FEC_User__c,
                FEC_User_Role__c,
                FEC_Remark_Type__c,
                FEC_Stage_Name__c,
                CreatedDate
            FROM FEC_Case_Remarks__c
            WHERE FEC_Case__c IN :caseIds
            ORDER BY FEC_Case__c, CreatedDate ASC, Id ASC
        ]) {
            Boolean include = useExtendedFilter == true
                ? includeCaseRemarkInExtendedExport(remark)
                : includeCaseRemarkInStrictExport(remark);
            if (remark.FEC_Case__c == null || !include) {
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

    // 03/06/2026 - Đã thay bằng FEC_BCH_ExportAssignmentRemarkLoader.loadByCaseId (FEC_Case_Remarks__c)
    // private static Map<Id, RemarkBlocks> loadAssignmentRemarkBlocks(Map<Id, AssignmentExportData> assignmentByCaseId) {
    //     Map<Id, RemarkBlocks> out = new Map<Id, RemarkBlocks>();
    //     Set<Id> assignmentIds = new Set<Id>();
    //     for (AssignmentExportData item : assignmentByCaseId.values()) {
    //         if (item != null && item.assignmentRecordId != null) {
    //             assignmentIds.add(item.assignmentRecordId);
    //         }
    //     }
    //     if (assignmentIds.isEmpty()) {
    //         return out;
    //     }
    //     for (FEC_Routing_Action_History__c hist : [
    //         SELECT FEC_Assignment__c, FEC_Description__c, FEC_User__c, FEC_User_Role__c, FEC_Date_Time__c, CreatedDate
    //         FROM FEC_Routing_Action_History__c
    //         WHERE FEC_Assignment__c IN :assignmentIds
    //         AND FEC_Routing_Action_Type__c = :FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT
    //         ORDER BY FEC_Assignment__c, CreatedDate ASC
    //     ]) {
    //         if (hist.FEC_Assignment__c == null) {
    //             continue;
    //         }
    //         if (!out.containsKey(hist.FEC_Assignment__c)) {
    //             out.put(hist.FEC_Assignment__c, new RemarkBlocks());
    //         }
    //         Datetime remarkDt = hist.FEC_Date_Time__c != null ? hist.FEC_Date_Time__c : hist.CreatedDate;
    //         out.get(hist.FEC_Assignment__c).add(
    //             hist.FEC_Description__c,
    //             hist.FEC_User__c,
    //             hist.FEC_User_Role__c,
    //             remarkDt
    //         );
    //     }
    //     return out;
    // }

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
            bundle.firstAdjustedAmount = formatExportCurrency(
                FEC_BatchCaseHandlingSObjectUtil.asDecimal(row.get('FEC_Adjusted_Amount__c'))
            );
            out.put(caseId, bundle);
        }
        return out;
    }

    // Toannd 11/06/2026 - lưu từng dòng remark để export theo cột (GSRTemp2_OtherCS)
    private class RemarkLine {
        public String remark = FEC_ConstantCommon.STR_EMPTY;
        public String enteredBy = FEC_ConstantCommon.STR_EMPTY;
        public String enteredByRole = FEC_ConstantCommon.STR_EMPTY;
        public String enteredOn = FEC_ConstantCommon.STR_EMPTY;
    }

    private class RemarkBlocks {
        public String remarks = FEC_ConstantCommon.STR_EMPTY;
        public String enteredBy = FEC_ConstantCommon.STR_EMPTY;
        public String enteredByRole = FEC_ConstantCommon.STR_EMPTY;
        public String enteredOn = FEC_ConstantCommon.STR_EMPTY;
        private Integer lineIndex = 0;
        private List<RemarkLine> lines = new List<RemarkLine>();

        public void add(String remarkText, String userText, String roleText, Datetime createdDt) {
            lineIndex += 1;
            String prefix = '#' + String.valueOf(lineIndex) + ': ';
            RemarkLine line = new RemarkLine();
            line.remark = prefix + safeText(remarkText);
            line.enteredBy = prefix + safeText(userText);
            line.enteredByRole = prefix + safeText(roleText);
            line.enteredOn = prefix + formatExportDatetime(createdDt);
            lines.add(line);
            remarks = appendLine(remarks, line.remark);
            enteredBy = appendLine(enteredBy, line.enteredBy);
            enteredByRole = appendLine(enteredByRole, line.enteredByRole);
            enteredOn = appendLine(enteredOn, line.enteredOn);
        }

        public String remarkAt(Integer index) {
            return valueAt(index, 'remark');
        }

        public String enteredByAt(Integer index) {
            return valueAt(index, 'enteredBy');
        }

        public String enteredByRoleAt(Integer index) {
            return valueAt(index, 'enteredByRole');
        }

        public String enteredOnAt(Integer index) {
            return valueAt(index, 'enteredOn');
        }

        // Toannd 11/06/2026 - lấy giá trị remark theo thứ tự (#1, #2, #3)
        private String valueAt(Integer index, String fieldName) {
            if (index == null || index < 1 || index > lines.size()) {
                return FEC_ConstantCommon.STR_EMPTY;
            }
            RemarkLine line = lines[index - 1];
            if (line == null) {
                return FEC_ConstantCommon.STR_EMPTY;
            }
            if (fieldName == 'remark') {
                return line.remark;
            }
            if (fieldName == 'enteredBy') {
                return line.enteredBy;
            }
            if (fieldName == 'enteredByRole') {
                return line.enteredByRole;
            }
            if (fieldName == 'enteredOn') {
                return line.enteredOn;
            }
            return FEC_ConstantCommon.STR_EMPTY;
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