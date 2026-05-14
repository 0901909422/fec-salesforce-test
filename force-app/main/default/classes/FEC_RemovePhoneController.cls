public without sharing class FEC_RemovePhoneController {

    private static final Pattern PHONE_VALID_PATTERN = Pattern.compile(FEC_ConstantCommon.PATTERN_PHONE_NUMBER);

    public class RemovablePhoneRowDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String customerName;
        @AuraEnabled public String contractNumber;
        @AuraEnabled public String contractStatus;
        @AuraEnabled public String phoneType;
        @AuraEnabled public String removable;
        @AuraEnabled public String reason;
    }

    public class CheckEligibilityResultDTO {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String code;
        @AuraEnabled public String description;
        @AuraEnabled public List<RemovablePhoneRowDTO> rows;
    }

    public class RemovePhoneRowSaveDTO {
        @AuraEnabled public String customerName;
        @AuraEnabled public String contractNumber;
        @AuraEnabled public String contractStatus;
        @AuraEnabled public String phoneType;
        @AuraEnabled public String removable;
        @AuraEnabled public String reason;
        @AuraEnabled public Boolean checkRemovePhone;
    }

    public class RemovePhoneDraftDTO {
        @AuraEnabled public String phone;
        @AuraEnabled public List<RemovePhoneRowSaveDTO> rows;
    }

    @AuraEnabled
    public static CheckEligibilityResultDTO checkEligibility(String phone) {
        CheckEligibilityResultDTO dto = new CheckEligibilityResultDTO();
        dto.success = false;
        dto.errorMessage = null;
        dto.rows = new List<RemovablePhoneRowDTO>();

        if (!isValidPhone(phone)) {
            dto.errorMessage = System.Label.FEC_MSG_Remove_Phone_Invalid_Format;
            return dto;
        }

        try {
            FEC_GetRemovablePhoneStatus.PhoneCheckResult calloutResult = FEC_GetRemovablePhoneStatus.getRemovablePhoneStatus(phone);
            FEC_GetRemovablePhoneStatus.logApiResponse();

            if (calloutResult == null) {
                dto.errorMessage = System.Label.FEC_MSG_Remove_Phone_Service_Failed;
                return dto;
            }

            dto.code = calloutResult.code;
            dto.description = calloutResult.description;

            if (!isTechnicalSuccess(calloutResult)) {
                dto.errorMessage = String.isBlank(calloutResult.errorMessage)
                    ? System.Label.FEC_MSG_Remove_Phone_Service_Failed
                    : calloutResult.errorMessage;
                return dto;
            }

            dto.rows = parseResponseRows(calloutResult.rawResponse);
            dto.success = true;
            return dto;
        } catch (Exception ex) {
            dto.errorMessage = System.Label.FEC_MSG_Remove_Phone_Service_Failed;
            return dto;
        }
    }

    @AuraEnabled
    public static void saveRemovePhoneSelections(Id caseId, String removedPhoneNumber, List<RemovePhoneRowSaveDTO> rows) {
        if (caseId == null) {
            if (rows == null || rows.isEmpty()) {
                return;
            }
            throw new AuraHandledException(System.Label.FEC_Toast_Save_Error_Message);
        }

        String phoneNorm = String.isBlank(removedPhoneNumber) ? null : removedPhoneNumber.trim();

        List<FEC_Contract_List_for_Remove_Phone__c> toInsert = new List<FEC_Contract_List_for_Remove_Phone__c>();
        if (!String.isBlank(phoneNorm) && rows != null) {
            for (RemovePhoneRowSaveDTO dto : rows) {
                if (dto == null) {
                    continue;
                }
                FEC_Contract_List_for_Remove_Phone__c rec = new FEC_Contract_List_for_Remove_Phone__c();
                rec.FEC_Case__c = caseId;
                rec.FEC_Removed_Phone_Number__c = phoneNorm;
                rec.FEC_Customer_Name__c = trimToNull(dto.customerName);
                rec.FEC_Account_Contract_Number__c = trimToNull(dto.contractNumber);
                rec.FEC_Account_Contract_Status__c = trimToNull(dto.contractStatus);
                rec.FEC_Phone_Type__c = trimToNull(dto.phoneType);
                rec.FEC_Removable__c = trimToNull(dto.removable);
                rec.FEC_Reason__c = trimToNull(dto.reason);
                rec.FEC_Check_Remove_Phone__c = (dto.checkRemovePhone == true);
                rec.Name = buildRemovePhoneListName(rec);
                toInsert.add(rec);
            }
        }

        List<FEC_Contract_List_for_Remove_Phone__c> existing = [
            SELECT Id
            FROM FEC_Contract_List_for_Remove_Phone__c
            WHERE FEC_Case__c = :caseId
        ];

        try {
            if (!existing.isEmpty()) {
                delete existing;
            }
            if (!toInsert.isEmpty()) {
                insert toInsert;
            }
        } catch (Exception ex) {
            throw new AuraHandledException(System.Label.FEC_Toast_Save_Error_Message);
        }
    }

    @AuraEnabled(cacheable=false)
    public static RemovePhoneDraftDTO loadRemovePhoneDraft(Id caseId) {
        RemovePhoneDraftDTO out = new RemovePhoneDraftDTO();
        out.phone = '';
        out.rows = new List<RemovePhoneRowSaveDTO>();
        if (caseId == null) {
            return out;
        }
        for (FEC_Contract_List_for_Remove_Phone__c r : [
            SELECT FEC_Customer_Name__c, FEC_Account_Contract_Number__c,
                   FEC_Account_Contract_Status__c, FEC_Phone_Type__c,
                   FEC_Removable__c, FEC_Reason__c, FEC_Check_Remove_Phone__c,
                   FEC_Removed_Phone_Number__c
            FROM FEC_Contract_List_for_Remove_Phone__c
            WHERE FEC_Case__c = :caseId
            ORDER BY CreatedDate ASC
        ]) {
            if (String.isBlank(out.phone) && !String.isBlank(r.FEC_Removed_Phone_Number__c)) {
                out.phone = r.FEC_Removed_Phone_Number__c;
            }
            RemovePhoneRowSaveDTO dto = new RemovePhoneRowSaveDTO();
            dto.customerName = r.FEC_Customer_Name__c;
            dto.contractNumber = r.FEC_Account_Contract_Number__c;
            dto.contractStatus = r.FEC_Account_Contract_Status__c;
            dto.phoneType = r.FEC_Phone_Type__c;
            dto.removable = r.FEC_Removable__c;
            dto.reason = r.FEC_Reason__c;
            dto.checkRemovePhone = (r.FEC_Check_Remove_Phone__c == true);
            out.rows.add(dto);
        }
        return out;
    }

    private static String trimToNull(String s) {
        if (s == null) {
            return null;
        }
        String t = s.trim();
        return t.length() == 0 ? null : t;
    }

    private static String buildRemovePhoneListName(FEC_Contract_List_for_Remove_Phone__c rec) {
        String base = rec.FEC_Account_Contract_Number__c;
        if (String.isBlank(base)) {
            base = 'RemovePhone';
        } else {
            base = base.trim();
        }
        if (base.length() > 80) {
            base = base.substring(0, 80);
        }
        return base;
    }

    private static Boolean isValidPhone(String phone) {
        if (String.isBlank(phone)) {
            return false;
        }
        String normalized = phone.trim();
        return PHONE_VALID_PATTERN.matcher(normalized).matches();
    }

    private static Boolean isTechnicalSuccess(FEC_GetRemovablePhoneStatus.PhoneCheckResult r) {
        if (r == null) {
            return false;
        }
        if (r.httpStatus != null && (r.httpStatus < 200 || r.httpStatus >= 300)) {
            return false;
        }
        if (!String.isBlank(r.errorMessage)) {
            return false;
        }
        return !String.isBlank(r.rawResponse);
    }

    private static List<RemovablePhoneRowDTO> parseResponseRows(String xmlBody) {
        List<RemovablePhoneRowDTO> rows = new List<RemovablePhoneRowDTO>();
        if (String.isBlank(xmlBody)) {
            return rows;
        }

        try {
            Dom.Document doc = new Dom.Document();
            doc.load(xmlBody);
            Dom.XmlNode envelope = doc.getRootElement();
            if (envelope == null) {
                return rows;
            }
            Dom.XmlNode body = getChildIgnoreNs(envelope, 'Body');
            if (body == null) {
                return rows;
            }
            Dom.XmlNode responseNode = getChildByEndsWith(body, 'GetRemovablePhoneStatusResponse');
            if (responseNode == null) {
                return rows;
            }

            List<Dom.XmlNode> itemNodes = collectItemNodes(responseNode);
            Integer idx = 0;
            for (Dom.XmlNode itemNode : itemNodes) {
                RemovablePhoneRowDTO row = new RemovablePhoneRowDTO();
                row.id = String.valueOf(idx);
                row.customerName = getNodeTextByCandidates(itemNode, new List<String>{ 'CustomerName', 'Customer_Name', 'CusName' });
                row.contractNumber = getNodeTextByCandidates(itemNode, new List<String>{ 'ContractNumber', 'AccountNumber', 'Contract_No', 'ContractNo' });
                row.contractStatus = getNodeTextByCandidates(itemNode, new List<String>{ 'ContractStatus', 'Status' });
                row.phoneType = getNodeTextByCandidates(itemNode, new List<String>{ 'PhoneType', 'Type' });
                row.removable = getNodeTextByCandidates(itemNode, new List<String>{ 'Removable', 'RemovableStatus' });
                row.reason = getNodeTextByCandidates(itemNode, new List<String>{ 'Reason', 'Description', 'Message' });
                rows.add(row);
                idx++;
            }
        } catch (Exception ex) {
            return new List<RemovablePhoneRowDTO>();
        }
        return rows;
    }

    private static List<Dom.XmlNode> collectItemNodes(Dom.XmlNode root) {
        List<Dom.XmlNode> nodes = new List<Dom.XmlNode>();
        for (Dom.XmlNode child : root.getChildElements()) {
            if (isNodeName(child, 'Items') || isNodeName(child, 'Data') || isNodeName(child, 'Contracts')) {
                for (Dom.XmlNode n : child.getChildElements()) {
                    if (isNodeName(n, 'Item') || isNodeName(n, 'Contract') || isNodeName(n, 'Row')) {
                        nodes.add(n);
                    }
                }
            } else if (isNodeName(child, 'Item') || isNodeName(child, 'Contract') || isNodeName(child, 'Row')) {
                nodes.add(child);
            }
        }
        return nodes;
    }

    private static String getNodeTextByCandidates(Dom.XmlNode parent, List<String> candidates) {
        if (parent == null || candidates == null || candidates.isEmpty()) {
            return null;
        }
        for (String candidate : candidates) {
            Dom.XmlNode child = getChildIgnoreNs(parent, candidate);
            if (child != null && !String.isBlank(child.getText())) {
                return child.getText();
            }
        }
        return null;
    }

    private static Dom.XmlNode getChildIgnoreNs(Dom.XmlNode parent, String localName) {
        if (parent == null || String.isBlank(localName)) {
            return null;
        }
        for (Dom.XmlNode child : parent.getChildElements()) {
            if (isNodeName(child, localName)) {
                return child;
            }
        }
        return null;
    }

    private static Dom.XmlNode getChildByEndsWith(Dom.XmlNode parent, String suffix) {
        if (parent == null || String.isBlank(suffix)) {
            return null;
        }
        for (Dom.XmlNode child : parent.getChildElements()) {
            String n = child.getName();
            if (!String.isBlank(n) && n.endsWith(suffix)) {
                return child;
            }
        }
        return null;
    }

    private static Boolean isNodeName(Dom.XmlNode node, String expected) {
        if (node == null || String.isBlank(expected)) {
            return false;
        }
        String actual = node.getName();
        if (String.isBlank(actual)) {
            return false;
        }
        return actual == expected || actual.endsWith(':' + expected);
    }
}