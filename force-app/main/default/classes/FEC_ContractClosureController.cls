public without sharing class FEC_ContractClosureController {

    public static final String MSG_NOTI_01 = System.Label.FEC_MSG_ContractClosure_Required_Fields;
    public static final String MSG_NOTI_02 = System.Label.FEC_MSG_ContractClosure_Delivery_Invalid;
    public static final String MSG_NOTI_03 = System.Label.FEC_Interaction_Email_Invalid_Msg;
    public static final String MSG_NOTI_16 = System.Label.FEC_MSG_ContractClosure_Phone_Invalid;
    public static final String MSG_ADDRESS_REQUIRED = System.Label.FEC_MSG_ContractClosure_Address_Required;
    public static final String MSG_TEMP_EMAIL_REQUIRED = System.Label.FEC_Complete_This_Field;
    public static final String MSG_ADDRESS_ROW_EMPTY = System.Label.FEC_MSG_ContractClosure_Address_Row_Empty;

    private static final String OBJ_CASE = 'Case';
    private static final String OBJ_ADDRESS = 'FEC_Address_Info__c';
    private static final String FLD_DELIVERY = 'FEC_Delivery_Option_2__c';
    private static final String FLD_RECIPIENT_NAME = 'FEC_Recipient_Name__c';
    private static final String FLD_RECIPIENT_PHONE = 'FEC_Recipient_Phone_Number__c';
    private static final String FLD_TEMP_EMAIL = 'FEC_Temporary_Email__c';
    private static final String OBJ_CONTACT_LIST = 'FEC_Contact_List__c';
    private static final String FLD_CL_HISTORY = 'FEC_Customer_History__c';
    private static final String FLD_CL_COMM_TYPE = 'FEC_Communication_Type__c';
    private static final String FLD_CL_CHANNEL = 'FEC_Channel__c';
    private static final String FLD_CL_CONTACT_STRING = 'FEC_Contact_String__c';
    private static final String FLD_CASE_CHANNEL = 'FEC_Channel__c';

    private static final String OBJ_ADDITIONAL_INFO = 'FEC_Additional_Info__c';
    private static final String FLD_AI_VERIFY = 'FEC_Verify_Information__c';
    private static final String FLD_AI_CALLBACK = 'FEC_Callback__c';

    /** Thử lần lượt — đổi thứ tự / thêm API nếu field thực tế trên Case khác tên. */
    private static final List<String> CASE_CASH24_FIELD_CANDIDATES = new List<String>{
        'FEC_SHD_Cash24__c',
        'FEC_Cash24_Contract_Text__c'
    };

    private static final Set<String> ADMIN_UNIT_OBJECTS = new Set<String>{ 'FEC_District__c', 'FEC_Province__c' };
    private static final String COUNTRY_CODE_VN = '2';
    private static Id countryIdVnCache;
    private static String caseSelectedAddressFieldApiCache;

    private static final Pattern EMAIL_PAT = Pattern.compile(FEC_ConstantCommon.PATTERN_EMAIL);

    public class PicklistEntryDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public PicklistEntryDTO(String l, String v) {
            label = l;
            value = v;
        }
    }

    public class AddressRowDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String addressType;
        @AuraEnabled public String address;
        @AuraEnabled public String mailingAddressLabel;
        @AuraEnabled public String building;
        @AuraEnabled public String streetNumber;
        @AuraEnabled public String street;
        @AuraEnabled public String wardRecordId;
        @AuraEnabled public String provinceRecordId;
        @AuraEnabled public String wardLabel;
        @AuraEnabled public String provinceLabel;
    }

    public class InitDataDTO {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String demographicEmail;
        @AuraEnabled public String demographicCustomerName;
        @AuraEnabled public String demographicPrimaryPhone;
        @AuraEnabled public List<AddressRowDTO> addresses;
        @AuraEnabled public List<PicklistEntryDTO> deliveryOptions;
        @AuraEnabled public List<PicklistEntryDTO> wardOptions;
        @AuraEnabled public List<PicklistEntryDTO> provinceOptions;
        @AuraEnabled public String savedDeliveryOption;
        @AuraEnabled public String savedRecipientName;
        @AuraEnabled public String savedRecipientPhone;
        @AuraEnabled public String savedSelectedAddressId;
        @AuraEnabled public String savedTemporaryEmail;
        @AuraEnabled public Id additionalInfoId;
        @AuraEnabled public String savedVerifyInformation;
        @AuraEnabled public String savedCallback;
        @AuraEnabled public List<PicklistEntryDTO> verifyInformationOptions;
        @AuraEnabled public List<PicklistEntryDTO> callbackOptions;
        @AuraEnabled public String savedCash24ContractText;
    }

    public class ValidationResultDTO {
        @AuraEnabled public Boolean valid;
        @AuraEnabled public List<String> messages;
        public ValidationResultDTO() {
            valid = true;
            messages = new List<String>();
        }
        public void addFail(String m) {
            valid = false;
            messages.add(m);
        }
    }

    public class SavePayloadDTO {
        public List<String> deliveryValues;
        public String deliveryOptionCombined;
        public Boolean deliveryEmailSelected;
        public Boolean deliveryAddressSelected;
        public Boolean deliveryOfficeSelected;
        public Boolean useExistingEmail;
        public String temporaryEmail;
        public String recipientName;
        public String recipientPhone;
        public String selectedAddressId;
        public String temporaryAddressDisplay;
        public TempAddressPartsDTO tempAddressParts;
        public String tempAddressRecordId;
        public String emailDeliveryChannel;
        public String verifyInformation;
        public String callback;
        public String cash24ContractText;
    }

    public class TempAddressPartsDTO {
        public String building;
        /** JSON từ LWC: streetNumber (tránh từ khóa reserved `number` trong Apex). */
        public String streetNumber;
        public String street;
        /** Id lookup FEC_Ward__c (hoặc giá trị picklist nếu org đổi kiểu field). */
        public String wardRecordId;
        /** Id lookup FEC_Province__c / FEC_Province_City__c tùy metadata org. */
        public String provinceRecordId;
        /** Nhãn hiển thị / ghép chuỗi địa chỉ (bắt buộc cho UI). */
        public String wardLabel;
        public String provinceLabel;
    }

    @AuraEnabled(cacheable=true)
    public static InitDataDTO getInitData(Id caseId) {
        InitDataDTO out = new InitDataDTO();
        out.addresses = new List<AddressRowDTO>();
        out.deliveryOptions = new List<PicklistEntryDTO>();
        out.wardOptions = new List<PicklistEntryDTO>();
        out.provinceOptions = new List<PicklistEntryDTO>();
        out.success = false;
        if (caseId == null) {
            out.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'});
            return out;
        }
        try {
            Map<String, Schema.SObjectField> caseFields = Schema.SObjectType.Case.fields.getMap();
            List<Case> rows = [
                SELECT Id,
                    FEC_Account_or_Contract__c,
                    FEC_Account_or_Contract__r.Id,
                    FEC_Account_or_Contract__r.FEC_Email__c,
                    FEC_Account_or_Contract__r.FEC_Customer_Name__c,
                    FEC_Account_or_Contract__r.FEC_Primary_Phone__c,
                    FEC_Delivery_Option_2__c,
                    FEC_Recipient_Name__c,
                    FEC_Recipient_Phone_Number__c,
                    FEC_Channel__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            if (rows.isEmpty()) {
                out.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Case' });
                return out;
            }
            Case c = rows[0];
            Id histId = c.FEC_Account_or_Contract__c;
            FEC_Customer_History__c hist = c.FEC_Account_or_Contract__r;
            if (hist != null) {
                out.demographicEmail = hist.FEC_Email__c;
                out.demographicCustomerName = hist.FEC_Customer_Name__c;
                out.demographicPrimaryPhone = hist.FEC_Primary_Phone__c;
            }
            if (histId != null) {
                if (
                    Schema.sObjectType.FEC_Address_Info__c.isAccessible() &&
                    Schema.SObjectType.FEC_Address_Info__c.fields.FEC_Address_Type__c.isAccessible() &&
                    Schema.SObjectType.FEC_Address_Info__c.fields.FEC_Full_Address__c.isAccessible() &&
                    Schema.SObjectType.FEC_Address_Info__c.fields.FEC_Mailing_Address__c.isAccessible()
                ) {
                    for (FEC_Address_Info__c a : [
                        SELECT Id, FEC_Address_Type__c, FEC_Full_Address__c, FEC_Mailing_Address__c,
                            FEC_Building__c, FEC_Number__c, FEC_Street__c,
                            FEC_District__c, FEC_District__r.FEC_Name_VN__c, FEC_Ward_Text__c,
                            FEC_Province__c, FEC_Province__r.FEC_Name_VN__c, FEC_Province_Text__c
                        FROM FEC_Address_Info__c
                        WHERE FEC_Customer_History__c = :histId
                        ORDER BY FEC_Address_Type__c
                    ]) {
                        AddressRowDTO row = new AddressRowDTO();
                        row.id = a.Id;
                        row.addressType = a.FEC_Address_Type__c;
                        String wardLabel = String.isNotBlank(a.FEC_Ward_Text__c)
                            ? a.FEC_Ward_Text__c
                            : (a.FEC_District__r == null ? null : a.FEC_District__r.FEC_Name_VN__c);
                        String provinceLabel = String.isNotBlank(a.FEC_Province_Text__c)
                            ? a.FEC_Province_Text__c
                            : (a.FEC_Province__r == null ? null : a.FEC_Province__r.FEC_Name_VN__c);
                        row.address = a.FEC_Full_Address__c;
                        row.mailingAddressLabel = a.FEC_Mailing_Address__c == null
                            ? FEC_ConstantCommon.STR_EMPTY
                            : String.valueOf(a.FEC_Mailing_Address__c);
                        row.building = a.FEC_Building__c;
                        row.streetNumber = a.FEC_Number__c;
                        row.street = a.FEC_Street__c;
                        row.wardRecordId = a.FEC_District__c == null ? null : String.valueOf(a.FEC_District__c);
                        row.provinceRecordId = a.FEC_Province__c == null ? null : String.valueOf(a.FEC_Province__c);
                        row.wardLabel = wardLabel;
                        row.provinceLabel = provinceLabel;
                        out.addresses.add(row);
                    }
                }
            }
            out.deliveryOptions = describePicklist(OBJ_CASE, FLD_DELIVERY);
            out.wardOptions = mergePicklistOptions(
                describePicklist(OBJ_ADDRESS, 'FEC_Ward__c'),
                describePicklist(OBJ_ADDRESS, 'FEC_Ward_Text__c')
            );
            out.provinceOptions = mergePicklistOptions(
                describePicklist(OBJ_ADDRESS, 'FEC_Province_City__c'),
                describePicklist(OBJ_ADDRESS, 'FEC_Province__c')
            );
            if (caseFields.containsKey(flc(FLD_DELIVERY))) {
                out.savedDeliveryOption = (String) c.get(FLD_DELIVERY);
            }
            if (caseFields.containsKey(flc(FLD_RECIPIENT_NAME))) {
                out.savedRecipientName = (String) c.get(FLD_RECIPIENT_NAME);
            }
            if (caseFields.containsKey(flc(FLD_RECIPIENT_PHONE))) {
                out.savedRecipientPhone = (String) c.get(FLD_RECIPIENT_PHONE);
            }
            String selectedAddressApi = resolveCaseSelectedAddressFieldApi();
            if (String.isNotBlank(selectedAddressApi) && caseFields.containsKey(flc(selectedAddressApi))) {
                List<SObject> selectedRows = Database.query(
                    'SELECT ' + selectedAddressApi + ' FROM Case WHERE Id = :caseId LIMIT 1'
                );
                if (!selectedRows.isEmpty()) {
                    Object selectedAddressVal = selectedRows[0].get(selectedAddressApi);
                    out.savedSelectedAddressId = selectedAddressVal == null ? null : String.valueOf(selectedAddressVal);
                }
            }
            out.savedTemporaryEmail = loadTemporaryEmailFromContactList(c);
            out.verifyInformationOptions = describePicklist(OBJ_ADDITIONAL_INFO, FLD_AI_VERIFY);
            out.callbackOptions = describePicklist(OBJ_ADDITIONAL_INFO, FLD_AI_CALLBACK);
            if (Schema.sObjectType.FEC_Additional_Info__c.isAccessible()) {
                List<FEC_Additional_Info__c> aiRows = [
                    SELECT Id, FEC_Verify_Information__c, FEC_Callback__c
                    FROM FEC_Additional_Info__c
                    WHERE FEC_Case__c = :caseId
                    LIMIT 1
                ];
                if (!aiRows.isEmpty()) {
                    out.additionalInfoId = aiRows[0].Id;
                    out.savedVerifyInformation = aiRows[0].FEC_Verify_Information__c;
                    out.savedCallback = aiRows[0].FEC_Callback__c;
                }
            }
            for (String cashApi : CASE_CASH24_FIELD_CANDIDATES) {
                if (!caseFields.containsKey(flc(cashApi))) {
                    continue;
                }
                List<SObject> cashOnly = Database.query(
                    'SELECT ' + cashApi + ' FROM Case WHERE Id = :caseId LIMIT 1'
                );
                if (!cashOnly.isEmpty()) {
                    out.savedCash24ContractText = (String) cashOnly[0].get(cashApi);
                }
                break;
            }
            out.success = true;
        } catch (Exception ex) {
            out.errorMessage = ex.getMessage();
        }
        return out;
    }

    @AuraEnabled
    public static ValidationResultDTO validateForComplete(Id caseId, String payloadJson) {
        InitDataDTO init = getInitData(caseId);
        SavePayloadDTO p = parsePayload(payloadJson);
        return runValidation(init, p, true, true);
    }

    @AuraEnabled
    public static ValidationResultDTO saveForm(Id caseId, String payloadJson) {
        ValidationResultDTO vr = new ValidationResultDTO();
        InitDataDTO init = getInitData(caseId);
        if (!init.success) {
            vr.addFail(init.errorMessage != null ? init.errorMessage : System.Label.FEC_Cannot_Refresh_Data);
            return vr;
        }
        SavePayloadDTO p = parsePayload(payloadJson);
        vr = runValidation(init, p, false, true);
        if (!vr.valid) {
            return vr;
        }
        return persistClosureForm(caseId, init, p);
    }

    @AuraEnabled
    public static ValidationResultDTO saveFormDraft(Id caseId, String payloadJson) {
        ValidationResultDTO vr = new ValidationResultDTO();
        InitDataDTO init = getInitData(caseId);
        if (!init.success) {
            vr.addFail(init.errorMessage != null ? init.errorMessage : System.Label.FEC_Cannot_Refresh_Data);
            return vr;
        }
        SavePayloadDTO p = parsePayload(payloadJson);
        vr = runValidation(init, p, false, false);
        if (!vr.valid) {
            return vr;
        }
        return persistClosureForm(caseId, init, p);
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistEntryDTO> searchAdministrativeUnits(String objectApiName, String searchKey, Id provinceId) {
        List<PicklistEntryDTO> opts = new List<PicklistEntryDTO>();
        if (String.isBlank(objectApiName) || !ADMIN_UNIT_OBJECTS.contains(objectApiName)) {
            return opts;
        }
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(objectApiName) || !gd.get(objectApiName).getDescribe().isAccessible()) {
            return opts;
        }
        String term = searchKey == null ? FEC_ConstantCommon.STR_EMPTY : searchKey.trim();
        String likeTerm = '%' + term + '%';
        Boolean hasSearchTerm = String.isNotBlank(term);
        Id countryId = resolveCountryIdByCode(COUNTRY_CODE_VN);
        if (countryId == null) {
            return opts;
        }
        if (objectApiName == 'FEC_Province__c') {
            if (hasSearchTerm) {
                for (FEC_Province__c row : [
                    SELECT Id, FEC_Name_VN__c
                    FROM FEC_Province__c
                    WHERE FEC_Country__c = :countryId
                    AND FEC_Name_VN__c != null
                    AND FEC_Name_VN__c LIKE :likeTerm
                    ORDER BY FEC_Name_VN__c
                ]) {
                    opts.add(new PicklistEntryDTO(row.FEC_Name_VN__c, (String) row.Id));
                }
            } else {
                for (FEC_Province__c row : [
                    SELECT Id, FEC_Name_VN__c
                    FROM FEC_Province__c
                    WHERE FEC_Country__c = :countryId
                    AND FEC_Name_VN__c != null
                    ORDER BY FEC_Name_VN__c
                ]) {
                    opts.add(new PicklistEntryDTO(row.FEC_Name_VN__c, (String) row.Id));
                }
            }
            return opts;
        }
        if (provinceId == null) {
            return opts;
        }
        if (hasSearchTerm) {
            for (FEC_District__c row : [
                SELECT Id, FEC_Name_VN__c
                FROM FEC_District__c
                WHERE FEC_Province__c = :provinceId
                AND FEC_Country__c = :countryId
                AND FEC_Name_VN__c != null
                AND FEC_Name_VN__c LIKE :likeTerm
                ORDER BY FEC_Name_VN__c
            ]) {
                opts.add(new PicklistEntryDTO(row.FEC_Name_VN__c, (String) row.Id));
            }
        } else {
            for (FEC_District__c row : [
                SELECT Id, FEC_Name_VN__c
                FROM FEC_District__c
                WHERE FEC_Province__c = :provinceId
                AND FEC_Country__c = :countryId
                AND FEC_Name_VN__c != null
                ORDER BY FEC_Name_VN__c
            ]) {
                opts.add(new PicklistEntryDTO(row.FEC_Name_VN__c, (String) row.Id));
            }
        }
        return opts;
    }

    @AuraEnabled
    public static void deleteTemporaryAddressRecord(Id addressInfoId) {
        if (addressInfoId == null) {
            return;
        }
        if (!Schema.sObjectType.FEC_Address_Info__c.isDeletable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
        }
        delete as user [SELECT Id FROM FEC_Address_Info__c WHERE Id = :addressInfoId LIMIT 1];
    }

    @AuraEnabled
    public static Id upsertTemporaryAddress(Id caseId, String payloadJson) {
        SavePayloadDTO p = parsePayload(payloadJson);
        if (p.tempAddressParts == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Temporary address'}));
        }
        TempAddressPartsDTO t = p.tempAddressParts;
        validateTempAddressParts(t);
        Id histId = resolveCustomerHistoryId(caseId);
        String line = buildTemporaryAddressLine(t);
        if (String.isNotBlank(p.tempAddressRecordId)) {
            return updateExistingTemporaryAddress((Id) p.tempAddressRecordId, caseId, histId, line, t);
        }
        if (!Schema.sObjectType.FEC_Address_Info__c.isCreateable()) {
            throw new AuraHandledException(System.Label.FEC_MSG_Insufficient_Access);
        }
        SObject addr = Schema.getGlobalDescribe().get(OBJ_ADDRESS).newSObject(null);
        addr.put('FEC_Customer_History__c', histId);
        putIfCreateable(addr, 'Name', 'Temporary-' + String.valueOf(Crypto.getRandomInteger()));
        putIfCreateable(addr, 'FEC_Case__c', caseId);
        putIfCreateable(addr, 'FEC_Country__c', resolveCountryIdByCode(COUNTRY_CODE_VN));
        applyAddressLineAndComponents(addr, line, t, true);
        SObjectAccessDecision dec = Security.stripInaccessible(
            AccessType.CREATABLE,
            new List<SObject>{ addr }
        );
        List<SObject> toIns = dec.getRecords();
        if (toIns.isEmpty()) {
            throw new AuraHandledException(System.Label.FEC_MSG_Insufficient_Access);
        }
        insert as user toIns;
        return toIns[0].Id;
    }

    private static void validateTempAddressParts(TempAddressPartsDTO t) {
        if (
            String.isBlank(t.building) ||
            String.isBlank(t.streetNumber) ||
            String.isBlank(t.street) ||
            String.isBlank(t.wardLabel) ||
            String.isBlank(t.provinceLabel)
        ) {
            throw new AuraHandledException(MSG_NOTI_01);
        }
    }

    private static Id resolveCustomerHistoryId(Id caseId) {
        List<SObject> caseRows = Database.query(
            'SELECT Id, FEC_Account_or_Contract__c, ' +
            'FEC_Account_or_Contract__r.FEC_CIF_Number__c, ' +
            'FEC_Channel__c ' +
            'FROM Case WHERE Id = :caseId LIMIT 1'
        );
        if (caseRows.isEmpty()) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Case' }));
        }
        Id histId = (Id) caseRows[0].get('FEC_Account_or_Contract__c');
        if (histId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Customer History' }));
        }
        return histId;
    }

    private static String buildTemporaryAddressLine(TempAddressPartsDTO t) {
        return String.join(
            new List<String>{
                t.building.trim(),
                t.streetNumber.trim(),
                t.street.trim(),
                t.wardLabel.trim(),
                t.provinceLabel.trim()
            },
            ', '
        );
    }

    private static Id updateExistingTemporaryAddress(Id rowId, Id caseId, Id histId, String line, TempAddressPartsDTO t) {
        if (!Schema.sObjectType.FEC_Address_Info__c.isUpdateable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Update_Permission);
        }
        FEC_Address_Info__c row = [
            SELECT Id, FEC_Customer_History__c
            FROM FEC_Address_Info__c
            WHERE Id = :rowId
            LIMIT 1
        ];
        if (row.FEC_Customer_History__c != histId) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Invalid, new List<String>{'Address'}));
        }
        SObject addr = row;
        putIfUpdateable(addr, 'FEC_Case__c', caseId);
        putIfUpdateable(addr, 'FEC_Country__c', resolveCountryIdByCode(COUNTRY_CODE_VN));
        applyAddressLineAndComponents(addr, line, t, false);
        SObjectAccessDecision dec = Security.stripInaccessible(
            AccessType.UPDATABLE,
            new List<SObject>{ addr }
        );
        if (dec.getRecords().isEmpty()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Field_Update_Permission);
        }
        update as user dec.getRecords();
        return rowId;
    }

    private static void applyAddressLineAndComponents(SObject addr, String line, TempAddressPartsDTO t, Boolean forInsert) {
        if (forInsert) {
            putIfCreateable(addr, 'FEC_Address_Type__c', FEC_ConstantCommon.CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY);
        } else {
            putIfUpdateable(addr, 'FEC_Address_Type__c', FEC_ConstantCommon.CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY);
        }
        if (forInsert) {
            putIfCreateable(addr, 'FEC_Building__c', t.building.trim());
            putIfCreateable(addr, 'FEC_Number__c', t.streetNumber.trim());
            putIfCreateable(addr, 'FEC_Street__c', t.street.trim());
            putIfCreateable(addr, 'FEC_Ward_Text__c', t.wardLabel.trim());
            putIfCreateable(addr, 'FEC_Province_Text__c', t.provinceLabel.trim());
        } else {
            putIfUpdateable(addr, 'FEC_Building__c', t.building.trim());
            putIfUpdateable(addr, 'FEC_Number__c', t.streetNumber.trim());
            putIfUpdateable(addr, 'FEC_Street__c', t.street.trim());
            putIfUpdateable(addr, 'FEC_Ward_Text__c', t.wardLabel.trim());
            putIfUpdateable(addr, 'FEC_Province_Text__c', t.provinceLabel.trim());
        }
        if (String.isNotBlank(t.wardRecordId)) {
            try {
                if (forInsert) {
                    putIfCreateable(addr, 'FEC_District__c', (Id) t.wardRecordId);
                } else {
                    putIfUpdateable(addr, 'FEC_District__c', (Id) t.wardRecordId);
                }
            } catch (Exception ignore) {
            }
        }
        if (String.isNotBlank(t.provinceRecordId)) {
            try {
                if (forInsert) {
                    putIfCreateable(addr, 'FEC_Province__c', (Id) t.provinceRecordId);
                } else {
                    putIfUpdateable(addr, 'FEC_Province__c', (Id) t.provinceRecordId);
                }
            } catch (Exception ignore) {
            }
        }
    }

    private static void putIfUpdateable(SObject rec, String api, Object val) {
        Map<String, Schema.SObjectField> m = rec.getSObjectType().getDescribe().fields.getMap();
        String fk = flc(api);
        if (!m.containsKey(fk)) {
            return;
        }
        Schema.DescribeFieldResult d = m.get(fk).getDescribe();
        if (d.isUpdateable()) {
            rec.put(api, val);
        }
    }

    private static SavePayloadDTO parsePayload(String payloadJson) {
        if (String.isBlank(payloadJson)) {
            return new SavePayloadDTO();
        }
        return (SavePayloadDTO) JSON.deserialize(payloadJson, SavePayloadDTO.class);
    }

    private static ValidationResultDTO persistClosureForm(Id caseId, InitDataDTO init, SavePayloadDTO p) {
        ValidationResultDTO vr = new ValidationResultDTO();
        try {
            SObject caseRec = buildCaseUpdate(caseId, p);
            if (caseRec != null && hasNonIdField(caseRec)) {
                SObjectAccessDecision dec = Security.stripInaccessible(
                    AccessType.UPDATABLE,
                    new List<SObject>{ caseRec }
                );
                List<SObject> safe = dec.getRecords();
                if (!safe.isEmpty() && hasNonIdField(safe[0])) {
                    update as user safe;
                }
            }
            persistAdditionalInfoRow(caseId, init.additionalInfoId, p.verifyInformation, p.callback);
            if (p.deliveryEmailSelected == true) {
                persistTemporaryEmailToContactList(caseId, p);
            }
            vr.valid = true;
        } catch (Exception ex) {
            vr.valid = false;
            vr.messages.add(ex.getMessage());
        }
        return vr;
    }

    private static ValidationResultDTO runValidation(InitDataDTO init, SavePayloadDTO p, Boolean forComplete, Boolean requireDelivery) {
        ValidationResultDTO r = new ValidationResultDTO();
        if (!init.success) {
            r.addFail(init.errorMessage != null ? init.errorMessage : System.Label.FEC_Cannot_Refresh_Data);
            return r;
        }
        Boolean hasEmail = p.deliveryEmailSelected == true;
        Boolean hasAddr = p.deliveryAddressSelected == true;
        Boolean hasOffice = p.deliveryOfficeSelected == true;
        Integer cnt = 0;
        if (hasEmail) {
            cnt++;
        }
        if (hasAddr) {
            cnt++;
        }
        if (hasOffice) {
            cnt++;
        }
        if (cnt == 0) {
            if (forComplete || requireDelivery) {
                r.addFail(MSG_NOTI_02);
            }
        }
        if (hasAddr && hasOffice) {
            r.addFail(MSG_NOTI_02);
        }
        if (cnt > 2) {
            r.addFail(MSG_NOTI_02);
        }
        if (hasEmail) {
            String channel = p.emailDeliveryChannel;
            if (String.isBlank(channel) && p.useExistingEmail == true) {
                channel = FEC_ConstantCommon.CONTRACT_CLOSURE_EMAIL_CHANNEL_C360;
            }
            String tempMail = p.temporaryEmail != null ? p.temporaryEmail.trim() : FEC_ConstantCommon.STR_EMPTY;
            Boolean hasTemp = String.isNotBlank(tempMail);
            if (hasTemp && !EMAIL_PAT.matcher(tempMail).matches()) {
                r.addFail(MSG_NOTI_03);
            }
            if (forComplete || requireDelivery) {
                Boolean hasDemo = String.isNotBlank(init.demographicEmail);
                if (!hasDemo) {
                    if (!hasTemp) {
                        r.addFail(MSG_TEMP_EMAIL_REQUIRED);
                    }
                } else {
                    if (
                        channel != FEC_ConstantCommon.CONTRACT_CLOSURE_EMAIL_CHANNEL_C360 &&
                        channel != FEC_ConstantCommon.CONTRACT_CLOSURE_EMAIL_CHANNEL_TEMPORARY
                    ) {
                        r.addFail(MSG_NOTI_02);
                    } else if (channel == FEC_ConstantCommon.CONTRACT_CLOSURE_EMAIL_CHANNEL_TEMPORARY && !hasTemp) {
                        r.addFail(MSG_TEMP_EMAIL_REQUIRED);
                    } else if (channel == FEC_ConstantCommon.CONTRACT_CLOSURE_EMAIL_CHANNEL_C360 && hasTemp) {
                        r.addFail(MSG_NOTI_02);
                    }
                }
            }
        }
        if (hasAddr) {
            String rn = p.recipientName != null ? p.recipientName.trim() : FEC_ConstantCommon.STR_EMPTY;
            String rp = p.recipientPhone != null ? FEC_CommonUltils.normalizePhone(p.recipientPhone) : FEC_ConstantCommon.STR_EMPTY;
            if (forComplete && String.isBlank(rn)) {
                r.addFail(MSG_NOTI_01);
            }
            if (forComplete && String.isBlank(rp)) {
                r.addFail(MSG_NOTI_01);
            }
            if (String.isNotBlank(rp) && !FEC_CommonUltils.isPhone(rp)) {
                r.addFail(MSG_NOTI_16);
            }
            if (forComplete || requireDelivery) {
                Boolean hasRow = String.isNotBlank(p.selectedAddressId);
                Boolean hasTempLine = String.isNotBlank(
                    p.temporaryAddressDisplay != null ? p.temporaryAddressDisplay.trim() : FEC_ConstantCommon.STR_EMPTY
                );
                if (!hasRow && !hasTempLine) {
                    r.addFail(MSG_ADDRESS_REQUIRED);
                }
                if (hasRow) {
                    Boolean rowLineOk = false;
                    if (init.addresses != null) {
                        for (AddressRowDTO row : init.addresses) {
                            if (row != null && row.id == p.selectedAddressId) {
                                rowLineOk = String.isNotBlank(
                                    row.address != null ? row.address.trim() : FEC_ConstantCommon.STR_EMPTY
                                );
                                break;
                            }
                        }
                    }
                    if (!rowLineOk) {
                        r.addFail(MSG_ADDRESS_ROW_EMPTY);
                    }
                }
            }
        }
        return r;
    }

    private static SObject buildCaseUpdate(Id caseId, SavePayloadDTO p) {
        Map<String, Schema.SObjectField> fm = Case.SObjectType.getDescribe().fields.getMap();
        SObject c = Case.SObjectType.newSObject();
        c.put('Id', caseId);
        Schema.SObjectField fDel = fm.get(flc(FLD_DELIVERY));
        if (fDel != null && fDel.getDescribe().isUpdateable()) {
            String combined = p.deliveryOptionCombined;
            if (String.isBlank(combined) && p.deliveryValues != null && !p.deliveryValues.isEmpty()) {
                combined = String.join(p.deliveryValues, ';');
            }
            c.put(FLD_DELIVERY, combined);
        }
        Schema.SObjectField fRn = fm.get(flc(FLD_RECIPIENT_NAME));
        if (fRn != null && fRn.getDescribe().isUpdateable()) {
            c.put(FLD_RECIPIENT_NAME, p.recipientName);
        }
        Schema.SObjectField fRp = fm.get(flc(FLD_RECIPIENT_PHONE));
        if (fRp != null && fRp.getDescribe().isUpdateable()) {
            c.put(FLD_RECIPIENT_PHONE, FEC_CommonUltils.normalizePhone(p.recipientPhone));
        }
        if (String.isNotBlank(p.selectedAddressId)) {
            putCaseSelectedAddress(c, p.selectedAddressId);
        }
        putCaseCash24OnRecord(c, p.cash24ContractText);
        return c;
    }

    private static void putCaseSelectedAddress(SObject caseRec, String selectedAddressId) {
        String selectedAddressApi = resolveCaseSelectedAddressFieldApi();
        if (String.isBlank(selectedAddressApi)) {
            return;
        }
        Map<String, Schema.SObjectField> fm = Case.SObjectType.getDescribe().fields.getMap();
        Schema.SObjectField sf = fm.get(flc(selectedAddressApi));
        if (sf == null) {
            return;
        }
        Schema.DisplayType t = sf.getDescribe().getType();
        if (t == DisplayType.REFERENCE) {
            caseRec.put(selectedAddressApi, (Id) selectedAddressId);
            return;
        }
        caseRec.put(selectedAddressApi, selectedAddressId);
    }

    private static Id resolveCountryIdByCode(String countryCode) {
        if (countryCode == COUNTRY_CODE_VN && countryIdVnCache != null) {
            return countryIdVnCache;
        }
        if (String.isBlank(countryCode)) {
            return null;
        }
        if (!Schema.sObjectType.FEC_Country__c.isAccessible()) {
            return null;
        }
        List<FEC_Country__c> rows = [
            SELECT Id, FEC_Code__c
            FROM FEC_Country__c
            WHERE FEC_Code__c = :countryCode
            LIMIT 1
        ];
        if (!rows.isEmpty()) {
            if (countryCode == COUNTRY_CODE_VN) {
                countryIdVnCache = rows[0].Id;
            }
            return rows[0].Id;
        }
        return null;
    }

    private static String resolveCaseSelectedAddressFieldApi() {
        if (String.isNotBlank(caseSelectedAddressFieldApiCache)) {
            return caseSelectedAddressFieldApiCache;
        }
        Map<String, Schema.SObjectField> fm = Case.SObjectType.getDescribe().fields.getMap();
        String fallbackApi;
        for (String api : new List<String>{ 'FEC_Selected_Address__c', 'FEC_Selected_Address_Info__c', 'FEC_Selected_Address_Id__c' }) {
            Schema.SObjectField fieldRef = fm.get(flc(api));
            if (fieldRef != null && fieldRef.getDescribe().isUpdateable()) {
                caseSelectedAddressFieldApiCache = fieldRef.getDescribe().getName();
                return caseSelectedAddressFieldApiCache;
            }
        }
        for (String apiLower : fm.keySet()) {
            Schema.DescribeFieldResult d = fm.get(apiLower).getDescribe();
            if (!d.isUpdateable()) {
                continue;
            }
            Boolean isAddressInfoRef = false;
            if (d.getType() == DisplayType.REFERENCE) {
                for (Schema.SObjectType refType : d.getReferenceTo()) {
                    if (refType.getDescribe().getName() == 'FEC_Address_Info__c') {
                        isAddressInfoRef = true;
                        break;
                    }
                }
            }
            String nameLower = d.getName().toLowerCase();
            String labelLower = d.getLabel().toLowerCase();
            Boolean isSelectedAddressName =
                (nameLower.contains('selected') && nameLower.contains('address')) ||
                (labelLower.contains('selected') && labelLower.contains('address'));
            if (!isAddressInfoRef && !isSelectedAddressName) {
                continue;
            }
            if (fallbackApi == null) {
                fallbackApi = d.getName();
            }
            if (
                (nameLower.contains('selected') && nameLower.contains('address')) ||
                (labelLower.contains('selected') && labelLower.contains('address'))
            ) {
                caseSelectedAddressFieldApiCache = d.getName();
                return caseSelectedAddressFieldApiCache;
            }
        }
        caseSelectedAddressFieldApiCache = fallbackApi;
        return caseSelectedAddressFieldApiCache;
    }

    private static void putCaseCash24OnRecord(SObject caseRec, String raw) {
        if (raw == null) {
            return;
        }
        String v = raw.trim();
        Map<String, Schema.SObjectField> fm = Case.SObjectType.getDescribe().fields.getMap();
        for (String api : CASE_CASH24_FIELD_CANDIDATES) {
            Schema.SObjectField f = fm.get(flc(api));
            if (f == null || !f.getDescribe().isUpdateable()) {
                continue;
            }
            Schema.DisplayType t = f.getDescribe().getType();
            if (t == DisplayType.STRING || t == DisplayType.TEXTAREA) {
                caseRec.put(api, v);
                return;
            }
        }
    }

    private static String loadTemporaryEmailFromContactList(Case caseRow) {
        if (caseRow == null) {
            return null;
        }
        if (!Schema.sObjectType.FEC_Contact_List__c.isAccessible()) {
            return null;
        }
        Map<String, Schema.SObjectField> clf = Schema.SObjectType.FEC_Contact_List__c.fields.getMap();
        String fk = flc(FLD_TEMP_EMAIL);
        if (!clf.containsKey(fk) || !clf.get(fk).getDescribe().isAccessible()) {
            return null;
        }
        List<FEC_Contact_List__c> matches = FEC_UpdateCustomerContact.getMatchingContactList(
            caseRow,
            FEC_UpdateCustomerContact.EMAIL_UPDATE
        );
        if (matches.isEmpty()) {
            return null;
        }
        Id clId = matches[0].Id;
        List<SObject> teRows = Database.query(
            'SELECT Id, ' +
                FLD_TEMP_EMAIL +
                ' FROM ' +
                OBJ_CONTACT_LIST +
                ' WHERE Id = :clId LIMIT 1'
        );
        if (teRows.isEmpty()) {
            return null;
        }
        return (String) teRows[0].get(FLD_TEMP_EMAIL);
    }

    @TestVisible
    private static void persistTemporaryEmailToContactList(Id caseId, SavePayloadDTO p) {
        Map<String, Schema.SObjectField> clf = Schema.SObjectType.FEC_Contact_List__c.fields.getMap();
        String fk = flc(FLD_TEMP_EMAIL);
        if (!clf.containsKey(fk)) {
            return;
        }
        Schema.DescribeFieldResult fdTe = clf.get(fk).getDescribe();
        List<SObject> caseRows = Database.query(
            'SELECT Id, FEC_Account_or_Contract__c, FEC_Channel__c FROM Case WHERE Id = :caseId LIMIT 1'
        );
        if (caseRows.isEmpty()) {
            return;
        }
        Case caseRec = (Case) caseRows[0];
        String te = p.temporaryEmail != null ? p.temporaryEmail.trim() : null;
        if (String.isBlank(te)) {
            te = null;
        }
        List<FEC_Contact_List__c> matches = FEC_UpdateCustomerContact.getMatchingContactList(
            caseRec,
            FEC_UpdateCustomerContact.EMAIL_UPDATE
        );
        if (!matches.isEmpty()) {
            if (!Schema.sObjectType.FEC_Contact_List__c.isUpdateable() || !fdTe.isUpdateable()) {
                return;
            }
            SObject row = matches[0];
            row.put(FLD_TEMP_EMAIL, te);
            SObjectAccessDecision dec = Security.stripInaccessible(
                AccessType.UPDATABLE,
                new List<SObject>{ row }
            );
            List<SObject> safe = dec.getRecords();
            if (!safe.isEmpty()) {
                update as user safe;
            }
        } else if (te != null) {
            if (!Schema.sObjectType.FEC_Contact_List__c.isCreateable() || !fdTe.isCreateable()) {
                return;
            }
            Id histId = caseRec.FEC_Account_or_Contract__c;
            if (histId == null) {
                return;
            }
            SObject n = Schema.getGlobalDescribe().get(OBJ_CONTACT_LIST).newSObject(null);
            n.put(FLD_CL_HISTORY, histId);
            n.put(FLD_CL_CHANNEL, caseRec.FEC_Channel__c);
            n.put(FLD_CL_COMM_TYPE, FEC_ConstantCommon.EMAIL);
            Map<String, Schema.SObjectField> clfAll = Schema.SObjectType.FEC_Contact_List__c.fields.getMap();
            if (
                clfAll.containsKey(flc(FLD_CL_CONTACT_STRING)) &&
                clfAll.get(flc(FLD_CL_CONTACT_STRING)).getDescribe().isCreateable()
            ) {
                if (
                    Schema.sObjectType.FEC_Customer_History__c.isAccessible() &&
                    Schema.SObjectType.FEC_Customer_History__c.fields.FEC_Email__c.isAccessible()
                ) {
                    List<FEC_Customer_History__c> hrs = [
                        SELECT FEC_Email__c
                        FROM FEC_Customer_History__c
                        WHERE Id = :histId
                        LIMIT 1
                    ];
                    if (!hrs.isEmpty() && String.isNotBlank(hrs[0].FEC_Email__c)) {
                        n.put(FLD_CL_CONTACT_STRING, hrs[0].FEC_Email__c);
                    }
                }
            }
            n.put(FLD_TEMP_EMAIL, te);
            SObjectAccessDecision decIns = Security.stripInaccessible(
                AccessType.CREATABLE,
                new List<SObject>{ n }
            );
            List<SObject> toIns = decIns.getRecords();
            if (!toIns.isEmpty()) {
                insert as user toIns;
            }
        }
    }

    private static void persistAdditionalInfoRow(Id caseId, Id rowId, String verify, String callback) {
        if (String.isBlank(verify) && String.isBlank(callback)) {
            return;
        }
        if (!Schema.sObjectType.FEC_Additional_Info__c.isAccessible()) {
            return;
        }
        if (rowId != null) {
            if (!Schema.sObjectType.FEC_Additional_Info__c.isUpdateable()) {
                return;
            }
            FEC_Additional_Info__c u = new FEC_Additional_Info__c(
                Id = rowId,
                FEC_Verify_Information__c = verify,
                FEC_Callback__c = callback
            );
            SObjectAccessDecision dec = Security.stripInaccessible(
                AccessType.UPDATABLE,
                new List<SObject>{ u }
            );
            if (!dec.getRecords().isEmpty()) {
                update as user dec.getRecords();
            }
        } else {
            if (!Schema.sObjectType.FEC_Additional_Info__c.isCreateable()) {
                return;
            }
            FEC_Additional_Info__c n = new FEC_Additional_Info__c(
                FEC_Case__c = caseId,
                FEC_Verify_Information__c = verify,
                FEC_Callback__c = callback
            );
            SObjectAccessDecision dec = Security.stripInaccessible(
                AccessType.CREATABLE,
                new List<SObject>{ n }
            );
            if (!dec.getRecords().isEmpty()) {
                insert as user dec.getRecords();
            }
        }
    }

    private static void putIfCreateable(SObject rec, String api, Object val) {
        Map<String, Schema.SObjectField> m = rec.getSObjectType().getDescribe().fields.getMap();
        String fk = flc(api);
        if (!m.containsKey(fk)) {
            return;
        }
        Schema.DescribeFieldResult d = m.get(fk).getDescribe();
        if (d.isCreateable()) {
            rec.put(api, val);
        }
    }

    private static Boolean hasNonIdField(SObject rec) {
        Map<String, Object> pop = rec.getPopulatedFieldsAsMap();
        if (pop == null) {
            return false;
        }
        for (String k : pop.keySet()) {
            if (k != 'Id') {
                return true;
            }
        }
        return false;
    }

    private static String flc(String api) {
        return api != null ? api.toLowerCase() : FEC_ConstantCommon.STR_EMPTY;
    }

    private static List<PicklistEntryDTO> describePicklist(String obj, String fieldApi) {
        List<PicklistEntryDTO> opts = new List<PicklistEntryDTO>();
        for (FEC_CommonUltils.PicklistOption po : FEC_CommonUltils.getPicklistOptionsWithAccess(obj, fieldApi)) {
            opts.add(new PicklistEntryDTO(po.label, po.value));
        }
        return opts;
    }

    private static List<PicklistEntryDTO> mergePicklistOptions(
        List<PicklistEntryDTO> a,
        List<PicklistEntryDTO> b
    ) {
        if (!a.isEmpty()) {
            return a;
        }
        return b;
    }
}