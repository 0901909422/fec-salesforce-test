import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import loadUserTypeList from '@salesforce/apex/FEC_IntegrationMappingController.loadUserTypeList';
import loadChannelList from '@salesforce/apex/FEC_IntegrationMappingController.loadChannelList';
import loadMasterIntegration from '@salesforce/apex/FEC_IntegrationMappingController.loadMasterIntegration';
import loadAdditionalProperties from '@salesforce/apex/FEC_IntegrationMappingController.loadAdditionalProperties';
import loadMapping from '@salesforce/apex/FEC_IntegrationMappingController.loadMapping';
import searchAdditionalFields   from '@salesforce/apex/FEC_IntegrationMappingController.searchAdditionalFields';
import saveIntegrationMapping
    from '@salesforce/apex/FEC_IntegrationMappingController.saveIntegrationMapping';


export default class FraudIntegrationMapping extends LightningElement {

    userTypeOptions = [];
    intUserTypeOptions = [];
    channelOptions = [];
    productLineOptions = [];
    serviceTypeOptions = [];
    categoryOptions = [];
    subCategoryOptions = [];
    subCodeOptions = [];

    @track rows = [];
    @api natureOfCaseId;
    @track loading = true;
    get notLoading() { return !this.loading; }

    /* ================= LIFECYCLE ================= */

    connectedCallback() {
        console.log('[INIT] FraudIntegrationMapping loaded');
        console.log('[RECORD ID]', this.natureOfCaseId);        
        //this.natureOfCaseId = 'a0PBK000007ui8o2AA';
        if (this.natureOfCaseId) {
            this.loadForUpdate();
        } else {
            this.loadUserTypes();
        }
        
    }

