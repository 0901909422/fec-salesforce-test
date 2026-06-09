/**
 * FEC_CampaignApiResponse
 * Shared API response wrapper classes for Campaign module.
 * Replaces duplicate inner classes in FEC_CheckCampaignStatusBatch
 * and FEC_GetCallingListResultBatch.
 * Used for JSON deserialization of external API responses.
 */
public class FEC_CampaignApiResponse {

    /**
     * Base response wrapper shared by all campaign APIs.
     */
    public virtual class BaseResponse {
        public String status;
        public String message;
    }

    /**
     * Response wrapper for check-status API.
     * Used by FEC_CheckCampaignStatusBatch.
     */
    public class StatusResponse extends BaseResponse {
        public List<StatusRecordData> data;
    }

    /**
     * Record-level data returned by check-status API.
     */
    public class StatusRecordData {
        public String recordId;
        public String csContractString;
        public String idiDocNbr;
        public String status;  // "1", "0", "-1"
        public String error;
    }

    /**
     * Response wrapper for get-calling-list-result API.
     * Used by FEC_GetCallingListResultBatch.
     */
    public class CallingListResponse extends BaseResponse {
        public List<CallingListRecordData> data;
    }

    /**
     * Record-level data returned by get-calling-list-result API.
     */
    public class CallingListRecordData {
        public String recordId;
        public String accountOrContractNumber;
        public String callTime;
        public String attempt;
        public String agentId;
        public String callResult;
    }
}
