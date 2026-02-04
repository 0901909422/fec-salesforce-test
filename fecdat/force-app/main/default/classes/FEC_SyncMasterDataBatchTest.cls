@isTest
private class FEC_SyncMasterDataBatchTest {

    @testSetup
    static void setupFullSyncData() {
        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;

        // Insert MDM records by type
        insert new List<FEC_MDM_Product_Type__c>{
            new FEC_MDM_Product_Type__c(Name='MDM Prod', ExternalID__c='EXT-P1', FEC_Code__c='P1', Process_Change_Status__c='Update'),
            new FEC_MDM_Product_Type__c(Name='MDM Prod New', ExternalID__c='EXT-P2', FEC_Code__c='P2', Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Business_Process__c>{
            new FEC_MDM_Business_Process__c(Name='MDM Biz', ExternalID__c='EXT-B1', FEC_Code__c='B1', Process_Change_Status__c='Update'),
            new FEC_MDM_Business_Process__c(Name='MDM Biz New', ExternalID__c='EXT-B2', FEC_Code__c='B2', Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Category__c>{
            new FEC_MDM_Category__c(Name='MDM Cat', ExternalID__c='EXT-C1', FEC_Code__c='C1', Process_Change_Status__c='Update'),
            new FEC_MDM_Category__c(Name='MDM Cat New', ExternalID__c='EXT-C2', FEC_Code__c='C2', Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Sub_Category__c>{
            new FEC_MDM_Sub_Category__c(Name='MDM SubCat', ExternalID__c='EXT-SC1', FEC_Code__c='SC1', Process_Change_Status__c='Update'),
            new FEC_MDM_Sub_Category__c(Name='MDM SubCat New', ExternalID__c='EXT-SC2', FEC_Code__c='SC2', Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Sub_Code__c>{
            new FEC_MDM_Sub_Code__c(Name='MDM SubCode', ExternalID__c='EXT-SCODE1', FEC_Code__c='SCODE1', Process_Change_Status__c='Update'),
            new FEC_MDM_Sub_Code__c(Name='MDM SubCode New', ExternalID__c='EXT-SCODE2', FEC_Code__c='SCODE2', Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Channel__c>{
            new FEC_MDM_Channel__c(Name='MDM Chan', ExternalID__c='EXT-CH1', FEC_Channel_ID__c='CH1', FEC_Channel_Vietnamese_name__c='MDM Chan VN', Process_Change_Status__c='Update'),
            new FEC_MDM_Channel__c(Name='MDM Chan New', ExternalID__c='EXT-CH2', FEC_Channel_ID__c='CH2', FEC_Channel_Vietnamese_name__c='MDM Chan New VN', Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Master_Data_Setting__c>{
            new FEC_MDM_Master_Data_Setting__c(FEC_Field_Object_Name__c='Obj1', ExternalID__c='EXT-MDS1', Process_Change_Status__c='Update'),
            new FEC_MDM_Master_Data_Setting__c(FEC_Field_Object_Name__c='Obj2', ExternalID__c='EXT-MDS2', Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Case_Stage__c>{
            new FEC_MDM_Case_Stage__c(Name='MDM Stage', ExternalID__c='EXT-CS1', FEC_Code__c='CS1', Process_Change_Status__c='Update'),
            new FEC_MDM_Case_Stage__c(Name='MDM Stage New', ExternalID__c='EXT-CS2', FEC_Code__c='CS2', Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Additional_Field__c>{
            new FEC_MDM_Additional_Field__c(Name='MDM AF', ExternalID__c='EXT-AF1', FEC_Unique_ID__c='AF1', FEC_Type__c='String', Process_Change_Status__c='Update'),
            new FEC_MDM_Additional_Field__c(Name='MDM AF New', ExternalID__c='EXT-AF2', FEC_Unique_ID__c='AF2', FEC_Type__c='String', Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Additional_Field_List_Value__c>{
            new FEC_MDM_Additional_Field_List_Value__c(Name='MDM AFLV', ExternalID__c='EXT-AFLV1', FEC_Name_VN__c='VN', FEC_Order__c=1, Process_Change_Status__c='Update'),
            new FEC_MDM_Additional_Field_List_Value__c(Name='MDM AFLV New', ExternalID__c='EXT-AFLV2', FEC_Name_VN__c='VN', FEC_Order__c=2, Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Nature_Of_Case__c>{
            new FEC_MDM_Nature_Of_Case__c(Name='MDM NOC', ExternalID__c='EXT-NOC1', FEC_Product_Type_Name__c=null, Process_Change_Status__c='Update'),
            new FEC_MDM_Nature_Of_Case__c(Name='MDM NOC New', ExternalID__c='EXT-NOC2', FEC_Product_Type_Name__c=null, Process_Change_Status__c='New')
        };

        // Insert Live records by type
        insert new List<FEC_Product_Type__c>{
            new FEC_Product_Type__c(Name='Live Prod Updated', ExternalID__c='EXT-P1', FEC_Code__c='P1')
        };
        insert new List<FEC_Business_Process__c>{
            new FEC_Business_Process__c(Name='Live Biz Updated', ExternalID__c='EXT-B1', FEC_Code__c='B1')
        };
        insert new List<FEC_Category__c>{
            new FEC_Category__c(Name='Live Cat Updated', ExternalID__c='EXT-C1', FEC_Code__c='C1')
        };
        insert new List<FEC_Sub_Category__c>{
            new FEC_Sub_Category__c(Name='Live SubCat Updated', ExternalID__c='EXT-SC1', FEC_Code__c='SC1')
        };
        insert new List<FEC_Sub_Code__c>{
            new FEC_Sub_Code__c(Name='Live SubCode Updated', ExternalID__c='EXT-SCODE1', FEC_Code__c='SCODE1')
        };
        insert new List<FEC_Channel__c>{
            new FEC_Channel__c(Name='Live Chan Updated', ExternalID__c='EXT-CH1', FEC_Channel_ID__c='CH1', FEC_Channel_Vietnamese_name__c='Live Chan VN')
        };
        insert new List<FEC_Master_Data_Setting__c>{
            new FEC_Master_Data_Setting__c(FEC_Field_Object_Name__c='Obj1', ExternalID__c='EXT-MDS1')
        };
        insert new List<FEC_Case_Stage__c>{
            new FEC_Case_Stage__c(Name='Live Stage Updated', ExternalID__c='EXT-CS1', FEC_Code__c='CS1')
        };
        insert new List<FEC_Additional_Field__c>{
            new FEC_Additional_Field__c(Name='Live AF Updated', ExternalID__c='EXT-AF1', FEC_Unique_ID__c='AF1', FEC_Type__c='String')
        };
        insert new List<FEC_Additional_Field_List_Value__c>{
            new FEC_Additional_Field_List_Value__c(Name='Live AFLV Updated', ExternalID__c='EXT-AFLV1', FEC_Name_VN__c='VN', FEC_Order__c=1)
        };
        insert new List<FEC_Nature_Of_Case__c>{
            new FEC_Nature_Of_Case__c(Name='Live NOC Updated', ExternalID__c='EXT-NOC1')
        };

        // Set lookups for NOC
        FEC_Nature_Of_Case__c liveNoc = [SELECT Id FROM FEC_Nature_Of_Case__c WHERE ExternalID__c = 'EXT-NOC1' LIMIT 1];
        FEC_Product_Type__c liveProd = [SELECT Id FROM FEC_Product_Type__c WHERE ExternalID__c = 'EXT-P1' LIMIT 1];
        liveNoc.FEC_Product_Type_Name__c = liveProd.Id;
        update liveNoc;

        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;
    }

    @isTest
    static void testSyncBatchFullCoverage() {
        Test.startTest();
        FEC_SyncMasterDataBatch batch = new FEC_SyncMasterDataBatch();
        Database.executeBatch(batch, 20);
        Test.stopTest();

        // Assert 'New' records are deleted
        System.assertEquals(0, [SELECT COUNT() FROM FEC_MDM_Product_Type__c WHERE Process_Change_Status__c = 'New']);
        System.assertEquals(0, [SELECT COUNT() FROM FEC_MDM_Business_Process__c WHERE Process_Change_Status__c = 'New']);
        System.assertEquals(0, [SELECT COUNT() FROM FEC_MDM_Category__c WHERE Process_Change_Status__c = 'New']);
        System.assertEquals(0, [SELECT COUNT() FROM FEC_MDM_Sub_Category__c WHERE Process_Change_Status__c = 'New']);
        System.assertEquals(0, [SELECT COUNT() FROM FEC_MDM_Sub_Code__c WHERE Process_Change_Status__c = 'New']);
        System.assertEquals(0, [SELECT COUNT() FROM FEC_MDM_Channel__c WHERE Process_Change_Status__c = 'New']);
        System.assertEquals(0, [SELECT COUNT() FROM FEC_MDM_Master_Data_Setting__c WHERE Process_Change_Status__c = 'New']);
        System.assertEquals(0, [SELECT COUNT() FROM FEC_MDM_Case_Stage__c WHERE Process_Change_Status__c = 'New']);
        System.assertEquals(0, [SELECT COUNT() FROM FEC_MDM_Additional_Field__c WHERE Process_Change_Status__c = 'New']);
        System.assertEquals(0, [SELECT COUNT() FROM FEC_MDM_Additional_Field_List_Value__c WHERE Process_Change_Status__c = 'New']);
        System.assertEquals(0, [SELECT COUNT() FROM FEC_MDM_Nature_Of_Case__c WHERE Process_Change_Status__c = 'New']);

        // Assert 'Update' records are set to 'Synced' and fields reverted
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Product_Type__c WHERE ExternalID__c = 'EXT-P1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('Live Prod Updated', [SELECT Name FROM FEC_MDM_Product_Type__c WHERE ExternalID__c = 'EXT-P1' LIMIT 1].Name);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Business_Process__c WHERE ExternalID__c = 'EXT-B1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('Live Biz Updated', [SELECT Name FROM FEC_MDM_Business_Process__c WHERE ExternalID__c = 'EXT-B1' LIMIT 1].Name);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Category__c WHERE ExternalID__c = 'EXT-C1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('Live Cat Updated', [SELECT Name FROM FEC_MDM_Category__c WHERE ExternalID__c = 'EXT-C1' LIMIT 1].Name);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Sub_Category__c WHERE ExternalID__c = 'EXT-SC1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('Live SubCat Updated', [SELECT Name FROM FEC_MDM_Sub_Category__c WHERE ExternalID__c = 'EXT-SC1' LIMIT 1].Name);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Sub_Code__c WHERE ExternalID__c = 'EXT-SCODE1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('Live SubCode Updated', [SELECT Name FROM FEC_MDM_Sub_Code__c WHERE ExternalID__c = 'EXT-SCODE1' LIMIT 1].Name);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Channel__c WHERE ExternalID__c = 'EXT-CH1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('Live Chan Updated', [SELECT Name FROM FEC_MDM_Channel__c WHERE ExternalID__c = 'EXT-CH1' LIMIT 1].Name);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Master_Data_Setting__c WHERE ExternalID__c = 'EXT-MDS1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('Obj1', [SELECT FEC_Field_Object_Name__c FROM FEC_MDM_Master_Data_Setting__c WHERE ExternalID__c = 'EXT-MDS1' LIMIT 1].FEC_Field_Object_Name__c);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Case_Stage__c WHERE ExternalID__c = 'EXT-CS1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('Live Stage Updated', [SELECT Name FROM FEC_MDM_Case_Stage__c WHERE ExternalID__c = 'EXT-CS1' LIMIT 1].Name);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Additional_Field__c WHERE ExternalID__c = 'EXT-AF1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('MDM AF', [SELECT Name FROM FEC_MDM_Additional_Field__c WHERE ExternalID__c = 'EXT-AF1' LIMIT 1].Name);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Additional_Field_List_Value__c WHERE ExternalID__c = 'EXT-AFLV1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('MDM AFLV', [SELECT Name FROM FEC_MDM_Additional_Field_List_Value__c WHERE ExternalID__c = 'EXT-AFLV1' LIMIT 1].Name);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Nature_Of_Case__c WHERE ExternalID__c = 'EXT-NOC1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('MDM NOC', [SELECT Name FROM FEC_MDM_Nature_Of_Case__c WHERE ExternalID__c = 'EXT-NOC1' LIMIT 1].Name);
    }

    @isTest
    static void testSyncBatchErrorScenario() {
        // Insert an 'Update' MDM record with no matching Live record
        FEC_MDM_Product_Type__c mdmProd = new FEC_MDM_Product_Type__c(Name='MDM Prod Error', ExternalID__c='EXT-P-ERR', FEC_Code__c='P-ERR', Process_Change_Status__c='Update');
        insert mdmProd;
        Test.startTest();
        FEC_SyncMasterDataBatch batch = new FEC_SyncMasterDataBatch();
        Database.executeBatch(batch, 20);
        Test.stopTest();
        // Assert record is not set to 'Synced' (should remain 'Update' since no Live found)
        System.assertEquals('Update', [SELECT Process_Change_Status__c FROM FEC_MDM_Product_Type__c WHERE ExternalID__c = 'EXT-P-ERR' LIMIT 1].Process_Change_Status__c);
    }
}
