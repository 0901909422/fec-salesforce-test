@IsTest
private class FEC_ZNSNotificationCallout_Test {

    private static final String TEMPLATE_ID_WITH_MAPPING = 'UT_ZNS_TEMPLATE_001';
    private static final String TEMPLATE_ID_NO_MAPPING = 'UT_ZNS_TEMPLATE_EMPTY';

    @TestSetup
    static void setupData() {
        setupApiSetting();

        Case testCase = new Case(
            Subject = '2026-06-20T18:20:28.280Z',
            Status = getPicklistValue(Case.Status, 'New'),
            Origin = getPicklistValue(Case.Origin, 'Phone'),
            SuppliedName = '20/06/2026',
            SuppliedPhone = '2026/06/20',
            SuppliedCompany = 'not-a-date',
            Description = '1234567890123456789'
        );

        insert testCase;

        List<FEC_Notification_ZNS_Param_Mapping__c> mappings =
            new List<FEC_Notification_ZNS_Param_Mapping__c>{
                buildMapping(
                    'blank_email_value',
                    TEMPLATE_ID_WITH_MAPPING,
                    'Case',
                    'SuppliedEmail',
                    'STRING',
                    FEC_ConstantCommon.NOTIFICATION_GET_LAST_4_DIGIT_CARD
                ),
                buildMapping(
                    'card_last4_short',
                    TEMPLATE_ID_WITH_MAPPING,
                    'Case',
                    'SuppliedPhone',
                    'STRING',
                    FEC_ConstantCommon.NOTIFICATION_GET_LAST_4_DIGIT_CARD
                ),
                buildMapping(
                    'card_last4_success',
                    TEMPLATE_ID_WITH_MAPPING,
                    'Case',
                    'Description',
                    'STRING',
                    FEC_ConstantCommon.NOTIFICATION_GET_LAST_4_DIGIT_CARD
                ),
                buildMapping(
                    'contact_date_created',
                    TEMPLATE_ID_WITH_MAPPING,
                    'Case',
                    'CreatedDate',
                    'DATE',
                    null
                ),
                buildMapping(
                    'contact_date_dmy',
                    TEMPLATE_ID_WITH_MAPPING,
                    'Case',
                    'SuppliedName',
                    'DATE',
                    null
                ),
                buildMapping(
                    'contact_date_iso',
                    TEMPLATE_ID_WITH_MAPPING,
                    'Case',
                    'Subject',
                    'DATE',
                    null
                ),
                buildMapping(
                    'contact_date_invalid',
                    TEMPLATE_ID_WITH_MAPPING,
                    'Case',
                    'SuppliedCompany',
                    'DATE',
                    null
                ),
                buildMapping(
                    'contact_date_ymd_slash',
                    TEMPLATE_ID_WITH_MAPPING,
                    'Case',
                    'SuppliedPhone',
                    'DATE',
                    null
                ),
                buildMapping(
                    'date_get_day',
                    TEMPLATE_ID_WITH_MAPPING,
                    'Case',
                    'CreatedDate',
                    'DATE',
                    FEC_ConstantCommon.NOTIFICATION_GET_DAY_OF_DATE
                ),
                buildMapping(
                    'normal_text',
                    TEMPLATE_ID_WITH_MAPPING,
                    'Case',
                    'Description',
                    'STRING',
                    null
                ),
                buildMapping(
                    'unsupported_object',
                    TEMPLATE_ID_WITH_MAPPING,
                    'Account',
                    'Name',
                    'STRING',
                    null
                ),
                buildMapping(
                    'invalid_field',
                    TEMPLATE_ID_WITH_MAPPING,
                    'Case',
                    'Not_Existing_Field__c',
                    'STRING',
                    null
                ),
                buildMapping(
                    'duplicate_param',
                    TEMPLATE_ID_WITH_MAPPING,
                    'Case',
                    'Description',
                    'STRING',
                    null
                ),
                buildMapping(
                    'duplicate_param',
                    TEMPLATE_ID_WITH_MAPPING,
                    'Case',
                    'Subject',
                    'STRING',
                    null
                )
            };

        insert mappings;
    }

