@IsTest
private class FEC_ZNSNotificationCallout_Test {

    private static void createApiSetting() {
        FEC_API_Setting__c apiSetting = new FEC_API_Setting__c();
        apiSetting.SetupOwnerId = UserInfo.getOrganizationId();
        apiSetting.FEC_Endpoint__c = 'https://example.com';
        insert apiSetting;
    }

    private static List<FEC_ZNSNotificationCallout.SendZnsMessageTemplateData> buildTemplateData() {
        List<FEC_ZNSNotificationCallout.SendZnsMessageTemplateData> templateData =
            new List<FEC_ZNSNotificationCallout.SendZnsMessageTemplateData>();

        templateData.add(
            new FEC_ZNSNotificationCallout.SendZnsMessageTemplateData(
                'company_name',
                'FE CREDIT'
            )
        );

        templateData.add(
            new FEC_ZNSNotificationCallout.SendZnsMessageTemplateData(
                'customer_name',
                'Nguyen Van A'
            )
        );

        templateData.add(
            new FEC_ZNSNotificationCallout.SendZnsMessageTemplateData(
                'product_name',
                'Credit Card'
            )
        );

        return templateData;
    }

    @IsTest
    static void testCallSendZNSMessageSuccessInTestMode() {
        createApiSetting();

        List<FEC_ZNSNotificationCallout.SendZnsMessageTemplateData> templateData =
            buildTemplateData();

        Test.startTest();

        FEC_ZNSNotificationCallout.SendZnsMessageResponseDto response =
            FEC_ZNSNotificationCallout.callSendZNSMessage(
                templateData,
                '84768433784',
                '535626'
            );

        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assertNotEquals(null, response.Sys);
        System.assertEquals(1, response.Sys.Code);
        System.assertEquals('Success', response.Sys.Description);
        System.assertEquals(true, response.isSuccess());

        System.assertNotEquals(null, response.data);
        System.assertEquals('TEST_MSG_ID', response.data.msg_id);
        System.assertNotEquals(null, response.data.sent_time);
    }

    @IsTest
    static void testParseSendZnsMessageRequest() {
        String jsonBody =
            '{"template_data":[' +
                '{"value":"FE CREDIT","param_name":"company_name"},' +
                '{"value":"Nguyen Van A","param_name":"customer_name"},' +
                '{"value":"Credit Card","param_name":"product_name"}' +
            '],' +
            '"phone":"84768433784",' +
            '"template_id":"535626",' +
            '"DateTime":"2026-06-09T11:18:44",' +
            '"department":"cs",' +
            '"Sys":{' +
                '"TransID":"16c74fb8-5cb9-4191-9754-1b915a146dc6",' +
                '"DateTime":"20260609T041844.956 GMT",' +
                '"RequestorID":"PEGA_CSM"' +
            '},' +
            '"tracking_id":"1780978724782"' +
            '}';

        FEC_ZNSNotificationCallout.SendZnsMessageRequestDto dto =
            FEC_ZNSNotificationCallout.parseSendZnsMessageRequest(jsonBody);

        System.assertNotEquals(null, dto);
        System.assertEquals('84768433784', dto.phone);
        System.assertEquals('535626', dto.template_id);
        System.assertEquals('2026-06-09T11:18:44', dto.dateTimeValue);
        System.assertEquals('cs', dto.department);
        System.assertEquals('1780978724782', dto.tracking_id);

        System.assertNotEquals(null, dto.template_data);
        System.assertEquals(3, dto.template_data.size());
        System.assertEquals('company_name', dto.template_data[0].param_name);
        System.assertEquals('FE CREDIT', dto.template_data[0].value);

        System.assertNotEquals(null, dto.Sys);
        System.assertEquals('16c74fb8-5cb9-4191-9754-1b915a146dc6', dto.Sys.TransID);
        System.assertEquals('20260609T041844.956 GMT', dto.Sys.dateTimeValue);
        System.assertEquals('PEGA_CSM', dto.Sys.RequestorID);
    }

