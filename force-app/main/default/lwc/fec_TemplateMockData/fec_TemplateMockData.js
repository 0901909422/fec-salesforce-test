/**
 * @description  Mock / dummy data for the Template Management console.
 *               Replaces real Apex data during the layout-first phase.
 *               When backend is ready, components will switch to @wire / imperative calls.
 * @module       fec_TemplateMockData
 */

/* ───────────────────────────────────────────── */
/*  FOLDERS                                      */
/* ───────────────────────────────────────────── */
export const MOCK_FOLDERS = [
    {
        id: 'folder-001',
        name: 'Marketing Emails',
        uniqueName: 'Marketing_Emails',
        parentFolderId: null,
        parentFolderName: '',
        description: 'All marketing campaign email templates',
        lastModifiedBy: 'Admin User',
        lastModifiedDate: '2026-02-10T09:00:00.000Z'
    },
    {
        id: 'folder-002',
        name: 'Transactional Emails',
        uniqueName: 'Transactional_Emails',
        parentFolderId: null,
        parentFolderName: '',
        description: 'Transactional and system email templates',
        lastModifiedBy: 'Admin User',
        lastModifiedDate: '2026-01-15T14:30:00.000Z'
    },
    {
        id: 'folder-003',
        name: 'Customer Service',
        uniqueName: 'Customer_Service',
        parentFolderId: null,
        parentFolderName: '',
        description: 'Customer service related templates',
        lastModifiedBy: 'System Admin',
        lastModifiedDate: '2026-01-20T11:00:00.000Z'
    },
    {
        id: 'folder-004',
        name: 'Promotions',
        uniqueName: 'Promotions',
        parentFolderId: 'folder-001',
        parentFolderName: 'Marketing Emails',
        description: 'Promotional email campaigns',
        lastModifiedBy: 'Marketing Team',
        lastModifiedDate: '2026-02-25T10:00:00.000Z'
    },
    {
        id: 'folder-005',
        name: 'Newsletters',
        uniqueName: 'Newsletters',
        parentFolderId: 'folder-001',
        parentFolderName: 'Marketing Emails',
        description: 'Monthly newsletter templates',
        lastModifiedBy: 'Marketing Team',
        lastModifiedDate: '2026-03-01T08:00:00.000Z'
    },
    {
        id: 'folder-006',
        name: 'OTP & Verification',
        uniqueName: 'OTP___Verification',
        parentFolderId: 'folder-002',
        parentFolderName: 'Transactional Emails',
        description: 'One-time password and verification templates',
        lastModifiedBy: 'System Admin',
        lastModifiedDate: '2026-02-18T16:00:00.000Z'
    },
    {
        id: 'folder-007',
        name: 'Archived',
        uniqueName: 'Archived',
        parentFolderId: null,
        parentFolderName: '',
        description: 'Archived / deprecated templates',
        lastModifiedBy: 'Admin User',
        lastModifiedDate: '2025-12-01T09:00:00.000Z'
    },
    {
        id: 'folder-008',
        name: 'Spring Campaigns',
        uniqueName: 'Spring_Campaigns',
        parentFolderId: 'folder-004',
        parentFolderName: 'Promotions',
        description: 'Spring 2026 promotional campaigns',
        lastModifiedBy: 'Marketing Team',
        lastModifiedDate: '2026-03-05T10:30:00.000Z'
    }
];

/* ───────────────────────────────────────────── */
/*  ENHANCED LETTERHEADS (lookup options)        */
/* ───────────────────────────────────────────── */
export const MOCK_LETTERHEADS = [
    { id: 'lh-001', name: 'Corporate Standard' },
    { id: 'lh-002', name: 'Marketing – Brand A' },
    { id: 'lh-003', name: 'FECredit Official' }
];