    // =========================================================================
    // Parser + DTO tests
    // =========================================================================
    @IsTest
    static void parseSendZnsMessageRequest_shouldParseFullPayloadAndSerializeBack() {
        String jsonBody = JSON.serialize(
            new Map<String, Object>{
                'template_data' => new List<Object>{
                    new Map<String, Object>{
                        'param_name' => 'customer_name',
                        'value' => 'NGUYEN VAN A'
                    },
                    new Map<String, Object>{
                        'param_name' => 'contact_date',
                        'value' => '20/06/2026'
                    }
                },
                'phone' => '84768433784',
                'template_id' => '207490',
                'DateTime' => '2026-06-20T18:20:28.280Z',
                'department' => 'cs',
                'tracking_id' => '1781954428280',
                'Sys' => new Map<String, Object>{
                    'TransID' => 'trans-001',
                    'DateTime' => '2026-06-20T18:20:28.280Z',
                    'RequestorID' => 'PEGA_CSM'
                }
            }
        );

        FEC_ZNSNotificationCallout.SendZnsMessageRequestDto dto =
            FEC_ZNSNotificationCallout.parseSendZnsMessageRequest(jsonBody);

        System.assertEquals('84768433784', dto.phone);
        System.assertEquals('207490', dto.template_id);
        System.assertEquals('2026-06-20T18:20:28.280Z', dto.dateTimeValue);
        System.assertEquals('cs', dto.department);
        System.assertEquals('1781954428280', dto.tracking_id);
        System.assertEquals(2, dto.template_data.size());
        System.assertEquals('customer_name', dto.template_data[0].param_name);
        System.assertEquals('NGUYEN VAN A', dto.template_data[0].value);
        System.assertEquals('trans-001', dto.Sys.TransID);
        System.assertEquals('PEGA_CSM', dto.Sys.RequestorID);

        String serialized = dto.toJson();
        System.assert(serialized.contains('"DateTime"'));
        System.assert(serialized.contains('"template_data"'));
    }

    @IsTest
    static void parseSendZnsMessageRequest_shouldHandleNullListsAndSys() {
        String jsonBody = JSON.serialize(
            new Map<String, Object>{
                'phone' => '84000000000',
                'template_id' => 'TEMPLATE_EMPTY',
                'DateTime' => '2026-06-20T18:20:28.280Z',
                'department' => 'cs',
                'tracking_id' => 'track-empty'
            }
        );

        FEC_ZNSNotificationCallout.SendZnsMessageRequestDto dto =
            FEC_ZNSNotificationCallout.parseSendZnsMessageRequest(jsonBody);

        System.assertEquals('84000000000', dto.phone);
        System.assertEquals('TEMPLATE_EMPTY', dto.template_id);
        System.assertEquals(0, dto.template_data.size());
        System.assertEquals(null, dto.Sys);

        String serialized = dto.toJson();
        System.assert(serialized.contains('"Sys":null'));
    }

    @IsTest
    static void parseSendZnsMessageResponse_shouldParseSuccessAndSerializeBack() {
        String jsonBody = JSON.serialize(
            new Map<String, Object>{
                'Sys' => new Map<String, Object>{
                    'TransID' => 'trans-001',
                    'DateTime' => '2026-06-20T18:20:28.280Z',
                    'Code' => '1',
                    'Description' => 'Success'
                },
                'data' => new Map<String, Object>{
                    'msg_id' => 'MSG001',
                    'sent_time' => '2026-06-20T18:20:30.000Z'
                }
            }
        );

        FEC_ZNSNotificationCallout.SendZnsMessageResponseDto dto =
            FEC_ZNSNotificationCallout.parseSendZnsMessageResponse(jsonBody);

        System.assertEquals(true, dto.isSuccess());
        System.assertEquals('trans-001', dto.Sys.TransID);
        System.assertEquals(1, dto.Sys.Code);
        System.assertEquals('Success', dto.Sys.Description);
        System.assertEquals('MSG001', dto.data.msg_id);

        String serialized = dto.toJson();
        System.assert(serialized.contains('"Code":1'));
        System.assert(serialized.contains('"msg_id"'));
    }

