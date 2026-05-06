// Routing logic cho NOC Contract Closure — Sub Code RL16.02 / RL16.03
// "Hợp đồng không thể đóng"          → Team SP, Queue FEC_DQ_CS_Support
// "Hợp đồng có thể đóng với tờ trình" → Team CC, Queue FEC_DQ_CS_Customer_Care

export const CASE_RD_PAYMENT_CONTRACT_ASSESSMENT  = "Case.FEC_RD_Payment_Contract_Assessment__c";
export const FIELD_RD_PAYMENT_CONTRACT_ASSESSMENT = "FEC_RD_Payment_Contract_Assessment__c";
export const SUB_CODE_RL16_02            = "RL16.02";
export const SUB_CODE_RL16_03            = "RL16.03";
export const RD_PAYMENT_QUEUE_DEV_NAMES  = ["FEC_DQ_CS_Support", "FEC_DQ_CS_Customer_Care"];

const MAP_RD_ASSESSMENT_ROUTING = {
    "Hợp đồng không thể đóng":          { team: "SP", queueDevName: "FEC_DQ_CS_Support" },
    "Hợp đồng có thể đóng với tờ trình": { team: "CC", queueDevName: "FEC_DQ_CS_Customer_Care" },
};

/** Kiểm tra subCodeCode thuộc RL16.02 hoặc RL16.03. */
export function isRdPaymentSubCode(subCodeCode) {
    return subCodeCode === SUB_CODE_RL16_02 || subCodeCode === SUB_CODE_RL16_03;
}

/**
 * Trả về { locked, nextTeam, nextQueue } theo giá trị assessment.
 * @param {string} assessmentVal - giá trị FEC_RD_Payment_Contract_Assessment__c
 * @param {Object} queueMap      - DeveloperName → {id, name}
 */
export function resolveRdPaymentRouting(assessmentVal, queueMap) {
    const config = MAP_RD_ASSESSMENT_ROUTING[assessmentVal];
    if (!config) return { locked: false, nextTeam: null, nextQueue: null };
    const queueInfo = (queueMap || {})[config.queueDevName];
    return {
        locked:    true,
        nextTeam:  config.team,
        nextQueue: queueInfo
            ? { label: queueInfo.name, value: queueInfo.id }
            : { label: config.queueDevName, value: null },
    };
}