    loadForUpdate() {
        this.loading = true;
        loadMapping({ natureOfCaseId: this.natureOfCaseId })
            .then(data => {
                //console.log('[LOAD UPDATE]', data);    
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
                this.loading = false;
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
        this.intUserTypeOptions = await loadMasterIntegration({ sourceType: 'IntUserType', parentId: this.channel, channelCode: this.channel });
        this.productLineOptions = await loadMasterIntegration({ sourceType: 'ProductLine', parentId:null , channelCode: data.channel });
        this.serviceTypeOptions = await loadMasterIntegration({ sourceType: 'CaseType', parentId: data.productLine, channelCode: this.channel });
        this.categoryOptions = await loadMasterIntegration({ sourceType: 'Category', parentId: data.serviceType, channelCode: this.channel });
        this.subCategoryOptions = await loadMasterIntegration({ sourceType: 'SubCategory', parentId: data.category, channelCode: this.channel });
        this.subCodeOptions = await loadMasterIntegration({ sourceType: 'SubCode', parentId: data.subCategory, channelCode: this.channel });  
    }


    applyMappingInfos(infos) {
        //console.log('applyMappingInfos list:', infos);
        // Load properties after hierarchy is ready    
        loadAdditionalProperties({
            category: this.category,
            subCategory: this.subCategory,
            subCode: this.subCode,
            channelCode: this.channel
        })
            .then(r => {
                //console.log('[SUCCESS] Additional Properties:', r);
                this.rows = r;
                this.rows = this.rows.map(r => {            
                const found = infos.find(i => i.property === r.property);
                console.log('found:', found);
                if (!found) return r;      
                console.log('r.:', found);              
                return {
                    ...r,
                    csmPropertyId: found.csmPropertyId,
                    csmPropertyType: found.csmPropertyType,
                    csmProperty: found.csmProperty? `${found.csmProperty}`: null,
                    autoMapping: found.autoMapping
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
            sourceType: 'IntUserType',
            parentId: this.channel
        });

        loadMasterIntegration({
            sourceType: 'IntUserType',
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
            sourceType: 'ProductLine',
            parentId: this.channel
        });

        loadMasterIntegration({
            sourceType: 'ProductLine',
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
            sourceType: 'CaseType',
            parentId: this.productLine
        });

        loadMasterIntegration({
            sourceType: 'CaseType',
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
            sourceType: 'Category',
            parentId: this.serviceType
        });

        loadMasterIntegration({
            sourceType: 'Category',
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
            sourceType: 'SubCategory',
            parentId: this.category
        });

        loadMasterIntegration({
            sourceType: 'SubCategory',
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
            sourceType: 'SubCode',
            parentId: this.subCategory
        });

        loadMasterIntegration({
            sourceType: 'SubCode',
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
            channelCode: this.channel
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

        loadAdditionalProperties({
            category: this.category,
            subCategory: this.subCategory,
            subCode: this.subCode,
            channelCode: this.channel
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
    
        // Reset UI state
        this.isLoading = true;
    
        // If update mode → reload mapping
        if (this.natureOfCaseId) {
            this.loadForUpdate();
        } else {
            this.loadUserTypes();
        }
    }
    
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
                    natureOfCaseId: this.natureOfCaseId
                },
                details: this.rows
            };
            
        //console.log('[SAVE] Payload:', JSON.stringify(payload));
        
        saveIntegrationMapping({ payloadJson: JSON.stringify(payload) })
            .then(res => {
                //console.log('[SAVE] Response:', res);
    
                if (res?.success) {
                    //SUCCESS TOAST
                    this.showToast(
                        'Success',
                        res.message || 'Mapping saved successfully',
                        'success'
                    );
    
                    // Optional: store returned mappingId
                    this.mappingId = res.mappingId;
    
                } else {
                    //FAILURE FROM SERVER
                    this.showToast(
                        'Error',
                        res?.message || 'Save failed',
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
                    error?.message ||
                    'Unexpected error occurred';
    
                this.showToast('Error', msg, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    handleAutoMappingChange(event) {
        const rowId = event.target.dataset.id;    
        //checkbox value comes from event.target.checked
        const checked = event.target.checked;    
        console.log('[AUTO MAPPING CHANGE]', { rowId, checked });
    
        this.rows = this.rows.map(r =>
            r.id === rowId
                ? { ...r, autoMapping: checked }
                : r
        );
    }
    

    hideDropdown(rowId) {
    this.rows = this.rows.map(r =>
        r.id === rowId
            ? { ...r, csmOptions: [], showDropdown: false }
            : r
        );
    }


    handleSelectCsm(event) {
    const { rowid, id, name, type } = event.currentTarget.dataset;

    const display = `${name} - ${type}`;

    // console.log('[SELECT CSM]', { id, name, type });
    // console.log('target:', event.target);
    // console.log('currentTarget:', event.currentTarget);
    // console.log('dataset:', event.currentTarget.dataset);
    // console.log('display:', display);


    this.rows = this.rows.map(r =>
        r.id === rowid
            ? {
                ...r,
                csmPropertyId: id,
                csmPropertyType: type,
                csmProperty: name,
                csmOptions: [],
                showDropdown: false
            }
            : r
    );
}

    


    handleCsmSearch(event) {
        const rowId = event.target.dataset.id;
        const keyword = event.target.value;

        console.log('[AUTOCOMPLETE] input change:', { rowId, keyword });

        // Update textbox value
        this.rows = this.rows.map(r =>
            r.id === rowId
                ? { ...r, csmDisplay: keyword }
                : r
        );

        if (!keyword || keyword.length < 2) {
            console.log('[AUTOCOMPLETE] keyword too short, hide dropdown');
            this.hideDropdown(rowId);
            return;
        }

        searchAdditionalFields({ keyword })
            .then(res => {
                // console.log('[AUTOCOMPLETE] Apex called');
                // console.log('[AUTOCOMPLETE] keyword:', keyword);
                // console.log('[AUTOCOMPLETE] result size:', res?.length);
                // console.log('[AUTOCOMPLETE] result data:', res);

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
            !this.subCategory) {            
            this.showToast(
                'Validation Error',
                'Please select all required header fields.',
                'error'
            );           
            return false;
        }
    
        // Validate rows
        if(this.rows.length < 1) {
            console.log("BEGIN Validate rows");
            this.showToast(
                'Validation Error',
                `Please select at least one property for mapping.`,
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