/* ───────────────────────────────────────────── */
/*  TEMPLATES                                    */
/* ───────────────────────────────────────────── */
export const MOCK_TEMPLATES = [
    {
        id: 'tmpl-001',
        name: 'Welcome Email',
        apiName: 'Welcome_Email',
        description: 'Sent to new customers after successful registration',
        folderId: 'folder-002',
        folderName: 'Transactional Emails',
        enhancedLetterheadId: 'lh-001',
        enhancedLetterheadName: 'Corporate Standard',
        applicableMailbox: ['dichvukhachhang@fecredit.com.vn', 'customercare@fecredit.com.vn'],
        isActive: true,
        subject: 'Welcome to Our Service!',
        emailBody: '<p>Dear {{{Contact.FirstName}}},</p><p>Welcome to our platform! We are thrilled to have you on board.</p><p>Your account has been created successfully. Here are your next steps:</p><ul><li>Complete your profile</li><li>Explore our features</li><li>Reach out to support if you need help</li></ul><p>Best regards,<br/>{{{Organization.Name}}}</p>',
        attachments: [
            { id: 'att-001', name: 'Welcome_Guide.pdf', size: 245000, type: 'application/pdf' }
        ],
        lastModifiedBy: 'Admin User',
        lastModifiedDate: '2026-02-15T10:30:00.000Z'
    },
    {
        id: 'tmpl-002',
        name: 'Password Reset',
        apiName: 'Password_Reset',
        description: 'Password reset link with 24-hour expiry',
        folderId: 'folder-006',
        folderName: 'OTP & Verification',
        enhancedLetterheadId: 'lh-001',
        enhancedLetterheadName: 'Corporate Standard',
        applicableMailbox: ['dichvukhachhang@fecredit.com.vn'],
        isActive: true,
        subject: 'Reset Your Password',
        emailBody: '<p>Hi {{{Contact.FirstName}}},</p><p>We received a request to reset your password. Click the link below to set a new password:</p><p><a href="#">Reset Password</a></p><p>This link will expire in 24 hours. If you did not request a password reset, please ignore this email.</p><p>Thanks,<br/>{{{Organization.Name}}} Support Team</p>',
        attachments: [],
        lastModifiedBy: 'Admin User',
        lastModifiedDate: '2026-03-01T08:15:00.000Z'
    },
    {
        id: 'tmpl-003',
        name: 'Monthly Newsletter – March',
        apiName: 'Monthly_Newsletter___March',
        description: 'Monthly newsletter template for March 2026 edition with product updates and tips',
        folderId: 'folder-005',
        folderName: 'Newsletters',
        enhancedLetterheadId: 'lh-002',
        enhancedLetterheadName: 'Marketing – Brand A',
        applicableMailbox: ['e_com@fecredit.com.vn', 'customercare@fecredit.com.vn'],
        isActive: true,
        subject: 'Your March Update',
        emailBody: '<h2>March 2026 Newsletter</h2><p>Hello {{{Contact.FirstName}}},</p><p>Here is what\'s new this month:</p><h3>🚀 Product Updates</h3><p>We have launched several exciting new features that will help you work more efficiently.</p><h3>📰 Industry News</h3><p>Stay up to date with the latest trends and insights from our team.</p><h3>💡 Tips &amp; Tricks</h3><p>Check out our blog for helpful tips on getting the most out of our platform.</p><p>See you next month!<br/>The {{{Organization.Name}}} Team</p>',
        attachments: [],
        lastModifiedBy: 'Marketing Team',
        lastModifiedDate: '2026-03-05T14:00:00.000Z'
    },
    {
        id: 'tmpl-004',
        name: 'Spring Sale Promo',
        apiName: 'Spring_Sale_Promo',
        description: 'Spring seasonal promotion with discount codes',
        folderId: 'folder-004',
        folderName: 'Promotions',
        enhancedLetterheadId: 'lh-002',
        enhancedLetterheadName: 'Marketing – Brand A',
        applicableMailbox: ['e_com@fecredit.com.vn', 'F2F@fecredit.com.vn'],
        isActive: true,
        subject: 'Spring Sale – Up to 50 % Off!',
        emailBody: '<h2>🌸 Spring Sale is Here!</h2><p>Dear {{{Contact.FirstName}}},</p><p>Spring has arrived and so have amazing deals! Enjoy up to <strong>50% off</strong> on selected products.</p><p>Use code: <strong>SPRING2026</strong> at checkout.</p><p>Hurry – offer valid until March 31, 2026!</p><p><a href="#">Shop Now</a></p><p>Happy shopping!<br/>{{{Organization.Name}}}</p>',
        attachments: [
            { id: 'att-002', name: 'Spring_Catalog.pdf', size: 1200000, type: 'application/pdf' },
            { id: 'att-003', name: 'Promo_Banner.png', size: 350000, type: 'image/png' }
        ],
        lastModifiedBy: 'Marketing Team',
        lastModifiedDate: '2026-02-28T11:45:00.000Z'
    },
    {
        id: 'tmpl-005',
        name: 'OTP Verification',
        apiName: 'OTP_Verification',
        description: 'One-time password for two-factor authentication',
        folderId: 'folder-006',
        folderName: 'OTP & Verification',
        enhancedLetterheadId: '',
        enhancedLetterheadName: '',
        applicableMailbox: ['dichvukhachhang@fecredit.com.vn', 'supportcsm@fecredit.com.vn'],
        isActive: true,
        subject: 'Your Verification Code',
        emailBody: '<p>Your verification code is <strong>{{{Case.OTP__c}}}</strong>. This code expires in 5 minutes. Do not share this code with anyone.</p>',
        attachments: [],
        lastModifiedBy: 'System Admin',
        lastModifiedDate: '2026-01-20T16:00:00.000Z'
    },
    {
        id: 'tmpl-006',
        name: 'Account Deactivation Notice',
        apiName: 'Account_Deactivation_Notice',
        description: 'Notification sent when a customer account is deactivated due to inactivity',
        folderId: 'folder-002',
        folderName: 'Transactional Emails',
        enhancedLetterheadId: 'lh-001',
        enhancedLetterheadName: 'Corporate Standard',
        applicableMailbox: ['cssupport@fecredit.com.vn'],
        isActive: false,
        subject: 'Your Account Has Been Deactivated',
        emailBody: '<p>Dear {{{Contact.FirstName}}},</p><p>We are writing to inform you that your account with {{{Organization.Name}}} has been deactivated due to prolonged inactivity.</p><p>If you believe this was done in error, please contact our support team to reactivate your account.</p><p>Regards,<br/>{{{Organization.Name}}} Support</p>',
        attachments: [],
        lastModifiedBy: 'Admin User',
        lastModifiedDate: '2025-12-10T09:00:00.000Z'
    },
    {
        id: 'tmpl-007',
        name: 'CS Follow-up',
        apiName: 'CS_Follow_up',
        description: 'Follow-up email after customer service interaction',
        folderId: 'folder-003',
        folderName: 'Customer Service',
        enhancedLetterheadId: 'lh-003',
        enhancedLetterheadName: 'FECredit Official',
        applicableMailbox: ['cs_d2c@fecredit.com.vn', 'CS_OM@fecredit.com.vn'],
        isActive: true,
        subject: 'Thank you for contacting us',
        emailBody: '<p>Dear {{{Contact.FirstName}}},</p><p>Thank you for contacting FECredit customer service. We value your feedback and are committed to providing the best experience.</p><p>If you have any further questions, please do not hesitate to reach out.</p><p>Warm regards,<br/>FECredit Customer Service Team</p>',
        attachments: [],
        lastModifiedBy: 'CS Team Lead',
        lastModifiedDate: '2026-03-08T13:30:00.000Z'
    },
    {
        id: 'tmpl-008',
        name: 'Holiday Greeting',
        apiName: 'Holiday_Greeting',
        description: 'Seasonal holiday greeting card email',
        folderId: 'folder-007',
        folderName: 'Archived',
        enhancedLetterheadId: 'lh-002',
        enhancedLetterheadName: 'Marketing – Brand A',
        applicableMailbox: ['customercare@fecredit.com.vn', 'e_com@fecredit.com.vn'],
        isActive: false,
        subject: 'Happy Holidays!',
        emailBody: '<h2>🎄 Happy Holidays!</h2><p>Dear {{{Contact.FirstName}}},</p><p>As the year comes to a close, we want to take a moment to thank you for being a valued customer of {{{Organization.Name}}}.</p><p>Wishing you and your family a wonderful holiday season filled with joy, peace, and prosperity.</p><p>Warm regards,<br/>The {{{Organization.Name}}} Team</p>',
        attachments: [
            { id: 'att-004', name: 'Holiday_Card.png', size: 520000, type: 'image/png' }
        ],
        lastModifiedBy: 'Admin User',
        lastModifiedDate: '2025-12-25T00:00:00.000Z'
    }
];

