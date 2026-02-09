@isTest
private class FEC_SyncMasterDataBatchTest {

    @testSetup
    static void setupFullSyncData() {
        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;

        // Insert MDM records by type
        insert new List<FEC_MDM_Product_Type__c>{
            new FEC_MDM_Product_Type__c(Name='MDM Prod', FEC_Code__c='P1', Process_Change_Status__c='Update'),
            new FEC_MDM_Product_Type__c(Name='MDM Prod New', FEC_Code__c='P2', Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Business_Process__c>{
            new FEC_MDM_Business_Process__c(Name='MDM Biz', FEC_Code__c='B1', Process_Change_Status__c='Update'),
            new FEC_MDM_Business_Process__c(Name='MDM Biz New', FEC_Code__c='B2', Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Category__c>{
            new FEC_MDM_Category__c(Name='MDM Cat', FEC_Code__c='C1', Process_Change_Status__c='Update'),
            new FEC_MDM_Category__c(Name='MDM Cat New', FEC_Code__c='C2', Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Sub_Category__c>{
            new FEC_MDM_Sub_Category__c(Name='MDM SubCat', FEC_Code__c='SC1', Process_Change_Status__c='Update'),
            new FEC_MDM_Sub_Category__c(Name='MDM SubCat New', FEC_Code__c='SC2', Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Sub_Code__c>{
            new FEC_MDM_Sub_Code__c(Name='MDM SubCode', FEC_Code__c='SCODE1', Process_Change_Status__c='Update'),
            new FEC_MDM_Sub_Code__c(Name='MDM SubCode New', FEC_Code__c='SCODE2', Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Channel__c>{
            new FEC_MDM_Channel__c(Name='MDM Chan', FEC_Channel_ID__c='CH1', FEC_Channel_Vietnamese_name__c='MDM Chan VN', Process_Change_Status__c='Update'),
            new FEC_MDM_Channel__c(Name='MDM Chan New', FEC_Channel_ID__c='CH2', FEC_Channel_Vietnamese_name__c='MDM Chan New VN', Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Master_Data_Setting__c>{
            new FEC_MDM_Master_Data_Setting__c(FEC_Field_Object_Name__c='Obj1', Process_Change_Status__c='Update'),
            new FEC_MDM_Master_Data_Setting__c(FEC_Field_Object_Name__c='Obj2', Process_Change_Status__c='New')
        };
        insert new List<FEC_MDM_Nature_Of_Case__c>{
            new FEC_MDM_Nature_Of_Case__c(Process_Change_Status__c='Update'),
            new FEC_MDM_Nature_Of_Case__c(Process_Change_Status__c='New')
        };

        // Insert Live records by type
        insert new List<FEC_Product_Type__c>{
            new FEC_Product_Type__c(Name='Live Prod Updated', FEC_Code__c='P1')
        };
        insert new List<FEC_Business_Process__c>{
            new FEC_Business_Process__c(Name='Live Biz Updated', FEC_Code__c='B1')
        };
        insert new List<FEC_Category__c>{
            new FEC_Category__c(Name='Live Cat Updated', FEC_Code__c='C1')
        };
        insert new List<FEC_Sub_Category__c>{
            new FEC_Sub_Category__c(Name='Live SubCat Updated', FEC_Code__c='SC1')
        };
        insert new List<FEC_Sub_Code__c>{
            new FEC_Sub_Code__c(Name='Live SubCode Updated', FEC_Code__c='SCODE1')
        };
        insert new List<FEC_Channel__c>{
            new FEC_Channel__c(Name='Live Chan Updated', FEC_Channel_ID__c='CH1', FEC_Channel_Vietnamese_name__c='Live Chan VN')
        };
        insert new List<FEC_Master_Data_Setting__c>{
            new FEC_Master_Data_Setting__c(FEC_Field_Object_Name__c='Obj1')
        };
        insert new List<FEC_Nature_Of_Case__c>{
            new FEC_Nature_Of_Case__c()
        };

        // Set lookups for NOC
        FEC_Nature_Of_Case__c liveNoc = [SELECT Id FROM FEC_Nature_Of_Case__c LIMIT 1];
        FEC_Product_Type__c liveProd = [SELECT Id FROM FEC_Product_Type__c WHERE FEC_Code__c = 'P1' LIMIT 1];
        liveNoc.FEC_Product_Type__c = liveProd.Id;
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
        System.assertEquals(0, [SELECT COUNT() FROM FEC_MDM_Nature_Of_Case__c WHERE Process_Change_Status__c = 'New']);

        // Assert 'Update' records are set to 'Synced' and fields reverted
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Product_Type__c WHERE FEC_Code__c = 'P1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('Live Prod Updated', [SELECT Name FROM FEC_MDM_Product_Type__c WHERE FEC_Code__c = 'P1' LIMIT 1].Name);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Business_Process__c WHERE FEC_Code__c = 'B1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('Live Biz Updated', [SELECT Name FROM FEC_MDM_Business_Process__c WHERE FEC_Code__c = 'B1' LIMIT 1].Name);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Category__c WHERE FEC_Code__c = 'C1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('Live Cat Updated', [SELECT Name FROM FEC_MDM_Category__c WHERE FEC_Code__c = 'C1' LIMIT 1].Name);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Sub_Category__c WHERE FEC_Code__c = 'SC1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('Live SubCat Updated', [SELECT Name FROM FEC_MDM_Sub_Category__c WHERE FEC_Code__c = 'SC1' LIMIT 1].Name);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Sub_Code__c WHERE FEC_Code__c = 'SCODE1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('Live SubCode Updated', [SELECT Name FROM FEC_MDM_Sub_Code__c WHERE FEC_Code__c = 'SCODE1' LIMIT 1].Name);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Channel__c WHERE FEC_Channel_ID__c = 'CH1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('Live Chan Updated', [SELECT Name FROM FEC_MDM_Channel__c WHERE FEC_Channel_ID__c = 'CH1' LIMIT 1].Name);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Master_Data_Setting__c WHERE FEC_Field_Object_Name__c = 'Obj1' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('Obj1', [SELECT FEC_Field_Object_Name__c FROM FEC_MDM_Master_Data_Setting__c WHERE FEC_Field_Object_Name__c = 'Obj1' LIMIT 1].FEC_Field_Object_Name__c);
        System.assertEquals('Synced', [SELECT Process_Change_Status__c FROM FEC_MDM_Nature_Of_Case__c WHERE Name = 'Live NOC Updated' LIMIT 1].Process_Change_Status__c);
        System.assertEquals('Live NOC Updated', [SELECT Name FROM FEC_MDM_Nature_Of_Case__c WHERE Name = 'Live NOC Updated' LIMIT 1].Name);
    }

    @isTest
    static void testSyncBatchErrorScenario() {
        // Insert an 'Update' MDM record with no matching Live record
        FEC_MDM_Product_Type__c mdmProd = new FEC_MDM_Product_Type__c(Name='MDM Prod Error', FEC_Code__c='P-ERR', Process_Change_Status__c='Update');
        insert mdmProd;
        Test.startTest();
        FEC_SyncMasterDataBatch batch = new FEC_SyncMasterDataBatch();
        Database.executeBatch(batch, 20);
        Test.stopTest();
        // Assert record is not set to 'Synced' (should remain 'Update' since no Live found)
        System.assertEquals('Update', [SELECT Process_Change_Status__c FROM FEC_MDM_Product_Type__c WHERE FEC_Code__c = 'P-ERR' LIMIT 1].Process_Change_Status__c);
    }
}
