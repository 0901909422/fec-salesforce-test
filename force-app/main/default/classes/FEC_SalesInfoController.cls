/****************************************************************************************
 * File Name    : FEC_SalesInfoController
 * Description  : Controller tổng hợp để lấy Sales Info từ nhiều API
 *                - GetCustomerList (param: AccountNumber/CreditCardNumber) → ApplicationID
 *                - GetCustomerSaleDisburseInfo (param: ApplicationID) → CC/DSA/TSA, Disbursement Channel
 *                - AppStatus (param: ApplicationID) → Origination Channel
 ****************************************************************************************/
public without sharing class FEC_SalesInfoController {
    
    //=============== RESULT WRAPPER ===============//
    
    public class SalesInfoResult {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorCode;
        @AuraEnabled public String errorMessage;

        // Sales Info Fields (chỉ giữ các trường cần thiết)
        @AuraEnabled public String applicationId;
        @AuraEnabled public String originationChannel;
        @AuraEnabled public String disbursementChannel;
        @AuraEnabled public String ccCode;
        @AuraEnabled public String ccName;
        @AuraEnabled public String dsaCode;
        @AuraEnabled public String dsaName;
        @AuraEnabled public String tsaCode;
        @AuraEnabled public String tsaName;

        public SalesInfoResult() {
            this.isSuccess = false;
        }
    }
    
    //=============== MAIN METHOD FOR LWC ===============//
    
    /**
     * Fetch Sales Info cho nhiều IPP records (async) - Dùng khi tạo IPP mới
     * @param ippRecordIds - Set of IPP Record IDs
     */
    @future(callout=true)
    public static void fetchSalesInfoAsync(Set<Id> ippRecordIds) {
        System.debug('### fetchSalesInfoAsync called for ' + ippRecordIds.size() + ' IPP records');
        
        if (ippRecordIds == null || ippRecordIds.isEmpty()) {
            return;
        }
        
        // Query IPP records với Customer History và Account Number
        List<FEC_IPP__c> ippRecords = [
            SELECT Id, FEC_Customer_History__c, 
                   FEC_Customer_History__r.FEC_Account_Number__c,
                   FEC_Application_ID__c
            FROM FEC_IPP__c
            WHERE Id IN :ippRecordIds
        ];
        
        for (FEC_IPP__c ipp : ippRecords) {
            // Chỉ fetch nếu chưa có Application ID
            if (String.isBlank(ipp.FEC_Application_ID__c)) {
                String accountNumber = ipp.FEC_Customer_History__r?.FEC_Account_Number__c;
                
                if (String.isNotBlank(accountNumber)) {
                    System.debug('### Fetching Sales Info for IPP: ' + ipp.Id + ', AccountNumber: ' + accountNumber);
                    
                    try {
                        SalesInfoResult result = getSalesInfoByAccountNumber(accountNumber);
                        
                        if (result.isSuccess) {
                            // Update IPP record với Sales Info
                            updateIPPRecordWithSalesInfo(result, ipp.Id);
                            System.debug('### Successfully fetched and saved Sales Info for IPP: ' + ipp.Id);
                        } else {
                            System.debug('### Failed to fetch Sales Info for IPP: ' + ipp.Id + ', Error: ' + result.errorMessage);
                        }
                    } catch (Exception e) {
                        System.debug('### Exception fetching Sales Info for IPP: ' + ipp.Id + ', Error: ' + e.getMessage());
                    }
                } else {
                    System.debug('### Skip IPP: ' + ipp.Id + ' - No Account Number');
                }
            } else {
                System.debug('### Skip IPP: ' + ipp.Id + ' - Already has Application ID');
            }
        }
    }
    
    /**
     * Lấy Sales Info từ IPP Record ID
     * Flow: IPP Record → Customer History → Account Number → GetCustomerList → ApplicationID → Sales Info
     */
    @AuraEnabled(cacheable=false)
    public static SalesInfoResult getSalesInfoByIPPRecord(String ippRecordId) {
        SalesInfoResult result = new SalesInfoResult();
        
        try {
            // Validate input
            if (String.isBlank(ippRecordId)) {
                result.errorCode = 'VALIDATION_ERROR';
                result.errorMessage = 'IPP Record ID is required.';
                return result;
            }
            
            // Step 1: Lấy Account Number từ IPP Record → Customer History
            FEC_IPP__c ippRecord = [
                SELECT Id, FEC_Customer_History__r.FEC_Account_Number__c
                FROM FEC_IPP__c
                WHERE Id = :ippRecordId
                LIMIT 1
            ];
            
            String accountNumber = ippRecord.FEC_Customer_History__r?.FEC_Account_Number__c;
            
            if (String.isBlank(accountNumber)) {
                result.errorCode = 'NO_DATA';
                result.errorMessage = 'Account Number not found on IPP Record.';
                return result;
            }
            
            // Step 2: Gọi GetCustomerList với Account Number để lấy ApplicationID
            result = getSalesInfoByAccountNumber(accountNumber);
            
        } catch (QueryException e) {
            result.isSuccess = false;
            result.errorCode = 'QUERY_ERROR';
            result.errorMessage = 'IPP Record not found: ' + e.getMessage();
        } catch (Exception e) {
            result.isSuccess = false;
            result.errorCode = 'UNKNOWN_ERROR';
            result.errorMessage = 'Error: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * Lấy Sales Info từ Account Number
     * Flow: AccountNumber → GetCustomerList → ApplicationID → GetCustomerSaleDisburseInfo + AppStatus
     */
    @AuraEnabled(cacheable=false)
    public static SalesInfoResult getSalesInfoByAccountNumber(String accountNumber) {
        SalesInfoResult result = new SalesInfoResult();
        try {
            if (String.isBlank(accountNumber)) {
                result.errorCode = 'VALIDATION_ERROR';
                result.errorMessage = 'AccountNumber is required.';
                return result;
            }

            // Bước 1: Query database trước (truy vấn qua Customer History)
            System.debug('### Step 1: Query database for AccountNumber: ' + accountNumber);
            FEC_IPP__c salesInfo = null;
            List<FEC_IPP__c> salesInfoList = [
                SELECT Id, FEC_Application_ID__c, FEC_Customer_History__c, FEC_CC_Code__c, FEC_CC_Name__c, FEC_DSA_Code__c, FEC_DSA_Name__c, FEC_TSA_Code__c, FEC_TSA_Name__c, FEC_Origination_Channel__c, FEC_Disbursement_Channel__c,
                       FEC_Customer_History__r.FEC_Account_Number__c
                FROM FEC_IPP__c
                WHERE FEC_Customer_History__r.FEC_Account_Number__c = :accountNumber
                LIMIT 1
            ];
            if (!salesInfoList.isEmpty()) {
                salesInfo = salesInfoList[0];
                System.debug('### Found IPP record: ' + salesInfo.Id);
                System.debug('### Current Application ID in DB: ' + salesInfo.FEC_Application_ID__c);
                System.debug('### Checking hasSalesInfo()...');
                
                // Kiểm tra xem IPP record đã có Sales Info chưa (không chỉ tồn tại record)
                Boolean hasInfo = hasSalesInfo(salesInfo);
                System.debug('### hasSalesInfo() returned: ' + hasInfo);
                
                if (hasInfo) {
                    System.debug('### IPP already has Sales Info → Return from DB (skip API)');
                    // Map dữ liệu từ DB sang DTO
                    result = mapSalesInfoToResult(salesInfo);
                    result.isSuccess = true;
                    return result;
                } else {
                    System.debug('### IPP exists but NO Sales Info → Will call API');
                }
            } else {
                System.debug('### No IPP record found → Will call API and create new');
            }

            // Bước 2: Validate AccountNumber format trước khi gọi API
            if (!isValidAccountNumber(accountNumber)) {
                result.errorCode = 'VALIDATION_ERROR';
                result.errorMessage = 'AccountNumber không hợp lệ. AccountNumber phải có 16 hoặc 19 chữ số. Giá trị hiện tại: ' + accountNumber;
                return result;
            }
            
            // Bước 3: Gọi API nếu chưa có dữ liệu Sales Info
            System.debug('### Step 3: Calling GetCustomerList API...');
            String applicationId = getApplicationIdByAccountNumber(accountNumber);
            if (String.isBlank(applicationId)) {
                result.errorCode = 'NO_DATA';
                result.errorMessage = 'Không tìm thấy ApplicationID từ AccountNumber: ' + accountNumber;
                return result;
            }
            System.debug('### Got ApplicationID: ' + applicationId);
            result.applicationId = applicationId;
            
            // Lấy dữ liệu từ API
            System.debug('### Step 4: Calling populateSaleDisburseInfo...');
            populateSaleDisburseInfo(result, applicationId);
            
            System.debug('### Step 5: Calling populateAppStatusInfo...');
            populateAppStatusInfo(result, applicationId);
            
            result.isSuccess = true;
            System.debug('### All API calls completed successfully');

            // Bước 3: Lưu vào database hoặc update IPP record hiện tại
            if (salesInfo != null) {
                // Update IPP record hiện tại
                updateIPPRecordWithSalesInfo(result, salesInfo.Id);
            } else {
                // Tạo IPP record mới
                Id customerHistoryId = null;
                List<FEC_Customer_History__c> chList = [SELECT Id FROM FEC_Customer_History__c WHERE FEC_Account_Number__c = :accountNumber LIMIT 1];
                if (!chList.isEmpty()) {
                    customerHistoryId = chList[0].Id;
                }
                saveSalesInfoToDatabase(result, customerHistoryId);
            }

        } catch (Exception e) {
            result.isSuccess = false;
            result.errorCode = 'UNKNOWN_ERROR';
            result.errorMessage = 'Error: ' + e.getMessage();
        }
        return result;
    }
    
    // Note: Method getSalesInfoByCreditCard đã bị remove vì FEC_Credit_Card_Number__c field không tồn tại
    // Nếu cần sử dụng sau này, cần tạo field FEC_Credit_Card_Number__c trên object FEC_IPP__c trước
    
    /**
     * Lấy Sales Info từ ApplicationID (nếu đã có sẵn)
     */
    @AuraEnabled(cacheable=false)
    public static SalesInfoResult getSalesInfoByApplicationId(String applicationId) {
        SalesInfoResult result = new SalesInfoResult();
        try {
            if (String.isBlank(applicationId)) {
                result.errorCode = 'VALIDATION_ERROR';
                result.errorMessage = 'ApplicationID is required.';
                return result;
            }

            // Bước 1: Query database trước
            FEC_IPP__c salesInfo = null;
            List<FEC_IPP__c> salesInfoList = [
                SELECT Id, FEC_Application_ID__c, FEC_Customer_History__c, FEC_CC_Code__c, FEC_CC_Name__c, FEC_DSA_Code__c, FEC_DSA_Name__c, FEC_TSA_Code__c, FEC_TSA_Name__c, FEC_Origination_Channel__c, FEC_Disbursement_Channel__c
                FROM FEC_IPP__c
                WHERE FEC_Application_ID__c = :applicationId
                LIMIT 1
            ];
            if (!salesInfoList.isEmpty()) {
                salesInfo = salesInfoList[0];
                result = mapSalesInfoToResult(salesInfo);
                result.isSuccess = true;
                return result;
            }

            // Bước 2: Gọi API nếu chưa có dữ liệu
            result.applicationId = applicationId;
            populateSaleDisburseInfo(result, applicationId);
            populateAppStatusInfo(result, applicationId);
            result.isSuccess = true;

            // Bước 3: Lưu vào database
            saveSalesInfoToDatabase(result, null);

        } catch (Exception e) {
            result.isSuccess = false;
            result.errorCode = 'UNKNOWN_ERROR';
            result.errorMessage = 'Error: ' + e.getMessage();
        }
        return result;
    }
    // Helper: Kiểm tra xem IPP record đã có FULL Sales Info chưa
    // Kiểm tra các field BẮT BUỘC bao gồm Origination Channel
    private static Boolean hasSalesInfo(FEC_IPP__c ipp) {
        if (ipp == null) {
            return false;
        }
        
        // PHẢI có đủ: ApplicationID + Origination Channel
        // Vì Origination Channel được fetch từ API riêng (AppStatus)
        // Nếu thiếu thì cần gọi lại API để lấy đủ data
        Boolean hasAppId = String.isNotBlank(ipp.FEC_Application_ID__c);
        Boolean hasOriginationChannel = String.isNotBlank(ipp.FEC_Origination_Channel__c);
        
        System.debug('### hasSalesInfo check: ApplicationID=' + hasAppId + ', OriginationChannel=' + hasOriginationChannel);
        
        return hasAppId && hasOriginationChannel;
    }

        // Helper: Map từ FEC_Sales_Info__c sang SalesInfoResult
        private static SalesInfoResult mapSalesInfoToResult(FEC_IPP__c info) {
            SalesInfoResult result = new SalesInfoResult();
            result.applicationId = info.FEC_Application_ID__c;
            result.originationChannel = info.FEC_Origination_Channel__c;
            result.disbursementChannel = info.FEC_Disbursement_Channel__c;
            result.ccCode = info.FEC_CC_Code__c;
            result.ccName = info.FEC_CC_Name__c;
            result.dsaCode = info.FEC_DSA_Code__c;
            result.dsaName = info.FEC_DSA_Name__c;
            result.tsaCode = info.FEC_TSA_Code__c;
            result.tsaName = info.FEC_TSA_Name__c;
            result.isSuccess = true;
            return result;
        }
        
        // Helper: Update IPP record với Sales Info
        private static void updateIPPRecordWithSalesInfo(SalesInfoResult result, Id ippRecordId) {
            try {
                FEC_IPP__c toUpdate = new FEC_IPP__c(Id = ippRecordId);
                Boolean hasUpdate = false;

                if (String.isNotBlank(result.applicationId)) {
                    toUpdate.FEC_Application_ID__c = result.applicationId;
                    hasUpdate = true;
                }
                if (String.isNotBlank(result.originationChannel)) {
                    toUpdate.FEC_Origination_Channel__c = result.originationChannel;
                    hasUpdate = true;
                }
                if (String.isNotBlank(result.disbursementChannel)) {
                    toUpdate.FEC_Disbursement_Channel__c = result.disbursementChannel;
                    hasUpdate = true;
                }
                if (String.isNotBlank(result.ccCode)) {
                    toUpdate.FEC_CC_Code__c = result.ccCode;
                    hasUpdate = true;
                }
                if (String.isNotBlank(result.ccName)) {
                    toUpdate.FEC_CC_Name__c = result.ccName;
                    hasUpdate = true;
                }
                if (String.isNotBlank(result.dsaCode)) {
                    toUpdate.FEC_DSA_Code__c = result.dsaCode;
                    hasUpdate = true;
                }
                if (String.isNotBlank(result.dsaName)) {
                    toUpdate.FEC_DSA_Name__c = result.dsaName;
                    hasUpdate = true;
                }
                if (String.isNotBlank(result.tsaCode)) {
                    toUpdate.FEC_TSA_Code__c = result.tsaCode;
                    hasUpdate = true;
                }
                if (String.isNotBlank(result.tsaName)) {
                    toUpdate.FEC_TSA_Name__c = result.tsaName;
                    hasUpdate = true;
                }

                if (hasUpdate) {
                    update toUpdate;
                    System.debug('### FEC_SalesInfoController: Updated Sales Info for IPP ' + ippRecordId);
                } else {
                    System.debug('### FEC_SalesInfoController: No Sales Info fields to update');
                }
            } catch (Exception e) {
                System.debug('### FEC_SalesInfoController updateIPPRecordWithSalesInfo ERROR: ' + e.getMessage());
                System.debug('### Stack Trace: ' + e.getStackTraceString());
            }
        }

        // Helper: Lưu SalesInfoResult vào FEC_IPP__c
        private static void saveSalesInfoToDatabase(SalesInfoResult result, Id customerHistoryId) {
            try {
                FEC_IPP__c info = new FEC_IPP__c();
                info.FEC_Application_ID__c = result.applicationId;
                if (customerHistoryId != null) info.FEC_Customer_History__c = customerHistoryId;
                info.FEC_Origination_Channel__c = result.originationChannel;
                info.FEC_Disbursement_Channel__c = result.disbursementChannel;
                info.FEC_CC_Code__c = result.ccCode;
                info.FEC_CC_Name__c = result.ccName;
                info.FEC_DSA_Code__c = result.dsaCode;
                info.FEC_DSA_Name__c = result.dsaName;
                info.FEC_TSA_Code__c = result.tsaCode;
                info.FEC_TSA_Name__c = result.tsaName;
                insert info;
            } catch (Exception e) {
                System.debug('Error saving SalesInfo to DB: ' + e.getMessage());
            }
        }
    
    //=============== PRIVATE HELPER METHODS ===============//
    
    /**
     * Kiểm tra AccountNumber có hợp lệ không (16 hoặc 19 chữ số)
     */
    private static Boolean isValidAccountNumber(String accountNumber) {
        if (String.isBlank(accountNumber)) {
            return false;
        }
        // AccountNumber phải có 16 hoặc 19 chữ số theo requirement của API GetCustomerList
        return Pattern.matches('^\\d{16}$', accountNumber) || Pattern.matches('^\\d{19}$', accountNumber);
    }
    
    /**
     * Gọi GetCustomerList để lấy ApplicationID từ AccountNumber
     */
    private static String getApplicationIdByAccountNumber(String accountNumber) {
        try {
            FEC_GetCustomerList.ResponseWrapper response = FEC_GetCustomerList.getCustomerList(
                'CRM',              // requestorId
                null,               // phoneNumber
                false,              // isReferenceSearch
                null,               // fullName
                null,               // nationalId
                null,               // applicationId
                null,               // creditCardNumber
                accountNumber,      // accountNumber ← Param tìm kiếm
                null,               // contractNumber
                null,               // email
                null                // personId
            );
            
            return extractApplicationIdFromResponse(response);
        } catch (Exception e) {
            System.debug('Error calling GetCustomerList by AccountNumber: ' + e.getMessage());
        }
        
        return null;
    }
    
    
    /**
     * Extract ApplicationID từ GetCustomerList response
     */
    private static String extractApplicationIdFromResponse(FEC_GetCustomerList.ResponseWrapper response) {
        if (response != null 
            && response.Sys != null 
            && '1'.equals(response.Sys.Code)
            && response.Customers != null 
            && !response.Customers.isEmpty()) {
            
            FEC_GetCustomerList.Customer customer = response.Customers[0];
            
            if (customer.Applications != null && !customer.Applications.isEmpty()) {
                return customer.Applications[0].ApplicationID;
            }
        }
        return null;
    }
    
    /**
     * Gọi GetCustomerSaleDisburseInfo và populate result
     */
    private static void populateSaleDisburseInfo(SalesInfoResult result, String applicationId) {
        try {
            FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleDisburseInfoResponse response = 
                FEC_GetCustomerSaleDisburseInfoCallout.getCustomerSaleDisburseInfo(applicationId);
            if (FEC_GetCustomerSaleDisburseInfoCallout.isSuccess(response)) {
                FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleInfo saleInfo = 
                    FEC_GetCustomerSaleDisburseInfoCallout.getFirstSaleInfo(response);
                if (saleInfo != null) {
                    result.ccCode = saleInfo.CC_CODE;
                    result.ccName = saleInfo.CC_NAME;
                    result.dsaCode = saleInfo.DSA_CODE;
                    result.dsaName = saleInfo.DSA_NAME;
                    result.tsaCode = saleInfo.TSA_CODE;
                    result.tsaName = saleInfo.TSA_NAME;
                    result.disbursementChannel = saleInfo.DISB_CHANNEL;
                }
            }
        } catch (Exception e) {
            System.debug('Error calling GetCustomerSaleDisburseInfo: ' + e.getMessage());
        }
    }
    
    /**
     * Gọi AppStatus và populate origination channel
     */
    /**
 * Gọi AppStatus và populate origination channel
 */
private static void populateAppStatusInfo(SalesInfoResult result, String applicationId) {
    System.debug('### [START] populateAppStatusInfo called with ApplicationID: ' + applicationId);
    try {
        FEC_GetAppStatusCallout.AppStatusResponse response = 
            FEC_GetAppStatusCallout.getAppStatus(applicationId);
        
        System.debug('### [RESPONSE] AppStatus API Response received');
        System.debug('### [CHECK] Response Sys Code: ' + (response?.Sys?.Code));
        System.debug('### [CHECK] Is Success: ' + FEC_GetAppStatusCallout.isSuccess(response));
        
        if (FEC_GetAppStatusCallout.isSuccess(response)) {
            FEC_GetAppStatusCallout.Application app = 
                FEC_GetAppStatusCallout.getFirstApplication(response);
            
            System.debug('### [CHECK] Application data: ' + (app != null ? 'Found' : 'NULL'));
            
            if (app != null) {
                System.debug('### [FOUND] OriginalChannel from API: ' + app.OriginalChannel);
                result.originationChannel = app.OriginalChannel;
                System.debug('### [SUCCESS] Set result.originationChannel = ' + result.originationChannel);
            } else {
                System.debug('### [WARNING] Application is NULL');
            }
        } else {
            System.debug('### [WARNING] AppStatus API not successful');
        }
    } catch (Exception e) {
        System.debug('### [ERROR] Exception in populateAppStatusInfo: ' + e.getMessage());
        System.debug('### [ERROR] Stack Trace: ' + e.getStackTraceString());
    }
    System.debug('### [END] populateAppStatusInfo completed');
}
}