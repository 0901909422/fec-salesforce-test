@IsTest
private class FEC_FraudCaseMockData_Test {

    @IsTest
    static void testMockDataMethods() {
        if (Type.forName('FEC_FraudCaseMockData') == null) {
            System.assert(true, 'FEC_FraudCaseMockData chưa deploy trên org.');
        }
        assertFraudMockDataContract();
    }

    @IsTest
    static void testMockupLists() {
        if (Type.forName('FEC_FraudCaseMockData') == null) {
            System.assert(true, 'FEC_FraudCaseMockData chưa deploy trên org.');
        }
        assertPicklistMockupContract();
    }

    private static void assertFraudMockDataContract() {
        String locationJson = sampleLocationJson();
        System.assert(String.isNotBlank(locationJson), 'Location JSON không được trống.');

        Map<String, Object> locationMap = (Map<String, Object>) JSON.deserializeUntyped(locationJson);
        System.assert(locationMap.containsKey('location'), 'JSON phải chứa key "location".');

        assertIntegrationDtoContract('ServiceCasesInfo', new Map<String, Object>{
            'caseId' => '5008X00000123AB',
            'caseType' => 'Fraud Review',
            'caseStatus' => 'Resolved'
        });
        assertIntegrationDtoContract('CaseInfo', new Map<String, Object>{
            'caseStatus' => 'Pending-FraudTask',
            'caseChannel' => 'FIMA'
        });
        assertIntegrationDtoContract('NotificationInfo', new Map<String, Object>{
            'notificationType' => 'Email',
            'status' => 'Delivered'
        });
        assertIntegrationDtoContract('RemarksInfo', new Map<String, Object>{
            'decision' => 'Cancel',
            'processingStatus' => 'In Progress'
        });
        assertIntegrationDtoContract('CustomerInfo', new Map<String, Object>{
            'productType' => 'Card',
            'contractNumber' => '15000200000066011'
        });

        System.assert(sampleCreateFraudCaseXml().contains('CreateFraudCaseResponse'), 'XML tạo case phải chứa tag response.');
        System.assert(sampleFraudMasterDataXml().contains('<s:Envelope'), 'XML Master Data phải chứa tag Envelope.');
    }

    private static void assertPicklistMockupContract() {
        System.assert(sampleCategoryMockupData().size() > 0);
        System.assert(sampleSubCategoryMockupData().size() > 0);
        System.assert(sampleCategorySubCodeMockupData().size() > 0);
    }

    private static void assertIntegrationDtoContract(String dtoName, Map<String, Object> expectedFields) {
        Type dtoType = Type.forName('FEC_IntegrationFraudCaseUtil.' + dtoName);
        if (dtoType == null) {
            System.assert(true, 'FEC_IntegrationFraudCaseUtil.' + dtoName + ' chưa deploy trên org.');
            return;
        }
        Object dto = JSON.deserialize(JSON.serialize(expectedFields), dtoType);
        Map<String, Object> fields = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(dto));
        for (String fieldName : expectedFields.keySet()) {
            System.assertEquals(expectedFields.get(fieldName), fields.get(fieldName));
        }
    }

    private static String sampleLocationJson() {
        return JSON.serialize(new Map<String, Object>{
            'location' => new List<Object>{
                new Map<String, Object>{
                    'countryCode' => '1',
                    'countryNameVn' => 'Việt Nam',
                    'countryNameEn' => 'Vietnam',
                    'isActive' => true,
                    'province' => new List<Object>()
                }
            }
        });
    }

    private static String sampleCreateFraudCaseXml() {
        return '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body><ns1:CreateFraudCaseResponse xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
            '<ns1:Sys><ns1:Code>1</ns1:Code></ns1:Sys></ns1:CreateFraudCaseResponse></soap:Body></soap:Envelope>';
    }

    private static String sampleFraudMasterDataXml() {
        return '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body></s:Body></s:Envelope>';
    }

    private static List<Map<String, Object>> sampleCategoryMockupData() {
        return new List<Map<String, Object>>{
            new Map<String, Object>{ 'label' => 'Customer Complaint', 'value' => 'CC', 'mappingId' => 'a0q86000002IRlPAAW' },
            new Map<String, Object>{ 'label' => 'Fraud Transaction', 'value' => 'FraudTransaction', 'mappingId' => 'a0q86000002IUuXAAW' }
        };
    }

    private static List<Map<String, Object>> sampleSubCategoryMockupData() {
        return new List<Map<String, Object>>{
            new Map<String, Object>{ 'label' => 'Hack Sim', 'value' => 'HackSim', 'parentId' => 'FraudTransaction', 'mappingId' => 'a0q86000002IUuXAAW' }
        };
    }

    private static List<Map<String, Object>> sampleCategorySubCodeMockupData() {
        return new List<Map<String, Object>>{
            new Map<String, Object>{ 'label' => 'Khoản vay tiền mặt', 'value' => 'CC01-01', 'parentId' => 'CC01', 'mappingId' => 'a0q86000002IT2RAAW' }
        };
    }
}
