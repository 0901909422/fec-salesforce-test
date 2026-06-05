import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { createRecord, updateRecord } from 'lightning/uiRecordApi';
import ENHANCED_LETTERHEAD_OBJECT from "@salesforce/schema/FEC_Enhanced_Letterhead__c";
import NAME_FIELD from "@salesforce/schema/FEC_Enhanced_Letterhead__c.Name";
import DESCRIPTION_FIELD from "@salesforce/schema/FEC_Enhanced_Letterhead__c.FEC_Description__c";
import HEADER_FIELD from "@salesforce/schema/FEC_Enhanced_Letterhead__c.FEC_Header__c";
import FOOTER_FIELD from "@salesforce/schema/FEC_Enhanced_Letterhead__c.FEC_Footer__c";
import RECORD_ID_FIELD from "@salesforce/schema/FEC_Enhanced_Letterhead__c.Id";
import newEnhancedLetterhead from '@salesforce/label/c.FEC_New_Enhanced_Letterhead';
import buttonSave from '@salesforce/label/c.FEC_Button_Save';
import buttonCancel from '@salesforce/label/c.FEC_Enhanced_Letterhead_Cancel';
import requireInfoLabel from '@salesforce/label/c.FEC_Required_Information';
import reviewErrorLabel from '@salesforce/label/c.FEC_Review_Error';
import informationLabel from '@salesforce/label/c.FEC_Information';
import contentLabel from '@salesforce/label/c.FEC_Letterhead_Content';
import contentInfoLabel from '@salesforce/label/c.FEC_Letterhead_Content_Info';
import headerInfo from '@salesforce/label/c.FEC_Header';
import footerInfo from '@salesforce/label/c.FEC_Footer';
import nameLabel from '@salesforce/label/c.FEC_Enhanced_Letterhead_Name';
import descriptionLabel from '@salesforce/label/c.FEC_Enhanced_Letterhead_Description';
import requiredNameLabel from '@salesforce/label/c.FEC_Required_Name';
import completeThisFieldLabel from '@salesforce/label/c.FEC_Complete_This_Field';
import requireHeaderOrFooterLabel from '@salesforce/label/c.FEC_Require_Header_Or_Footer';
import successMessage from '@salesforce/label/c.FEC_Enhanced_Letterhead_Success';
import updateSuccessMessage from '@salesforce/label/c.FEC_Letterhead_Success_Message';
import systemInfo from '@salesforce/label/c.FEC_System_Infomation';
import createdBy from '@salesforce/label/c.FEC_Created_By';
import lastModifiedBy from '@salesforce/label/c.FEC_Last_Modified_By';


export default class Fec_CustomLetterheadEditor extends NavigationMixin(LightningElement) {
    @track hasErrors = false;
    @track errorMessage = '';
    @track isPickerOpen = false;
    @track activeTarget = ''; // Stores 'header' or 'footer'
    @track savedSelection;
    @track editorValue = '';
    @track lastActiveEditorId = '';

    // public properties
    @api isCloneMode = '';
    @api recordId = '';
    @api name = '';
    @api description = '';
    @api header = '';
    @api footer = '';
    @api createdBy = '';
    @api createdById = '';
    @api lastModifyBy = '';
    @api lastModifyById = '';
    @api createdDate = '';
    @api LastModifiedDate = '';
    @api headerEditLabel = '';
    
    labels = {
        newEnhancedLetterhead,
        buttonSave,
        buttonCancel,
        requireInfoLabel,
        reviewErrorLabel,
        informationLabel,
        contentLabel,
        contentInfoLabel,
        headerInfo,
        footerInfo,
        nameLabel,
        descriptionLabel,
        requiredNameLabel,
        completeThisFieldLabel,
        requireHeaderOrFooterLabel,
        successMessage, 
        updateSuccessMessage,
        systemInfo,
        createdBy,
        lastModifiedBy
    }
 

    get createdByUrl () {
        return `/lightning/r/User/${this.createdById}/view`;
    }

    get lastModifyByUrl() {
        return `/lightning/r/User/${this.lastModifyById}/view`;
    }

    get headerTitle() {
        return this.isCloneMode ? this.labels.newEnhancedLetterhead : this.headerEditLabel;
    }

    get getMergeFieldLabel() {
        return '{ }';
    }

    get isNewMode() {
        return !this.recordId;
    }

    get containerCss() {
       return this.isPickerOpen ? 'slds-hide' : 'slds-modal__container';
    }


    get backdropCss(){
        return this.isCloneMode ? '' : 'slds-backdrop slds-backdrop_open';
    }

