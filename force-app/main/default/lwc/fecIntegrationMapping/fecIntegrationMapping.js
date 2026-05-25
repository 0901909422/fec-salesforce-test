import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import loadUserTypeList from '@salesforce/apex/FEC_IntegrationMappingController.loadUserTypeList';
import loadChannelList from '@salesforce/apex/FEC_IntegrationMappingController.loadChannelList';
import loadMasterIntegration from '@salesforce/apex/FEC_IntegrationMappingController.loadMasterIntegration';
import loadAdditionalProperties from '@salesforce/apex/FEC_IntegrationMappingController.loadAdditionalProperties';
import loadIntegrationMapping from '@salesforce/apex/FEC_IntegrationMappingController.loadIntegrationMapping';
import searchAdditionalFields   from '@salesforce/apex/FEC_IntegrationMappingController.searchAdditionalFields';
import saveIntegrationMapping
    from '@salesforce/apex/FEC_IntegrationMappingController.saveIntegrationMapping';
import Loading from '@salesforce/label/c.Loading';
import User_Type from '@salesforce/label/c.User_Type';
import Int_Channel from '@salesforce/label/c.Int_Channel';
import Int_User_Type from '@salesforce/label/c.Int_User_Type';
import Int_Product_Line from '@salesforce/label/c.Int_Product_Line';
import Int_Service_Type from '@salesforce/label/c.Int_Service_Type';
import Int_Category from '@salesforce/label/c.Int_Category';
import Int_Sub_Category from '@salesforce/label/c.Int_Sub_Category';
import Int_Sub_Code from '@salesforce/label/c.Int_Sub_Code';
import Integrating_Property from '@salesforce/label/c.Integrating_Property';
import Vietnamese_Name from '@salesforce/label/c.Vietnamese_Name';
import Integrating_Property_Type from '@salesforce/label/c.Integrating_Property_Type';
import CSM_Property from '@salesforce/label/c.CSM_Property';
import CSM_Property_Type from '@salesforce/label/c.CSM_Property_Type';
import Auto_Mapping from '@salesforce/label/c.Auto_Mapping';
import Mandatory from '@salesforce/label/c.Mandatory';
import Cancel from '@salesforce/label/c.Cancel';
import Save from '@salesforce/label/c.Save';
import Integration_Mapping_Title from '@salesforce/label/c.Integration_Mapping_Title';
import LBL_Success from '@salesforce/label/c.LBL_Success';
import LBL_Error from '@salesforce/label/c.LBL_Error';
import LBL_SaveSuccess from '@salesforce/label/c.LBL_SaveSuccess';
import LBL_SaveFailed from '@salesforce/label/c.LBL_SaveFailed';
import LBL_UnexpectedError from '@salesforce/label/c.LBL_UnexpectedError';
import LBL_ValidationError from '@salesforce/label/c.LBL_ValidationError';
import LBL_HeaderRequired from '@salesforce/label/c.LBL_HeaderRequired';
import LBL_SelectAtLeastOneRow from '@salesforce/label/c.LBL_SelectAtLeastOneRow';



export default class FraudIntegrationMapping extends LightningElement {

    // Dropdown options
    @track userTypeOptions = [];
    @track intUserTypeOptions = [];
    @track channelOptions = [];
    @track productLineOptions = [];
    @track serviceTypeOptions = [];
    @track categoryOptions = [];
    @track subCategoryOptions = [];
    @track subCodeOptions = [];
    
    // Selected values
    @track userType = null;
    @track channel = null;
    @track intUserType = null;
    @track productLine = null;
    @track serviceType = null;
    @track category = null;
    @track subCategory = null;
    @track subCode = null;
    
    // Constants
    inSourceType = 'intUserType';
    intProductLine = 'productLine';
    intCaseType = 'CaseType';
    intCategory = 'Category';
    intSubCategory = 'SubCategory';
    intSubCode = 'SubCode';

    @track rows = [];
    @track loading = true;
    @api mappingId;
    @api userTypeName;           // NEW: Receive userType from parent
    @api channelFilter;          // NEW: Receive channel from parent
    @api natureOfCaseId;
    @api caseStageId;
    @api screenCaseId;
    