    @IsTest
    static void parseSendZnsMessageResponse_shouldHandleNullSysAndData() {
        FEC_ZNSNotificationCallout.SendZnsMessageResponseDto dto =
            FEC_ZNSNotificationCallout.parseSendZnsMessageResponse('{}');

        System.assertEquals(false, dto.isSuccess());
        System.assertEquals(null, dto.Sys);
        System.assertEquals(null, dto.data);

        String serialized = dto.toJson();
        System.assert(serialized.contains('"Sys":null'));
        System.assert(serialized.contains('"data":null'));
    }

    @IsTest
    static void responseDto_shouldReturnFalse_whenCodeIsNotSuccess() {
        FEC_ZNSNotificationCallout.SendZnsMessageResponseDto dto =
            new FEC_ZNSNotificationCallout.SendZnsMessageResponseDto();

        dto.Sys = new FEC_ZNSNotificationCallout.SendZnsMessageResponseSysInfo();
        dto.Sys.Code = 0;
        dto.Sys.Description = 'Failed';

        System.assertEquals(false, dto.isSuccess());
        System.assert(dto.toJson().contains('"Code":0'));
    }

    @IsTest
    static void templateDataConstructors_shouldWork() {
        FEC_ZNSNotificationCallout.SendZnsMessageTemplateData emptyData =
            new FEC_ZNSNotificationCallout.SendZnsMessageTemplateData();

        emptyData.param_name = 'manual_param';
        emptyData.value = 'manual_value';

        System.assertEquals('manual_param', emptyData.param_name);
        System.assertEquals('manual_value', emptyData.value);

        FEC_ZNSNotificationCallout.SendZnsMessageTemplateData data =
            new FEC_ZNSNotificationCallout.SendZnsMessageTemplateData(
                'customer_name',
                'NGUYEN VAN A'
            );

        System.assertEquals('customer_name', data.param_name);
        System.assertEquals('NGUYEN VAN A', data.value);
    }

    // =========================================================================
    // Callout methods - direct template data
    // =========================================================================
    @IsTest
    static void callSendZNSMessage_shouldReturnTestSuccessResponseAndClearLog() {
        List<FEC_ZNSNotificationCallout.SendZnsMessageTemplateData> templateData =
            new List<FEC_ZNSNotificationCallout.SendZnsMessageTemplateData>{
                new FEC_ZNSNotificationCallout.SendZnsMessageTemplateData(
                    'customer_name',
                    'NGUYEN VAN A'
                )
            };

        Test.startTest();

        FEC_ZNSNotificationCallout.SendZnsMessageResponseDto response =
            FEC_ZNSNotificationCallout.callSendZNSMessage(
                templateData,
                '84768433784',
                '207490'
            );

        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assertEquals(true, response.isSuccess());
        System.assertEquals('TEST_MSG_ID', response.data.msg_id);

        // Null path
        FEC_ZNSNotificationCallout.writeLogSendNoti();
    }

    @IsTest
    static void callSendZNSMessageWithoutLogging_shouldSetResponseLogAndWriteLater() {
        List<FEC_ZNSNotificationCallout.SendZnsMessageTemplateData> templateData =
            new List<FEC_ZNSNotificationCallout.SendZnsMessageTemplateData>{
                new FEC_ZNSNotificationCallout.SendZnsMessageTemplateData(
                    'contact_date',
                    '20/06/2026'
                )
            };

        Test.startTest();

        FEC_ZNSNotificationCallout.SendZnsMessageResponseDto response =
            FEC_ZNSNotificationCallout.callSendZNSMessageWithoutLogging(
                templateData,
                '84768433784',
                '207490'
            );

        FEC_ZNSNotificationCallout.writeLogSendNoti();

        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assertEquals(true, response.isSuccess());

        // Null path after log is cleared
        FEC_ZNSNotificationCallout.writeLogSendNoti();
    }