/* ───────────────────────────────────────────── */
/*  MOCK ATTACHMENTS (post-upload state)         */
/* ───────────────────────────────────────────── */
export const MOCK_UPLOADED_FILES = [
    { id: 'att-demo-001', name: 'Sample_Upload.pdf', size: 128000, type: 'application/pdf' },
    { id: 'att-demo-002', name: 'Logo.png',          size: 45000,  type: 'image/png' }
];

/* ───────────────────────────────────────────── */
/*  TEMPLATE HISTORY (FEC_Template__History)   */
/* ───────────────────────────────────────────── */
export const MOCK_TEMPLATE_HISTORY = [
    {
        id: 'th-001',
        templateId: 'tmpl-001',
        date: '2026-02-15T10:30:00.000Z',
        fieldName: 'Subject',
        userName: 'Admin User',
        originalValue: 'Welcome!',
        newValue: 'Welcome to Our Service!'
    },
    {
        id: 'th-002',
        templateId: 'tmpl-001',
        date: '2026-02-14T09:00:00.000Z',
        fieldName: 'Active',
        userName: 'Admin User',
        originalValue: 'false',
        newValue: 'true'
    },
    {
        id: 'th-003',
        templateId: 'tmpl-001',
        date: '2026-02-10T08:00:00.000Z',
        fieldName: 'Folder',
        userName: 'System Admin',
        originalValue: 'Marketing Emails',
        newValue: 'Transactional Emails'
    },
    {
        id: 'th-004',
        templateId: 'tmpl-004',
        date: '2026-02-28T11:45:00.000Z',
        fieldName: 'Subject',
        userName: 'Marketing Team',
        originalValue: 'Spring Sale – 30% Off!',
        newValue: 'Spring Sale – Up to 50 % Off!'
    }
];

