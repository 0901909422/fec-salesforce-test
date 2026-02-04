import { LightningElement, api, track, wire } from 'lwc';
import loadMainInfo from '@salesforce/apex/FEC_MainInfoController.loadMainInfo';
import logSensitiveFromMainInfo from '@salesforce/apex/FEC_MainInfoController.logSensitiveFromMainInfo';
import { loadStyle } from 'lightning/platformResourceLoader';
import { formatDateVNI, maskValue } from 'c/fec_CommonUtils';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_Demographic_Label from '@salesforce/label/c.FEC_Demographic_Label';
import FEC_Customer_Number_Label from '@salesforce/label/c.FEC_Customer_Number_Label';
import FEC_Addresses_List_Label from '@salesforce/label/c.FEC_Addresses_List_Label';
import FEC_Customer_Name_Label from '@salesforce/label/c.FEC_Customer_Name_Label';
import FEC_Last_Name_Label from '@salesforce/label/c.FEC_Last_Name_Label';
import FEC_Middle_Name_Label from '@salesforce/label/c.FEC_Middle_Name_Label';
import FEC_First_Name_Label from '@salesforce/label/c.FEC_First_Name_Label';
import FEC_Date_of_Birth_Label from '@salesforce/label/c.FEC_Date_of_Birth_Label';
import FEC_Gender_Label from '@salesforce/label/c.FEC_Gender_Label';
import FEC_National_ID_Passport_ID_Label from '@salesforce/label/c.FEC_National_ID_Passport_ID_Label';
import FEC_Date_of_Issue_Label from '@salesforce/label/c.FEC_Date_of_Issue_Label';
import FEC_Place_of_Issue_Label from '@salesforce/label/c.FEC_Place_of_Issue_Label';
import FEC_Marital_Status_Label from '@salesforce/label/c.FEC_Marital_Status_Label';
import FEC_Primary_Phone_Label from '@salesforce/label/c.FEC_Primary_Phone_Label';
import FEC_CIF_Number_Label from '@salesforce/label/c.FEC_CIF_Number_Label';
import FEC_PID_Number_Label from '@salesforce/label/c.FEC_PID_Number_Label';

import COMMON_STYLES from '@salesforce/resourceUrl/FEC_CommonCss';

export default class Fec_MainInfo extends LightningElement {

    /* ================= INPUT ================= */
    @api recordId;

    /* ================= STATE ================= */
    @track data;
    @track error;
    @track isLoading = true;

    @track primaryPhone = false;
    @track nationalIDPassportID = false;
    @track activeSections = ['demographic', 'customerNumber', 'addresses'];

    addressColumns = [
        { label: 'Address Type', fieldName: 'addressType' },
        { label: 'Address', fieldName: 'address' },
        { label: 'Mailing Address', fieldName: 'mailingAddress' }
    ];

    customLabel = {
        msgErrorApiLabel: FEC_MSG_Error_API_Label,
        demographicLabel: FEC_Demographic_Label,
        customerNumberLabel: FEC_Customer_Number_Label,
        addressesListLabel: FEC_Addresses_List_Label,
        customerNameLabel: FEC_Customer_Name_Label,
        lastNameLabel: FEC_Last_Name_Label,
        middleNameLabel: FEC_Middle_Name_Label,
        firstNameLabel: FEC_First_Name_Label,
        dateOfBirthLabel: FEC_Date_of_Birth_Label,
        genderLabel: FEC_Gender_Label,
        nationalIDPassportIDLabel: FEC_National_ID_Passport_ID_Label,
        dateOfIssueLabel: FEC_Date_of_Issue_Label,
        placeOfIssueLabel: FEC_Place_of_Issue_Label,
        maritalStatusLabel: FEC_Marital_Status_Label,
        primaryPhoneLabel: FEC_Primary_Phone_Label,
        cifNumberLabel: FEC_CIF_Number_Label,
        pidNumberLabel: FEC_PID_Number_Label
    }

    /* ================= LIFECYCLE ================= */

    connectedCallback() {

        loadStyle(this, COMMON_STYLES)
            .then(() => {
                console.log("Common styles loaded successfully");
            })
            .catch((error) => {
                console.error("Error loading common styles", error);
            });
        this.fetchData();
    }

    /* ================= DATA ================= */

    fetchData() {
        this.isLoading = true;

        loadMainInfo({ caseId: this.recordId })
            .then(res => {
                this.data = res;
                console.log('his.data ====>', JSON.stringify(this.data));
                this.error = undefined;
            })
            .catch(err => {
                this.error = err?.body?.message || err;
                this.data = undefined;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }



    /* ================= GETTERS ================= */

    get hasData() {
        return this.data && Object.keys(this.data).length > 0;
    }

    get fullName() { return this.data?.fullName || ''; }
    get lastName() { return this.data?.lastName || ''; }
    get middleName() { return this.data?.middleName || ''; }
    get firstName() { return this.data?.firstName || ''; }
    get gender() { return this.data?.gender || ''; }
    get maritalStatus() { return this.data?.maritalStatus || ''; }
    get cifNumber() { return this.data?.cifNumber || ''; }
    get nationalIDPassportID() { return this.data?.nationalIDPassportID || ''; }
    get dateOfIssue() { return this.data?.dateOfIssue || ''; }
    get placeOfIssue() { return this.data?.placeOfIssue || ''; }

    get dateOfBirth() {
        return formatDateVNI(this.data?.birthDate);
    }

    getMaskingConfig(key) {
        const configs = {
            phone: {
                state: 'primaryPhone',
                section: 'Demographic',
                objectApi: 'Case',
                fieldLabel: 'Primary Phone',
                fieldApi: 'fec_primary_phone__c'
            },
            nationalId: {
                state: 'nationalIDPassportID',
                section: 'Demographic',
                objectApi: 'Case',
                fieldLabel: 'National ID / Passport ID',
                fieldApi: 'fec_national_id__passport_id__c'
            }
        };

        return configs[key];
    }
    toggleMasking(key) {
        const config = this.getMaskingConfig(key);
        if (!config) return;

        const stateName = config.state;

        if (!this[stateName]) {
            logSensitiveFromMainInfo({
                section: config.section,
                fieldLabel: config.fieldLabel,
                relatedCaseId: this.recordId
            }).catch(e => {
                console.error('Sensitive log failed', e);
            });
        }

        this[stateName] = !this[stateName];
    }

    get maskedPhone() {
        return maskValue(
            this.data?.primaryPhone,
            this.primaryPhone
        );
    }

    get maskedNationalIDPassportID() {
        return maskValue(
            this.data?.nationalIDPassportID,
            this.nationalIDPassportID
        );
    }


    get phoneEyeIcon() {
        return this.primaryPhone ? 'utility:preview' : 'utility:hide';
    }

    get nationalIDEyeIcon() {
        return this.nationalIDPassportID ? 'utility:preview' : 'utility:hide';
    }

    get addresses() {
        return this.data?.addresses || [];
    }

    get helpTextMap() {
        return this.data?.helpTexts || {};
    }

    /* ================= ACTION ================= */

    handleTogglePhone() {
        this.toggleMasking('phone');
    }

    handleToggleNationalIDPassportID() {
        this.toggleMasking('nationalId');
    }


}