    // --- Input Change Handlers ---
    handleNameChange(event) {
        this.name = event.target.value;
        // Clear error banner once user starts typing
        if (this.name) {
            this.hasErrors = false;
        }
    }

    handleDescChange(event) {
        this.description = event.target.value;
    }

    handleHeaderChange(event) {
        this.header = event.target.value;
        console.log('this.handleHeaderChange:', this.header);
    }

    handleFooterChange(event) {
        this.footer = event.target.value;
        console.log('this.handleFooterChange:', this.footer);
    }

    async handleSave() {
        // Simple validation for required Name field
      const nameField = this.template.querySelector('.name-input');
        
        // 1. Validate Input Field (Adds the red border and "Complete this field" message)
        if (!nameField.value || nameField.value.trim() === '') {
            nameField.setCustomValidity(this.labels.completeThisFieldLabel);
            nameField.reportValidity();
            this.errorMessage = this.labels.requiredNameLabel; // msg: 'These required fields must be completed: Name';
            this.hasErrors = true; // Shows the top banner
            return;
        } else {
            nameField.setCustomValidity(''); // Clear previous errors
            nameField.reportValidity();
        }

        // 2. Validate Header/Footer (At least one must have content)
        // Note: Rich text often contains empty HTML tags like <p><br></p>, 
        // so we strip tags for a true "empty" check.
        const plainHeader = this.header?.replace(/<[^>]*>/g, '').trim();
        const plainFooter = this.footer?.replace(/<[^>]*>/g, '').trim();

        if (!plainHeader && !plainFooter) {
            this.errorMessage = this.labels.requireHeaderOrFooterLabel; // msg: 'The header and footer fields are empty. Add something to at least one field, then try again.';
            this.hasErrors = true;
            return;
        }

        let fields = {};
        // Map the user input to the fields
        fields[NAME_FIELD.fieldApiName] = this.name;
        fields[DESCRIPTION_FIELD.fieldApiName] = this.description;
        fields[HEADER_FIELD.fieldApiName] = this.header;
        fields[FOOTER_FIELD.fieldApiName] = this.footer;

        // Map the fields to the Object API structure

        
        if (this.isNewMode || this.isCloneMode) {
            const recordInput = { apiName: ENHANCED_LETTERHEAD_OBJECT.objectApiName, fields };
            await this.handleInsertRecord(recordInput);
       } else {
            fields[RECORD_ID_FIELD.fieldApiName] = this.recordId;
            const recordInput = { fields };
            await this.handleUpdateRecord(recordInput);
       }
    }

    async handleInsertRecord(recordInput) {
        try {
            const result = await createRecord(recordInput);
            const newRecordId = result.id; // Capture the new ID
            this.showToast('', this.labels.successMessage.replace('NAME_MERGE_FIELD', this.name), 'success');
            // 1. Dispatch event to Aura parent
            this.dispatchEvent(new CustomEvent('save', {
                detail: { recordId: newRecordId }
            })); //
        } catch (error) {
            this.showToast('Error creating record', error.body.error || error.body.message, 'error');
            console.error('Error:', error);
        }
    }

    async handleUpdateRecord(recordInput) {
        try {
            // Execution waits here until the promise is resolved
            await updateRecord(recordInput);
            this.showToast('', this.labels.updateSuccessMessage.replace('NAME_MERGE_FIELD', this.name), 'success');
            // Refresh and close after successful update
            await this.refreshPage();
        } catch (error) {
             this.showToast('Error updating record', error.body.error || error.body.message, 'error');
            console.error('Error:', error);
        }
    }

    /**
     * Refreshes the view and closes the modal
     */
    async refreshPage() {
        this.handleCancel();
    }

    // Helper to show toast notifications
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    openMergePicker(even) {
        // Placeholder for future Merge Field logic
        this.isPickerOpen = true;
        this.activeTarget = event.currentTarget.dataset.target;
        console.log('Merge field picker opened');
    }


    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    // Called when clicking Insert in the modal
    handleMergeFieldInsert(event) {
        const mergeTag = event.detail; // e.g., {{{Account.Name}}}

        if (this.activeTarget === 'header') {
            this.header = this.header + mergeTag;
        } else if (this.activeTarget === 'footer') {
            this.footer = this.footer + mergeTag;
        }

        this.handleClosePicker();
    }

    // Called when clicking Cancel in the modal
    handleClosePicker() {
        this.isPickerOpen = false;
        this.activeTarget = '';
    }
}