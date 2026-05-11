import { LightningElement, api, wire } from "lwc";

import {
    subscribe,
    unsubscribe,
    APPLICATION_SCOPE,
    MessageContext,
} from "lightning/messageService";

import CASE_NOC
    from "@salesforce/messageChannel/FEC_Case_NOC__c";

import getSubProcesses
    from "@salesforce/apex/FEC_SubProcessService.getSubProcesses";

export default class Fec_SubProcessContainer
    extends LightningElement {

    @api recordId;

    @wire(MessageContext)
    messageContext;

    subscription = null;

    lastKey;

    config = {
        showHoldCase: false,
        showRemovePhone: false,
        showDNB: false,
        showTransferCall: false,
    };

    // ===== LIFECYCLE =====

    connectedCallback() {

        console.log(
            "🔥 [INIT] connectedCallback"
        );

        this.subscribeToMessageChannel();
    }

    disconnectedCallback() {

        console.log(
            "🧹 [CLEANUP] disconnectedCallback"
        );

        this.unsubscribeFromMessageChannel();
    }

    // ===== LMS =====

    subscribeToMessageChannel() {

        if (this.subscription) {
            return;
        }

        this.subscription = subscribe(
            this.messageContext,
            CASE_NOC,
            (message) => this.handleMessage(message),
            { scope: APPLICATION_SCOPE }
        );

        console.log("[LMS] Subscribed");
    }

    unsubscribeFromMessageChannel() {

        if (this.subscription) {

            unsubscribe(this.subscription);

            this.subscription = null;

            console.log("[LMS] Unsubscribed");
        }
    }

    // ===== HANDLE MESSAGE =====

    async handleMessage(message) {

        console.log(
            "[LMS] Received:",
            JSON.stringify(message)
        );

        if (!message) {
            return;
        }

        const {
            productTypeId,
            categoryId,
            subCategoryId,
            subCodeId
        } = message;

        const key =
            `${productTypeId}-${categoryId}-${subCategoryId}-${subCodeId}`;

        // prevent duplicate reload
        if (this.lastKey === key) {
            return;
        }

        this.lastKey = key;

        await this.loadSubProcesses({
            recordId: this.recordId,
            productTypeId,
            categoryId,
            subCategoryId,
            subCodeId
        });
    }

    // ===== LOAD CONFIG =====

    async loadSubProcesses(params) {

        try {

            const result =
                await getSubProcesses({
                    recordId: params.recordId,
                    productTypeId: params.productTypeId,
                    categoryId: params.categoryId,
                    subCategoryId: params.subCategoryId,
                    subCodeId: params.subCodeId
                });

            this.config = result || {
                showHoldCase: false,
                showRemovePhone: false,
                showDNB: false,
                showTransferCall: false,
            };

            console.log(
                "[SUBPROCESS CONFIG]",
                JSON.stringify(this.config)
            );

        } catch (error) {

            console.error(
                "[SUBPROCESS ERROR]",
                JSON.stringify(error)
            );
        }
    }
}