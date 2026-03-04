public class FEC_IntegrationSoapFraudcaseService {
    public class CustomerInfo_element {
        public String UserType;
        private String[] UserType_type_info = new String[]{'UserType','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'UserType'};
    }
    public class ChildrenType {
        public String ID;
        public String Name;
        public String NameVN;
        public Integer PosOrder;
        public String ApplyTo;
        public String Type_x;
        public FEC_IntegrationSoapFraudcaseService.AdditionalPropertiesType[] AdditionalProperties;
        public FEC_IntegrationSoapFraudcaseService.ChildrenType[] Children;
        private String[] ID_type_info = new String[]{'ID','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Name_type_info = new String[]{'Name','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] NameVN_type_info = new String[]{'NameVN','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] PosOrder_type_info = new String[]{'PosOrder','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] ApplyTo_type_info = new String[]{'ApplyTo','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Type_x_type_info = new String[]{'Type','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] AdditionalProperties_type_info = new String[]{'AdditionalProperties','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','-1','false'};
        private String[] Children_type_info = new String[]{'Children','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','-1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'ID','Name','NameVN','PosOrder','ApplyTo','Type_x','AdditionalProperties','Children'};
    }
    public class GetFraudMasterDataResponseType {
        public FEC_IntegrationSoapFraudcaseService.SysType2 Sys;
        public FEC_IntegrationSoapFraudcaseService.MasterDataItemsType[] MasterDataItems;
        private String[] Sys_type_info = new String[]{'Sys','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] MasterDataItems_type_info = new String[]{'MasterDataItems','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','-1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'Sys','MasterDataItems'};
    }
    public class AvailableValuesType {
        public String ID;
        public String Name;
        public String NameVN;
        private String[] ID_type_info = new String[]{'ID','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Name_type_info = new String[]{'Name','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] NameVN_type_info = new String[]{'NameVN','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'ID','Name','NameVN'};
    }
    public class CreateFraudCaseRequestType {
        public FEC_IntegrationSoapFraudcaseService.SysType Sys;
        public FEC_IntegrationSoapFraudcaseService.CustomerInfo_element CustomerInfo;
        public FEC_IntegrationSoapFraudcaseService.RequestInfo_element RequestInfo;
        public FEC_IntegrationSoapFraudcaseService.CreatorInfoType CreatorInfo;
        private String[] Sys_type_info = new String[]{'Sys','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] CustomerInfo_type_info = new String[]{'CustomerInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] RequestInfo_type_info = new String[]{'RequestInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] CreatorInfo_type_info = new String[]{'CreatorInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'Sys','CustomerInfo','RequestInfo','CreatorInfo'};
    }
    public class GetFraudAttachedFileResponseType {
        public FEC_IntegrationSoapFraudcaseService.SysType2 Sys;
        public String FileName;
        public String FileContent;
        public String FileType;
        private String[] Sys_type_info = new String[]{'Sys','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] FileName_type_info = new String[]{'FileName','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] FileContent_type_info = new String[]{'FileContent','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] FileType_type_info = new String[]{'FileType','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'Sys','FileName','FileContent','FileType'};
    }
    public class TasksType {
        public String Name;
        public String UIC;
        public DateTime Deadline;
        private String[] Name_type_info = new String[]{'Name','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] UIC_type_info = new String[]{'UIC','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Deadline_type_info = new String[]{'Deadline','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'Name','UIC','Deadline'};
    }
    public class RequestInfoType2 {
        public String CaseID;
        public String FileID;
        private String[] CaseID_type_info = new String[]{'CaseID','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] FileID_type_info = new String[]{'FileID','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'CaseID','FileID'};
    }
    public class CreatorInfoType2 {
        public String CreatorEmail;
        private String[] CreatorEmail_type_info = new String[]{'CreatorEmail','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'CreatorEmail'};
    }
    public class SysType {
        public String Channel;
        public String TransactionID;
        public DateTime DateTime_x;
        private String[] Channel_type_info = new String[]{'Channel','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] TransactionID_type_info = new String[]{'TransactionID','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] DateTime_x_type_info = new String[]{'DateTime','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'Channel','TransactionID','DateTime_x'};
    }
    public class MasterDataItemsType {
        public String ID;
        public String Name;
        public String NameVN;
        public Integer PosOrder;
        public String ApplyTo;
        public String Type_x;
        public FEC_IntegrationSoapFraudcaseService.AdditionalPropertiesType[] AdditionalProperties;
        public FEC_IntegrationSoapFraudcaseService.ChildrenType[] Children;
        private String[] ID_type_info = new String[]{'ID','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Name_type_info = new String[]{'Name','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] NameVN_type_info = new String[]{'NameVN','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] PosOrder_type_info = new String[]{'PosOrder','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] ApplyTo_type_info = new String[]{'ApplyTo','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Type_x_type_info = new String[]{'Type','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] AdditionalProperties_type_info = new String[]{'AdditionalProperties','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','-1','false'};
        private String[] Children_type_info = new String[]{'Children','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','-1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'ID','Name','NameVN','PosOrder','ApplyTo','Type_x','AdditionalProperties','Children'};
    }
    public class RequestInfo_element {
        public String CaseID;
        public String CaseType;
        public String ProductType;
        public String Category;
        public String SubCategory;
        public String SubCode;
        public String Remarks;
        public FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element[] AdditionalInfo;
        private String[] CaseID_type_info = new String[]{'CaseID','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] CaseType_type_info = new String[]{'CaseType','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] ProductType_type_info = new String[]{'ProductType','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Category_type_info = new String[]{'Category','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] SubCategory_type_info = new String[]{'SubCategory','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] SubCode_type_info = new String[]{'SubCode','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] Remarks_type_info = new String[]{'Remarks','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] AdditionalInfo_type_info = new String[]{'AdditionalInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','-1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'CaseID','CaseType','ProductType','Category','SubCategory','SubCode','Remarks','AdditionalInfo'};
    }
    public class InvestigationResultsType {
        public String AppID;
        public String Conclusion;
        public FEC_IntegrationSoapFraudcaseService.TasksType[] Tasks;
        private String[] AppID_type_info = new String[]{'AppID','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Conclusion_type_info = new String[]{'Conclusion','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Tasks_type_info = new String[]{'Tasks','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','-1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'AppID','Conclusion','Tasks'};
    }
    public class GetFraudMasterDataRequestType {
        public FEC_IntegrationSoapFraudcaseService.SysType Sys;
        private String[] Sys_type_info = new String[]{'Sys','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'Sys'};
    }
    public class AdditionalInfoType {
        public String ID;
        public String Value;
        private String[] ID_type_info = new String[]{'ID','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Value_type_info = new String[]{'Value','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'ID','Value'};
    }
    public class CaseInfoType {
        public String CaseID;
        public String Remarks;
        private String[] CaseID_type_info = new String[]{'CaseID','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Remarks_type_info = new String[]{'Remarks','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'CaseID','Remarks'};
    }
    public class CreateFraudCaseResponseType {
        public FEC_IntegrationSoapFraudcaseService.SysType2 Sys;
        public String CaseID;
        private String[] Sys_type_info = new String[]{'Sys','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] CaseID_type_info = new String[]{'CaseID','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'Sys','CaseID'};
    }
    public class SysType2 {
        public String TransactionID;
        public DateTime DateTime_x;
        public String Code;
        public String Description;
        private String[] TransactionID_type_info = new String[]{'TransactionID','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] DateTime_x_type_info = new String[]{'DateTime','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Code_type_info = new String[]{'Code','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Description_type_info = new String[]{'Description','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'TransactionID','DateTime_x','Code','Description'};
    }
    public class CustomerInfoType {
        public String UserType;
        private String[] UserType_type_info = new String[]{'UserType','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'UserType'};
    }
    public class SysType3 {
        public String Channel;
        public String TransactionID;
        public DateTime DateTime_x;
        private String[] Channel_type_info = new String[]{'Channel','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] TransactionID_type_info = new String[]{'TransactionID','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] DateTime_x_type_info = new String[]{'DateTime','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'Channel','TransactionID','DateTime_x'};
    }
    public class CaseDetailedInfoType {
        public String ID;
        public String Value;
        private String[] ID_type_info = new String[]{'ID','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Value_type_info = new String[]{'Value','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'ID','Value'};
    }
    public class ProcessCaseResponseType {
        public FEC_IntegrationSoapFraudcaseService.SysType2 Sys;
        private String[] Sys_type_info = new String[]{'Sys','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'Sys'};
    }
    public class RequestInfoType {
        public String CaseType;
        public String ProductType;
        public String Category;
        public String SubCategory;
        public String SubCode;
        public String Remarks;
        public FEC_IntegrationSoapFraudcaseService.AdditionalInfoType[] AdditionalInfo;
        private String[] CaseType_type_info = new String[]{'CaseType','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] ProductType_type_info = new String[]{'ProductType','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Category_type_info = new String[]{'Category','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] SubCategory_type_info = new String[]{'SubCategory','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] SubCode_type_info = new String[]{'SubCode','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] Remarks_type_info = new String[]{'Remarks','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] AdditionalInfo_type_info = new String[]{'AdditionalInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','-1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'CaseType','ProductType','Category','SubCategory','SubCode','Remarks','AdditionalInfo'};
    }
    public class AdditionalInfo_element {
        public String ID;
        public String Value;
        private String[] ID_type_info = new String[]{'ID','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Value_type_info = new String[]{'Value','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'ID','Value'};
    }
    public class CaseInfoType3 {
        public String CaseID;
        public String CaseStatus;
        public String ReferenceID;
        public String ParentID;
        public DateTime CreatedTime;
        public DateTime UpdatedTime;
        public String Remarks;
        public FEC_IntegrationSoapFraudcaseService.OriginalRequestType OriginalRequest;
        public FEC_IntegrationSoapFraudcaseService.InvestigationResultsType[] InvestigationResults;
        public FEC_IntegrationSoapFraudcaseService.CaseDetailedInfoType[] CaseDetailedInfo;
        private String[] CaseID_type_info = new String[]{'CaseID','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] CaseStatus_type_info = new String[]{'CaseStatus','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] ReferenceID_type_info = new String[]{'ReferenceID','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] ParentID_type_info = new String[]{'ParentID','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] CreatedTime_type_info = new String[]{'CreatedTime','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] UpdatedTime_type_info = new String[]{'UpdatedTime','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Remarks_type_info = new String[]{'Remarks','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] OriginalRequest_type_info = new String[]{'OriginalRequest','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] InvestigationResults_type_info = new String[]{'InvestigationResults','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','-1','false'};
        private String[] CaseDetailedInfo_type_info = new String[]{'CaseDetailedInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','-1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'CaseID','CaseStatus','ReferenceID','ParentID','CreatedTime','UpdatedTime','Remarks','OriginalRequest','InvestigationResults','CaseDetailedInfo'};
    }
    public class GetFraudCaseStatusRequestType {
        public FEC_IntegrationSoapFraudcaseService.SysType Sys;
        public FEC_IntegrationSoapFraudcaseService.CaseInfoType2 CaseInfo;
        public FEC_IntegrationSoapFraudcaseService.CreatorInfoType CreatorInfo;
        private String[] Sys_type_info = new String[]{'Sys','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] CaseInfo_type_info = new String[]{'CaseInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] CreatorInfo_type_info = new String[]{'CreatorInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'Sys','CaseInfo','CreatorInfo'};
    }
    public class CaseInfoType2 {
        public String CaseID;
        public Boolean IncludeFinishedRequest;
        private String[] CaseID_type_info = new String[]{'CaseID','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] IncludeFinishedRequest_type_info = new String[]{'IncludeFinishedRequest','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'CaseID','IncludeFinishedRequest'};
    }
    public class CancelFraudCaseResponseType {
        public FEC_IntegrationSoapFraudcaseService.SysType2 Sys;
        public String CaseID;
        public FEC_IntegrationSoapFraudcaseService.OriginalRequestType OriginalRequest;
        private String[] Sys_type_info = new String[]{'Sys','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] CaseID_type_info = new String[]{'CaseID','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] OriginalRequest_type_info = new String[]{'OriginalRequest','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'Sys','CaseID','OriginalRequest'};
    }
    public class CreatorInfoType {
        public String CreatorEmail;
        private String[] CreatorEmail_type_info = new String[]{'CreatorEmail','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'CreatorEmail'};
    }
    public class CaseInfoType4 {
        public String CaseID;
        public String Decision;
        public String SubDecision;
        public String Reason;
        public String Remarks;
        private String[] CaseID_type_info = new String[]{'CaseID','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Decision_type_info = new String[]{'Decision','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] SubDecision_type_info = new String[]{'SubDecision','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] Reason_type_info = new String[]{'Reason','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] Remarks_type_info = new String[]{'Remarks','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'CaseID','Decision','SubDecision','Reason','Remarks'};
    }
    public class ProcessCaseRequestType {
        public FEC_IntegrationSoapFraudcaseService.SysType Sys;
        public FEC_IntegrationSoapFraudcaseService.CaseInfoType4 CaseInfo;
        public FEC_IntegrationSoapFraudcaseService.CreatorInfoType CreatorInfo;
        private String[] Sys_type_info = new String[]{'Sys','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] CaseInfo_type_info = new String[]{'CaseInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] CreatorInfo_type_info = new String[]{'CreatorInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'Sys','CaseInfo','CreatorInfo'};
    }
    public class GetFraudCaseStatusResponseType {
        public FEC_IntegrationSoapFraudcaseService.SysType2 Sys;
        public FEC_IntegrationSoapFraudcaseService.CaseInfoType3[] CaseInfo;
        private String[] Sys_type_info = new String[]{'Sys','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] CaseInfo_type_info = new String[]{'CaseInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','-1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'Sys','CaseInfo'};
    }
    public class AdditionalPropertiesType {
        public String ID;
        public String Name;
        public String NameVN;
        public Integer PosOrder;
        public String ApplyTo;
        public Boolean Mandatory;
        public FEC_IntegrationSoapFraudcaseService.AvailableValuesType[] AvailableValues;
        public String Type_x;
        private String[] ID_type_info = new String[]{'ID','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Name_type_info = new String[]{'Name','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] NameVN_type_info = new String[]{'NameVN','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] PosOrder_type_info = new String[]{'PosOrder','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] ApplyTo_type_info = new String[]{'ApplyTo','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] Mandatory_type_info = new String[]{'Mandatory','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] AvailableValues_type_info = new String[]{'AvailableValues','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','-1','false'};
        private String[] Type_x_type_info = new String[]{'Type','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'ID','Name','NameVN','PosOrder','ApplyTo','Mandatory','AvailableValues','Type_x'};
    }
    public class GetFraudAttachedFileRequestType {
        public FEC_IntegrationSoapFraudcaseService.SysType Sys;
        public FEC_IntegrationSoapFraudcaseService.RequestInfoType2 RequestInfo;
        public FEC_IntegrationSoapFraudcaseService.CreatorInfoType CreatorInfo;
        private String[] Sys_type_info = new String[]{'Sys','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] RequestInfo_type_info = new String[]{'RequestInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] CreatorInfo_type_info = new String[]{'CreatorInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'Sys','RequestInfo','CreatorInfo'};
    }
    public class OriginalRequestType {
        public FEC_IntegrationSoapFraudcaseService.SysType3 Sys;
        public FEC_IntegrationSoapFraudcaseService.CustomerInfoType CustomerInfo;
        public FEC_IntegrationSoapFraudcaseService.RequestInfoType RequestInfo;
        public FEC_IntegrationSoapFraudcaseService.CreatorInfoType2 CreatorInfo;
        private String[] Sys_type_info = new String[]{'Sys','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] CustomerInfo_type_info = new String[]{'CustomerInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] RequestInfo_type_info = new String[]{'RequestInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] CreatorInfo_type_info = new String[]{'CreatorInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'0','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'Sys','CustomerInfo','RequestInfo','CreatorInfo'};
    }
    public class CancelFraudCaseRequestType {
        public FEC_IntegrationSoapFraudcaseService.SysType Sys;
        public FEC_IntegrationSoapFraudcaseService.CaseInfoType CaseInfo;
        public FEC_IntegrationSoapFraudcaseService.CreatorInfoType CreatorInfo;
        private String[] Sys_type_info = new String[]{'Sys','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] CaseInfo_type_info = new String[]{'CaseInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] CreatorInfo_type_info = new String[]{'CreatorInfo','urn:PegaRULES:SOAP:FraudCase:Services',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Services','false','false'};
        private String[] field_order_type_info = new String[]{'Sys','CaseInfo','CreatorInfo'};
    }
    public class ServicePortSOAP {
        public String endpoint_x = FEC_FraudConstantCommon.FRAUD_SERVICE_SOAP_ENDPOINT;
        public Map<String,String> inputHttpHeaders_x;
        public Map<String,String> outputHttpHeaders_x;
        public String clientCertName_x;
        public String clientCert_x;
        public String clientCertPasswd_x;
        public Integer timeout_x;
        private String[] ns_map_type_info = new String[]{'urn:PegaRULES:SOAP:FraudCase:Service', 'PegaSoapFraudcaseService', 'urn:PegaRULES:SOAP:FraudCase:Services', 'PegaSoapFraudcaseService'};
        public FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType CreateFraudCase(FEC_IntegrationSoapFraudcaseService.SysType Sys,FEC_IntegrationSoapFraudcaseService.CustomerInfo_element CustomerInfo,FEC_IntegrationSoapFraudcaseService.RequestInfo_element RequestInfo,FEC_IntegrationSoapFraudcaseService.CreatorInfoType CreatorInfo) {
            FEC_IntegrationSoapFraudcaseService.CreateFraudCaseRequestType request_x = new FEC_IntegrationSoapFraudcaseService.CreateFraudCaseRequestType();
            request_x.Sys = Sys;
            request_x.CustomerInfo = CustomerInfo;
            request_x.RequestInfo = RequestInfo;
            request_x.CreatorInfo = CreatorInfo;
            FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType response_x;
            Map<String, FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType> response_map_x = new Map<String, FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
              this,
              request_x,
              response_map_x,
              new String[]{endpoint_x,
              'urn:PegaRULES:SOAP:FraudCase:Service#CreateFraudCase',
              'urn:PegaRULES:SOAP:FraudCase:Services',
              'CreateFraudCaseRequest',
              'urn:PegaRULES:SOAP:FraudCase:Services',
              'CreateFraudCaseResponse',
              'FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType'}
            );
            response_x = response_map_x.get('response_x');
            return response_x;
        }
        public FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType MoveCaseToNextStage(FEC_IntegrationSoapFraudcaseService.SysType Sys,FEC_IntegrationSoapFraudcaseService.CaseInfoType CaseInfo,FEC_IntegrationSoapFraudcaseService.CreatorInfoType CreatorInfo) {
            FEC_IntegrationSoapFraudcaseService.CancelFraudCaseRequestType request_x = new FEC_IntegrationSoapFraudcaseService.CancelFraudCaseRequestType();
            request_x.Sys = Sys;
            request_x.CaseInfo = CaseInfo;
            request_x.CreatorInfo = CreatorInfo;
            FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType response_x;
            Map<String, FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType> response_map_x = new Map<String, FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
              this,
              request_x,
              response_map_x,
              new String[]{endpoint_x,
              'urn:PegaRULES:SOAP:FraudCase:Service#MoveCaseToNextStage',
              'urn:PegaRULES:SOAP:FraudCase:Services',
              'CancelFraudCaseRequest',
              'urn:PegaRULES:SOAP:FraudCase:Services',
              'CancelFraudCaseResponse',
              'FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType'}
            );
            response_x = response_map_x.get('response_x');
            return response_x;
        }
        public FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType CancelFraudCase(FEC_IntegrationSoapFraudcaseService.SysType Sys,FEC_IntegrationSoapFraudcaseService.CaseInfoType CaseInfo,FEC_IntegrationSoapFraudcaseService.CreatorInfoType CreatorInfo) {
            FEC_IntegrationSoapFraudcaseService.CancelFraudCaseRequestType request_x = new FEC_IntegrationSoapFraudcaseService.CancelFraudCaseRequestType();
            request_x.Sys = Sys;
            request_x.CaseInfo = CaseInfo;
            request_x.CreatorInfo = CreatorInfo;
            FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType response_x;
            Map<String, FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType> response_map_x = new Map<String, FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
              this,
              request_x,
              response_map_x,
              new String[]{endpoint_x,
              'urn:PegaRULES:SOAP:FraudCase:Service#CancelFraudCase',
              'urn:PegaRULES:SOAP:FraudCase:Services',
              'CancelFraudCaseRequest',
              'urn:PegaRULES:SOAP:FraudCase:Services',
              'CancelFraudCaseResponse',
              'FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType'}
            );
            response_x = response_map_x.get('response_x');
            return response_x;
        }
        public FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType GetFraudCaseStatus(FEC_IntegrationSoapFraudcaseService.SysType Sys,FEC_IntegrationSoapFraudcaseService.CaseInfoType2 CaseInfo,FEC_IntegrationSoapFraudcaseService.CreatorInfoType CreatorInfo) {
            FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusRequestType request_x = new FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusRequestType();
            request_x.Sys = Sys;
            request_x.CaseInfo = CaseInfo;
            request_x.CreatorInfo = CreatorInfo;
            FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType response_x;
            Map<String, FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType> response_map_x = new Map<String, FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
              this,
              request_x,
              response_map_x,
              new String[]{endpoint_x,
              'urn:PegaRULES:SOAP:FraudCase:Service#GetFraudCaseStatus',
              'urn:PegaRULES:SOAP:FraudCase:Services',
              'GetFraudCaseStatusRequest',
              'urn:PegaRULES:SOAP:FraudCase:Services',
              'GetFraudCaseStatusResponse',
              'FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType'}
            );
            response_x = response_map_x.get('response_x');
            return response_x;
        }
        public FEC_IntegrationSoapFraudcaseService.SysType2 ProcessCase(FEC_IntegrationSoapFraudcaseService.SysType Sys,FEC_IntegrationSoapFraudcaseService.CaseInfoType4 CaseInfo,FEC_IntegrationSoapFraudcaseService.CreatorInfoType CreatorInfo) {
            FEC_IntegrationSoapFraudcaseService.ProcessCaseRequestType request_x = new FEC_IntegrationSoapFraudcaseService.ProcessCaseRequestType();
            request_x.Sys = Sys;
            request_x.CaseInfo = CaseInfo;
            request_x.CreatorInfo = CreatorInfo;
            FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType response_x;
            Map<String, FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType> response_map_x = new Map<String, FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
              this,
              request_x,
              response_map_x,
              new String[]{endpoint_x,
              'urn:PegaRULES:SOAP:FraudCase:Service#ProcessCase',
              'urn:PegaRULES:SOAP:FraudCase:Services',
              'ProcessCaseRequest',
              'urn:PegaRULES:SOAP:FraudCase:Services',
              'ProcessCaseResponse',
              'FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType'}
            );
            response_x = response_map_x.get('response_x');
            return response_x.Sys;
        }
        public FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType GetFraudAttachedFile(FEC_IntegrationSoapFraudcaseService.SysType Sys,FEC_IntegrationSoapFraudcaseService.RequestInfoType2 RequestInfo,FEC_IntegrationSoapFraudcaseService.CreatorInfoType CreatorInfo) {
            FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileRequestType request_x = new FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileRequestType();
            request_x.Sys = Sys;
            request_x.RequestInfo = RequestInfo;
            request_x.CreatorInfo = CreatorInfo;
            FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType response_x;
            Map<String, FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType> response_map_x = new Map<String, FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
              this,
              request_x,
              response_map_x,
              new String[]{endpoint_x,
              'urn:PegaRULES:SOAP:FraudCase:Service#GetFraudAttachedFile',
              'urn:PegaRULES:SOAP:FraudCase:Services',
              'GetFraudAttachedFileRequest',
              'urn:PegaRULES:SOAP:FraudCase:Services',
              'GetFraudAttachedFileResponse',
              'FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType'}
            );
            response_x = response_map_x.get('response_x');
            return response_x;
        }
        public FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType GetFraudMasterData(FEC_IntegrationSoapFraudcaseService.SysType Sys) {
            FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataRequestType request_x = new FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataRequestType();
            request_x.Sys = Sys;
            FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType response_x;
            Map<String, FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType> response_map_x = new Map<String, FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
              this,
              request_x,
              response_map_x,
              new String[]{endpoint_x,
              'urn:PegaRULES:SOAP:FraudCase:Service#GetFraudMasterData',
              'urn:PegaRULES:SOAP:FraudCase:Services',
              'GetFraudMasterDataRequest',
              'urn:PegaRULES:SOAP:FraudCase:Services',
              'GetFraudMasterDataResponse',
              'FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType'}
            );
            response_x = response_map_x.get('response_x');
            return response_x;
        }
    }
}