    get notLoading() { return !this.loading; }
    get hasSubCodeOptions() { return this.subCodeOptions && this.subCodeOptions.length > 0; }
    labels = {
        Integration_Mapping_Title,
        Loading,
        User_Type,
        Int_Channel,
        Int_User_Type,
        Int_Product_Line,
        Int_Service_Type,
        Int_Category,
        Int_Sub_Category,
        Int_Sub_Code,
        Integrating_Property,
        Vietnamese_Name,
        Integrating_Property_Type,
        CSM_Property,
        CSM_Property_Type,
        Auto_Mapping,
        Mandatory,
        Cancel,
        Save,
        success: LBL_Success,
        error: LBL_Error,
        saveSuccess: LBL_SaveSuccess,
        saveFailed: LBL_SaveFailed,
        unexpectedError: LBL_UnexpectedError,
        validationError: LBL_ValidationError,
        headerRequired: LBL_HeaderRequired,
        selectAtLeastOneRow: LBL_SelectAtLeastOneRow
    };

    /* ================= LIFECYCLE ================= */

    connectedCallback() {
        console.log('[INIT] FraudIntegrationMapping loaded');
        console.log('[INIT] Parent values:', {
            mappingId: this.mappingId,
            userTypeName: this.userTypeName,
            channelFilter: this.channelFilter,
            natureOfCaseId: this.natureOfCaseId
        });
        
        // Priority 1: Edit existing mapping
        if (this.mappingId) {
            this.loadForUpdate();
        }
        // Priority 2: Initialize from parent values
        else if (this.userTypeName && this.channelFilter) {
            console.log('[INIT] Initialize from parent values');
            this.initializeFromParent();
        }
        // Priority 3: Fresh start
        else {
            this.loadUserTypes();
        }
    }

    async initializeFromParent() {
        try {
            console.log('[INIT PARENT] Start loading dropdowns from parent values');
            this.loading = true;

            // Step 1: Load User Type dropdown
            this.userTypeOptions = await loadUserTypeList();
            console.log('[INIT PARENT] userTypeOptions loaded:', this.userTypeOptions);

            // Step 2: Find and set userType by name
            const userTypeMatch = this.userTypeOptions.find(
                opt => opt.label === this.userTypeName || opt.value === this.userTypeName
            );
            
            if (userTypeMatch) {
                this.userType = userTypeMatch.value;
                console.log('[INIT PARENT] userType matched:', {
                    name: this.userTypeName,
                    value: this.userType
                });
            } else {
                console.warn('[INIT PARENT] userTypeName not found:', this.userTypeName);
            }

            // Step 3: Load Channel dropdown
            this.channelOptions = await loadChannelList();
            console.log('[INIT PARENT] channelOptions loaded:', this.channelOptions);

            // Step 4: Find and set channel by filter
            const channelMatch = this.channelOptions.find(
                opt => opt.label === this.channelFilter || opt.value === this.channelFilter
            );
            
            if (channelMatch) {
                this.channel = channelMatch.value;
                console.log('[INIT PARENT] channel matched:', {
                    filter: this.channelFilter,
                    value: this.channel
                });

                // Step 5: Load Int User Type based on channel
                await this.loadIntUserTypeForChannel();
            } else {
                console.warn('[INIT PARENT] channelFilter not found:', this.channelFilter);
            }

            console.log('[INIT PARENT] Initialization complete');
        } catch (error) {
            console.error('[INIT PARENT ERROR]', error);
            this.showToast(this.labels.error, 'Error initializing from parent', 'error');
        } finally {
            this.loading = false;
        }
    }

    async loadIntUserTypeForChannel() {
        try {
            if (!this.channel) {
                console.warn('[LOAD INT USER TYPE] channel not set');
                return;
            }

            console.log('[LOAD INT USER TYPE] Loading for channel:', this.channel);
            
            this.intUserTypeOptions = await loadMasterIntegration({
                sourceType: this.inSourceType,
                parentId: this.channel,
                channelCode: this.channel
            });

            console.log('[LOAD INT USER TYPE] Loaded:', this.intUserTypeOptions);
        } catch (error) {
            console.error('[LOAD INT USER TYPE ERROR]', error);
        }
    }

    loadForUpdate() {
        //this.loading = true;
        loadIntegrationMapping({ mappingId: this.mappingId })
            .then(data => {
                this.loading = false;
                console.log('[LOAD UPDATE]', data);    
                //Top section
                this.userType = data.userTypeId;
                //this.userTypeId = data.userTypeId;
                this.channel = data.channel;
                this.intUserType = data.intUserTypeId;
                this.productLine = data.productLine;
                this.serviceType = data.serviceType;
                this.category = data.category;
                this.subCategory = data.subCategory;
                this.subCode = data.subCode;
    
                //Load hierarchy dropdowns in order
                this.loadDropdownChain(data);
    
                //Map child rows
                this.applyMappingInfos(data.infos);
                
            })
            .catch(err => {
                console.error('[LOAD UPDATE ERROR]', err);
                this.loading = false;
            });
    }

