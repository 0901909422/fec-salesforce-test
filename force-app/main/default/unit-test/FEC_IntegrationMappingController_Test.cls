@IsTest
private class FEC_IntegrationMappingController_Test {

    /* =====================================================
     * TEST DATA SETUP
     * ===================================================== */
    @testSetup
    static void setupData() {

        // Additional field
        insert new FEC_Additional_Field__c(
            Name = 'Address',
            FEC_Unique_ID__c = 'Address',
            FEC_Name_VN__c = 'Đại chỉ',
            FEC_Type__c = 'string'
        );

        // Master data - DIGITAL
        insert new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'AdditionalProperty',
            FEC_Source_Id__c = 'AccountNumber',
            FEC_Source_Name__c = 'Account Number',
            FEC_Source_Field_Type__c = 'string',
            FEC_Source_Is_Mandatory__c = true,
            FEC_Channel__c = 'FIMA',
            FEC_Source_Parent_Id__c = 'CC'
        );

        // Master data - NON DIGITAL (to hit filter/continue)
        insert new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'AdditionalProperty',
            FEC_Source_Id__c = 'AccountNumber',
            FEC_Source_Name__c = 'Account Number 2',
            FEC_Source_Field_Type__c = 'string',
            FEC_Source_Is_Mandatory__c = false,
            FEC_Channel__c = 'BRANCH',
            FEC_Source_Parent_Id__c = 'CC'
        );
    }

    /* =====================================================
     * saveIntegrationMapping – INSERT PATH
     * ===================================================== */
    @IsTest
    static void testSaveIntegrationMapping_insert() {

        String payload = JSON.serialize(new Map<String,Object>{
            'header' => new Map<String,Object>{
                //'natureOfCaseId' => 'a0EBK000002Cp0p2AC',
                //'caseStageId' => '',
                //'screenCaseId' => '',
                //'mappingId' => 'a06BK00000JIuLmYAL',
                'userType' => 'a0BBK000003Tfqr2AC',
                'channel' => 'FIMA',
                'intUserType' => 'NONEXISTING',
                'productLine' => 'Loan',
                'serviceType' => 'FECredit_OP_Work_FraudHandling',
                'category' => 'CC',
                'subCategory' => 'CC01',
                'subCode' => 'CC01-03'


            },
            'details' => new List<Object>{
                new Map<String,Object>{
                    'property' => 'AccountNumber',
                    'type' => 'string',
                    'displayName' => 'Account Number',
                    'id' => 'a01BK00000a4PB0YAM',
                    'csmProperty' => 'Address',
                    'csmPropertyType' => 'String',
                    'autoMapping' => true,
                    'mandatory' => true
                }
            }
        });

        Test.startTest();
        FEC_IntegrationMappingController.SaveResultDTO result =
            FEC_IntegrationMappingController.saveIntegrationMapping(payload);
        Test.stopTest();
        System.debug(LoggingLevel.INFO, 'testSaveIntegrationMapping_insert: ' + result);
        
        System.assertEquals(true, result.success);
    }
 
    /* =====================================================
     * saveIntegrationMapping – UPDATE PATH
     * ===================================================== */
    @IsTest
    static void testSaveIntegrationMapping_update() {

        FEC_Data_Integration_Mapping__c m =
            new FEC_Data_Integration_Mapping__c(
                //FEC_Nature_Of_Case__c = 'NOC01',
                FEC_Int_Channel__c = 'FIMA',
                FEC_Status__c = true
            );
        insert m;

        String payload = JSON.serialize(new Map<String,Object>{
            'header' => new Map<String,Object>{
                'mappingId' => m.Id,
                'channel' => 'FIMA',
                'category' => 'CC'
                
            },
            'details' => new List<Object>()
        });

        Test.startTest();
        FEC_IntegrationMappingController.SaveResultDTO result =
            FEC_IntegrationMappingController.saveIntegrationMapping(payload);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
       
    }

    /* =====================================================
     * saveIntegrationMapping – NULL PAYLOAD
     * ===================================================== */
    @IsTest
    static void testSaveIntegrationMapping_nullPayload() {

        Test.startTest();
        FEC_IntegrationMappingController.SaveResultDTO result =
            FEC_IntegrationMappingController.saveIntegrationMapping('');
        Test.stopTest();

        System.assertEquals(false, result.success);
    }

    /* =====================================================
     * saveIntegrationMapping – MISSING HEADER
     * ===================================================== */
    @IsTest
    static void testSaveIntegrationMapping_missingHeader() {

        String payload = JSON.serialize(
            new Map<String,Object>{ 'details' => new List<Object>() }
        );

        Test.startTest();
        FEC_IntegrationMappingController.SaveResultDTO result =
            FEC_IntegrationMappingController.saveIntegrationMapping(payload);
        Test.stopTest();
       
        System.assertEquals(false, result.success);
    }

    /* =====================================================
     * saveIntegrationMapping – EXCEPTION (JSON ERROR)
     * ===================================================== */
    @IsTest
    static void testSaveIntegrationMapping_exception() {
        
        Test.startTest();
        FEC_IntegrationMappingController.SaveResultDTO result =
            FEC_IntegrationMappingController.saveIntegrationMapping('{"header":"INVALID"}');
        Test.stopTest();

        System.assertEquals(false, result.success);
    }

    /* =====================================================
     * loadIntegrationMapping – SUCCESS
     * ===================================================== */
    @IsTest
    static void testLoadIntegrationMapping_success() {

        FEC_Data_Integration_Mapping__c m =
            new FEC_Data_Integration_Mapping__c(
                //FEC_Nature_Of_Case__c = 'NOC01',
                FEC_Int_Channel__c = 'FIMA',
                FEC_Status__c = true
            );
        insert m;

        insert new FEC_Data_Integration_Mapping_Info__c(
            FEC_Data_Integration_Mapping__c = m.Id,
            FEC_Integrating_Property__c = 'Address'
        );

        Test.startTest();
        FEC_IntegrationMappingController.MappingDTO dto =
        FEC_IntegrationMappingController.loadIntegrationMapping(m.Id);
        Test.stopTest();

        System.assertEquals(m.Id, dto.id);
    }

    /* =====================================================
     * loadIntegrationMapping – NULL ID
     * ===================================================== */
    @IsTest
    static void testLoadIntegrationMapping_null() {

        FEC_IntegrationMappingController.MappingDTO dto =
            FEC_IntegrationMappingController.loadIntegrationMapping(null);

        System.assertEquals(null, dto.id);
    }

    /* =====================================================
     * searchAdditionalFields
     * ===================================================== */
    @IsTest
    static void testSearchAdditionalFields() {

        Test.startTest();
        List<FEC_IntegrationMappingController.CsmFieldDTO> result =
            FEC_IntegrationMappingController.searchAdditionalFields('Address', 'string');
        Test.stopTest();

        System.assertEquals(1, result.size());
    }

    /* =====================================================
     * loadAdditionalProperties – DIGITAL
     * ===================================================== */
    @IsTest
    static void testLoadAdditionalProperties_digital() {

        Test.startTest();
        List<FEC_IntegrationMappingController.PropertyDTO> result =
            FEC_IntegrationMappingController.loadAdditionalProperties(
                'CC', 'CC01', 'CC01-03', 'FIMA'
            );
        Test.stopTest();

        System.assertEquals(1, result.size());
    }

    /* =====================================================
     * loadAdditionalProperties – WRONG CHANNEL
     * ===================================================== */
    @IsTest
    static void testLoadAdditionalProperties_wrongChannel() {

        Test.startTest();
        List<FEC_IntegrationMappingController.PropertyDTO> result =
            FEC_IntegrationMappingController.loadAdditionalProperties(
                'CC', null, null, 'FIMA'
            );
        Test.stopTest();

        System.assertEquals(1, result.size());
    }
    @IsTest
    static void testSaveIntegrationMapping_success_emptyDetails() {

        String payload = JSON.serialize(new Map<String,Object>{
            'header' => new Map<String,Object>{
                'channel' => 'FIMA',
                'category' => 'CC'
            },
            'details' => new List<Object>()
        });

        Test.startTest();
        FEC_IntegrationMappingController.SaveResultDTO result =
            FEC_IntegrationMappingController.saveIntegrationMapping(payload);
        Test.stopTest();

        System.assertEquals(true, result.success);
    }
    @IsTest
    static void testLoadAdditionalProperties_fullFilter() {

        Test.startTest();
        List<FEC_IntegrationMappingController.PropertyDTO> result =
            FEC_IntegrationMappingController.loadAdditionalProperties(
                'CC', 'CC01', 'CC01-03', 'BRANCH'
            );
        Test.stopTest();

        System.assertEquals(1, result.size());
    }
}