/* ───────────────────────────────────────────── */
/*  CONTENT HISTORY (FEC_Content_History__c)     */
/* ───────────────────────────────────────────── */
export const MOCK_CONTENT_HISTORY = [
    {
        id: 'ch-001',
        templateId: 'tmpl-001',
        date: '2026-02-15T10:30:00.000Z',
        userName: 'Admin User',
        originalValue: '<p>Dear Customer, Welcome!</p>',
        newValue: '<p>Dear {{{Contact.FirstName}}},</p><p>Welcome to our platform!</p>',
        mergeFieldsUsed: '{{{Contact.FirstName}}}, {{{Organization.Name}}}'
    },
    {
        id: 'ch-002',
        templateId: 'tmpl-001',
        date: '2026-02-14T09:00:00.000Z',
        userName: 'Admin User',
        originalValue: '<p>Welcome email body draft v1</p>',
        newValue: '<p>Dear Customer, Welcome!</p>',
        mergeFieldsUsed: ''
    },
    {
        id: 'ch-003',
        templateId: 'tmpl-004',
        date: '2026-02-28T11:45:00.000Z',
        userName: 'Marketing Team',
        originalValue: '<p>Spring sale announcement draft</p>',
        newValue: '<h2>🌸 Spring Sale is Here!</h2><p>Dear {{{Contact.FirstName}}},</p>',
        mergeFieldsUsed: '{{{Contact.FirstName}}}, {{{Organization.Name}}}'
    }
];