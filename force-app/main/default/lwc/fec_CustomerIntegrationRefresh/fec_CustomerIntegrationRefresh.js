import { subscribe, unsubscribe, onError } from 'lightning/empApi';

export const CUSTOMER_INTEGRATION_REFRESH_CHANNEL =
    '/event/FEC_Customer_Integration_Refresh__e';

let errorListenerRegistered = false;

function registerEmpErrorListener() {
    if (errorListenerRegistered) {
        return;
    }
    errorListenerRegistered = true;
    onError(() => {});
}

/**
 * Subscribe to customer integration completion events for a Case.
 * @param {String} caseId
 * @param {Function} onRefresh callback when integration completes for this case
 * @returns {Promise<Object>} empApi subscription handle
 */
export function subscribeCustomerIntegrationRefresh(caseId, onRefresh) {
    registerEmpErrorListener();

    return subscribe(CUSTOMER_INTEGRATION_REFRESH_CHANNEL, -1, (message) => {
        const eventCaseId = message?.data?.payload?.FEC_Case_Id__c;
        if (eventCaseId === caseId && typeof onRefresh === 'function') {
            onRefresh();
        }
    });
}

export function unsubscribeCustomerIntegrationRefresh(subscription) {
    if (!subscription) {
        return;
    }
    unsubscribe(subscription, () => {});
}
