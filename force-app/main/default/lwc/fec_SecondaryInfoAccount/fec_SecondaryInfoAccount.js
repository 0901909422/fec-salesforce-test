import { LightningElement, api, track } from 'lwc';
import loadSecondaryAccount
    from '@salesforce/apex/FEC_SecondaryInfoAccountController.loadSecondaryAccount';
import refreshSecondaryAccount
    from '@salesforce/apex/FEC_SecondaryInfoAccountController.refreshSecondaryAccount';

export default class Fec_SecondaryInfoAccount extends LightningElement {

    /* ================= INPUT ================= */
    @api recordId;

    /* ================= STATE ================= */
    @track limitFields = [];
    @track mainCardFields = [];
    @track pinFields = [];
    @track feeFields = [];
    @track collectionsInfoFields = [];
    @track salesInfoFields = [];
    @track dto;

    isLoading = false;
    error;

    activeSections = [
        'Limit',
        'Main Card'
    ];

    refreshStatusMap = {
        'Limit': 'NONE',
        'Main Card': 'NONE',
        'PIN': 'NONE',
        'Fee': 'NONE',
        'Collections Info': 'NONE',
        'Sales Info': 'NONE'
    };

    /* ================= LIFECYCLE ================= */

    connectedCallback() {
        if (this.recordId) {
            this.loadData();
        }
    }

    /* ================= LOAD ================= */

    loadData() {
        this.isLoading = true;

        loadSecondaryAccount({ caseId: this.recordId })
            .then(dto => {
                this.dto = dto;
                this.mapLimitSection(dto, 'NONE');
                this.mapMainCardSection(dto, 'NONE');
                this.mapPinSection(dto, 'NONE');
                this.mapFeeSection(dto, 'NONE');
                this.mapCollectionsInfoSection(dto, 'NONE');
                this.mapSalesInfoSection(dto, 'NONE');
                this.error = undefined;
            })
            .catch(err => {
                console.error('SecondaryInfo load error', err)
            })
            .catch(err => {
                console.error('SecondaryInfo load error', err);
                this.error = err;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    get hasData() {
        console.log('dto ===>', JSON.stringify(this.dto))
        return this.dto && Object.keys(this.dto).length > 0;
    }

    /* ================= REFRESH ================= */

    setRefreshStatus(section, status) {
        this.refreshStatusMap = {
            ...this.refreshStatusMap,
            [section]: status
        };
    }

    handleRefresh(event) {
        event.stopPropagation();

        const section = event.detail?.section;
        if (!section || !this.recordId) return;

        this.setRefreshStatus(section, 'NONE');
        this.isLoading = true;

        refreshSecondaryAccount({ caseId: this.recordId })
            .then(dto => {

                if (section === 'Main Card') {
                    this.mapMainCardSection(dto, 'SUCCESS');
                }

                if (section === 'PIN') {
                    this.mapPinSection(dto, 'SUCCESS');
                }

                if (section === 'Collections Info') {
                    this.mapCollectionsInfoSection(dto, 'SUCCESS');
                }

                this.setRefreshStatus(section, 'SUCCESS');
            })
            .catch(err => {
                console.error('Refresh SecondaryInfo error', err);
                this.setRefreshStatus(section, 'ERROR');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /* ================= MAP UI ================= */

    mapLimitSection(dto) {
        this.limitFields = [
            this.buildField('Daily Retail Limit', dto.dailyRetailLimit),
            this.buildField('Daily Cash Limit', dto.dailyCashLimit),

            this.buildField('One-Time Retail Limit', dto.oneTimeRetailLimit),
            this.buildField('One-Time Cash Limit', dto.oneTimeCashLimit),

            this.buildField('Daily Retail Number', dto.dailyRetailNumber),
            this.buildField('Daily Cash Number', dto.dailyCashNumber),

            this.buildField('Daily E-commerce Limit', dto.dailyECommerceLimit),
            this.buildField('Available Cash Limit', dto.availableCashLimit),

            this.buildField('One-Time E-commerce Limit', dto.oneTimeECommerceLimit),
            this.buildField('Last Credit Limit', dto.lastCreditLimit),

            this.buildField('Daily E-commerce Number', dto.dailyECommerceNumber),
            this.buildField('Last Credit Limit Date', dto.lastCreditLimitDate)
        ];
    }

    mapMainCardSection(dto, status = 'NONE') {
        this.mainCardFields = [
            this.buildField('First Transaction Amount', dto.firstTransactionAmount, status),
            this.buildField('Last Transaction Amount', dto.lastTransactionAmount, status),
            this.buildField('First Effective Date', dto.firstEffectiveDate, status),
            this.buildField('Last Effective Date', dto.lastEffectiveDate, status),
            this.buildField('Embossing Name', dto.embossingName, status),
            this.buildField('Last Advance Amount', dto.lastAdvanceAmount, status),
            this.buildField('Statement Notification Type', dto.statementNotificationType, status),
            this.buildField('Last Advance Date', dto.lastAdvanceDate, status),
            this.buildField('Memorable Question', dto.memorableQuestion, status)
        ];
    }

    mapPinSection(dto, status) {
        this.pinFields = [
            this.buildField('Last PIN Status', dto.lastPinStatus, status),
            this.buildField('Last PIN Action Date', dto.lastPinActionDate, status)
        ];
    }

    mapFeeSection(dto, status) {
        this.feeFields = [
            this.buildField('Annual Fee', dto.annualFee, status),
            this.buildField('Last AF Date', dto.lastAFDate, status)
        ];
    }

    mapCollectionsInfoSection(dto, status) {
        this.collectionsInfoFields = [
            this.buildField('Responsible Unit', dto.responsibleUnit, status),
            this.buildField('Date Assigned', dto.responsiblePerson, status),
            this.buildField('Responsible Person', dto.dateAssigned, status),
            this.buildField('Delinquency Date', dto.delinquencyDate, status),
        ];
    }
    mapSalesInfoSection(dto, status) {
        this.salesInfoFields = [
            this.buildField('CC Code', dto.ccCode, status),
            this.buildField('CC Name', dto.ccName, status),
            this.buildField('DSA Code', dto.dsaCode, status),
            this.buildField('DSA Name', dto.dsaName, status),
            this.buildField('TSA Code', dto.tsaCode, status),
            this.buildField('TSA Name', dto.tsaName, status)
        ];
    }
    /* ================= FIELD BUILDER ================= */

    buildField(label, value, status) {
        return {
            label,
            value: value || '-',
            syncStatus: status
        };
    }
}