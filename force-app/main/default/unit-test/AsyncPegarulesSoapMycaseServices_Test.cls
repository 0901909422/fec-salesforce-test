/**
 * Unit tests for AsyncPegarulesSoapMycaseServices (WSDL async Future wrappers).
 */
@IsTest
private class AsyncPegarulesSoapMycaseServices_Test {

    private static pegarulesSoapMycaseServices.SysType sampleSys() {
        pegarulesSoapMycaseServices.SysType sys = new pegarulesSoapMycaseServices.SysType();
        sys.Channel = 'CRM';
        sys.TransactionID = 'TXN-ASYNC-SVC';
        sys.DateTime_x = System.now();
        return sys;
    }

    private static AsyncPegarulesSoapMycaseService.AsyncServicePortSOAP newTestPort() {
        AsyncPegarulesSoapMycaseService.AsyncServicePortSOAP port =
            new AsyncPegarulesSoapMycaseService.AsyncServicePortSOAP();
        port.endpoint_x = 'https://test.invalid/prweb/PRSOAPServlet/SOAP/MyCase/Service';
        port.timeout_x = 120000;
        return port;
    }

    private static Continuation newContinuation(Integer id) {
        return new Continuation(id);
    }

    @IsTest
    static void testFutureGetValue_allOperations() {
        Test.setMock(WebServiceMock.class, new AsyncPegarulesSoapMycaseServices_WebServiceMock());

        pegarulesSoapMycaseServices.SysType sys = sampleSys();
        pegarulesSoapMycaseServices.CaseInfoType caseInfo = new pegarulesSoapMycaseServices.CaseInfoType();
        caseInfo.CaseID = 'CASE-ASYNC-1';
        caseInfo.Reason = 'Reason';
        caseInfo.Note = 'Note';

        pegarulesSoapMycaseServices.CaseGetInfoType getInfo = new pegarulesSoapMycaseServices.CaseGetInfoType();
        getInfo.CaseID = 'CASE-ASYNC-1';

        pegarulesSoapMycaseServices.CustomerInfoType customer =
            new pegarulesSoapMycaseServices.CustomerInfoType();
        customer.CustomerID = 'CUST-1';
        customer.CustomerName = 'Test Customer';
        customer.NationalID = '123456789';
        customer.Mobile = '0901234567';

        pegarulesSoapMycaseServices.ContractInfoType contract =
            new pegarulesSoapMycaseServices.ContractInfoType();
        contract.ContractNumber = 'CON-1';
        contract.ProductCode = 'CC';

        pegarulesSoapMycaseServices.CaseCreateType createCase =
            new pegarulesSoapMycaseServices.CaseCreateType();
        createCase.CaseType = 'Request';
        createCase.DetailCaseType = 'Detail';
        createCase.Content = 'Body';

        AsyncPegarulesSoapMycaseService.AsyncServicePortSOAP port = newTestPort();

        Test.startTest();
        AsyncPegarulesSoapMycaseServices.CancelCSCaseResponseTypeFuture cancelFuture =
            port.beginCancelCSCase(newContinuation(1), sys, caseInfo);
        pegarulesSoapMycaseServices.ResultType cancelResult = cancelFuture.getValue();

        AsyncPegarulesSoapMycaseServices.GetCSCaseDetailResponseTypeFuture detailFuture =
            port.beginGetCSCaseDetail(newContinuation(2), sys, getInfo);
        pegarulesSoapMycaseServices.GetCSCaseDetailResponseType detailResp = detailFuture.getValue();

        AsyncPegarulesSoapMycaseServices.GetCSCaseStatusResponseTypeFuture statusFuture =
            port.beginGetCSCaseStatus(newContinuation(3), sys, getInfo);
        pegarulesSoapMycaseServices.GetCSCaseStatusResponseType statusResp = statusFuture.getValue();

        AsyncPegarulesSoapMycaseServices.GetCSMasterDataByCodeResponseTypeFuture byCodeFuture =
            port.beginGetCSMasterDataByCode(newContinuation(4), sys, 'Category', 'PARENT');
        pegarulesSoapMycaseServices.GetCSMasterDataByCodeResponseType byCodeResp = byCodeFuture.getValue();

        AsyncPegarulesSoapMycaseServices.CreateCSCaseResponseTypeFuture createFuture =
            port.beginCreateCSCase(newContinuation(5), sys, customer, contract, createCase);
        pegarulesSoapMycaseServices.CreateCSCaseResponseType createResp = createFuture.getValue();

        AsyncPegarulesSoapMycaseServices.GetCSMasterDataResponseTypeFuture masterFuture =
            port.beginGetCSMasterData(newContinuation(6), sys, 'Category');
        pegarulesSoapMycaseServices.GetCSMasterDataResponseType masterResp = masterFuture.getValue();
        Test.stopTest();

        System.assertNotEquals(null, cancelResult, 'CancelCSCase getValue() returned null Result.');
        System.assertEquals('0', cancelResult.Code);

        System.assertNotEquals(null, detailResp, 'GetCSCaseDetail getValue() returned null.');
        System.assertNotEquals(null, detailResp.Result);
        System.assertEquals('0', detailResp.Result.Code);

        System.assertNotEquals(null, statusResp, 'GetCSCaseStatus getValue() returned null.');
        System.assertNotEquals(null, statusResp.CaseInfo);

        System.assertNotEquals(null, byCodeResp, 'GetCSMasterDataByCode getValue() returned null.');
        System.assertNotEquals(null, byCodeResp.DataList);

        System.assertNotEquals(null, createResp, 'CreateCSCase getValue() returned null.');
        System.assertNotEquals(null, createResp.CaseInfo);

        System.assertNotEquals(null, masterResp, 'GetCSMasterData getValue() returned null.');
        System.assertEquals('0', masterResp.Result.Code);
    }
}
