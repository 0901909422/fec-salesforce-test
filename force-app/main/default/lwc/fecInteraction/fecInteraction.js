import { LightningElement, track, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';
import getInteraction from '@salesforce/apex/FEC_InteractionController.getInteraction';

const FIELDS = [
    'Case.FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c',
    'Case.FEC_Account_or_Contract__r.FEC_Primary_Phone__c',
    'Case.RecordType.DeveloperName'
];

export default class FecAllInteractionsCase extends NavigationMixin(LightningElement) {
    @api recordId;
    @track interactions = [];
    @track error;
    @track currentNationalID;
    @track currentPrimaryPhone;
    recordTypeName;
    
    sortedBy = 'FEC_Interaction_Start_On__c';
    sortDirection = 'desc';

    // Wire để lấy National ID, Phone Number và RecordType từ bản ghi hiện tại
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.currentNationalID = data.fields.FEC_Account_or_Contract__r?.value?.fields?.FEC_National_ID_Passport_ID__c?.value;
            this.currentPrimaryPhone = data.fields.FEC_Account_or_Contract__r?.value?.fields?.FEC_Primary_Phone__c?.value;
            this.recordTypeName = data.fields.RecordType?.value?.fields?.DeveloperName?.value;
            
            // Load interactions khi có đủ dữ liệu
            if (this.currentNationalID && this.currentPrimaryPhone) {
                this.loadInteractions();
            }
        } else if (error) {
            console.error('Error loading record:', error);
        }
    }

    // Chỉ hiển thị component khi recordType là 'Interaction'
    get isInteractionRecordType() {
        return this.recordTypeName === 'Interaction';
    }

    interactionColumns = [
        { 
            label: 'ID', 
            fieldName: 'LinkURL', 
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'DisplayID' },
                target: '_blank'
            },
            sortable: true
        },
        { 
            label: 'Interaction Channel', 
            fieldName: 'FEC_Channel__c', 
            type: 'text',
            sortable: true
        },
        { 
            label: 'Interaction Subchannel', 
            fieldName: 'FEC_Interaction_Subchannel__c', 
            type: 'text',
            sortable: true
        },
        { 
            label: 'Interaction Start On', 
            fieldName: 'FEC_Interaction_Start_On__c', 
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: '2-digit',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit'
            },
            sortable: true
        },
        { 
            label: 'Created By', 
            fieldName: 'CreatedByName', 
            type: 'text',
            sortable: true
        },
        { 
            label: 'Interaction Duration', 
            fieldName: 'FEC_Interaction_Duration__c', 
            type: 'text',
            sortable: true
        },
        { 
            label: 'Interaction End On', 
            fieldName: 'FEC_Interaction_End_On__c', 
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: '2-digit',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit'
            },
            sortable: true
        },
        { 
            label: 'Final Status', 
            fieldName: 'FEC_Final_Status__c', 
            type: 'text',
            sortable: true
        },
        { 
            label: 'External Interaction ID', 
            fieldName: 'FEC_External_Interaction_ID__c', 
            type: 'text',
            sortable: true
        },
        { 
            label: 'Interaction Phone', 
            fieldName: 'FEC_Phone_Number__c', 
            type: 'text',
            sortable: true
        },
        { 
            label: 'Email', 
            fieldName: 'FEC_Interaction_Email__c', 
            type: 'text',
            sortable: true
        }
    ];

    // Load Interactions được lọc theo National ID và Phone Number
    loadInteractions() {
        console.log('Loading interactions with:', {
            nationalId: this.currentNationalID,
            primaryPhone: this.currentPrimaryPhone
        });
        
        getInteraction({ 
            nationalId: this.currentNationalID,
            primaryPhone: this.currentPrimaryPhone 
        })
        .then(data => {
            console.log('Interactions loaded:', data.length, 'records');
            this.interactions = data.map(record => {
                return {
                    ...record,
                    CreatedByName: record.CreatedBy ? record.CreatedBy.Name : '',
                    LinkURL: '/' + record.Id,
                    DisplayID: this.generateDisplayID(record)
                };
            });
            this.error = undefined;
        })
        .catch(error => {
            console.error('Error loading interactions:', error);
            this.error = error;
            this.interactions = [];
        });
    }

    get interactionRecordInfo() {
        const count = this.interactions ? this.interactions.length : 0;
        const updated = 'Updated 3 minutes ago';
        return `${count} Item${count !== 1 ? 's' : ''} • Sorted by Created Date • ${updated}`;
    }

    get hasInteractions() {
        return this.interactions && this.interactions.length > 0;
    }

    handleInteractionRefresh() {
        // Reload interactions from server
        if (this.recordId && this.currentNationalID && this.currentPrimaryPhone) {
            this.loadInteractions();
        }
    }

    handleInteractionSettings() {
        console.log('Interaction Settings clicked');
    }

    handleViewAllInteractions() {
        // Navigate to standard Case list view filtered by Interaction record type
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'list'
            },
            state: {
                filterName: 'Recent' // Or use a specific list view name
            }
        });
    }

    handleInteractionRowAction(event) {
        const row = event.detail.row;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: row.Id,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData(this.interactions, this.sortedBy, this.sortDirection);
    }

    sortData(data, fieldName, direction) {
        let parseData = JSON.parse(JSON.stringify(data));
        let keyValue = (a) => {
            return a[fieldName];
        };
        let isReverse = direction === 'asc' ? 1: -1;
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : '';
            y = keyValue(y) ? keyValue(y) : '';
            return isReverse * ((x > y) - (y > x));
        });
        
        this.interactions = parseData;
    }

    generateDisplayID(record) {
        // Nếu không có FEC_ID__c thì trả về text mặc định
        if (!record.FEC_ID__c) {
            return 'N/A';
        }

        let prefix = ''; // Default
        
        // Xác định prefix theo Kênh (Channel)
        const channel = record.FEC_Channel__c;
        switch(channel) {
            case 'Inbound':
                prefix = 'I';
                break;
            case 'Outbound':
                prefix = 'O';
                break;
            case 'Email':
                prefix = 'E';
                break;
            case 'Chat':
                prefix = 'C';
                break;
            case 'F2F':
                prefix = 'F';
                break;
            case 'Letter':
                prefix = 'L';
                break;
            case 'Internal':
                prefix = 'IN';
                break;
            case 'External':
                prefix = 'EX';
                break;
            default:
                prefix = 'S';
        }
        
        return prefix + '-' + record.FEC_ID__c;
    }

}