    // =========================================================================
    // Callout methods - by Case + mapping
    // =========================================================================
    @IsTest
    static void callSendZNSMessageByCase_shouldBuildTemplateDataFromMappings() {
        Case testCase = [
            SELECT Id
            FROM Case
            LIMIT 1
        ];

        Test.startTest();

        FEC_ZNSNotificationCallout.SendZnsMessageResponseDto response =
            FEC_ZNSNotificationCallout.callSendZNSMessageByCase(
                testCase.Id,
                '0768433784',
                TEMPLATE_ID_WITH_MAPPING
            );

        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assertEquals(true, response.isSuccess());
        System.assertEquals('TEST_MSG_ID', response.data.msg_id);
    }

    @IsTest
    static void callSendZNSMessageByCaseWithoutLogging_shouldBuildTemplateDataFromMappings() {
        Case testCase = [
            SELECT Id
            FROM Case
            LIMIT 1
        ];

        Test.startTest();

        FEC_ZNSNotificationCallout.SendZnsMessageResponseDto response =
            FEC_ZNSNotificationCallout.callSendZNSMessageByCaseWithoutLogging(
                testCase.Id,
                '84768433784',
                TEMPLATE_ID_WITH_MAPPING
            );

        FEC_ZNSNotificationCallout.writeLogSendNoti();

        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assertEquals(true, response.isSuccess());
    }

    @IsTest
    static void callSendZNSMessageByCase_shouldHandleBlankTemplateIdAndBlankPhone() {
        Case testCase = [
            SELECT Id
            FROM Case
            LIMIT 1
        ];

        Test.startTest();

        FEC_ZNSNotificationCallout.SendZnsMessageResponseDto response =
            FEC_ZNSNotificationCallout.callSendZNSMessageByCase(
                testCase.Id,
                '',
                ''
            );

        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assertEquals(true, response.isSuccess());
    }

    @IsTest
    static void callSendZNSMessageByCase_shouldHandleNoMappingAndNullCaseId() {
        Test.startTest();

        FEC_ZNSNotificationCallout.SendZnsMessageResponseDto response =
            FEC_ZNSNotificationCallout.callSendZNSMessageByCase(
                null,
                '0768433784',
                TEMPLATE_ID_NO_MAPPING
            );

        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assertEquals(true, response.isSuccess());
    }

    // =========================================================================
    // Helpers
    // =========================================================================
    private static void setupApiSetting() {
        FEC_API_Setting__c setting = FEC_API_Setting__c.getOrgDefaults();

        setting.FEC_Call_Mock__c = false;
        setting.FEC_Endpoint__c = 'https://unit.test';

        if (setting.Id == null) {
            setting.SetupOwnerId = UserInfo.getOrganizationId();
            insert setting;
        } else {
            update setting;
        }
    }

    private static FEC_Notification_ZNS_Param_Mapping__c buildMapping(
        String name,
        String templateId,
        String pageContext,
        String fieldName,
        String paramType,
        String formatFunction
    ) {
        FEC_Notification_ZNS_Param_Mapping__c mapping =
            new FEC_Notification_ZNS_Param_Mapping__c();

        mapping.Name = name;
        mapping.Template_ID__c = templateId;
        mapping.Page_Context__c = pageContext;
        mapping.Field_Name__c = fieldName;
        mapping.Param_Type__c = paramType;
        mapping.Format_Function__c = formatFunction;
        mapping.Accept_Null__c = true;
        mapping.Require__c = false;
        mapping.Min_Length__c = 0;
        mapping.Max_Length__c = 255;

        return mapping;
    }

    private static String getPicklistValue(
        Schema.SObjectField fieldToken,
        String preferredValue
    ) {
        List<Schema.PicklistEntry> entries =
            fieldToken.getDescribe().getPicklistValues();

        for (Schema.PicklistEntry entry : entries) {
            if (
                entry.isActive() &&
                entry.getValue().equalsIgnoreCase(preferredValue)
            ) {
                return entry.getValue();
            }
        }

        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }

        return preferredValue;
    }
}