    async loadDropdownChain(data) {
        loadUserTypeList()
            .then(r => {
                console.log('[SUCCESS] UserType list:', r);
                this.userTypeOptions = r;
            })
            .catch(err => {
                console.error('[ERROR] loadUserTypeList:', err);
            });
        this.userTypeOptions = await loadUserTypeList();
        this.channelOptions = await loadChannelList();
        this.intUserTypeOptions = await loadMasterIntegration({ sourceType: this.inSourceType, parentId: this.channel, channelCode: this.channel });

        this.productLineOptions = await loadMasterIntegration({ sourceType: this.intProductLine, parentId:null , channelCode: data.channel});
        this.serviceTypeOptions = await loadMasterIntegration({ sourceType: this.intCaseType, parentId: data.productLine, channelCode: this.channel});
        this.categoryOptions = await loadMasterIntegration({ sourceType: this.intCategory, parentId: data.serviceType, channelCode: this.channel});
        this.subCategoryOptions = await loadMasterIntegration({ sourceType: this.intSubCategory, parentId: data.category, channelCode: this.channel });
        this.subCodeOptions = await loadMasterIntegration({ sourceType: this.intSubCode, parentId: data.subCategory, channelCode: this.channel});  
      
    }


    applyMappingInfos(infos) {
        //console.log('applyMappingInfos list:', infos);
        // Load properties after hierarchy is ready    
        loadAdditionalProperties({
            category: this.category,
            subCategory: this.subCategory,
            subCode: this.subCode,
            channelCode: this.channel,
            serviceType: this.serviceType,
            userTypeId: this.userType
        })
            .then(r => {
                //console.log('[SUCCESS] Additional Properties:', r);
                this.rows = r;
                this.rows = this.rows.map(r => {            
                const found = infos.find(i => i.property === r.property);
                console.log('found:', found);
                this.loading = false;
                if (!found) return r;      
                console.log('r.:', found);              
                return {
                    ...r,
                    csmPropertyId: found.csmPropertyId,
                    csmPropertyType: found.csmPropertyType,
                    csmProperty: found.csmProperty? `${found.csmProperty}`: null,
                    autoMapping: found.autoMapping,
                    autoMappingPropertySource: found.autoMappingPropertySource || r.autoMappingPropertySource
                };
                });
            })
            .catch(err => {
                console.error('[ERROR] loadAdditionalProperties:', err);
            });
        
    }
    
    
    /* ================= LOAD USER TYPE ================= */

    loadUserTypes() {
        console.log('[LOAD] UserType list');
    
        // ================= RESET ALL LOWER FIELDS =================
        console.log('[RESET] Reset Channel, ProductLine, ServiceType, Category, SubCategory, SubCode');
    
        // Reset selected values
        this.userType = null;
        this.intUserType = null;
        this.intUserType = null;
        this.channel = null;
        this.productLine = null;
        this.serviceType = null;
        this.category = null;
        this.subCategory = null;
        this.subCode = null;
    
        // Reset option lists
        this.channelOptions = [];
        this.productLineOptions = [];
        this.serviceTypeOptions = [];
        this.categoryOptions = [];
        this.subCategoryOptions = [];
        this.subCodeOptions = [];
        this.intUserTypeOptions = [];
    
        // Reset table
        this.rows = [];
    
        // ================= LOAD USER TYPE =================
        loadUserTypeList()
            .then(r => {
                console.log('[SUCCESS] UserType list:', r);
                this.userTypeOptions = r;
            })
            .catch(err => {
                console.error('[ERROR] loadUserTypeList:', err);
            });
    }
    

    /* ================= USER TYPE CHANGE ================= */

    handleUserType(e) {        
        this.userType = e.detail.value;
        console.log('[CHANGE] UserType selected:', this.userType);

        console.log('[RESET] Reset after UserType change');
        this.reset();
        // Reset option lists     
        this.intUserTypeOptions = [];   
        this.productLineOptions = [];
        this.serviceTypeOptions = [];
        this.categoryOptions = [];
        this.subCategoryOptions = [];
        this.subCodeOptions = [];
        this.channel = null;

        loadChannelList()
            .then(r => {
                console.log('[SUCCESS] Channel list:', r);
                this.channelOptions = r;
            })
            .catch(err => {
                console.error('[ERROR] loadChannelList:', err);
            });
    }

