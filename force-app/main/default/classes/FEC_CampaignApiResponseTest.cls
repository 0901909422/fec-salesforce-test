/**
 * FEC_CampaignApiResponseTest
 * Tests for FEC_CampaignApiResponse deserialization.
 * Validates: Requirements 8.1, 8.2, 8.3
 */
@isTest
private class FEC_CampaignApiResponseTest {

    // Feature: campaign-module-refactor, Property 5: API response deserialization round-trip
    // **Validates: Requirements 8.3**
    @isTest
    static void testApiResponseDeserialization_RoundTrip() {
        for (Integer i = 0; i < 100; i++) {
            // --- StatusResponse round-trip ---
            String statusJson = buildRandomStatusResponseJson();
            FEC_CampaignApiResponse.StatusResponse statusResp =
                (FEC_CampaignApiResponse.StatusResponse) JSON.deserialize(
                    statusJson, FEC_CampaignApiResponse.StatusResponse.class
                );
            String reserialized = JSON.serialize(statusResp);
            FEC_CampaignApiResponse.StatusResponse statusResp2 =
                (FEC_CampaignApiResponse.StatusResponse) JSON.deserialize(
                    reserialized, FEC_CampaignApiResponse.StatusResponse.class
                );
            Assert.areEqual(statusResp.status, statusResp2.status,
                'StatusResponse.status mismatch on iteration ' + i);
            Assert.areEqual(statusResp.message, statusResp2.message,
                'StatusResponse.message mismatch on iteration ' + i);
            if (statusResp.data != null) {
                Assert.areEqual(statusResp.data.size(), statusResp2.data.size(),
                    'StatusResponse.data size mismatch on iteration ' + i);
            }

            // --- CallingListResponse round-trip ---
            String callingJson = buildRandomCallingListResponseJson();
            FEC_CampaignApiResponse.CallingListResponse callingResp =
                (FEC_CampaignApiResponse.CallingListResponse) JSON.deserialize(
                    callingJson, FEC_CampaignApiResponse.CallingListResponse.class
                );
            String reserializedCalling = JSON.serialize(callingResp);
            FEC_CampaignApiResponse.CallingListResponse callingResp2 =
                (FEC_CampaignApiResponse.CallingListResponse) JSON.deserialize(
                    reserializedCalling, FEC_CampaignApiResponse.CallingListResponse.class
                );
            Assert.areEqual(callingResp.status, callingResp2.status,
                'CallingListResponse.status mismatch on iteration ' + i);
            if (callingResp.data != null) {
                Assert.areEqual(callingResp.data.size(), callingResp2.data.size(),
                    'CallingListResponse.data size mismatch on iteration ' + i);
            }
        }
    }

    @isTest
    static void testStatusResponse_ValidJson() {
        String jsonStr = '{"status":"OK","message":"success","data":[' +
            '{"recordId":"REC001","csContractString":"CS123","idiDocNbr":"DOC1","status":"1","error":null}' +
            ']}';
        FEC_CampaignApiResponse.StatusResponse resp =
            (FEC_CampaignApiResponse.StatusResponse) JSON.deserialize(
                jsonStr, FEC_CampaignApiResponse.StatusResponse.class
            );
        Assert.areEqual('OK', resp.status);
        Assert.areEqual(1, resp.data.size());
        Assert.areEqual('REC001', resp.data[0].recordId);
        Assert.areEqual('1', resp.data[0].status);
    }

    @isTest
    static void testCallingListResponse_ValidJson() {
        String jsonStr = '{"status":"OK","message":"done","data":[' +
            '{"recordId":"R1","accountOrContractNumber":"ACC001","callTime":"2024-01-01T10:00:00",' +
            '"attempt":"3","agentId":"AG01","callResult":"33"}' +
            ']}';
        FEC_CampaignApiResponse.CallingListResponse resp =
            (FEC_CampaignApiResponse.CallingListResponse) JSON.deserialize(
                jsonStr, FEC_CampaignApiResponse.CallingListResponse.class
            );
        Assert.areEqual('OK', resp.status);
        Assert.areEqual(1, resp.data.size());
        Assert.areEqual('ACC001', resp.data[0].accountOrContractNumber);
        Assert.areEqual('33', resp.data[0].callResult);
    }

    @isTest
    static void testStatusResponse_EmptyData() {
        String jsonStr = '{"status":"OK","message":"empty","data":[]}';
        FEC_CampaignApiResponse.StatusResponse resp =
            (FEC_CampaignApiResponse.StatusResponse) JSON.deserialize(
                jsonStr, FEC_CampaignApiResponse.StatusResponse.class
            );
        Assert.areEqual(0, resp.data.size());
    }

    @isTest
    static void testCallingListResponse_NullFields() {
        String jsonStr = '{"status":null,"message":null,"data":null}';
        FEC_CampaignApiResponse.CallingListResponse resp =
            (FEC_CampaignApiResponse.CallingListResponse) JSON.deserialize(
                jsonStr, FEC_CampaignApiResponse.CallingListResponse.class
            );
        Assert.areEqual(null, resp.status);
        Assert.areEqual(null, resp.data);
    }

    @isTest
    static void testBaseResponse_Coverage() {
        FEC_CampaignApiResponse.BaseResponse base = new FEC_CampaignApiResponse.BaseResponse();
        base.status = 'OK';
        base.message = 'test';
        Assert.areEqual('OK', base.status);
    }

    // ─── Data Generators ───────────────────────────────────────────

    private static String buildRandomStatusResponseJson() {
        Integer dataSize = Math.mod(Math.abs(Crypto.getRandomInteger()), 5);
        String dataJson = '';
        for (Integer j = 0; j < dataSize; j++) {
            if (j > 0) dataJson += ',';
            dataJson += '{"recordId":"' + randomAlphaNum(8) + '",' +
                '"csContractString":"' + randomAlphaNum(6) + '",' +
                '"idiDocNbr":"' + randomAlphaNum(5) + '",' +
                '"status":"' + (Math.mod(j, 3) == 0 ? '1' : (Math.mod(j, 3) == 1 ? '0' : '-1')) + '",' +
                '"error":null}';
        }
        return '{"status":"OK","message":"' + randomAlphaNum(10) + '","data":[' + dataJson + ']}';
    }

    private static String buildRandomCallingListResponseJson() {
        Integer dataSize = Math.mod(Math.abs(Crypto.getRandomInteger()), 5);
        String dataJson = '';
        for (Integer j = 0; j < dataSize; j++) {
            if (j > 0) dataJson += ',';
            dataJson += '{"recordId":"' + randomAlphaNum(8) + '",' +
                '"accountOrContractNumber":"' + randomAlphaNum(10) + '",' +
                '"callTime":"2024-01-01T10:00:00",' +
                '"attempt":"' + Math.mod(Math.abs(Crypto.getRandomInteger()), 10) + '",' +
                '"agentId":"' + randomAlphaNum(5) + '",' +
                '"callResult":"' + Math.mod(Math.abs(Crypto.getRandomInteger()), 60) + '"}';
        }
        return '{"status":"OK","message":"' + randomAlphaNum(10) + '","data":[' + dataJson + ']}';
    }

    private static String randomAlphaNum(Integer len) {
        String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        String result = '';
        for (Integer i = 0; i < len; i++) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            result += chars.substring(idx, idx + 1);
        }
        return result;
    }
}
