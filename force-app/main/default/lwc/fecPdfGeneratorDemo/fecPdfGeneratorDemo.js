import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

const SAMPLE_LSTT = {
    CurrentDay: 12,
    CurrentMonth: 5,
    CurrentYear: 2026,
    ContractNumber: "HD-2024-001234",
    NationalID: "079088012345",
    FullName: "Nguyễn Văn A",
    logoUrl: "/resource/Logo",
    _rows: [
        { RemovalNote: "1", BankAddress: "15/03/2025", PaymentAmount: 5000000 },
        { RemovalNote: "2", BankAddress: "10/04/2025", PaymentAmount: 7500000 }
    ]
};

/** Mau du lieu khop template ThongBaoChoVayLichTraNo (TBCV_LTN) — key la hau to sau dau cham cuoi trong pega:reference */
const SAMPLE_TBCV_LTN = {
    ContractNumber: "HD-2026-TBCV-0001",
    CustomerName: "Nguyễn Văn A",
    CustomerAddress: "123 Nguyễn Huệ, Q.1, TP.HCM",
    NationalID: "079088012345",
    DateOfIssue: "01/01/2015",
    PlaceOfIssue: "CA TP.HCM",
    TotalLoanAmount: "150.000.000",
    LoanAmountInVNText: "Một trăm năm mươi triệu đồng",
    MonthlyRate: "1,2",
    YearlyRate: "15,6",
    MaturityDate2: "15/05/2028",
    _rows: [
        {
            InstallmentDueDate: "15/06/2026",
            Principal: 5000000,
            Interest: 1800000,
            ClosingPrincipal: 145000000,
            RepaymentFees: 12000,
            InstallmentAmount: 6812000
        },
        {
            InstallmentDueDate: "15/07/2026",
            Principal: 5100000,
            Interest: 1700000,
            ClosingPrincipal: 139900000,
            RepaymentFees: 12000,
            InstallmentAmount: 6812000
        }
    ]
};

/** Mau du lieu cho XacNhanThanhLyHDTD (XNTL_HDTD) va XacNhanChamDutThe (XNCD_THE) — cung bo pega:reference .Field */
const SAMPLE_XN_HDTD_THE = {
    DocumentNumber: "0123",
    DocumentIssueBy: "XL",
    YearOfTheDocument: "2026",
    CurrentDay: "12",
    CurrentMonth: "05",
    CurrentYear: "2026",
    CustomerName: "Nguyễn Văn A",
    NationalID: "079088012345",
    CorrAgreementDate: "2024-01-15",
    ContractNumber: "HD-TD-2024-00987",
    LoanAmount: "50.000.000",
    Tenure: "36",
    AccountStatusChangeDate: "2026-05-10",
    CorrSignature1: "FE CREDIT",
    pyTitle: "GIÁM ĐỐC KHỐI",
    pyName: "Nguyễn Thị B"
};

export default class FecPdfGeneratorDemo extends LightningElement {
    @track isGenerating = false;

    handleGenerateLstt() {
        return this.generateWithTemplate("LSTT", SAMPLE_LSTT);
    }

    handleGenerateTbcvLtn() {
        return this.generateWithTemplate("TBCV_LTN", SAMPLE_TBCV_LTN);
    }

    handleGenerateXntlHtd() {
        return this.generateWithTemplate("XNTL_HDTD", SAMPLE_XN_HDTD_THE);
    }

    handleGenerateXncdThe() {
        return this.generateWithTemplate("XNCD_THE", SAMPLE_XN_HDTD_THE);
    }

    async generateWithTemplate(templateCode, sampleData) {
        this.isGenerating = true;
        try {
            const generator = this.template.querySelector("c-fec-pdf-generator");
            if (!generator) {
                throw new Error("Khong tim thay c-fec-pdf-generator");
            }

            const { base64, fileName } = await generator.generatePdf(templateCode, sampleData);
            this.downloadPdf(base64, fileName || templateCode);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Thanh cong",
                    message: `Da tao PDF tu template ${templateCode}`,
                    variant: "success"
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Loi tao PDF",
                    message: error?.body?.message || error?.message || "Unknown error",
                    variant: "error"
                })
            );
        } finally {
            this.isGenerating = false;
        }
    }

    downloadPdf(base64, fileName) {
        const byteCharacters = atob(base64);
        const byteNumbers = new Array(byteCharacters.length);
        for (let i = 0; i < byteCharacters.length; i += 1) {
            byteNumbers[i] = byteCharacters.charCodeAt(i);
        }
        const byteArray = new Uint8Array(byteNumbers);
        const blob = new Blob([byteArray], { type: "application/pdf" });
        const url = URL.createObjectURL(blob);

        const link = document.createElement("a");
        link.href = url;
        link.download = `${fileName}.pdf`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
    }
}
