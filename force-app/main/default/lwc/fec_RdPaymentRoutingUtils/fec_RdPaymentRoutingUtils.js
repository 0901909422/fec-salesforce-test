// Routing logic cho NOC Contract Closure — Sub Code RL16.02 / RL16.03
// Mapping assessment → team/queue được cung cấp bởi Apex (FEC_RDPaymentContractAssessmentService.getRoutingConfig)
// để tránh hardcode picklist API value trong LWC.

export const CASE_RD_PAYMENT_CONTRACT_ASSESSMENT  = "Case.FEC_RD_Payment_Contract_Assessment__c";
export const FIELD_RD_PAYMENT_CONTRACT_ASSESSMENT = "FEC_RD_Payment_Contract_Assessment__c";
export const SUB_CODE_RL16_02 = "RL16.02";
export const SUB_CODE_RL16_03 = "RL16.03";

/** Kiểm tra subCodeCode thuộc RL16.02 hoặc RL16.03. */
export function isRdPaymentSubCode(subCodeCode) {
    return subCodeCode === SUB_CODE_RL16_02 || subCodeCode === SUB_CODE_RL16_03;
}

/**
 * Trả về { locked, nextTeam, nextQueue } theo giá trị assessment.
 *
 * @param {string} assessmentVal  - giá trị FEC_RD_Payment_Contract_Assessment__c (API value từ onchange
 *                                  hoặc label từ toLabel() khi load — cả hai đều được thử)
 * @param {Object} queueMap       - DeveloperName → {id, name}  (từ server)
 * @param {Object} routingMap     - assessmentApiValue → {team, queueDevName}  (từ server)
 * @param {Array}  picklistOptions - [{value, label}] từ picklistOptionsMap (để resolve label → API value)
 */
export function resolveRdPaymentRouting(assessmentVal, queueMap, routingMap, picklistOptions) {
    if (!routingMap || !assessmentVal) return { locked: false, nextTeam: null, nextQueue: null };

    // Thử trực tiếp với giá trị nhận được (API value từ onchange)
    let config = routingMap[assessmentVal];

    // Nếu không khớp, có thể assessmentVal là label (từ toLabel()) — resolve về API value qua picklistOptions
    if (!config && Array.isArray(picklistOptions)) {
        const opt = picklistOptions.find(
            (o) => o.label === assessmentVal || o.label?.trim() === assessmentVal?.trim()
        );
        if (opt) {
            config = routingMap[opt.value];
        }
    }

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
