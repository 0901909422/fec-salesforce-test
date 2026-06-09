/** Gate BP — khớp FEC_Business_Process__c.FEC_Code__c trên org. */
const SCOPED_BP_CODES = new Set([
  "Document Request",
  "Original MRC Return",
]);

export function isScopedStageChangeRoutingBusinessProcess(businessCode) {
  if (!businessCode || typeof businessCode !== "string") {
    return false;
  }
  return SCOPED_BP_CODES.has(businessCode.trim());
}

export function findRouteToActionId(routingActionlst) {
  if (!routingActionlst?.length) {
    return null;
  }
  const routeTo = routingActionlst.find(
    (a) =>
      a.code === "Route to" &&
      a.value === "Route to",
  );
  return routeTo?.id ?? null;
}