    /* ================= CHANNEL CHANGE ================= */
    handleChannel(e) {
        this.channel = e.detail.value;
        console.log('[CHANGE] Channel selected:', this.channel);

        console.log('[RESET] Reset after Channel change');
        this.intUserType = null;
        this.productLine = null;
        this.serviceType = null;
        this.category = null;
        this.subCategory = null;
        this.subCode = null;

        this.intUserTypeOptions = [];
        this.productLineOptions = [];
        this.serviceTypeOptions = [];
        this.categoryOptions = [];
        this.subCategoryOptions = [];
        this.subCodeOptions = [];
        this.rows = [];

        console.log('[CALL] loadMasterIntegration(IntUserType)', {
            sourceType: this.inSourceType,
            parentId: this.channel
        });

        loadMasterIntegration({
            sourceType: this.inSourceType,
            parentId: this.channel,
            channelCode: this.channel
        })
            .then(r => {
                console.log('[SUCCESS] IntUserType list:', r);
                this.intUserTypeOptions = r;
            })
            .catch(err => {
                console.error('[ERROR] loadMasterIntegration(IntUserType):', err);
            });
    }


    handleIntUserType(e) {
        this.intUserType = e.detail.value;
        console.log('[CHANGE] IntUserType selected:', this.intUserType);

        console.log('[RESET] Reset after intUserType change');
        this.productLine = null;
        this.serviceType = null;
        this.category = null;
        this.subCategory = null;
        this.subCode = null;

        this.productLineOptions = [];
        this.serviceTypeOptions = [];
        this.categoryOptions = [];
        this.subCategoryOptions = [];
        this.subCodeOptions = [];
        this.rows = [];

        console.log('[CALL] loadMasterIntegration(ProductLine)', {
            sourceType: this.intProductLine,
            parentId: this.channel
        });

        loadMasterIntegration({
            sourceType: this.intProductLine,
            parentId: null,
            channelCode: this.channel
        })
            .then(r => {
                console.log('[SUCCESS] ProductLine list:', r);
                this.productLineOptions = r;
            })
            .catch(err => {
                console.error('[ERROR] loadMasterIntegration(ProductLine):', err);
            });
    }

    /* ================= PRODUCT LINE CHANGE ================= */

    handleProductLine(e) {
        this.productLine = e.detail.value;
        console.log('[CHANGE] ProductLine selected:', this.productLine);

        console.log('[RESET] Reset after ProductLine change');
        this.serviceType = null;
        this.category = null;
        this.subCategory = null;
        this.subCode = null;

        this.serviceTypeOptions = [];
        this.categoryOptions = [];
        this.subCategoryOptions = [];
        this.subCodeOptions = [];
        this.rows = [];

        console.log('[CALL] loadMasterIntegration(ServiceType)', {
            sourceType: this.intCaseType,
            parentId: this.productLine
        });

        loadMasterIntegration({
            sourceType: this.intCaseType,
            parentId: this.productLine,
            channelCode: this.channel
        })
            .then(r => {
                console.log('[SUCCESS] CaseType list:', r);
                this.serviceTypeOptions = r;
            })
            .catch(err => {
                console.error('[ERROR] loadMasterIntegration(CaseType):', err);
            });
    }

    /* ================= SERVICE TYPE CHANGE ================= */

    handleServiceType(e) {
        this.serviceType = e.detail.value;
        console.log('[CHANGE] ServiceType selected:', this.serviceType);

        console.log('[RESET] Reset after ServiceType change');
        this.category = null;
        this.subCategory = null;
        this.subCode = null;

        this.categoryOptions = [];
        this.subCategoryOptions = [];
        this.subCodeOptions = [];
        this.rows = [];

        console.log('[CALL] loadMasterIntegration(Category)', {
            sourceType: this.intCategory,
            parentId: this.serviceType
        });

        loadMasterIntegration({
            sourceType: this.intCategory,
            parentId: this.serviceType,
            channelCode: this.channel
        })
            .then(r => {
                console.log('[SUCCESS] Category list:', r);
                this.categoryOptions = r;
            })
            .catch(err => {
                console.error('[ERROR] loadMasterIntegration(Category):', err);
            });
    }

    /* ================= CATEGORY CHANGE ================= */