    @IsTest
    static void testRequestDtoToJson() {
        FEC_ZNSNotificationCallout.SendZnsMessageRequestDto dto =
            new FEC_ZNSNotificationCallout.SendZnsMessageRequestDto();

        dto.template_data = buildTemplateData();
        dto.phone = '84768433784';
        dto.template_id = '535626';
        dto.dateTimeValue = '2026-06-09T11:18:44';
        dto.department = 'cs';
        dto.tracking_id = '1780978724782';

        dto.Sys = new FEC_ZNSNotificationCallout.SendZnsMessageRequestSysInfo();
        dto.Sys.TransID = 'TRANS_ID_TEST';
        dto.Sys.dateTimeValue = '20260609T041844.956 GMT';
        dto.Sys.RequestorID = 'PEGA_CSM';

        String jsonBody = dto.toJson();

        System.assert(String.isNotBlank(jsonBody));
        System.assert(jsonBody.contains('"template_data"'));
        System.assert(jsonBody.contains('"phone"'));
        System.assert(jsonBody.contains('"template_id"'));
        System.assert(jsonBody.contains('"DateTime"'));
        System.assert(jsonBody.contains('"Sys"'));
        System.assert(jsonBody.contains('FE CREDIT'));
    }

    @IsTest
    static void testRequestDtoToJsonWithNullSys() {
        FEC_ZNSNotificationCallout.SendZnsMessageRequestDto dto =
            new FEC_ZNSNotificationCallout.SendZnsMessageRequestDto();

        dto.template_data = buildTemplateData();
        dto.phone = '84768433784';
        dto.template_id = '535626';
        dto.dateTimeValue = '2026-06-09T11:18:44';
        dto.department = 'cs';
        dto.tracking_id = '1780978724782';
        dto.Sys = null;

        String jsonBody = dto.toJson();

        System.assert(String.isNotBlank(jsonBody));
        System.assert(jsonBody.contains('"Sys":null'));
    }

    @IsTest
    static void testRequestSysInfoToMap() {
        FEC_ZNSNotificationCallout.SendZnsMessageRequestSysInfo sysInfo =
            new FEC_ZNSNotificationCallout.SendZnsMessageRequestSysInfo();

        sysInfo.TransID = 'TRANS_ID_TEST';
        sysInfo.dateTimeValue = '20260609T041844.956 GMT';
        sysInfo.RequestorID = 'PEGA_CSM';

        Map<String, Object> result = sysInfo.toMap();

        System.assertEquals('TRANS_ID_TEST', result.get('TransID'));
        System.assertEquals('20260609T041844.956 GMT', result.get('DateTime'));
        System.assertEquals('PEGA_CSM', result.get('RequestorID'));
    }

    @IsTest
    static void testParseSendZnsMessageResponseSuccess() {
        String jsonBody =
            '{"Sys":{' +
                '"TransID":"aebc37e5-8742-4405-821b-9bcd866768bb",' +
                '"DateTime":"2026-06-09T15:33:22.076+07:00",' +
                '"Code":1,' +
                '"Description":"Success"' +
            '},' +
            '"data":{' +
                '"msg_id":"96844f5a0975d32c8a63",' +
                '"sent_time":"1780994001908"' +
            '}}';

        FEC_ZNSNotificationCallout.SendZnsMessageResponseDto dto =
            FEC_ZNSNotificationCallout.parseSendZnsMessageResponse(jsonBody);

        System.assertNotEquals(null, dto);
        System.assertNotEquals(null, dto.Sys);
        System.assertEquals('aebc37e5-8742-4405-821b-9bcd866768bb', dto.Sys.TransID);
        System.assertEquals('2026-06-09T15:33:22.076+07:00', dto.Sys.dateTimeValue);
        System.assertEquals(1, dto.Sys.Code);
        System.assertEquals('Success', dto.Sys.Description);
        System.assertEquals(true, dto.isSuccess());

        System.assertNotEquals(null, dto.data);
        System.assertEquals('96844f5a0975d32c8a63', dto.data.msg_id);
        System.assertEquals('1780994001908', dto.data.sent_time);
    }

