/**
 * Shared test data helpers for My Case API tests (fptqa01, fptsb01, …).
 */
@IsTest
public class FEC_UnitTestMyCaseChannelUtil {

    public static final String VALID_ACCOUNT_16 = '0001500060000003';

    public static FEC_Channel__c ensureApiChannel() {
        String apiChannel = FEC_ConstantCommon.KEY_VALID_CHANNELS_API;
        List<FEC_Channel__c> existing = [
            SELECT Id, FEC_Channel_ID__c, FEC_Get_Nature_Of_Case__c
            FROM FEC_Channel__c
            WHERE FEC_Channel_ID__c = :apiChannel
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0];
        }
        FEC_Channel__c ch = new FEC_Channel__c(
            Name = apiChannel,
            FEC_Code__c = apiChannel,
            FEC_Channel_ID__c = apiChannel,
            FEC_Channel_Vietnamese_name__c = apiChannel,
            FEC_Channel_Status__c = true,
            FEC_Get_Nature_Of_Case__c = true
        );
        insert ch;
        return ch;
    }

    public static FEC_Channel__c ensureInboundMyCaseChannel() {
        List<FEC_Channel__c> existing = [
            SELECT Id,
                   FEC_Channel_ID__c,
                   FEC_Get_Nature_Of_Case__c,
                   FEC_Update_Case_Status__c,
                   FEC_Cancel_Case__c
            FROM FEC_Channel__c
            WHERE FEC_Channel_ID__c = :FEC_ConstantCommon.CHANNEL_INBOUND_NAME
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            FEC_Channel__c ch = existing[0];
            Boolean needsUpdate =
                ch.FEC_Get_Nature_Of_Case__c != true
                || ch.FEC_Update_Case_Status__c != true;
            if (needsUpdate) {
                ch.FEC_Get_Nature_Of_Case__c = true;
                ch.FEC_Update_Case_Status__c = true;
                ch.FEC_Cancel_Case__c = true;
                update ch;
            }
            return ch;
        }
        FEC_Channel__c ch = new FEC_Channel__c(
            Name = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
            FEC_Code__c = 'INBOUND',
            FEC_Channel_ID__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
            FEC_Channel_Vietnamese_name__c = 'Inbound',
            FEC_Channel_Status__c = true,
            FEC_Get_Nature_Of_Case__c = true,
            FEC_Update_Case_Status__c = true,
            FEC_Cancel_Case__c = true
        );
        insert ch;
        return ch;
    }

    public static void linkNocToChannel(Id nocId, Id channelId) {
        if (nocId == null || channelId == null) {
            return;
        }
        FEC_Channel__c ch = [
            SELECT FEC_Channel_ID__c
            FROM FEC_Channel__c
            WHERE Id = :channelId
            LIMIT 1
        ];
        update new FEC_Nature_of_Case__c(
            Id = nocId,
            FEC_Channel__c = ch.FEC_Channel_ID__c
        );
    }

    public static void assertNotSuccessWithMessage(
        FEC_CreateCSCaseService.CreateCSCaseResponse res,
        String expectedSubstring
    ) {
        System.assertNotEquals('1', res.Sys.Code, res.Sys.Description);
        System.assert(
            res.Sys.Description != null
                && res.Sys.Description.contains(expectedSubstring),
            'Expected message containing "' + expectedSubstring + '", got: ' + res.Sys.Description
        );
    }
}