    handleCategory(e) {
        this.category = e.detail.value;
        console.log('[CHANGE] Category selected:', this.category);

        console.log('[RESET] Reset after Category change');
        this.subCategory = null;
        this.subCode = null;

        this.subCategoryOptions = [];
        this.subCodeOptions = [];
        this.rows = [];

        console.log('[CALL] loadMasterIntegration(SubCategory)', {
            sourceType: this.intSubCategory,
            parentId: this.category
        });

        loadMasterIntegration({
            sourceType: this.intSubCategory,
            parentId: this.category,
            channelCode: this.channel
        })
            .then(r => {
                console.log('[SUCCESS] SubCategory list:', r);
                this.subCategoryOptions = r;
            })
            .catch(err => {
                console.error('[ERROR] loadMasterIntegration(SubCategory):', err);
            });
    }

    /* ================= SUB CATEGORY CHANGE ================= */

    handleSubCategory(e) {
        this.subCategory = e.detail.value;
        console.log('[CHANGE] SubCategory selected:', this.subCategory);

        console.log('[RESET] Reset after SubCategory change');
        this.subCode = null;
        this.subCodeOptions = [];
        this.rows = [];

        console.log('[CALL] loadMasterIntegration(SubCode)', {
            sourceType: this.intSubCode,
            parentId: this.subCategory
        });

        loadMasterIntegration({
            sourceType: this.intSubCode,
            parentId: this.subCategory,
            channelCode: this.channel
        })
            .then(r => {
                console.log('[SUCCESS] SubCode list:', r);
                this.subCodeOptions = r;
            })
            .catch(err => {
                console.error('[ERROR] loadMasterIntegration(SubCode):', err);
            });
        //Load Additional Properties
        loadAdditionalProperties({
            category: this.category,
            subCategory: this.subCategory,
            subCode: this.subCode,
            channelCode: this.channel,
            serviceType: this.serviceType,
            userTypeId: this.userType

        })
            .then(r => {
                console.log('[SUCCESS] Additional Properties:', r);
                this.rows = r;
            })
            .catch(err => {
                console.error('[ERROR] loadAdditionalProperties:', err);
            });
    }

    /* ================= SUB CODE CHANGE ================= */

    handleSubCode(e) {
        this.subCode = e.detail.value;
        console.log('[CHANGE] SubCode selected:', this.subCode);

        console.log('[CALL] loadAdditionalProperties', {
            category: this.category,
            subCategory: this.subCategory,
            subCode: this.subCode
        });
        console.log('userTypeId: ', this.userType);

        loadAdditionalProperties({
            category: this.category,
            subCategory: this.subCategory,
            subCode: this.subCode,
            channelCode: this.channel,
            serviceType: this.serviceType,
            userTypeId: this.userType

        })
            .then(r => {
                console.log('[SUCCESS] Additional Properties:', r);
                this.rows = r;
            })
            .catch(err => {
                console.error('[ERROR] loadAdditionalProperties:', err);
            });
    }
    handleCancel() {
        console.log('[CANCEL] Reload mapping data');
        this.dispatchEvent(new CustomEvent('cancelfraud'));
    
        // Reset UI state
        //this.isLoading = true;
    
        // If update mode → reload mapping
        if (this.mappingId) {
            this.loadForUpdate();
        } else {
            this.loadUserTypes();
        }
    }
    