    @IsTest
    static void testParseSendZnsMessageResponseFailed() {
        String jsonBody =
            '{"Sys":{' +
                '"TransID":"TRANS_ID_TEST",' +
                '"DateTime":"2026-06-09T15:33:22.076+07:00",' +
                '"Code":0,' +
                '"Description":"Failed"' +
            '},' +
            '"data":{' +
                '"msg_id":"MSG_ID_TEST",' +
                '"sent_time":"1780994001908"' +
            '}}';

        FEC_ZNSNotificationCallout.SendZnsMessageResponseDto dto =
            FEC_ZNSNotificationCallout.parseSendZnsMessageResponse(jsonBody);

        System.assertNotEquals(null, dto);
        System.assertNotEquals(null, dto.Sys);
        System.assertEquals(0, dto.Sys.Code);
        System.assertEquals('Failed', dto.Sys.Description);
        System.assertEquals(false, dto.isSuccess());
    }

    @IsTest
    static void testParseSendZnsMessageResponseWithoutCode() {
        String jsonBody =
            '{"Sys":{' +
                '"TransID":"TRANS_ID_TEST",' +
                '"DateTime":"2026-06-09T15:33:22.076+07:00",' +
                '"Description":"Success Without Code"' +
            '},' +
            '"data":{' +
                '"msg_id":"MSG_ID_TEST",' +
                '"sent_time":"1780994001908"' +
            '}}';

        FEC_ZNSNotificationCallout.SendZnsMessageResponseDto dto =
            FEC_ZNSNotificationCallout.parseSendZnsMessageResponse(jsonBody);

        System.assertNotEquals(null, dto);
        System.assertNotEquals(null, dto.Sys);
        System.assertEquals(null, dto.Sys.Code);
        System.assertEquals(false, dto.isSuccess());
    }

    @IsTest
    static void testResponseDtoToJson() {
        FEC_ZNSNotificationCallout.SendZnsMessageResponseDto dto =
            new FEC_ZNSNotificationCallout.SendZnsMessageResponseDto();

        dto.Sys = new FEC_ZNSNotificationCallout.SendZnsMessageResponseSysInfo();
        dto.Sys.TransID = 'TRANS_ID_TEST';
        dto.Sys.dateTimeValue = '2026-06-09T15:33:22.076+07:00';
        dto.Sys.Code = 1;
        dto.Sys.Description = 'Success';

        dto.data = new FEC_ZNSNotificationCallout.SendZnsMessageResponseData();
        dto.data.msg_id = 'MSG_ID_TEST';
        dto.data.sent_time = '1780994001908';

        String jsonBody = dto.toJson();

        System.assert(String.isNotBlank(jsonBody));
        System.assert(jsonBody.contains('"Sys"'));
        System.assert(jsonBody.contains('"DateTime"'));
        System.assert(jsonBody.contains('"Code":1'));
        System.assert(jsonBody.contains('"Description":"Success"'));
        System.assert(jsonBody.contains('"msg_id":"MSG_ID_TEST"'));
        System.assertEquals(true, dto.isSuccess());
    }

    @IsTest
    static void testResponseDtoToJsonWithNullSysAndData() {
        FEC_ZNSNotificationCallout.SendZnsMessageResponseDto dto =
            new FEC_ZNSNotificationCallout.SendZnsMessageResponseDto();

        dto.Sys = null;
        dto.data = null;

        String jsonBody = dto.toJson();

        System.assert(String.isNotBlank(jsonBody));
        System.assert(jsonBody.contains('"Sys":null'));
        System.assert(jsonBody.contains('"data":null'));
        System.assertEquals(false, dto.isSuccess());
    }

    @IsTest
    static void testResponseSysInfoToMap() {
        FEC_ZNSNotificationCallout.SendZnsMessageResponseSysInfo sysInfo =
            new FEC_ZNSNotificationCallout.SendZnsMessageResponseSysInfo();

        sysInfo.TransID = 'TRANS_ID_TEST';
        sysInfo.dateTimeValue = '2026-06-09T15:33:22.076+07:00';
        sysInfo.Code = 1;
        sysInfo.Description = 'Success';

        Map<String, Object> result = sysInfo.toMap();

        System.assertEquals('TRANS_ID_TEST', result.get('TransID'));
        System.assertEquals('2026-06-09T15:33:22.076+07:00', result.get('DateTime'));
        System.assertEquals(1, result.get('Code'));
        System.assertEquals('Success', result.get('Description'));
    }
}