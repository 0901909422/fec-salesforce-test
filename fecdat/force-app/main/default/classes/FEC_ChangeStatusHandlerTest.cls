/**
 * @description Test class cho FEC_ProcessChangeStatusTriggerHandler.
 * Kiểm tra việc tự động cập nhật Process_Change_Status__c và sinh ExternalID__c.
 * @author Senior Salesforce Developer
 * @date 2026-01-27
 */
@isTest
private class FEC_ChangeStatusHandlerTest {

    /**
     * @description Test logic Before Insert:
     * 1. Status phải luôn là 'New'.
     * 2. ExternalID__c phải được sinh ra tự động.
     */
    @isTest
    static void testHandleStatusBeforeInsert() {
        // Khởi tạo bản ghi nhưng chưa insert
        FEC_MDM_Product_Type__c prod = new FEC_MDM_Product_Type__c(
            FEC_Code__c = 'P_INSERT',
            Name = 'Test Product Insert'
        );

        Test.startTest();
        insert prod;
        Test.stopTest();

        // Kiểm tra kết quả sau khi Insert
        FEC_MDM_Product_Type__c result = [
            SELECT Process_Change_Status__c, ExternalID__c 
            FROM FEC_MDM_Product_Type__c 
            WHERE Id = :prod.Id
        ];

        Assert.areEqual('New', result.Process_Change_Status__c, 'Bản ghi mới tạo phải có status là New');
        Assert.isNotNull(result.ExternalID__c, 'ExternalID phải được tạo tự động');
    }

    /**
     * @description Test logic Before Update:
     * 1. Nếu đang là 'New', update xong vẫn phải là 'New'.
     * 2. Nếu không phải 'New' (ví dụ đã Sync), update xong phải chuyển thành 'Update'.
     */
    @isTest
    static void testHandleStatusBeforeUpdate() {
        // 1. Tạo bản ghi ban đầu (Status sẽ là 'New')
        FEC_MDM_Product_Type__c prod = new FEC_MDM_Product_Type__c(
            FEC_Code__c = 'P_UPDATE',
            Name = 'Test Product Update'
        );
        insert prod;

        // Kiểm tra Case 1: Đang 'New' -> Update -> Vẫn 'New'
        prod.Name = 'Test Product Updated Name';
        update prod;
        
        FEC_MDM_Product_Type__c res1 = [SELECT Process_Change_Status__c FROM FEC_MDM_Product_Type__c WHERE Id = :prod.Id];
        Assert.areEqual('New', res1.Process_Change_Status__c, 'Đang là New thì update vẫn phải giữ New');

        // 2. Giả lập bản ghi đã được đồng bộ (Status không còn là 'New')
        // Lưu ý: Tắt trigger để giả lập trạng thái từ hệ thống khác hoặc sau khi Sync
        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;
        prod.Process_Change_Status__c = 'Synced'; 
        update prod;
        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = true;

        // Kiểm tra Case 2: Đang 'Synced' -> Update -> Chuyển sang 'Update'
        Test.startTest();
        prod.Name = 'Change again';
        update prod;
        Test.stopTest();

        FEC_MDM_Product_Type__c res2 = [SELECT Process_Change_Status__c FROM FEC_MDM_Product_Type__c WHERE Id = :prod.Id];
        Assert.areEqual('Update', res2.Process_Change_Status__c, 'Bản ghi cũ khi sửa đổi phải chuyển sang status Update');
    }

    /**
     * @description Test tính năng 'Công tắc' (isTriggerEnabled).
     */
    @isTest
    static void testTriggerDisabled() {
        // Tắt trigger
        FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled = false;

        FEC_MDM_Product_Type__c prod = new FEC_MDM_Product_Type__c(
            FEC_Code__c = 'P_DISABLED',
            Process_Change_Status__c = 'Custom'
        );

        Test.startTest();
        insert prod;
        Test.stopTest();

        FEC_MDM_Product_Type__c result = [SELECT Process_Change_Status__c FROM FEC_MDM_Product_Type__c WHERE Id = :prod.Id];
        // Vì trigger bị tắt, giá trị 'Custom' không bị ghi đè thành 'New'
        Assert.areEqual('Custom', result.Process_Change_Status__c, 'Trigger bị tắt thì không được ghi đè status');
    }
}