    @api
    handleSave() {
        console.log('[SAVE] Start saving mapping');
    
        if (!this.validateBeforeSave()) {
            return;
        }
    
        this.loading = true;
            const payload = {
                header: {
                    userType: this.userType,
                    channel: this.channel,
                    intUserType: this.intUserType,
                    productLine: this.productLine,
                    serviceType: this.serviceType,
                    category: this.category,
                    subCategory: this.subCategory,
                    subCode: this.subCode,
                    natureOfCaseId: this.natureOfCaseId,
                    caseStageId: this.caseStageId,
                    screenCaseId: this.screenCaseId,
                    mappingId: this.mappingId
                },
                details: this.rows
            };
            
        console.log('[SAVE] Payload:', JSON.stringify(payload));
        
        saveIntegrationMapping({ payloadJson: JSON.stringify(payload) })
            .then(res => {
                console.log('[SAVE] Response:', res);
    
                if (res?.success) {
                    this.showToast(
                        this.labels.success,
                        res.message || this.labels.saveSuccess,
                        'success'
                    );
    
                    // Optional: store returned mappingId
                    this.mappingId = res.mappingId;
                    //SEND TO PARENT COMPONENT
                    this.dispatchEvent(
                        new CustomEvent('successintegration', {
                            detail: { mappingId: res.mappingId },
                            bubbles: true,
                            composed: true
                        })
                    );
    
                } else {
                    this.showToast(
                        this.labels.error,
                        res?.message || this.labels.saveFailed,
                        'error'
                    );
                }
                this.loading = false;
            })
            .catch(error => {
                console.error('[SAVE ERROR]', error);
                this.loading = false;
                const msg =
                    error?.body?.message ||
                    error?.message || this.labels.unexpectedError;
    
                this.showToast(this.labels.error, msg, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    

    hideDropdown(rowId) {
    this.rows = this.rows.map(r =>
        r.id === rowId
            ? { ...r, csmOptions: [], showDropdown: false }
            : r
        );
    }


    handleSelectCsm(event) {
        const rowId = String(event.currentTarget.dataset.rowid);
        const fieldId = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        const type = event.currentTarget.dataset.type;
    
        const display = `${name} - ${type}`;
    
        this.rows = this.rows.map(r =>
            String(r.id) === rowId
                ? {
                    ...r,
                    csmPropertyId: fieldId,
                    csmPropertyType: type,
                    csmProperty: name,
                    csmDisplay: display,
                    csmOptions: [],
                    showDropdown: false,
                    selectedFieldId: fieldId
                }
                : r
        );
    }
    



    handleCsmSearch(event) {
        const rowId = String(event.target.dataset.id);
        const keyword = event.target.value;
        //get fileType from Integrating Property Type column
        const currentRow = this.rows.find(r => String(r.id) === rowId);
        const fileType = currentRow?.type;
        // console.log('fileType:', fileType);
        // console.log('currentRow:', currentRow);
        // console.log('keyword:', keyword);
        // console.log('ROW OBJECT:', JSON.stringify(currentRow));
        // console.log('fileType:', currentRow?.type);
       

       // console.log('[AUTOCOMPLETE] input change:', { rowId, keyword, fileType });

        // Update textbox value
        this.rows = this.rows.map(r =>
            r.id === rowId
                ? { ...r, csmDisplay: keyword }
                : r
        );
        //If user clears input → clear CSM Property Type too
        if (!keyword || keyword.length === 0) {
            this.rows = this.rows.map(r =>
                String(r.id) === rowId
                    ? {
                        ...r,
                        csmDisplay: '',
                        csmProperty: '',
                        csmPropertyType: '',
                        csmPropertyId: null,
                        selectedFieldId: null,
                        csmOptions: [],
                        showDropdown: false
                    }
                    : r
            );
            return;
        }
        

        //If keyword too short → hide dropdown only
        if (keyword.length < 2) {
            console.log('[AUTOCOMPLETE] keyword too short, hide dropdown');
            this.hideDropdown(rowId);
            return;
        }

        searchAdditionalFields({ keyword,fileType })
            .then(res => {
                // console.log('[AUTOCOMPLETE] Apex called');
                // console.log('[AUTOCOMPLETE] keyword:', keyword);
                // console.log('[AUTOCOMPLETE] result size:', res?.length);
                console.log('[AUTOCOMPLETE] result data:', res);

                this.rows = this.rows.map(r => {
                    if (r.id === rowId) {
                        console.log('[AUTOCOMPLETE] updating row:', r.id);
                        return {
                            ...r,
                            csmOptions: res,
                            showDropdown: res && res.length > 0
                        };
                    }
                    return r;
                });

                console.log('[AUTOCOMPLETE] rows updated');
            })
            .catch(err => {
                console.error('[AUTOCOMPLETE][ERROR]', err);
            });
    }

    

    validateBeforeSave() {
        // Validate header fields
        console.log("BEGIN validateBeforeSave");
        if (!this.userType || !this.channel || !this.productLine ||
            !this.serviceType || !this.category ||
            !this.subCategory || (this.hasSubCodeOptions && !this.subCode)) {            
            this.showToast(
                this.labels.validationError,
                this.labels.headerRequired,
                'error'
            );           
            return false;
        }
    
        // Validate rows
        if(this.rows.length < 1) {
            console.log("BEGIN Validate rows");
            this.showToast(
                this.labels.validationError,
                this.labels.selectAtLeastOneRow,
                'error'
            );
            return false;
        }      
        return true;
    }
    

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
                mode: 'dismissable'
            })
        );
    }
    
    
    /* ================= RESET ================= */

    reset() {
        console.log('[RESET] Clear rows');
        this.rows = [];
    }
}