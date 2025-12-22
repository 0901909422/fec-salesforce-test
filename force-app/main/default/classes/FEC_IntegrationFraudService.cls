global with sharing class FEC_IntegrationFraudService {

    public static String getFraudMasterDataResponse() {
        return xmlPart1() +
        xmlPart2() +
        xmlPart3() +
        xmlPart4() +
        xmlPart5() +
        xmlPart6() +
        xmlPart7();
    }

    private static String xmlPart1() {
        return '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">\n   <s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">\n      <GetFraudMasterDataResponse xmlns="urn:PegaRULES:SOAP:FraudCase:Services">\n         <MasterDataItems>\n            <ID>Loan</ID>\n            <Name>Application</Name>\n            <NameVN>Application</NameVN>\n            <PosOrder>1</PosOrder>\n            <ApplyTo>ALL</ApplyTo>\n            <Type>Product</Type>\n            <AdditionalProperties>\n               <ID>ReferenceID</ID>\n               <Name>ReferenceID</Name>\n               <NameVN>ReferenceID</NameVN>\n               <PosOrder>100</PosOrder>\n               <ApplyTo>ALL</ApplyTo>\n               <Mandatory>false</Mandatory>\n               <Type>string</Type>\n            </AdditionalProperties>\n            <Children>\n               <ID>FECredit_OP_Work_FraudHandling</ID>\n               <Name>FraudHandling</Name>\n               <NameVN>FraudHandling</NameVN>\n               <PosOrder>100</PosOrder>\n               <ApplyTo>ALL</ApplyTo>\n               <Type>CaseType</Type>\n               <AdditionalProperties>\n                  <ID>Province</ID>\n                  <Name>Province</Name>\n                  <NameVN>Province</NameVN>\n                  <PosOrder>1</PosOrder>\n                  <ApplyTo>ALL</ApplyTo>\n                  <Mandatory>true</Mandatory>\n                  <Type>list</Type>\n                  <AvailableValues>\n                     <ID>1</ID>\n                     <Name>Tỉnh Đắk Nông</Name>\n                     <NameVN>Tỉnh Đắk Nông</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>100</ID>\n                     <Name>Tỉnh Kiên Giang</Name>\n                     <NameVN>Tỉnh Kiên Giang</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>101</ID>\n                     <Name>Tỉnh Kon Tum</Name>\n                     <NameVN>Tỉnh Kon Tum</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>102</ID>\n                     <Name>Tỉnh Lai Châu</Name>\n                     <NameVN>Tỉnh Lai Châu</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>103</ID>\n                     <Name>Tỉnh Long An</Name>\n                     <NameVN>Tỉnh Long An</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>104</ID>\n                     <Name>Tỉnh Lào Cai</Name>\n                     <NameVN>Tỉnh Lào Cai</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>105</ID>\n                     <Name>Tỉnh Lâm Đồng</Name>\n                     <NameVN>Tỉnh Lâm Đồng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>106</ID>\n                     <Name>Tỉnh Lạng Sơn</Name>\n                     <NameVN>Tỉnh Lạng Sơn</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>107</ID>\n                     <Name>Tỉnh Nam Định</Name>\n                     <NameVN>Tỉnh Nam Định</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>108</ID>\n                     <Name>Tỉnh Nghệ An</Name>\n                     <NameVN>Tỉnh Nghệ An</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>109</ID>\n                     <Name>Tỉnh Ninh Bình</Name>\n                     <NameVN>Tỉnh Ninh Bình</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>110</ID>\n                     <Name>Tỉnh Ninh Thuận</Name>\n                     <NameVN>Tỉnh Ninh Thuận</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>111</ID>\n                     <Name>Tỉnh Phú Thọ</Name>\n                     <NameVN>Tỉnh Phú Thọ</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>112</ID>\n                     <Name>Tỉnh Phú Yên</Name>\n                     <NameVN>Tỉnh Phú Yên</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>113</ID>\n                     <Name>Tỉnh Quảng Bình</Name>\n                     <NameVN>Tỉnh Quảng Bình</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>114</ID>\n                     <Name>Tỉnh Quảng Nam</Name>\n                     <NameVN>Tỉnh Quảng Nam</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>115</ID>\n                     <Name>Tỉnh Quảng Ngãi</Name>\n                     <NameVN>Tỉnh Quảng Ngãi</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>116</ID>\n                     <Name>Tỉnh Quảng Ninh</Name>\n                     <NameVN>Tỉnh Quảng Ninh</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>117</ID>\n                     <Name>Tỉnh Quảng Trị</Name>\n                     <NameVN>Tỉnh Quảng Trị</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>118</ID>\n                     <Name>Tỉnh Sóc Trăng</Name>\n                     <NameVN>Tỉnh Sóc Trăng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>119</ID>\n                     <Name>Tỉnh Sơn La</Name>\n                     <NameVN>Tỉnh Sơn La</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>120</ID>\n                     <Name>Tỉnh Thanh Hóa</Name>\n                     <NameVN>Tỉnh Thanh Hóa</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>121</ID>\n                     <Name>Tỉnh Thái Bình</Name>\n                     <NameVN>Tỉnh Thái Bình</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>122</ID>\n                     <Name>Tỉnh Thái Nguyên</Name>\n                     <NameVN>Tỉnh Thái Nguyên</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>123</ID>\n                     <Name>Tỉnh Thừa Thiên - Huế</Name>\n                     <NameVN>Tỉnh Thừa Thiên - Huế</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>124</ID>\n                     <Name>Tỉnh Tiền Giang</Name>\n                     <NameVN>Tỉnh Tiền Giang</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>125</ID>\n                     <Name>TP Hồ Chí Minh</Name>\n                     <NameVN>TP Hồ Chí Minh</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>126</ID>\n                     <Name>Tỉnh Trà Vinh</Name>\n                     <NameVN>Tỉnh Trà Vinh</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>127</ID>\n                     <Name>Tỉnh Tuyên Quang</Name>\n                     <NameVN>Tỉnh Tuyên Quang</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>128</ID>\n                     <Name>Tỉnh Tây Ninh</Name>\n                     <NameVN>Tỉnh Tây Ninh</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>129</ID>\n                     <Name>Tỉnh Vĩnh Long</Name>\n                     <NameVN>Tỉnh Vĩnh Long</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>130</ID>\n                     <Name>Tỉnh Vĩnh Phúc</Name>\n                     <NameVN>Tỉnh Vĩnh Phúc</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>131</ID>\n                     <Name>Tỉnh Yên Bái</Name>\n                     <NameVN>Tỉnh Yên Bái</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>132</ID>\n                     <Name>Tỉnh Điện Biên</Name>\n                     <NameVN>Tỉnh Điện Biên</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>133</ID>\n                     <Name>Thành phố Đà Nẵng</Name>\n                     <NameVN>Thành phố Đà Nẵng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>134</ID>\n                     <Name>Tỉnh Đắk Lắk</Name>\n                     <NameVN>Tỉnh Đắk Lắk</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>2</ID>\n                     <Name>Tỉnh Đồng Nai</Name>\n                     <NameVN>Tỉnh Đồng Nai</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>7</ID>\n                     <Name>Tỉnh Đồng Tháp</Name>\n                     <NameVN>Tỉnh Đồng Tháp</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>75</ID>\n                     <Name>Tỉnh An Giang</Name>\n                     <NameVN>Tỉnh An Giang</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>76</ID>\n                     <Name>Tỉnh Bà Rịa - Vũng Tàu</Name>\n                     <NameVN>Tỉnh Bà Rịa - Vũng Tàu</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>77</ID>\n                     <Name>Tỉnh Bình Dương</Name>\n                     <NameVN>Tỉnh Bình Dương</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>78</ID>\n                     <Name>Tỉnh Bình Phước</Name>\n                     <NameVN>Tỉnh Bình Phước</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>79</ID>\n                     <Name>Tỉnh Bình Thuận</Name>\n                     <NameVN>Tỉnh Bình Thuận</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>80</ID>\n                     <Name>Tỉnh Bình Định</Name>\n                     <NameVN>Tỉnh Bình Định</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>81</ID>\n                     <Name>Tỉnh Bạc Liêu</Name>\n                     <NameVN>Tỉnh Bạc Liêu</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>82</ID>\n                     <Name>Tỉnh Bắc Giang</Name>\n                     <NameVN>Tỉnh Bắc Giang</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>83</ID>\n                     <Name>Tỉnh Bắc Kạn</Name>\n                     <NameVN>Tỉnh Bắc Kạn</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>84</ID>\n                     <Name>Tỉnh Bắc Ninh</Name>\n                     <NameVN>Tỉnh Bắc Ninh</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>85</ID>\n                     <Name>Tỉnh Bến Tre</Name>\n                     <NameVN>Tỉnh Bến Tre</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>86</ID>\n                     <Name>Tỉnh Cao Bằng</Name>\n                     <NameVN>Tỉnh Cao Bằng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>87</ID>\n                     <Name>Tỉnh Cà Mau</Name>\n                     <NameVN>Tỉnh Cà Mau</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>88</ID>\n                     <Name>Thành phố Cần Thơ</Name>\n                     <NameVN>Thành phố Cần Thơ</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>89</ID>\n                     <Name>Tỉnh Gia Lai</Name>\n                     <NameVN>Tỉnh Gia Lai</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>90</ID>\n                     <Name>Tỉnh Hòa Bình</Name>\n                     <NameVN>Tỉnh Hòa Bình</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>91</ID>\n                     <Name>Tỉnh Hà Giang</Name>\n                     <NameVN>Tỉnh Hà Giang</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>92</ID>\n                     <Name>Tỉnh Hà Nam</Name>\n                     <NameVN>Tỉnh Hà Nam</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>93</ID>\n                     <Name>Thành phố Hà Nội</Name>\n                     <NameVN>Thành phố Hà Nội</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>94</ID>\n                     <Name>Tỉnh Hà Tĩnh</Name>\n                     <NameVN>Tỉnh Hà Tĩnh</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>95</ID>\n                     <Name>Tỉnh Hưng Yên</Name>\n                     <NameVN>Tỉnh Hưng Yên</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>96</ID>\n                     <Name>Tỉnh Hải Dương</Name>\n                     <NameVN>Tỉnh Hải Dương</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>97</ID>\n                     <Name>Thành phố Hải Phòng</Name>\n                     <NameVN>Thành phố Hải Phòng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>98</ID>\n                     <Name>Tỉnh Hậu Giang</Name>\n                     <NameVN>Tỉnh Hậu Giang</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>99</ID>\n                     <Name>Tỉnh Khánh Hòa</Name>\n                     <NameVN>Tỉnh Khánh Hòa</NameVN>\n                  </AvailableValues>\n               </AdditionalProperties>\n               <AdditionalProperties>\n                  <ID>Source</ID>\n                  <Name>Source</Name>\n                  <NameVN>Source</NameVN>\n                  <PosOrder>2</PosOrder>\n                  <ApplyTo>ALL</ApplyTo>\n                  <Mandatory>true</Mandatory>\n                  <Type>list</Type>\n                  <AvailableValues>\n                     <ID>CIC</ID>\n                     <Name>CIC</Name>\n                     <NameVN>CIC</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>EA</ID>\n                     <Name>EA</Name>\n                     <NameVN>EA</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>F2F</ID>\n                     <Name>F2F</Name>\n                     <NameVN>F2F</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>LocalAuthorities</ID>\n                     <Name>CQCA</Name>\n                     <NameVN>CQCA</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>Normal</ID>\n                     <Name>Normal</Name>\n                     <NameVN>Normal</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>PR/MKT</ID>\n                     <Name>PR/MKT</Name>\n                     <NameVN>PR/MKT</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>SBV</ID>\n                     <Name>SBV</Name>\n                     <NameVN>SBV</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>Special Follow</ID>\n                     <Name>Special Follow</Name>\n                     <NameVN>Special Follow</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>VCCA</ID>\n                     <Name>VCCA</Name>\n                     <NameVN>VCCA</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>VIP</ID>\n                     <Name>VIP</Name>\n                     <NameVN>VIP</NameVN>\n                  </AvailableValues>\n               </AdditionalProperties>\n               <AdditionalProperties>\n                  <ID>Department</ID>\n                  <Name>Department</Name>\n                  <NameVN>Phòng Ban</NameVN>\n                  <PosOrder>100</PosOrder>\n                  <ApplyTo>ALL</ApplyTo>\n                  <Mandatory>true</Mandatory>\n                  <Type>list</Type>\n                  <AvailableValues>\n                     <ID>3026150</ID>\n                     <Name>Phòng Công Nghệ Tích Hợp</Name>\n                     <NameVN>Phòng Công Nghệ Tích Hợp</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026151</ID>\n                     <Name>Phòng Ứng Dụng Nội Bộ</Name>\n                     <NameVN>Phòng Ứng Dụng Nội Bộ</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026152</ID>\n                     <Name>Phòng Kiến Trúc CNTT Doanh Nghiệp</Name>\n                     <NameVN>Phòng Kiến Trúc CNTT Doanh Nghiệp</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026154</ID>\n                     <Name>Phòng Trải Nghiệm Người Dùng Ứng Dụng Di Động</Name>\n                     <NameVN>Phòng Trải Nghiệm Người Dùng Ứng Dụng Di Động</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026158</ID>\n                     <Name>Phòng Tiếp Thị Kỹ Thuật Số -1</Name>\n                     <NameVN>Phòng Tiếp Thị Kỹ Thuật Số -1</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026159</ID>\n                     <Name>Phòng Phát Triển &amp; Quản Lý Sản Phẩm Kỹ Thuật Số</Name>\n                     <NameVN>Phòng Phát Triển &amp; Quản Lý Sản Phẩm Kỹ Thuật Số</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026160</ID>\n                     <Name>Phòng Dữ Liệu &amp; Phân Tích Kinh Doanh Kỹ Thuật Số</Name>\n                     <NameVN>Phòng Dữ Liệu &amp; Phân Tích Kinh Doanh Kỹ Thuật Số</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026164</ID>\n                     <Name>Phòng Khách Hàng Cá Nhân UB</Name>\n                     <NameVN>Phòng Khách Hàng Cá Nhân UB</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026165</ID>\n                     <Name>Phòng Quan Hệ Doanh Nghiệp UB</Name>\n                     <NameVN>Phòng Quan Hệ Doanh Nghiệp UB</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026166</ID>\n                     <Name>Phòng Thu Hút Khách Hàng Qua Kênh Kỹ Thuật Số UB</Name>\n                     <NameVN>Phòng Thu Hút Khách Hàng Qua Kênh Kỹ Thuật Số UB</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026168</ID>\n                     <Name>Phòng Sản Phẩm Thẻ &amp; Usuper UB</Name>\n                     <NameVN>Phòng Sản Phẩm Thẻ &amp; Usuper UB</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026169</ID>\n                     <Name>Phòng Sản Phẩm Cho Vay UB</Name>\n                     <NameVN>Phòng Sản Phẩm Cho Vay UB</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026170</ID>\n                     <Name>Phòng Tiếp Thị UB</Name>\n                     <NameVN>Phòng Tiếp Thị UB</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026178</ID>\n                     <Name>Phòng Thu Hút Nhân Tài - Thị Trường</Name>\n                     <NameVN>Phòng Thu Hút Nhân Tài - Thị Trường</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026179</ID>\n                     <Name>Phòng Thu Hút Nhân Tài - Văn Phòng</Name>\n                     <NameVN>Phòng Thu Hút Nhân Tài - Văn Phòng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026180</ID>\n                     <Name>Phòng Thu Hút Nhân Tài - Nhân Sự Cấp Cao &amp; Giải Pháp Tuyển Dụng</Name>\n                     <NameVN>Phòng Thu Hút Nhân Tài - Nhân Sự Cấp Cao &amp; Giải Pháp Tuyển Dụng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026181</ID>\n                     <Name>Phòng Quản Lý &amp; Phân Tích Danh Mục Chuyên Sâu</Name>\n                     <NameVN>Phòng Quản Lý &amp; Phân Tích Danh Mục Chuyên Sâu</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026182</ID>\n                     <Name>Phòng Quản Trị Rủi Ro Inorganic &amp; Làm Giàu Dữ Liệu</Name>\n                     <NameVN>Phòng Quản Trị Rủi Ro Inorganic &amp; Làm Giàu Dữ Liệu</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026183</ID>\n                     <Name>Phòng Quản Trị Rủi Ro Organic</Name>\n                     <NameVN>Phòng Quản Trị Rủi Ro Organic</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026185</ID>\n                     <Name>Phòng Ứng Dụng Di Động-2</Name>\n                     <NameVN>Phòng Ứng Dụng Di Động-2</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026186</ID>\n                     <Name>Phòng Chiến Lược &amp; Phân Tích Thu Hồi Tín Dụng</Name>\n                     <NameVN>Phòng Chiến Lược &amp; Phân Tích Thu Hồi Tín Dụng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026187</ID>\n                     <Name>Phòng Kiểm Soát Chất Lượng &amp; Xử Lý Khiếu Nại Xử Lý Tín Dụng</Name>\n                     <NameVN>Phòng Kiểm Soát Chất Lượng &amp; Xử Lý Khiếu Nại Xử Lý Tín Dụng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026188</ID>\n                     <Name>Phòng Tiếp Thị Sản Phẩm</Name>\n                     <NameVN>Phòng Tiếp Thị Sản Phẩm</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026189</ID>\n                     <Name>Phòng Sản Phẩm Thẻ</Name>\n                     <NameVN>Phòng Sản Phẩm Thẻ</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026190</ID>\n                     <Name>Phòng Xử Lý Tín Dụng Ngoại Bảng Nội Bộ - 2</Name>\n                     <NameVN>Phòng Xử Lý Tín Dụng Ngoại Bảng Nội Bộ - 2</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026191</ID>\n                     <Name>Phòng Xử Lý Tín Dụng Ngoại Bảng Nội Bộ - 1</Name>\n                     <NameVN>Phòng Xử Lý Tín Dụng Ngoại Bảng Nội Bộ - 1</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026192</ID>\n                     <Name>Phòng Thương Hiệu</Name>\n                     <NameVN>Phòng Thương Hiệu</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026194</ID>\n                     <Name>Phòng Vận Hành Kinh Doanh Bảo Hiểm</Name>\n                     <NameVN>Phòng Vận Hành Kinh Doanh Bảo Hiểm</NameVN>\n                  </AvailableValues>\n          ';
    }

    private static String xmlPart2() {
        return '        <AvailableValues>\n                     <ID>3026195</ID>\n                     <Name>Phòng Xử Lý Tín Dụng Ngoại Bảng Nội Bộ - 3</Name>\n                     <NameVN>Phòng Xử Lý Tín Dụng Ngoại Bảng Nội Bộ - 3</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026196</ID>\n                     <Name>Phòng Quản Lý Kênh Kinh Doanh Bảo Hiểm</Name>\n                     <NameVN>Phòng Quản Lý Kênh Kinh Doanh Bảo Hiểm</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026197</ID>\n                     <Name>Phòng Tiếp Thị Bảo Hiểm</Name>\n                     <NameVN>Phòng Tiếp Thị Bảo Hiểm</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026198</ID>\n                     <Name>Phòng Quản Lý Ứng Dụng Bảo Hiểm</Name>\n                     <NameVN>Phòng Quản Lý Ứng Dụng Bảo Hiểm</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026199</ID>\n                     <Name>Phòng Quản Lý Dự Án &amp; Chiến Dịch Kinh Doanh Bảo Hiểm</Name>\n                     <NameVN>Phòng Quản Lý Dự Án &amp; Chiến Dịch Kinh Doanh Bảo Hiểm</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026200</ID>\n                     <Name>Phòng Phát Triển Chiến Lược Kinh Doanh Bảo Hiểm</Name>\n                     <NameVN>Phòng Phát Triển Chiến Lược Kinh Doanh Bảo Hiểm</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026201</ID>\n                     <Name>Phòng Kinh Doanh Bảo Hiểm Qua Điện Thoại</Name>\n                     <NameVN>Phòng Kinh Doanh Bảo Hiểm Qua Điện Thoại</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026202</ID>\n                     <Name>Phòng Quản Lý Tăng Trưởng Kinh Doanh X-sell</Name>\n                     <NameVN>Phòng Quản Lý Tăng Trưởng Kinh Doanh X-sell</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026204</ID>\n                     <Name>Phòng Chiến Lược &amp; Quản Lý Hiệu Quả Xử Lý Tín Dụng</Name>\n                     <NameVN>Phòng Chiến Lược &amp; Quản Lý Hiệu Quả Xử Lý Tín Dụng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026207</ID>\n                     <Name>Phòng Quản Lý Hiệu Quả Kinh Doanh X-sell Qua Điện Thoại</Name>\n                     <NameVN>Phòng Quản Lý Hiệu Quả Kinh Doanh X-sell Qua Điện Thoại</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026208</ID>\n                     <Name>Phòng Báo Cáo, Phân Tích &amp; Đánh Giá Thông Tin Kinh Doanh X-sell</Name>\n                     <NameVN>Phòng Báo Cáo, Phân Tích &amp; Đánh Giá Thông Tin Kinh Doanh X-sell</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026209</ID>\n                     <Name>Phòng Năng Lực Kinh Doanh Thông Minh UB</Name>\n                     <NameVN>Phòng Năng Lực Kinh Doanh Thông Minh UB</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026210</ID>\n                     <Name>Phòng Sản Phẩm Cho Vay UB</Name>\n                     <NameVN>Phòng Sản Phẩm Cho Vay UB</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026211</ID>\n                     <Name>Phòng Đối Tác Nhân Sự - 4</Name>\n                     <NameVN>Phòng Đối Tác Nhân Sự - 4</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026213</ID>\n                     <Name>Phòng Chính Sách Xử Lý Tín Dụng</Name>\n                     <NameVN>Phòng Chính Sách Xử Lý Tín Dụng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026214</ID>\n                     <Name>Phòng Chiến Lược Xử Lý Tín Dụng</Name>\n                     <NameVN>Phòng Chiến Lược Xử Lý Tín Dụng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026215</ID>\n                     <Name>Phòng Quản Lý Ứng Dụng Di Động UB</Name>\n                     <NameVN>Phòng Quản Lý Ứng Dụng Di Động UB</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026216</ID>\n                     <Name>Phòng Trải Nghiệm Khách Hàng Ứng Dụng UB</Name>\n                     <NameVN>Phòng Trải Nghiệm Khách Hàng Ứng Dụng UB</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026218</ID>\n                     <Name>Phòng Dự Án UB</Name>\n                     <NameVN>Phòng Dự Án UB</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026219</ID>\n                     <Name>Phòng Phát Triển Ứng Dụng Di Động UB</Name>\n                     <NameVN>Phòng Phát Triển Ứng Dụng Di Động UB</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026221</ID>\n                     <Name>Phòng Bán Hàng Qua Điện Thoại X-sell 3</Name>\n                     <NameVN>Phòng Bán Hàng Qua Điện Thoại X-sell 3</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026222</ID>\n                     <Name>Phòng Đối Tác Nhân Sự - 1</Name>\n                     <NameVN>Phòng Đối Tác Nhân Sự - 1</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026223</ID>\n                     <Name>Phòng Tố Tụng</Name>\n                     <NameVN>Phòng Tố Tụng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026224</ID>\n                     <Name>Phòng Vận Hành Xử Lý Tín Dụng Ngoại Bảng</Name>\n                     <NameVN>Phòng Vận Hành Xử Lý Tín Dụng Ngoại Bảng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026225</ID>\n                     <Name>Phòng Xử Lý Tín Dụng Ngoại Bảng Nội Bộ - 1</Name>\n                     <NameVN>Phòng Xử Lý Tín Dụng Ngoại Bảng Nội Bộ - 1</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026226</ID>\n                     <Name>Phòng Xử Lý Tín Dụng Ngoại Bảng Nội Bộ - 2</Name>\n                     <NameVN>Phòng Xử Lý Tín Dụng Ngoại Bảng Nội Bộ - 2</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026227</ID>\n                     <Name>Phòng Xử Lý Tín Dụng Ngoại Bảng Nội Bộ - 3</Name>\n                     <NameVN>Phòng Xử Lý Tín Dụng Ngoại Bảng Nội Bộ - 3</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026228</ID>\n                     <Name>Phòng Quản Lý Thu Hồi Nợ Ngoại Bảng Bên Thứ Ba</Name>\n                     <NameVN>Phòng Quản Lý Thu Hồi Nợ Ngoại Bảng Bên Thứ Ba</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026229</ID>\n                     <Name>Phòng Vận Hành Thu Hồi Nợ</Name>\n                     <NameVN>Phòng Vận Hành Thu Hồi Nợ</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026230</ID>\n                     <Name>Phòng Kiểm Soát Chất Lượng Thu Hồi Nợ</Name>\n                     <NameVN>Phòng Kiểm Soát Chất Lượng Thu Hồi Nợ</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026231</ID>\n                     <Name>Phòng Xử Lý Tín Dụng Ngoại Bảng Phụ Trội</Name>\n                     <NameVN>Phòng Xử Lý Tín Dụng Ngoại Bảng Phụ Trội</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026232</ID>\n                     <Name>Phòng Phát Triển Nguồn Khách Hàng Tiềm Năng -1</Name>\n                     <NameVN>Phòng Phát Triển Nguồn Khách Hàng Tiềm Năng -1</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>4018009</ID>\n                     <Name>Phòng Kinh Doanh Đối Tác Phân Phối 1</Name>\n                     <NameVN>Phòng Kinh Doanh Đối Tác Phân Phối 1</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>4018010</ID>\n                     <Name>Phòng Kinh Doanh Đối Tác Phân Phối 2</Name>\n                     <NameVN>Phòng Kinh Doanh Đối Tác Phân Phối 2</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>4018011</ID>\n                     <Name>Phòng Kinh Doanh Đối Tác Phân Phối 3</Name>\n                     <NameVN>Phòng Kinh Doanh Đối Tác Phân Phối 3</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>4018012</ID>\n                     <Name>Phòng Kinh Doanh Đối Tác Phân Phối 4</Name>\n                     <NameVN>Phòng Kinh Doanh Đối Tác Phân Phối 4</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>4018013</ID>\n                     <Name>Phòng Kinh Doanh Đối Tác Phân Phối 5</Name>\n                     <NameVN>Phòng Kinh Doanh Đối Tác Phân Phối 5</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>4018123</ID>\n                     <Name>Phòng Quản Lý Dự Án</Name>\n                     <NameVN>Phòng Quản Lý Dự Án</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>4018128</ID>\n                     <Name>Phòng Công Nghệ Tiếp Thị &amp; Thiết Kế Trải Nghiệm Khách Hàng</Name>\n                     <NameVN>Phòng Công Nghệ Tiếp Thị &amp; Thiết Kế Trải Nghiệm Khách Hàng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>4018129</ID>\n                     <Name>Phòng Giải Pháp Sáng Tạo Trải Nghiệm Khách Hàng Số</Name>\n                     <NameVN>Phòng Giải Pháp Sáng Tạo Trải Nghiệm Khách Hàng Số</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>4018253</ID>\n                     <Name>Phòng Phát Triển Chiến Lược Kinh Doanh Thị Trường</Name>\n                     <NameVN>Phòng Phát Triển Chiến Lược Kinh Doanh Thị Trường</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>4018254</ID>\n                     <Name>Phòng Vận Hành Kinh Doanh Thị Trường</Name>\n                     <NameVN>Phòng Vận Hành Kinh Doanh Thị Trường</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010823</ID>\n                     <Name>Phòng Thu Hút Nhân Tài</Name>\n                     <NameVN>Phòng Thu Hút Nhân Tài</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010825</ID>\n                     <Name>Phòng Phát Triển Tổ Chức</Name>\n                     <NameVN>Phòng Phát Triển Tổ Chức</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010832</ID>\n                     <Name>Phòng Quản Trị Rủi Ro Hoạt Động</Name>\n                     <NameVN>Phòng Quản Trị Rủi Ro Hoạt Động</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010836</ID>\n                     <Name>Phòng Mô Hình, Báo Cáo &amp; Phân Tích</Name>\n                     <NameVN>Phòng Mô Hình, Báo Cáo &amp; Phân Tích</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010860</ID>\n                     <Name>Phòng Thanh Toán</Name>\n                     <NameVN>Phòng Thanh Toán</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010865</ID>\n                     <Name>Phòng Mua Sắm</Name>\n                     <NameVN>Phòng Mua Sắm</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010866</ID>\n                     <Name>Phòng Hành Chính</Name>\n                     <NameVN>Phòng Hành Chính</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010867</ID>\n                     <Name>Phòng Cơ Sở Vật Chất</Name>\n                     <NameVN>Phòng Cơ Sở Vật Chất</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010868</ID>\n                     <Name>Phòng Kế Toán Tài Chính</Name>\n                     <NameVN>Phòng Kế Toán Tài Chính</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010876</ID>\n                     <Name>Phòng Báo Cáo</Name>\n                     <NameVN>Phòng Báo Cáo</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010884</ID>\n                     <Name>Phòng Xây Dựng Hệ Thống CNTT Tài Chính</Name>\n                     <NameVN>Phòng Xây Dựng Hệ Thống CNTT Tài Chính</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010886</ID>\n                     <Name>Phòng Quản Trị Viên Cộng Sự</Name>\n                     <NameVN>Phòng Quản Trị Viên Cộng Sự</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010887</ID>\n                     <Name>Phòng Quản Trị Quy Trình CNTT</Name>\n                     <NameVN>Phòng Quản Trị Quy Trình CNTT</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010888</ID>\n                     <Name>Phòng Phát Triển Pega</Name>\n                     <NameVN>Phòng Phát Triển Pega</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010891</ID>\n                     <Name>Phòng Cơ Sở Hạ Tầng CNTT</Name>\n                     <NameVN>Phòng Cơ Sở Hạ Tầng CNTT</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010892</ID>\n                     <Name>Phòng Dịch Vụ CNTT</Name>\n                     <NameVN>Phòng Dịch Vụ CNTT</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010894</ID>\n                     <Name>Phòng Phát Triển Phần Mềm</Name>\n                     <NameVN>Phòng Phát Triển Phần Mềm</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010895</ID>\n                     <Name>Phòng Hệ Thống &amp; Cơ Sở Dữ Liệu CNTT</Name>\n                     <NameVN>Phòng Hệ Thống &amp; Cơ Sở Dữ Liệu CNTT</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010899</ID>\n                     <Name>Phòng Kiểm Toán Nội Bộ</Name>\n                     <NameVN>Phòng Kiểm Toán Nội Bộ</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010901</ID>\n                     <Name>Phòng Sáng Tạo</Name>\n                     <NameVN>Phòng Sáng Tạo</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010914</ID>\n                     <Name>Phòng Chính Sách &amp; Phúc Lợi</Name>\n                     <NameVN>Phòng Chính Sách &amp; Phúc Lợi</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010916</ID>\n                     <Name>Phòng Vận Hành Thẻ</Name>\n                     <NameVN>Phòng Vận Hành Thẻ</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010932</ID>\n                     <Name>Phòng Vận Hành Thu Hồi Nợ</Name>\n                     <NameVN>Phòng Vận Hành Thu Hồi Nợ</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010939</ID>\n                     <Name>Phòng Quản Lý Dự Án Sáng Kiến</Name>\n                     <NameVN>Phòng Quản Lý Dự Án Sáng Kiến</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010940</ID>\n                     <Name>Phòng Dịch Vụ Nhân Sự</Name>\n                     <NameVN>Phòng Dịch Vụ Nhân Sự</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010953</ID>\n                     <Name>Phòng Quan Hệ Đối Ngoại</Name>\n                     <NameVN>Phòng Quan Hệ Đối Ngoại</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010955</ID>\n                     <Name>Phòng Dịch Vụ Khách Hàng</Name>\n                     <NameVN>Phòng Dịch Vụ Khách Hàng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010956</ID>\n                     <Name>Phòng Xử Lý Hợp Đồng Vay</Name>\n                     <NameVN>Phòng Xử Lý Hợp Đồng Vay</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010964</ID>\n                     <Name>Phòng Phân Tích Nâng Cao</Name>\n                     <NameVN>Phòng Phân Tích Nâng Cao</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010965</ID>\n                     <Name>Phòng Quản Lý Dữ Liệu</Name>\n                     <NameVN>Phòng Quản Lý Dữ Liệu</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3010966</ID>\n                     <Name>Phòng Quản Trị &amp; Chất Lượng Dữ Liệu</Name>\n                     <NameVN>Phòng Quản Trị &amp; Chất Lượng Dữ Liệu</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3011024</ID>\n                     <Name>Phòng Điều Tra &amp; Xử Lý Tín Dụng</Name>\n                     <NameVN>Phòng Điều Tra &amp; Xử Lý Tín Dụng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3011101</ID>\n                     <Name>Phòng Phát Triển Giải Pháp Đào Tạo</Name>\n                     <NameVN>Phòng Phát Triển Giải Pháp Đào Tạo</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3013332</ID>\n                     <Name>Phòng Vận Hành &amp; Hệ Thống Đào Tạo</Name>\n                     <NameVN>Phòng Vận Hành &amp; Hệ Thống Đào Tạo</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3013333</ID>\n                     <Name>Phòng Phát Triển Năng Lực</Name>\n                     <NameVN>Phòng Phát Triển Năng Lực</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3013334</ID>\n                     <Name>Phòng Giải Pháp Học Thuật</Name>\n                     <NameVN>Phòng Giải Pháp Học Thuật</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3013409</ID>\n                     <Name>Phòng Quản Lý Dự Án</Name>\n                     <NameVN>Phòng Quản Lý Dự Án</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3025978</ID>\n                     <Name>Phòng Tiếp Thị Kỹ Thuật Số</Name>\n                     <NameVN>Phòng Tiếp Thị Kỹ Thuật Số</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3025980</ID>\n                     <Name>Phòng Phân Tích &amp; Báo Cáo Phức Hợp</Name>\n                     <NameVN>Phòng Phân Tích &amp; Báo Cáo Phức Hợp</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3025983</ID>\n                     <Name>Phòng Thu Hồi Nợ Qua Điện Thoại</Name>\n                     <NameVN>Phòng Thu Hồi Nợ Qua Điện Thoại</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3025984</ID>\n                     <Name>Phòng Thu Hồi Nợ Trễ Hạn Qua Điện Thoại</Name>\n                     <NameVN>Phòng Thu Hồi Nợ Trễ Hạn Qua Điện Thoại</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3025985</ID>\n                     <Name>Phòng Quản Lý Thu Hồi Nợ Nội Bảng Bên Thứ Ba</Name>\n                     <NameVN>Phòng Quản Lý Thu Hồi Nợ Nội Bảng Bên Thứ Ba</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3025987</ID>\n                     <Name>Phòng Thu Hồi Nợ Thẻ Tín Dụng Qua Điện Thoại</Name>\n                     <NameVN>Phòng Thu Hồi Nợ Thẻ Tín Dụng Qua Điện Thoại</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3025988</ID>\n                     <Name>Phòng Thu Hồi Nợ Thẻ Tín Dụng Trễ Hạn Qua Điện Thoại &amp; Tại Nhà</Name>\n                     <NameVN>Phòng Thu Hồi Nợ Thẻ Tín Dụng Trễ Hạn Qua Điện Thoại &amp; Tại Nhà</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3025989</ID>\n                     <Name>Phòng Chiến Lược &amp; Phân Tích Thu Hồi Nợ</Name>\n                     <NameVN>Phòng Chiến Lược &amp; Phân Tích Thu Hồi Nợ</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3025991</ID>\n                     <Name>Phòng Thu Hồi Nợ Tại Nhà - Miền Bắc/ Miền Trung/ Miền Đông/ Miền Nam/ Mekong - 1</Name>\n                     <NameVN>Phòng Thu Hồi Nợ Tại Nhà - Miền Bắc/ Miền Trung/ Miền Đông/ Miền Nam/ Mekong - 1</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3025992</ID>\n                     <Name>Phòng Thu Hồi Nợ Tại Nhà - Miền Bắc/ Miền Trung/ Miền Đông/ Miền Nam/ Mekong - 2</Name>\n                     <NameVN>Phòng Thu Hồi Nợ Tại Nhà - Miền Bắc/ Miền Trung/ Miền Đông/ Miền Nam/ Mekong - 2</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3025996</ID>\n                     <Name>Phòng Phát Triển Nguồn Khách Hàng Tiềm Năng</Name>\n                     <NameVN>Phòng Phát Triển Nguồn Khách Hàng Tiềm Năng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026003</ID>\n                     <Name>Phòng Công Nghệ Cho Vay Kỹ Thuật Số</Name>\n                     <NameVN>Phòng Công Nghệ Cho Vay Kỹ Thuật Số</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026008</ID>\n                     <Name>Phòng Quản Trị Quy Trình CNTT</Name>\n                     <NameVN>Phòng Quản Trị Quy Trình CNTT</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026012</ID>\n                     <Name>Phòng Quản Lý Bảng Cân Đối Kế Toán</Name>\n                     <NameVN>Phòng Quản Lý Bảng Cân Đối Kế Toán</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026013</ID>\n                     <Name>Phòng Quản Lý Chi Phí</Name>\n                     <NameVN>Phòng Quản Lý Chi Phí</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026015</ID>\n                     <Name>Phòng Kiến Trúc CNTT Doanh Nghiệp</Name>\n                     <NameVN>Phòng Kiến Trúc CNTT Doanh Nghiệp</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026016</ID>\n                     <Name>Phòng Phân Tích Nghiệp Vụ CNTT</Name>\n                     <NameVN>Phòng Phân Tích Nghiệp Vụ CNTT</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026027</ID>\n                     <Name>Phòng Quản Lý Quy Trình</Name>\n                     <NameVN>Phòng Quản Lý Quy Trình</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n       ';
    }

    private static String xmlPart3() {
        return '              <ID>3026055</ID>\n                     <Name>Phòng Kinh Doanh Tiền Tệ &amp; Định Chế Tài Chính</Name>\n                     <NameVN>Phòng Kinh Doanh Tiền Tệ &amp; Định Chế Tài Chính</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026056</ID>\n                     <Name>Phòng Huy Động Nguồn Vốn - Miền Bắc</Name>\n                     <NameVN>Phòng Huy Động Nguồn Vốn - Miền Bắc</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026057</ID>\n                     <Name>Phòng Huy Động Nguồn Vốn - Miền Nam</Name>\n                     <NameVN>Phòng Huy Động Nguồn Vốn - Miền Nam</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026069</ID>\n                     <Name>Phòng Nguồn Lực Tương Lai</Name>\n                     <NameVN>Phòng Nguồn Lực Tương Lai</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026084</ID>\n                     <Name>Phòng Nền Tảng &amp; Sản phẩm Bảo Hiểm Kỹ Thuật Số</Name>\n                     <NameVN>Phòng Nền Tảng &amp; Sản phẩm Bảo Hiểm Kỹ Thuật Số</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026086</ID>\n                     <Name>Phòng Xử Lý Tín Dụng Sớm - Vay Tiêu Dùng</Name>\n                     <NameVN>Phòng Xử Lý Tín Dụng Sớm - Vay Tiêu Dùng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026087</ID>\n                     <Name>Phòng Xử Lý Tín Dụng Sớm - Thẻ Tín Dụng</Name>\n                     <NameVN>Phòng Xử Lý Tín Dụng Sớm - Thẻ Tín Dụng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026091</ID>\n                     <Name>Phòng An Ninh Tổng Hợp</Name>\n                     <NameVN>Phòng An Ninh Tổng Hợp</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026092</ID>\n                     <Name>Phòng Phê Duyệt Tín Dụng</Name>\n                     <NameVN>Phòng Phê Duyệt Tín Dụng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026093</ID>\n                     <Name>Phòng Vận Hành &amp; Quản Lý Dự Án Phê Duyệt &amp; Xử Lý Tín Dụng Sớm</Name>\n                     <NameVN>Phòng Vận Hành &amp; Quản Lý Dự Án Phê Duyệt &amp; Xử Lý Tín Dụng Sớm</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026097</ID>\n                     <Name>Phòng Truyền Thông</Name>\n                     <NameVN>Phòng Truyền Thông</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026099</ID>\n                     <Name>Phòng Quản Lý Thu Hồi Nợ Nội Bảng Bên Thứ Ba</Name>\n                     <NameVN>Phòng Quản Lý Thu Hồi Nợ Nội Bảng Bên Thứ Ba</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026102</ID>\n                     <Name>Phòng Hỗ Trợ Điều Hành</Name>\n                     <NameVN>Phòng Hỗ Trợ Điều Hành</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026103</ID>\n                     <Name>Phòng Quản lý Quan hệ Đầu tư</Name>\n                     <NameVN>Phòng Quản lý Quan hệ Đầu tư</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026106</ID>\n                     <Name>Phòng Phát Triển Chiến Lược Kinh Doanh Thị Trường</Name>\n                     <NameVN>Phòng Phát Triển Chiến Lược Kinh Doanh Thị Trường</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026107</ID>\n                     <Name>Phòng Vận Hành Kinh Doanh Thị Trường</Name>\n                     <NameVN>Phòng Vận Hành Kinh Doanh Thị Trường</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026108</ID>\n                     <Name>Phòng Bán Hàng Qua Điện Thoại X-sell 1</Name>\n                     <NameVN>Phòng Bán Hàng Qua Điện Thoại X-sell 1</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026109</ID>\n                     <Name>Phòng Bán Hàng Qua Điện Thoại X-sell 2</Name>\n                     <NameVN>Phòng Bán Hàng Qua Điện Thoại X-sell 2</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026110</ID>\n                     <Name>Phòng Vận Hành Kinh Doanh Qua Điện Thoại</Name>\n                     <NameVN>Phòng Vận Hành Kinh Doanh Qua Điện Thoại</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026111</ID>\n                     <Name>Phòng Phát Triển Chiến Lược Kinh Doanh Qua Điện Thoại</Name>\n                     <NameVN>Phòng Phát Triển Chiến Lược Kinh Doanh Qua Điện Thoại</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026112</ID>\n                     <Name>Phòng Bán Hàng Qua Nguồn Khách Hàng Tiềm Năng</Name>\n                     <NameVN>Phòng Bán Hàng Qua Nguồn Khách Hàng Tiềm Năng</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026113</ID>\n                     <Name>Phòng Quản Lý Dự Án Tài Chính, Rủi Ro &amp; Thu Hồi Nợ</Name>\n                     <NameVN>Phòng Quản Lý Dự Án Tài Chính, Rủi Ro &amp; Thu Hồi Nợ</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026114</ID>\n                     <Name>Phòng Quản Lý Dự Án Vận Hành &amp; CNTT</Name>\n                     <NameVN>Phòng Quản Lý Dự Án Vận Hành &amp; CNTT</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026115</ID>\n                     <Name>Phòng Quản Lý Dự Án Kinh Doanh, Sản Phẩm &amp; Tiếp Thị</Name>\n                     <NameVN>Phòng Quản Lý Dự Án Kinh Doanh, Sản Phẩm &amp; Tiếp Thị</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026116</ID>\n                     <Name>Phòng Bán Hàng Đối Tác Phân Phối 2</Name>\n                     <NameVN>Phòng Bán Hàng Đối Tác Phân Phối 2</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026117</ID>\n                     <Name>Phòng Bán Hàng Tại Điểm Giới Thiệu Dịch Vụ 1</Name>\n                     <NameVN>Phòng Bán Hàng Tại Điểm Giới Thiệu Dịch Vụ 1</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026118</ID>\n                     <Name>Phòng Bán Hàng Tại Điểm Giới Thiệu Dịch Vụ 2</Name>\n                     <NameVN>Phòng Bán Hàng Tại Điểm Giới Thiệu Dịch Vụ 2</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026119</ID>\n                     <Name>Phòng Bán Hàng Tại Điểm Giới Thiệu Dịch Vụ 3</Name>\n                     <NameVN>Phòng Bán Hàng Tại Điểm Giới Thiệu Dịch Vụ 3</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026120</ID>\n                     <Name>Phòng Bán Hàng Tại Điểm Giới Thiệu Dịch Vụ 4</Name>\n                     <NameVN>Phòng Bán Hàng Tại Điểm Giới Thiệu Dịch Vụ 4</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026121</ID>\n                     <Name>Phòng Bán Hàng Tại Điểm Giới Thiệu Dịch Vụ 5</Name>\n                     <NameVN>Phòng Bán Hàng Tại Điểm Giới Thiệu Dịch Vụ 5</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026122</ID>\n                     <Name>Phòng Bán Hàng Tại Điểm Giới Thiệu Dịch Vụ 6</Name>\n                     <NameVN>Phòng Bán Hàng Tại Điểm Giới Thiệu Dịch Vụ 6</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026123</ID>\n                     <Name>Phòng Đối Tác Chiến Lược</Name>\n                     <NameVN>Phòng Đối Tác Chiến Lược</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026124</ID>\n                     <Name>Phòng Bán Hàng Trực Tiếp 1</Name>\n                     <NameVN>Phòng Bán Hàng Trực Tiếp 1</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026125</ID>\n                     <Name>Phòng Bán Hàng Trực Tiếp 2</Name>\n                     <NameVN>Phòng Bán Hàng Trực Tiếp 2</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026126</ID>\n                     <Name>Phòng Bán Hàng Trực Tiếp 3</Name>\n                     <NameVN>Phòng Bán Hàng Trực Tiếp 3</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026127</ID>\n                     <Name>Phòng Bán Hàng Trực Tiếp 4</Name>\n                     <NameVN>Phòng Bán Hàng Trực Tiếp 4</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026128</ID>\n                     <Name>Phòng Bán Hàng Trực Tiếp 5</Name>\n                     <NameVN>Phòng Bán Hàng Trực Tiếp 5</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026129</ID>\n                     <Name>Phòng Bán Hàng Trực Tiếp 6</Name>\n                     <NameVN>Phòng Bán Hàng Trực Tiếp 6</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026130</ID>\n                     <Name>Phòng Bán Hàng Trực Tiếp 7</Name>\n                     <NameVN>Phòng Bán Hàng Trực Tiếp 7</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026133</ID>\n                     <Name>Phòng Bán Hàng Đối Tác Phân Phối 1</Name>\n                     <NameVN>Phòng Bán Hàng Đối Tác Phân Phối 1</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026141</ID>\n                     <Name>Phòng Phát Triển Liên Kết B@W</Name>\n                     <NameVN>Phòng Phát Triển Liên Kết B@W</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026142</ID>\n                     <Name>Phòng Phát Triển Đối Tác Kỹ Thuật Số</Name>\n                     <NameVN>Phòng Phát Triển Đối Tác Kỹ Thuật Số</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026143</ID>\n                     <Name>Phòng Quản Lý Kênh Hợp Tác Kỹ Thuật Số</Name>\n                     <NameVN>Phòng Quản Lý Kênh Hợp Tác Kỹ Thuật Số</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026145</ID>\n                     <Name>Phòng Bán Hàng Qua Điện Thoại Bên Thứ Ba</Name>\n                     <NameVN>Phòng Bán Hàng Qua Điện Thoại Bên Thứ Ba</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026146</ID>\n                     <Name>Phòng Ứng Dụng Core</Name>\n                     <NameVN>Phòng Ứng Dụng Core</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026147</ID>\n                     <Name>Phòng Pega</Name>\n                     <NameVN>Phòng Pega</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026148</ID>\n                     <Name>Phòng Ứng Dụng Di Động</Name>\n                     <NameVN>Phòng Ứng Dụng Di Động</NameVN>\n                  </AvailableValues>\n                  <AvailableValues>\n                     <ID>3026149</ID>\n                     <Name>Phòng Ứng Dụng CRM</Name>\n                     <NameVN>Phòng Ứng Dụng CRM</NameVN>\n                  </AvailableValues>\n               </AdditionalProperties>\n               <Children>\n                  <ID>CC</ID>\n                  <Name>Customer Complaint</Name>\n                  <NameVN>Customer Complaint</NameVN>\n                  <PosOrder>1</PosOrder>\n                  <ApplyTo>ALL</ApplyTo>\n                  <Type>Category</Type>\n                  <AdditionalProperties>\n                     <ID>CollectedEvidences</ID>\n                     <Name>Collected Evidences</Name>\n                     <NameVN>Collected Evidences</NameVN>\n                     <PosOrder>1</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n                     <Mandatory>true</Mandatory>\n                     <Type>list</Type>\n                     <AvailableValues>\n                        <ID>F</ID>\n                        <Name>Đầy đủ chứng từ</Name>\n                        <NameVN>Đầy đủ chứng từ</NameVN>\n                     </AvailableValues>\n                     <AvailableValues>\n                        <ID>NF</ID>\n                        <Name>Không đầy đủ chứng từ</Name>\n                        <NameVN>Không đầy đủ chứng từ</NameVN>\n                     </AvailableValues>\n                     <AvailableValues>\n                        <ID>NP</ID>\n                        <Name>Không cung cấp</Name>\n                        <NameVN>Không cung cấp</NameVN>\n                     </AvailableValues>\n                  </AdditionalProperties>\n                  <AdditionalProperties>\n                     <ID>Address</ID>\n                     <Name>Current Address</Name>\n                     <NameVN>Địa chỉ hiện tại</NameVN>\n                     <PosOrder>2</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n                     <Mandatory>true</Mandatory>\n                     <Type>string</Type>\n                  </AdditionalProperties>\n                  <AdditionalProperties>\n                     <ID>Phone</ID>\n                     <Name>Phone number</Name>\n                     <NameVN>Số điện thoại</NameVN>\n                     <PosOrder>3</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n                     <Mandatory>true</Mandatory>\n                     <Type>string</Type>\n                  </AdditionalProperties>\n                  <AdditionalProperties>\n                     <ID>ComplainantSelfie</ID>\n                     <Name>Complainant\'\'s Selfie image</Name>\n                     <NameVN>Ảnh chân dung NKN</NameVN>\n                     <PosOrder>98</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n                     <Mandatory>false</Mandatory>\n                     <Type>file</Type>\n                  </AdditionalProperties>\n                  <AdditionalProperties>\n                     <ID>ComplainantIDcard</ID>\n                     <Name>Complainant\'\'s ID card</Name>\n                     <NameVN>CMND của NKN</NameVN>\n                     <PosOrder>100</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n                     <Mandatory>false</Mandatory>\n                     <Type>file</Type>\n                  </AdditionalProperties>\n                  <AdditionalProperties>\n                     <ID>Complaint Letter</ID>\n                     <Name>Complaint Letter</Name>\n                     <NameVN>Đơn khiếu nại</NameVN>\n                     <PosOrder>100</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n                     <Mandatory>false</Mandatory>\n                     <Type>file</Type>\n                  </AdditionalProperties>\n                  <AdditionalProperties>\n                     <ID>ComplainantOther</ID>\n                     <Name>Complainant\'\'s Other Document</Name>\n                     <NameVN>Chứng từ liên quan khác của NKN</NameVN>\n                     <PosOrder>100</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n                     <Mandatory>false</Mandatory>\n                     <Type>file</Type>\n                  </AdditionalProperties>\n                  <Children>\n                     <ID>CC01</ID>\n                     <Name>KH không làm hồ sơ vay</Name>\n                     <NameVN>KH không làm hồ sơ vay</NameVN>\n                     <PosOrder>1</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n                     <Type>SubCategory</Type>\n                     <AdditionalProperties>\n                        <ID>AppIDs</ID>\n                        <Name>App IDs</Name>\n                        <NameVN>App IDs</NameVN>\n                        <PosOrder>1</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>multi</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>ContractNumbers</ID>\n                        <Name>Contract Numbers</Name>\n                        <NameVN>Các khoản vay</NameVN>\n                        <PosOrder>2</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>multi</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>NationalIDs</ID>\n                        <Name>National IDs</Name>\n                        <NameVN>Danh sách CMND</NameVN>\n                        <PosOrder>3</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>multi</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>HistoryLoan</ID>\n                        <Name>Did customer apply loan in any place?</Name>\n                        <NameVN>KH có từng làm hồ sơ vay ở đâu khác không?</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>HistoryPhone</ID>\n                        <Name>Has customer changed phone number in application belong to customer or not?</Name>\n                        <NameVN>KH có từng thay đổi SĐT không? Nếu có SĐT cũ của KH là gì?</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>IDreissued</ID>\n                        <Name>Is customer\'\'s ID reissued?</Name>\n                        <NameVN>KH có từng làm lại CMND không?</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>LostDoc</ID>\n                        <Name>Did customer lose ID/document during application time?</Name>\n                        <NameVN>Có làm mất giấy tờ trong thời gian xảy ra hợp đồng không?</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>LostDocN</ID>\n                           <Name>Không</Name>\n                           <NameVN>Không</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>LostDocY</ID>\n                           <Name>Có</Name>\n                           <NameVN>Có</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>PhoneVerify</ID>\n                        <Name>Did the customer used phone number on application at the time apply loan? If yes, did the customer share his/her phone for stranger or did not use it for a time?</Name>\n                        <NameVN>KH có đang sử dụng số điện thoại trên hồ sơ tại thời điểm làm hồ sơ không? Nếu có, KH có đưa điện thoại cho ai hay số điện thoại bị gián đoạn không?</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>ProvideDoc</ID>\n                        <Name>Did customer provided ID/document to anyone?</Name>\n                        <NameVN>Có cung cấp giấy tờ cho ai/ cho ai mượn không?</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>ProvideDocN</ID>\n                           <Name>Không</Name>\n                           <NameVN>Không</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>ProvideDocY</ID>\n                           <Name>Có</Name>\n                           <NameVN>Có</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <Children>\n                        <ID>CC01-01</ID>\n                        <Name>Khoản vay tiền mặt</Name>\n                        <NameVN>Khoản vay tiền mặt</NameVN>\n                        <PosOrder>1</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Type>SubCode</Type>\n                        <AdditionalProperties>\n                           <ID>BAVerify</ID>\n                           <Name>Does bank account number in application (if disbursed to bank transfer) belong to customer?</Name>\n                           <NameVN>Xác nhận STK KH  trên hệ thống (nếu giải ngân qua bank transfer) có phải của KH không?</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                     </Children>\n                     <Children>\n                        <ID>CC01-02</ID>\n                        <Name>Khoản vay CD-TW</Name>\n                        <NameVN>Khoản vay CD-TW</NameVN>\n                        <PosOrder>1</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Type>SubCode</Type>\n                     </Children>\n                     <Children>\n                        <ID>CC01-03</ID>\n                        <Name>Hợp đồng mở thẻ</Name>\n                        <NameVN>Hợp đồng mở thẻ</NameVN>\n                        <PosOrder>1</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Type>SubCode</Type>\n                        <AdditionalProperties>\n                           <ID>AccountNumber</ID>\n                           <Name>Account Number</Name>\n                           <NameVN>Số Tài Khoản của Khách hàng</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                     </Children>\n                  </Children>\n                  <Children>\n                     <ID>CC02</ID>\n                     <Name>KH bị chiếm dụng</Name>\n                     <NameVN>KH bị chiếm dụng</NameVN>\n                     <PosOrder>1</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n                     <Type>SubCategory</Type>\n                     <AdditionalProperties>\n                        <ID>AppIDs</ID>\n                        <Name>App IDs</Name>\n                        <NameVN>App ';
    }

    private static String xmlPart4() {
        return 'IDs</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>multi</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>ApproDate</ID>\n                        <Name>Date of Appropriation</Name>\n                        <NameVN>Ngày xảy ra chiếm dụng</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>date</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>ContractNumbers</ID>\n                        <Name>Contract Numbers</Name>\n                        <NameVN>Các khoản vay</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>false</Mandatory>\n                        <Type>multi</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>LossAmt</ID>\n                        <Name>Loss Amount</Name>\n                        <NameVN>Số tiền bị chiếm dụng</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>number</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>NationalIDs</ID>\n                        <Name>National IDs</Name>\n                        <NameVN>Danh sách CMND</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>multi</Type>\n                     </AdditionalProperties>\n                     <Children>\n                        <ID>CC02-01</ID>\n                        <Name>Khoản giải ngân</Name>\n                        <NameVN>Khoản giải ngân</NameVN>\n                        <PosOrder>1</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Type>SubCode</Type>\n                        <AdditionalProperties>\n                           <ID>ApproDoc</ID>\n                           <Name>Evidences of Fund Appropriation</Name>\n                           <NameVN>Bằng chứng chiếm dụng tiền</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>file</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>BAVerify</ID>\n                           <Name>Does bank account number in application (if disbursed to bank transfer) belong to customer?</Name>\n                           <NameVN>Xác nhận STK KH  trên hệ thống (nếu giải ngân qua bank transfer) có phải của KH không?</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>DisbInfo</ID>\n                           <Name>Did customer receive disbursement? How much?</Name>\n                           <NameVN>KH có nhận được khoản giải ngân hay không? KH nhận được bao nhiêu tiền?</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>FundInfo</ID>\n                           <Name>Did customer give money to fraudster? By cash or via bank transfer? Fraudster\'\'s Information?</Name>\n                           <NameVN>KH có chuyển tiền cho đối tượng hay không? Tiền mặt hay chuyển khoản? Thông tin của đối tượng và tài khoản nhận tiền (nếu có)?</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>PhoneVerify</ID>\n                           <Name>Did the customer used phone number on application at the time apply loan? If yes, did the customer share his/her phone for stranger or did not use it for a time?</Name>\n                           <NameVN>KH có đang sử dụng số điện thoại trên hồ sơ tại thời điểm làm hồ sơ không? Nếu có, KH có đưa điện thoại cho ai hay số điện thoại bị gián đoạn không?</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>ProvideInfo</ID>\n                           <Name>Did customer provide ID/document/OTP/Security code to sales/CC or any object? If yes, provide info (name, phone)</Name>\n                           <NameVN>KH có cung cấp giấy tờ/ Mã bảo mât cho nhân viên tư vấn hồ sơ/ đối tượng nào khác không? Nếu có vui lòng cung cấp thông tin (tên, thông tin SĐT)</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>SalesInfo</ID>\n                           <Name>Detailed info about sales staff/CC: name, phone</Name>\n                           <NameVN>Thông tin cụ thể về nhân viên làm hồ sơ/ tư vấn bao gồm: tên, thông tin SĐT</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                     </Children>\n                     <Children>\n                        <ID>CC02-02</ID>\n                        <Name>Sản phẩm CD-TW</Name>\n                        <NameVN>Sản phẩm CD-TW</NameVN>\n                        <PosOrder>1</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Type>SubCode</Type>\n                        <AdditionalProperties>\n                           <ID>ApproDoc</ID>\n                           <Name>Evidences of Fund Appropriation</Name>\n                           <NameVN>Bằng chứng chiếm dụng tiền</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>file</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>GaveMoney</ID>\n                           <Name>Who gave money to customer? Customer received money by cash or via bank transfer? How much?</Name>\n                           <NameVN>KH nhận tiền mặt từ ai? Hình thức nhận bằng tiền mặt hay chuyển khoản? KH nhận được bao nhiêu tiền?</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>PhoneVerify</ID>\n                           <Name>Did the customer used phone number on application at the time apply loan? If yes, did the customer share his/her phone for stranger or did not use it for a time?</Name>\n                           <NameVN>KH có đang sử dụng số điện thoại trên hồ sơ tại thời điểm làm hồ sơ không? Nếu có, KH có đưa điện thoại cho ai hay số điện thoại bị gián đoạn không?</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>ProvideInfo</ID>\n                           <Name>Did customer provide ID/document/OTP/Security code to sales/CC or any object? If yes, provide info (name, phone)</Name>\n                           <NameVN>KH có cung cấp giấy tờ/ Mã bảo mât cho nhân viên tư vấn hồ sơ/ đối tượng nào khác không? Nếu có vui lòng cung cấp thông tin (tên, thông tin SĐT)</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>ReceiveProduct</ID>\n                           <Name>Did customer receive product from POS? If yes, whom customer gave product to? Customer gave product at POS or oustside POS?</Name>\n                           <NameVN>KH có nhận được sản phẩm tại cửa hàng hay không? Nếu có, KH đã giao sản phẩm cho ai? KH giao tại cửa hàng hay ra bên ngoài để đưa?</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>SalesInfo</ID>\n                           <Name>Detailed info about sales staff/CC: name, phone</Name>\n                           <NameVN>Thông tin cụ thể về nhân viên làm hồ sơ/ tư vấn bao gồm: tên, thông tin SĐT</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>WhereApply</ID>\n                           <Name>Where did customer apply? Pos name and address?</Name>\n                           <NameVN>KH làm hồ sơ tại đâu? Tên cửa hàng và địa chỉ cửa hàng?</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                     </Children>\n                     <Children>\n                        <ID>CC02-03</ID>\n                        <Name>Khoản thanh toán</Name>\n                        <NameVN>Khoản thanh toán</NameVN>\n                        <PosOrder>1</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Type>SubCode</Type>\n                        <AdditionalProperties>\n                           <ID>ApproDoc</ID>\n                           <Name>Evidences of Fund Appropriation</Name>\n                           <NameVN>Bằng chứng chiếm dụng tiền</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>file</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>CollAllocate</ID>\n                           <Name>Collection Allocation</Name>\n                           <NameVN>Thông tin nhân viên THN được phân bổ tại thời điểm xảy ra chiếm dụng</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>FundInfo</ID>\n                           <Name>Did customer give money to fraudster? By cash or via bank transfer? Fraudster\'\'s Information?</Name>\n                           <NameVN>KH có chuyển tiền cho đối tượng hay không? Tiền mặt hay chuyển khoản? Thông tin của đối tượng và tài khoản nhận tiền (nếu có)?</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                     </Children>\n                     <Children>\n                        <ID>CC02-04</ID>\n                        <Name>Khoản thanh  lý</Name>\n                        <NameVN>Khoản thanh  lý</NameVN>\n                        <PosOrder>1</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Type>SubCode</Type>\n                        <AdditionalProperties>\n                           <ID>ApproDoc</ID>\n                           <Name>Evidences of Fund Appropriation</Name>\n                           <NameVN>Bằng chứng chiếm dụng tiền</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>file</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>CollAllocate</ID>\n                           <Name>Collection Allocation</Name>\n                           <NameVN>Thông tin nhân viên THN được phân bổ tại thời điểm xảy ra chiếm dụng</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>FundInfo</ID>\n                           <Name>Did customer give money to fraudster? By cash or via bank transfer? Fraudster\'\'s Information?</Name>\n                           <NameVN>KH có chuyển tiền cho đối tượng hay không? Tiền mặt hay chuyển khoản? Thông tin của đối tượng và tài khoản nhận tiền (nếu có)?</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                     </Children>\n                     <Children>\n                        <ID>CC02-05</ID>\n                        <Name>Xe máy thanh lý</Name>\n                        <NameVN>Xe máy thanh lý</NameVN>\n                        <PosOrder>1</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Type>SubCode</Type>\n                        <AdditionalProperties>\n                           <ID>FundInfo2</ID>\n                           <Name>Whom did customer give motobike and fraudster\'\'s information?</Name>\n                           <NameVN>KH đã đưa xe cho ai? Thông tin của đối tượng liên quan?</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>EXISTING</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>ApproDoc</ID>\n                           <Name>Evidences of Fund Appropriation</Name>\n                           <NameVN>Bằng chứng chiếm dụng tiền</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>file</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>CollAllocate</ID>\n                           <Name>Collection Allocation</Name>\n                           <NameVN>Thông tin nhân viên THN được phân bổ tại thời điểm xảy ra chiếm dụng</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                     </Children>\n                     <Children>\n                        <ID>CC02-06</ID>\n                        <Name>Khoản giải ngân_IPP</Name>\n                        <NameVN>Khoản giải ngân_IPP</NameVN>\n                        <PosOrder>1</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Type>SubCode</Type>\n                        <AdditionalProperties>\n                           <ID>AccountNumber</ID>\n                           <Name>Account Number</Name>\n                           <NameVN>Số Tài Khoản của Khách hàng</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>ApproDoc</ID>\n                           <Name>Evidences of Fund Appropriation</Name>\n                           <NameVN>Bằng chứng chiếm dụng tiền</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>false</Mandatory>\n                           <Type>file</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>AprovalCodes</ID>\n                           <Name>Approval code</Name>\n                           <NameVN>Mã Chuẩn chi của giao dịch khiếu nại</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>multi</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>DisbInfo</ID>\n                           <Name>Did customer receive disbursement? How much?</Name>\n                           <NameVN>KH có nhận được khoản giải ngân hay không? KH nhận được bao nhiêu tiền?</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>FundInfo</ID>\n                           <Name>Did customer give money to fraudster? By cash or via bank transfer? Fraudster\'\'s Information?</Name>\n                           <NameVN>KH có chuyển tiền cho đối tượng hay không? Tiền mặt hay chuyển khoản? Thông tin của đối tượng và tài khoản nhận tiền (nếu có)?</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>ProvideInfo</ID>\n                           <Name>Did customer provide ID/document/OTP/Security code to sales/CC or any object? If yes, provide info (name, phone)</Name>\n                           <NameVN>KH có cung cấp giấy tờ/ Mã bảo mât cho nhân viên tư vấn hồ sơ/ đối tượng nào khác không? Nếu có vui lòng cung cấp thông tin (tên, thông tin SĐT)</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>Siminfo</ID>\n                           <Name>Thời điểm giao dịch phát sinh khách hàng có bị mất sim/ hư sim/hack sim hay không</Name>\n                           <NameVN>Thời điểm giao dịch phát sinh khách hàng có bị mất sim/ hư sim/hack sim hay không</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                     </Children>\n                     <Children>\n                        <ID>CC02-07</ID>\n                        <Name>BH Sức khỏe</Name>\n                        <NameVN>BH Sức khỏe</NameVN>\n                        <PosOrder>1</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Type>SubCode</Type>\n                        <AdditionalProperties>\n                           <ID>ApproDoc</ID>\n                           <Name>Evidences of Fund Appropriation</Name>\n                           <NameVN>Bằng chứng chiếm dụng tiền</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>file</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>FundInfo</ID>\n                           <Name>Did customer give money to fraudster? By cash or via bank transfer? Fraudster\'\'s Information?</Name>\n                           <NameVN>KH có chuyển tiền cho đối tượng hay không? Tiền mặt hay chuyển khoản? Thông tin của đối tượng và tài khoản nhận tiền (nếu có)?</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>ALL</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                     </Children>\n                     <Children>\n                        <ID>CC02-08</ID>\n                        <Name>Khoản giải ngân_ACL</Name>\n                        <NameVN>Khoản giải ngân_ACL</NameVN>\n                        <PosOrder>1</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Type>SubCode</Type>\n                        <AdditionalProperties>\n                           <ID>AccountNumber</ID>\n                           <Name>Account Number</Name>\n                           <NameVN>Số Tài Khoản của Khách hàng</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>EXISTING</ApplyTo>\n                           <Mandatory>false</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>ACLQuestion</ID>\n                           <Name>(Tại thời điểm phát sinh khoản ACL) KH có đăng ký khoản vay Loan và nhận giải ngân không? Số tiền giải ngân nhận được bao nhiêu?</Name>\n                           <NameVN>(Tại thời điểm phát sinh khoản ACL) KH có đăng ký khoản vay Loan và nhận giải ngân không? Số tiền giải ngân nhận được bao nhiêu?</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>EXISTING</ApplyTo>\n                           <Mandatory>false</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID';
    }

    private static String xmlPart5() {
        return '>ApproDoc</ID>\n                           <Name>Evidences of Fund Appropriation</Name>\n                           <NameVN>Bằng chứng chiếm dụng tiền</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>EXISTING</ApplyTo>\n                           <Mandatory>false</Mandatory>\n                           <Type>file</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>Card_number</ID>\n                           <Name>Credit card number</Name>\n                           <NameVN>số thẻ</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>EXISTING</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>CusName</ID>\n                           <Name>Họ tên KH</Name>\n                           <NameVN>Customer name</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>EXISTING</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>GaveCard</ID>\n                           <Name>Khách hàng có từng đưa thẻ cho ai hoặc đọc/ chụp hình thông tin OTP/ thẻ (2 mặt thẻ) của mình cho người khác không</Name>\n                           <NameVN>Khách hàng có từng đưa thẻ cho ai hoặc đọc/ chụp hình thông tin OTP/ thẻ (2 mặt thẻ) của mình cho người khác không</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>EXISTING</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>Howtoknow</ID>\n                           <Name>Khách hàng biết được giao dịch gian lận của mình bằng cách nào</Name>\n                           <NameVN>Khách hàng biết được giao dịch gian lận của mình bằng cách nào</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>EXISTING</ApplyTo>\n                           <Mandatory>false</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>ProvideInfo</ID>\n                           <Name>Did customer provide ID/document/OTP/Security code to sales/CC or any object? If yes, provide info (name, phone)</Name>\n                           <NameVN>KH có cung cấp giấy tờ/ Mã bảo mât cho nhân viên tư vấn hồ sơ/ đối tượng nào khác không? Nếu có vui lòng cung cấp thông tin (tên, thông tin SĐT)</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>EXISTING</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>Siminfo</ID>\n                           <Name>Thời điểm giao dịch phát sinh khách hàng có bị mất sim/ hư sim/hack sim hay không</Name>\n                           <NameVN>Thời điểm giao dịch phát sinh khách hàng có bị mất sim/ hư sim/hack sim hay không</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>EXISTING</ApplyTo>\n                           <Mandatory>true</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                        <AdditionalProperties>\n                           <ID>Transaction_code</ID>\n                           <Name>mã chuẩn chi của giao dịch khiếu nại</Name>\n                           <NameVN>mã chuẩn chi của giao dịch khiếu nại</NameVN>\n                           <PosOrder>100</PosOrder>\n                           <ApplyTo>EXISTING</ApplyTo>\n                           <Mandatory>false</Mandatory>\n                           <Type>string</Type>\n                        </AdditionalProperties>\n                     </Children>\n                  </Children>\n                  <Children>\n                     <ID>CC03</ID>\n                     <Name>KH bị yêu cầu tiền phí</Name>\n                     <NameVN>KH bị yêu cầu tiền phí</NameVN>\n                     <PosOrder>1</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n                     <Type>SubCategory</Type>\n                     <AdditionalProperties>\n                        <ID>AppIDs</ID>\n                        <Name>App IDs</Name>\n                        <NameVN>App IDs</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>false</Mandatory>\n                        <Type>multi</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>ApproDate</ID>\n                        <Name>Date of Appropriation</Name>\n                        <NameVN>Ngày xảy ra chiếm dụng</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>date</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>ApproDoc</ID>\n                        <Name>Evidences of Fund Appropriation</Name>\n                        <NameVN>Bằng chứng chiếm dụng tiền</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>file</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>ContractNumbers</ID>\n                        <Name>Contract Numbers</Name>\n                        <NameVN>Các khoản vay</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>false</Mandatory>\n                        <Type>multi</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>FundInfo</ID>\n                        <Name>Did customer give money to fraudster? By cash or via bank transfer? Fraudster\'\'s Information?</Name>\n                        <NameVN>KH có chuyển tiền cho đối tượng hay không? Tiền mặt hay chuyển khoản? Thông tin của đối tượng và tài khoản nhận tiền (nếu có)?</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>LossAmt</ID>\n                        <Name>Loss Amount</Name>\n                        <NameVN>Số tiền bị chiếm dụng</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>number</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>NationalIDs</ID>\n                        <Name>National IDs</Name>\n                        <NameVN>Danh sách CMND</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>multi</Type>\n                     </AdditionalProperties>\n                  </Children>\n                  <Children>\n                     <ID>CC04</ID>\n                     <Name>KH yêu cầu gỡ Blacklist</Name>\n                     <NameVN>KH yêu cầu gỡ Blacklist</NameVN>\n                     <PosOrder>1</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n                     <Type>SubCategory</Type>\n                     <AdditionalProperties>\n                        <ID>AppIDs</ID>\n                        <Name>App IDs</Name>\n                        <NameVN>App IDs</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>multi</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>ContractNumbers</ID>\n                        <Name>Contract Numbers</Name>\n                        <NameVN>Các khoản vay</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>false</Mandatory>\n                        <Type>multi</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>NationalIDs</ID>\n                        <Name>National IDs</Name>\n                        <NameVN>Danh sách CMND</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>multi</Type>\n                     </AdditionalProperties>\n                  </Children>\n                  <Children>\n                     <ID>CC05</ID>\n                     <Name>Rò rỉ thông tin</Name>\n                     <NameVN>Rò rỉ thông tin</NameVN>\n                     <PosOrder>1</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n                     <Type>SubCategory</Type>\n                     <AdditionalProperties>\n                        <ID>Event_date</ID>\n                        <Name>Event Date</Name>\n                        <NameVN>Ngày xảy ra sự kiện</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>EXISTING</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>date</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>Leak_comp_contact</ID>\n                        <Name>Company name contact customer</Name>\n                        <NameVN>Đơn vị tài chính liên hệ đến KH</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>EXISTING</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>Leak_question</ID>\n                        <Name>Do customer have loan with another bank at time having phone call</Name>\n                        <NameVN>Tại thời điểm đối tượng liên hệ, KH có vay ở đơn vị tài chính khác</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>EXISTING</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>NationalID</ID>\n                        <Name>National ID</Name>\n                        <NameVN>National ID</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>EXISTING</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>SuspectInformation</ID>\n                        <Name>Thông tin đối tượng tư vấn/ liên hệ với khách hàng</Name>\n                        <NameVN>Thông tin đối tượng tư vấn/ liên hệ với khách hàng</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>EXISTING</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>AppID</ID>\n                        <Name>App ID</Name>\n                        <NameVN>App ID</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>EXISTING</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>App_status</ID>\n                        <Name>FEC Application status</Name>\n                        <NameVN>Trạng thái hồ sơ KH tại FE</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>EXISTING</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CusName</ID>\n                        <Name>Họ tên KH</Name>\n                        <NameVN>Customer name</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>EXISTING</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CustomerReport</ID>\n                        <Name>Nội dung khách hàng phản ánh</Name>\n                        <NameVN>Nội dung khách hàng phản ánh</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>EXISTING</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                  </Children>\n                  <Children>\n                     <ID>Wrong consultant</ID>\n                     <Name>Nhân viên tư vấn sai thông tin</Name>\n                     <NameVN>Nhân viên tư vấn sai thông tin</NameVN>\n                     <PosOrder>1</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n                     <Type>SubCategory</Type>\n                     <AdditionalProperties>\n                        <ID>AppIDs</ID>\n                        <Name>App IDs</Name>\n                        <NameVN>App IDs</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>multi</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>ContractNumbers</ID>\n                        <Name>Contract Numbers</Name>\n                        <NameVN>Các khoản vay</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>multi</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>NationalIDs</ID>\n                        <Name>National IDs</Name>\n                        <NameVN>Danh sách CMND</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>multi</Type>\n                     </AdditionalProperties>\n                  </Children>\n               </Children>\n            </Children>\n         </MasterDataItems>\n         <MasterDataItems>\n            <ID>Card</ID>\n            <Name>Card Transaction</Name>\n            <NameVN>Card Transaction</NameVN>\n            <PosOrder>12</PosOrder>\n            <ApplyTo>ALL</ApplyTo>\n            <Type>Product</Type>\n            <AdditionalProperties>\n               <ID>AccountNumber</ID>\n               <Name>Account Number</Name>\n               <NameVN>Số Tài Khoản của Khách hàng</NameVN>\n               <PosOrder>100</PosOrder>\n               <ApplyTo>EXISTING</ApplyTo>\n               <Mandatory>true</Mandatory>\n               <Type>string</Type>\n            </AdditionalProperties>\n            <AdditionalProperties>\n               <ID>AprovalCodes</ID>\n               <Name>Approval code</Name>\n               <NameVN>Mã Chuẩn chi của giao dịch khiếu nại</NameVN>\n               <PosOrder>100</PosOrder>\n               <ApplyTo>EXISTING</ApplyTo>\n               <Mandatory>true</Mandatory>\n               <Type>multi</Type>\n            </AdditionalProperties>\n            <AdditionalProperties>\n               <ID>NationalID</ID>\n               <Name>National ID</Name>\n               <NameVN>National ID</NameVN>\n               <PosOrder>100</PosOrder>\n               <ApplyTo>EXISTING</ApplyTo>\n               <Mandatory>false</Mandatory>\n               <Type>string</Type>\n            </AdditionalProperties>\n            <AdditionalProperties>\n               <ID>ReferenceID</ID>\n               <Name>ReferenceID</Name>\n               <NameVN>ReferenceID</NameVN>\n               <PosOrder>100</PosOrder>\n               <ApplyTo>ALL</ApplyTo>\n               <Mandatory>false</Mandatory>\n               <Type>string</Type>\n            </AdditionalProperties>\n            <Children>\n               <ID>FECredit_OP_Work_FraudHandling</ID>\n               <Name>FraudHandling</Name>\n               <NameVN>FraudHandling</NameVN>\n               <PosOrder>100</PosOrder>\n               <ApplyTo>ALL</ApplyTo>\n               <Type>CaseType</Type>\n               <Children>\n                  <ID>FraudTransaction</ID>\n                  <Name>Fraud Transaction</Name>\n                  <NameVN>Fraud Transaction</NameVN>\n                  <PosOrder>1</PosOrder>\n                  <ApplyTo>ALL</ApplyTo>\n                  <Type>Category</Type>\n                  <Children>\n                     <ID>HackSim</ID>\n                     <Name>Hack Sim</Name>\n                     <NameVN>Hack Sim</NameVN>\n                     <PosOrder>1</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n                     <Type>SubCategory</Type>\n                     <AdditionalProperties>\n                        <ID>sim_info</ID>\n                        <Name>do customer lost sim/sim error/ hack sim during transaction time</Name>\n                        <NameVN>Thời điểm giao dịch phát sinh khách hàng có bị mất sim/ hư sim/hack sim hay không</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>EXISTING</ApplyTo>\n                        <Mandatory>false</Mandatory>\n                        <Type>boolean</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>AppID</ID>\n                        <Name>App ID</Name>\n                        <NameVN>App ID</NameVN>\n                        <PosOrder>1</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CustomerReport</ID>\n                        <Name>Nội dung khách hàng phản ánh</Name>\n                        <NameVN>Nội dung khách hàng phản ánh</NameVN>\n                        <PosOrder>2</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>SuspectInformation</ID>\n                        <Name>Thông tin đối tượng tư vấn/ liên hệ với khách hàng</Name>\n                        <NameVN>Thông tin đối tượng tư vấn/ liên hệ với khách hàng</NameVN>\n                        <PosOrder>3</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_CUS_MOB</ID>\n                        <Name>CF_CUS MOB</Name>\n                        <NameVN>Số điện thoại trên CMS có phải là của khách hàng không</NameVN>\n                        <PosOrder>5</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>NO</ID>\n                           <Name>KHÔNG</Name>\n                           <NameVN>KHÔNG</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>YES</ID>\n                           <Name>CÓ</Name>\n                           <NameVN>CÓ</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_CardKeep</ID>\n                        <Name>CF_CardKeep</Name>\n                        <NameVN>Khách hàng còn giữ thẻ lúc giao dịch phát sinh hay không</NameVN>\n                        <PosOrder>6</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>NO</ID>\n                           <Name>KHÔNG</Name>\n                           <NameVN>KHÔNG</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>YES</ID>\n                           <Name>CÓ</Name>\n                           <NameVN>CÓ</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_HowToKnow</ID>\n                        <Name>CF_HowToKnow</Name>\n                        <NameVN>Khách hàng biết được giao dịch gian lận của mình bằng cách nào</NameVN>\n                        <PosOrder>7</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>COL</ID>\n                           <Name>Thu hồi nợ</Name>\n                           <NameVN>Thu hồi nợ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>OTH</ID>\n                           <Name>OTHER</Name>\n                           <NameVN>OTHER</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>SMS</ID>\n                           <Name>Tin Nhắn</Name>\n                           <NameVN>Tin Nhắn</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>STA</ID>\n                           <Name>Sao Kê</Name>\n                           <NameVN>Sao Kê</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_ReasonOTP</ID>\n                        <Name>CF_ReasonOTP</Name>\n                        <NameVN>Lý do khách hàng cung cấp OTP/thông tin thẻ (2 mặt thẻ)/ chụp hình thẻ</NameVN>\n                        <PosOrder>9</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>F01</ID>\n                           <Name>Nhân viên gọi tư vấn thu hồi thẻ</Name>\n                           <NameVN>Nhân viên gọi tư vấn thu hồi thẻ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F02</ID>\n                           <Name>Nhân viên tư vấn rút tiền mặt</Name>\n                           <NameVN>Nhân viên tư vấn rút tiền';
    }

    private static String xmlPart6() {
        return ' mặt</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F03</ID>\n                           <Name>Nhân viên tư vấn chuyển đổi trả góp</Name>\n                           <NameVN>Nhân viên tư vấn chuyển đổi trả góp</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F04</ID>\n                           <Name>Nhân viên tư vấn gọi đến hỗ trợ hủy thẻ</Name>\n                           <NameVN>Nhân viên tư vấn gọi đến hỗ trợ hủy thẻ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F05</ID>\n                           <Name>Nhân viên hỗ trợ kiểm tra tài khoản/Kiểm tra số dư</Name>\n                           <NameVN>Nhân viên hỗ trợ kiểm tra tài khoản/Kiểm tra số dư</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F06</ID>\n                           <Name>Nhân viên tư vấn đáo hạn</Name>\n                           <NameVN>Nhân viên tư vấn đáo hạn</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F07</ID>\n                           <Name>Nhân viên tư vấn hủy bảo hiểm</Name>\n                           <NameVN>Nhân viên tư vấn hủy bảo hiểm</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F08</ID>\n                           <Name>Nhân viên tư vấn về phí thường niên</Name>\n                           <NameVN>Nhân viên tư vấn về phí thường niên</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F09</ID>\n                           <Name>Nhân viên tư vấn nhận thẻ cào/chương trình khuyến mãi/trúng thưởng</Name>\n                           <NameVN>Nhân viên tư vấn nhận thẻ cào/chương trình khuyến mãi/trúng thưởng</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F10</ID>\n                           <Name>Gia hạn thẻ</Name>\n                           <NameVN>Gia hạn thẻ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F11</ID>\n                           <Name>Nhân viên tư vấn để không bị gọi nhắc nợ</Name>\n                           <NameVN>Nhân viên tư vấn để không bị gọi nhắc nợ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F12</ID>\n                           <Name>Hỗ trợ kích hoạt thẻ</Name>\n                           <NameVN>Hỗ trợ kích hoạt thẻ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F13</ID>\n                           <Name>Rút tiền dư trong thẻ</Name>\n                           <NameVN>Rút tiền dư trong thẻ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>NULL</ID>\n                           <Name>Không có</Name>\n                           <NameVN>Không có</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_CardInfoShare</ID>\n                        <Name>CF_CardInfoShare</Name>\n                        <NameVN>Khách hàng có từng đưa thẻ cho ai hoặc đọc/ chụp hình thông tin OTP/ thẻ (2 mặt thẻ) của mình cho người khác không</NameVN>\n                        <PosOrder>9</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>NO</ID>\n                           <Name>KHÔNG</Name>\n                           <NameVN>KHÔNG</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>YES</ID>\n                           <Name>CÓ</Name>\n                           <NameVN>CÓ</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_CashReceive</ID>\n                        <Name>CF_CashReceive</Name>\n                        <NameVN>Nếu có người tư vấn rút tiền/vay/trả góp khách hàng có nhận được tiền hay không</NameVN>\n                        <PosOrder>12</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>NO</ID>\n                           <Name>KHÔNG</Name>\n                           <NameVN>KHÔNG</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>YES</ID>\n                           <Name>CÓ</Name>\n                           <NameVN>CÓ</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_ReceiveAmount</ID>\n                        <Name>CF_ReceiveAmount</Name>\n                        <NameVN>Số tiền khách hàng nhận được</NameVN>\n                        <PosOrder>13</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>number</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_ReceiveMethod</ID>\n                        <Name>CF_ReceiveMethod</Name>\n                        <NameVN>Cách thức KH nhận tiền</NameVN>\n                        <PosOrder>14</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>BT</ID>\n                           <Name>Chuyển khoản</Name>\n                           <NameVN>Chuyển khoản</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>DMX</ID>\n                           <Name>Điện máy xanh</Name>\n                           <NameVN>Điện máy xanh</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>NUL</ID>\n                           <Name>Không có</Name>\n                           <NameVN>Không có</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>TGD</ID>\n                           <Name>Thế giới di động</Name>\n                           <NameVN>Thế giới di động</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>VNP</ID>\n                           <Name>VNPOST</Name>\n                           <NameVN>VNPOST</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>VT</ID>\n                           <Name>Viettel</Name>\n                           <NameVN>Viettel</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                  </Children>\n                  <Children>\n                     <ID>NoCashReceive</ID>\n                     <Name>OTP Compromised_No need feedback</Name>\n                     <NameVN>OTP Compromised_No need feedback</NameVN>\n                     <PosOrder>1</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n                     <Type>SubCategory</Type>\n                     <AdditionalProperties>\n                        <ID>AppID</ID>\n                        <Name>App ID</Name>\n                        <NameVN>App ID</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>EXISTING</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>Receive_enough_money</ID>\n                        <Name>Does the customer receive enough money?</Name>\n                        <NameVN>Khách hàng có nhận đủ tiền không?</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>EXISTING</ApplyTo>\n                        <Mandatory>false</Mandatory>\n                        <Type>boolean</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CustomerReport</ID>\n                        <Name>Nội dung khách hàng phản ánh</Name>\n                        <NameVN>Nội dung khách hàng phản ánh</NameVN>\n                        <PosOrder>1</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_CardInfoShare</ID>\n                        <Name>CF_CardInfoShare</Name>\n                        <NameVN>Khách hàng có từng đưa thẻ cho ai hoặc đọc/ chụp hình thông tin OTP/ thẻ (2 mặt thẻ) của mình cho người khác không</NameVN>\n                        <PosOrder>5</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>false</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>NO</ID>\n                           <Name>KHÔNG</Name>\n                           <NameVN>KHÔNG</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>YES</ID>\n                           <Name>CÓ</Name>\n                           <NameVN>CÓ</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_ReceiveAmount</ID>\n                        <Name>CF_ReceiveAmount</Name>\n                        <NameVN>Số tiền khách hàng nhận được</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>false</Mandatory>\n                        <Type>number</Type>\n                     </AdditionalProperties>\n                  </Children>\n                  <Children>\n                     <ID>Non3DS</ID>\n                     <Name>No OTP Transactions</Name>\n                     <NameVN>No OTP Transactions</NameVN>\n                     <PosOrder>1</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n                     <Type>SubCategory</Type>\n                     <AdditionalProperties>\n                        <ID>CustomerReport</ID>\n                        <Name>Nội dung khách hàng phản ánh</Name>\n                        <NameVN>Nội dung khách hàng phản ánh</NameVN>\n                        <PosOrder>1</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>SuspectInformation</ID>\n                        <Name>Thông tin đối tượng tư vấn/ liên hệ với khách hàng</Name>\n                        <NameVN>Thông tin đối tượng tư vấn/ liên hệ với khách hàng</NameVN>\n                        <PosOrder>2</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>AppID</ID>\n                        <Name>App ID</Name>\n                        <NameVN>App ID</NameVN>\n                        <PosOrder>4</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_CUS_MOB</ID>\n                        <Name>CF_CUS MOB</Name>\n                        <NameVN>Số điện thoại trên CMS có phải là của khách hàng không</NameVN>\n                        <PosOrder>5</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>NO</ID>\n                           <Name>KHÔNG</Name>\n                           <NameVN>KHÔNG</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>YES</ID>\n                           <Name>CÓ</Name>\n                           <NameVN>CÓ</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_CardKeep</ID>\n                        <Name>CF_CardKeep</Name>\n                        <NameVN>Khách hàng còn giữ thẻ lúc giao dịch phát sinh hay không</NameVN>\n                        <PosOrder>6</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>NO</ID>\n                           <Name>KHÔNG</Name>\n                           <NameVN>KHÔNG</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>YES</ID>\n                           <Name>CÓ</Name>\n                           <NameVN>CÓ</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_HowToKnow</ID>\n                        <Name>CF_HowToKnow</Name>\n                        <NameVN>Khách hàng biết được giao dịch gian lận của mình bằng cách nào</NameVN>\n                        <PosOrder>7</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>COL</ID>\n                           <Name>Thu hồi nợ</Name>\n                           <NameVN>Thu hồi nợ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>OTH</ID>\n                           <Name>OTHER</Name>\n                           <NameVN>OTHER</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>SMS</ID>\n                           <Name>Tin Nhắn</Name>\n                           <NameVN>Tin Nhắn</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>STA</ID>\n                           <Name>Sao Kê</Name>\n                           <NameVN>Sao Kê</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_CardInfoShare</ID>\n                        <Name>CF_CardInfoShare</Name>\n                        <NameVN>Khách hàng có từng đưa thẻ cho ai hoặc đọc/ chụp hình thông tin OTP/ thẻ (2 mặt thẻ) của mình cho người khác không</NameVN>\n                        <PosOrder>9</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>NO</ID>\n                           <Name>KHÔNG</Name>\n                           <NameVN>KHÔNG</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>YES</ID>\n                           <Name>CÓ</Name>\n                           <NameVN>CÓ</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_ReasonOTP</ID>\n                        <Name>CF_ReasonOTP</Name>\n                        <NameVN>Lý do khách hàng cung cấp OTP/thông tin thẻ (2 mặt thẻ)/ chụp hình thẻ</NameVN>\n                        <PosOrder>10</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>F01</ID>\n                           <Name>Nhân viên gọi tư vấn thu hồi thẻ</Name>\n                           <NameVN>Nhân viên gọi tư vấn thu hồi thẻ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F02</ID>\n                           <Name>Nhân viên tư vấn rút tiền mặt</Name>\n                           <NameVN>Nhân viên tư vấn rút tiền mặt</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F03</ID>\n                           <Name>Nhân viên tư vấn chuyển đổi trả góp</Name>\n                           <NameVN>Nhân viên tư vấn chuyển đổi trả góp</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F04</ID>\n                           <Name>Nhân viên tư vấn gọi đến hỗ trợ hủy thẻ</Name>\n                           <NameVN>Nhân viên tư vấn gọi đến hỗ trợ hủy thẻ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F05</ID>\n                           <Name>Nhân viên hỗ trợ kiểm tra tài khoản/Kiểm tra số dư</Name>\n                           <NameVN>Nhân viên hỗ trợ kiểm tra tài khoản/Kiểm tra số dư</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F06</ID>\n                           <Name>Nhân viên tư vấn đáo hạn</Name>\n                           <NameVN>Nhân viên tư vấn đáo hạn</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F07</ID>\n                           <Name>Nhân viên tư vấn hủy bảo hiểm</Name>\n                           <NameVN>Nhân viên tư vấn hủy bảo hiểm</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F08</ID>\n                           <Name>Nhân viên tư vấn về phí thường niên</Name>\n                           <NameVN>Nhân viên tư vấn về phí thường niên</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F09</ID>\n                           <Name>Nhân viên tư vấn nhận thẻ cào/chương trình khuyến mãi/trúng thưởng</Name>\n                           <NameVN>Nhân viên tư vấn nhận thẻ cào/chương trình khuyến mãi/trúng thưởng</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F10</ID>\n                           <Name>Gia hạn thẻ</Name>\n                           <NameVN>Gia hạn thẻ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F11</ID>\n                           <Name>Nhân viên tư vấn để không bị gọi nhắc nợ</Name>\n                           <NameVN>Nhân viên tư vấn để không bị gọi nhắc nợ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F12</ID>\n                           <Name>Hỗ trợ kích hoạt thẻ</Name>\n                           <NameVN>Hỗ trợ kích hoạt thẻ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F13</ID>\n                           <Name>Rút tiền dư trong thẻ</Name>\n                           <NameVN>Rút tiền dư trong thẻ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>NULL</ID>\n                           <Name>Không có</Name>\n                           <NameVN>Không có</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_ReceiveAmount</ID>\n                        <Name>CF_ReceiveAmount</Name>\n                        <NameVN>Số tiền khách hàng nhận được</NameVN>\n                        <PosOrder>13</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>number</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_ReceiveMethod</ID>\n                        <Name>CF_ReceiveMethod</Name>\n                        <NameVN>Cách thức KH nhận tiền</NameVN>\n                        <PosOrder>14</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>BT</ID>\n                           <Name>Chuyển khoản</Name>\n                           <NameVN>Chuyển khoản</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>DMX</ID>\n                           <Name>Điện máy xanh</Name>\n                           <NameVN>Điện máy xanh</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>NUL</ID>\n                           <Name>Không có</Name>\n                           <NameVN>Không có</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>TGD</ID>\n                           <Name>Thế giới di động</Name>\n                           <NameVN>Thế giới di động</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>VNP</ID>\n                           <Name>VNPOST</Name>\n                           <NameVN>VNPOST</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>VT</ID>\n                           <Name>Viettel</Name>\n                           <NameVN>Viettel</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_SIM_LOST</ID>\n                        <Name>CF_SIM LOST</Name>\n                        <NameVN>Thời điểm giao dịch phát sinh khách hàng có bị hack sim hay không</NameVN>\n                        <PosOrder>100</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>NO</ID>\n                           <Name>KHÔNG</Name>\n                           <NameVN>KHÔNG</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>YES</ID>\n                           <Name>CÓ</Name>\n                           <NameVN>CÓ</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                  </Children>\n                  <Children>\n                     <ID>NotReceivedEnough</ID>\n                     <Name>OTP Compromised_Need CF feedback</Name>\n                     <NameVN>OTP Compromised_Need CF feedback</NameVN>\n                     <PosOrder>1</PosOrder>\n                     <ApplyTo>ALL</ApplyTo>\n               ';
    }

    private static String xmlPart7() {
        return '      <Type>SubCategory</Type>\n                     <AdditionalProperties>\n                        <ID>CustomerReport</ID>\n                        <Name>Nội dung khách hàng phản ánh</Name>\n                        <NameVN>Nội dung khách hàng phản ánh</NameVN>\n                        <PosOrder>1</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>SuspectInformation</ID>\n                        <Name>Thông tin đối tượng tư vấn/ liên hệ với khách hàng</Name>\n                        <NameVN>Thông tin đối tượng tư vấn/ liên hệ với khách hàng</NameVN>\n                        <PosOrder>2</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>AppID</ID>\n                        <Name>App ID</Name>\n                        <NameVN>App ID</NameVN>\n                        <PosOrder>4</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>string</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_CUS_MOB</ID>\n                        <Name>CF_CUS MOB</Name>\n                        <NameVN>Số điện thoại trên CMS có phải là của khách hàng không</NameVN>\n                        <PosOrder>5</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>NO</ID>\n                           <Name>KHÔNG</Name>\n                           <NameVN>KHÔNG</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>YES</ID>\n                           <Name>CÓ</Name>\n                           <NameVN>CÓ</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_CardKeep</ID>\n                        <Name>CF_CardKeep</Name>\n                        <NameVN>Khách hàng còn giữ thẻ lúc giao dịch phát sinh hay không</NameVN>\n                        <PosOrder>6</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>NO</ID>\n                           <Name>KHÔNG</Name>\n                           <NameVN>KHÔNG</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>YES</ID>\n                           <Name>CÓ</Name>\n                           <NameVN>CÓ</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_HowToKnow</ID>\n                        <Name>CF_HowToKnow</Name>\n                        <NameVN>Khách hàng biết được giao dịch gian lận của mình bằng cách nào</NameVN>\n                        <PosOrder>7</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>COL</ID>\n                           <Name>Thu hồi nợ</Name>\n                           <NameVN>Thu hồi nợ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>OTH</ID>\n                           <Name>OTHER</Name>\n                           <NameVN>OTHER</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>SMS</ID>\n                           <Name>Tin Nhắn</Name>\n                           <NameVN>Tin Nhắn</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>STA</ID>\n                           <Name>Sao Kê</Name>\n                           <NameVN>Sao Kê</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_CardInfoShare</ID>\n                        <Name>CF_CardInfoShare</Name>\n                        <NameVN>Khách hàng có từng đưa thẻ cho ai hoặc đọc/ chụp hình thông tin OTP/ thẻ (2 mặt thẻ) của mình cho người khác không</NameVN>\n                        <PosOrder>9</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>false</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>NO</ID>\n                           <Name>KHÔNG</Name>\n                           <NameVN>KHÔNG</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>YES</ID>\n                           <Name>CÓ</Name>\n                           <NameVN>CÓ</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_ReasonOTP</ID>\n                        <Name>CF_ReasonOTP</Name>\n                        <NameVN>Lý do khách hàng cung cấp OTP/thông tin thẻ (2 mặt thẻ)/ chụp hình thẻ</NameVN>\n                        <PosOrder>10</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>F01</ID>\n                           <Name>Nhân viên gọi tư vấn thu hồi thẻ</Name>\n                           <NameVN>Nhân viên gọi tư vấn thu hồi thẻ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F02</ID>\n                           <Name>Nhân viên tư vấn rút tiền mặt</Name>\n                           <NameVN>Nhân viên tư vấn rút tiền mặt</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F03</ID>\n                           <Name>Nhân viên tư vấn chuyển đổi trả góp</Name>\n                           <NameVN>Nhân viên tư vấn chuyển đổi trả góp</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F04</ID>\n                           <Name>Nhân viên tư vấn gọi đến hỗ trợ hủy thẻ</Name>\n                           <NameVN>Nhân viên tư vấn gọi đến hỗ trợ hủy thẻ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F05</ID>\n                           <Name>Nhân viên hỗ trợ kiểm tra tài khoản/Kiểm tra số dư</Name>\n                           <NameVN>Nhân viên hỗ trợ kiểm tra tài khoản/Kiểm tra số dư</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F06</ID>\n                           <Name>Nhân viên tư vấn đáo hạn</Name>\n                           <NameVN>Nhân viên tư vấn đáo hạn</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F07</ID>\n                           <Name>Nhân viên tư vấn hủy bảo hiểm</Name>\n                           <NameVN>Nhân viên tư vấn hủy bảo hiểm</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F08</ID>\n                           <Name>Nhân viên tư vấn về phí thường niên</Name>\n                           <NameVN>Nhân viên tư vấn về phí thường niên</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F09</ID>\n                           <Name>Nhân viên tư vấn nhận thẻ cào/chương trình khuyến mãi/trúng thưởng</Name>\n                           <NameVN>Nhân viên tư vấn nhận thẻ cào/chương trình khuyến mãi/trúng thưởng</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F10</ID>\n                           <Name>Gia hạn thẻ</Name>\n                           <NameVN>Gia hạn thẻ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F11</ID>\n                           <Name>Nhân viên tư vấn để không bị gọi nhắc nợ</Name>\n                           <NameVN>Nhân viên tư vấn để không bị gọi nhắc nợ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F12</ID>\n                           <Name>Hỗ trợ kích hoạt thẻ</Name>\n                           <NameVN>Hỗ trợ kích hoạt thẻ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>F13</ID>\n                           <Name>Rút tiền dư trong thẻ</Name>\n                           <NameVN>Rút tiền dư trong thẻ</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>NULL</ID>\n                           <Name>Không có</Name>\n                           <NameVN>Không có</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_CashReceive</ID>\n                        <Name>CF_CashReceive</Name>\n                        <NameVN>Nếu có người tư vấn rút tiền/vay/trả góp khách hàng có nhận được tiền hay không</NameVN>\n                        <PosOrder>12</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>NO</ID>\n                           <Name>KHÔNG</Name>\n                           <NameVN>KHÔNG</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>YES</ID>\n                           <Name>CÓ</Name>\n                           <NameVN>CÓ</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_ReceiveAmount</ID>\n                        <Name>CF_ReceiveAmount</Name>\n                        <NameVN>Số tiền khách hàng nhận được</NameVN>\n                        <PosOrder>13</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>number</Type>\n                     </AdditionalProperties>\n                     <AdditionalProperties>\n                        <ID>CF_ReceiveMethod</ID>\n                        <Name>CF_ReceiveMethod</Name>\n                        <NameVN>Cách thức KH nhận tiền</NameVN>\n                        <PosOrder>14</PosOrder>\n                        <ApplyTo>ALL</ApplyTo>\n                        <Mandatory>true</Mandatory>\n                        <Type>list</Type>\n                        <AvailableValues>\n                           <ID>BT</ID>\n                           <Name>Chuyển khoản</Name>\n                           <NameVN>Chuyển khoản</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>DMX</ID>\n                           <Name>Điện máy xanh</Name>\n                           <NameVN>Điện máy xanh</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>NUL</ID>\n                           <Name>Không có</Name>\n                           <NameVN>Không có</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>TGD</ID>\n                           <Name>Thế giới di động</Name>\n                           <NameVN>Thế giới di động</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>VNP</ID>\n                           <Name>VNPOST</Name>\n                           <NameVN>VNPOST</NameVN>\n                        </AvailableValues>\n                        <AvailableValues>\n                           <ID>VT</ID>\n                           <Name>Viettel</Name>\n                           <NameVN>Viettel</NameVN>\n                        </AvailableValues>\n                     </AdditionalProperties>\n                  </Children>\n               </Children>\n            </Children>\n         </MasterDataItems>\n         <Sys>\n            <TransactionID>2cc1685d-3545-4322-8956-e9b7af1b35c8</TransactionID>\n            <DateTime>2025-11-06T06:46:30.0342034Z</DateTime>\n            <Code>1</Code>\n            <Description>Success</Description>\n         </Sys>\n      </GetFraudMasterDataResponse>\n   </s:Body>\n</s:Envelope>';
    }

    public static Integer syncMasterDataIntegration() {
        String integrationChannelId = getIntegrationChannelCode('FIMA');
        // 1) Load ALL existing mapping records into a map for upsert comparison
        Map<String, FEC_Master_Data_Integration__c> existingMap = loadExisting(integrationChannelId);        

        // 2) Parse XML
        String xml = getFraudMasterDataResponse();
        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode root = doc.getRootElement();
        Dom.XmlNode body = getChildIgnoreNS(root, 'Body');
        Dom.XmlNode response = findChildByEndsWith(body, 'GetFraudMasterDataResponse');

        // Data to upsert
        Map<String, FEC_Master_Data_Integration__c> toUpsert = new Map<String, FEC_Master_Data_Integration__c>();

        for (Dom.XmlNode mdi : response.getChildElements()) {
            if (mdi.getName() == 'MasterDataItems') {
                processMasterDataItem(mdi, null, '', toUpsert, existingMap, integrationChannelId);
            }
        }

        // 3) UPSERT records
        upsertMasterDataRecords(toUpsert);

        return toUpsert.size();
    }
    

    // --------------------------------------------------------------------------------
    // UPSERT in batches
    // --------------------------------------------------------------------------------
    private static void upsertMasterDataRecords(Map<String, FEC_Master_Data_Integration__c> toUpsert) {
        List<FEC_Master_Data_Integration__c> batch = new List<FEC_Master_Data_Integration__c>();

        for (FEC_Master_Data_Integration__c rec : toUpsert.values()) {
            batch.add(rec);

            if (batch.size() == 150) {
                upsert batch;
                batch.clear();
            }
        }
        if (!batch.isEmpty()) upsert batch;
    }

    // --------------------------------------------------------------------------------
    // Process Master Node
    // --------------------------------------------------------------------------------
    private static void processMasterDataItem(
        Dom.XmlNode node,
        String parentId,
        String path,
        Map<String, FEC_Master_Data_Integration__c> upsertMap,
        Map<String, FEC_Master_Data_Integration__c> existingMap,
        String integrationChannelId
    ) {
        String id = text(node, 'ID');
        String name = text(node, 'Name');
        String nameVN = text(node, 'NameVN');
        String type = text(node, 'Type');
        String newPath = (path == '' ? name : path + ' > ' + name);
        String applyTo = text(node, 'ApplyTo');
        applyTo = String.isBlank(applyTo) ? null : applyTo;
        String posOrderStr = text(node, 'PosOrder');
        Integer posOrder = (posOrderStr != null && posOrderStr.trim() != '') ? Integer.valueOf(posOrderStr) : null;

        if (type != null && (
            type == 'Product' ||
            type == 'CaseType' ||
            type == 'Category' ||
            type == 'SubCategory' ||
            type == 'SubCode'
        )) {
            upsertNode(
                type, id, parentId, name, nameVN, null, null, null, newPath,
                existingMap, upsertMap, integrationChannelId, applyTo, posOrder
            );
        }

        // AdditionalProperties
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == 'AdditionalProperties') {
                processAdditionalProperty(child, id, newPath, upsertMap, existingMap, integrationChannelId);
            }
        }

        // Children
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == 'Children') {
                processMasterDataItem(child, id, newPath, upsertMap, existingMap, integrationChannelId);
            }
        }
    }

    // --------------------------------------------------------------------------------
    // Process Additional Properties
    // --------------------------------------------------------------------------------
    private static void processAdditionalProperty(
        Dom.XmlNode node,
        String parentId,
        String path,
        Map<String, FEC_Master_Data_Integration__c> upsertMap,
        Map<String, FEC_Master_Data_Integration__c> existingMap,
        String integrationChannelId
    ) {
        String fieldId = text(node, 'ID');
        String fieldName = text(node, 'Name');
        String nameVN = text(node, 'NameVN');
        String type = text(node, 'Type');
        String mandStr = text(node, 'Mandatory');
        Boolean mandatory = (mandStr != null && mandStr.toLowerCase() == 'true') ? true : false;
        String applyTo = text(node, 'ApplyTo');
        applyTo = String.isBlank(applyTo) ? null : applyTo;
        String posOrderStr = text(node, 'PosOrder');
        Integer posOrder = (posOrderStr != null && posOrderStr.trim() != '') ? Integer.valueOf(posOrderStr) : null;



        // Upsert AdditionalProperty
        upsertNode(
            'AdditionalProperty', fieldId, parentId, fieldName, nameVN,
            type, mandatory, null, path + ' > ' + fieldName,
            existingMap, upsertMap, integrationChannelId, applyTo, posOrder
        );

        // Available Values
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == 'AvailableValues') {
                String valId = text(child, 'ID');
                String valName = text(child, 'Name');
                String valNameVN = text(child, 'NameVN');
                applyTo = text(child, 'ApplyTo');
                applyTo = String.isBlank(applyTo) ? null : applyTo;
                posOrderStr = text(child, 'PosOrder');
                posOrder = (posOrderStr != null && posOrderStr.trim() != '') ? Integer.valueOf(posOrderStr) : null;

                upsertNode(
                    'AvailableValue', valId, fieldId,
                    valName, valNameVN,
                    null, null, valId,
                    path + ' > ' + fieldName + ' > ' + valName,
                    existingMap, upsertMap, integrationChannelId, applyTo, posOrder
                );
            }
        }
    }
    @AuraEnabled
    public static Map<String, Object> getFraudCaseDetail(String caseId) {

        System.debug('==============================');
        System.debug('[START] getFraudCaseDetail');
        System.debug('Input caseId = ' + caseId);
        System.debug('==============================');

        if (String.isBlank(caseId)) {
            throw new AuraHandledException('caseId is required');
        }

        // =====================================================
        // 1) LOAD ROOT (FH) + BU
        // =====================================================
        System.debug('Query ROOT + BU cases');

        List<FEC_Integration_Case__c> rootAndBu = [
            SELECT Id,
                FEC_CaseID__c,
                FEC_Parent_CaseID__c,
                FEC_Service_Case_ID__c,
                FEC_Case_Status__c,
                FEC_Category__c,
                FEC_Sub_Category__c,
                FEC_Sub_Code__c,
                FEC_Remark__c,
                FEC_Investigation_Conclusion__c,
                FEC_Sys_Channel__c,
                FEC_Creator_Email__c,
                CreatedDate,
                LastModifiedDate
            FROM FEC_Integration_Case__c
            WHERE FEC_CaseID__c = :caseId
            OR FEC_Parent_CaseID__c = :caseId
            ORDER BY CreatedDate
        ];

        System.debug('rootAndBu size = ' + rootAndBu.size());

        // =====================================================
        // 2) COLLECT BU CASE IDs
        // =====================================================
        Set<String> buCaseIds = new Set<String>();
        FEC_Integration_Case__c rootCase;

        for (FEC_Integration_Case__c c : rootAndBu) {
            if (c.FEC_CaseID__c == caseId) {
                rootCase = c;
            } else if (c.FEC_Parent_CaseID__c == caseId) {
                buCaseIds.add(c.FEC_CaseID__c);
            }
        }

        if (rootCase == null) {
            throw new AuraHandledException('Root case not found: ' + caseId);
        }

        System.debug('BU CaseIDs = ' + buCaseIds);

        // =====================================================
        // 3) LOAD TK (CHILDREN OF BU)
        // =====================================================
        List<FEC_Integration_Case__c> tkCases = new List<FEC_Integration_Case__c>();

        if (!buCaseIds.isEmpty()) {
            System.debug('Query TK cases');

            tkCases = [
                SELECT Id,
                    FEC_CaseID__c,
                    FEC_Parent_CaseID__c,
                    FEC_Service_Case_ID__c,
                    FEC_Case_Status__c,
                    FEC_Category__c,
                    FEC_Sub_Category__c,
                    FEC_Sub_Code__c,
                    FEC_Remark__c,
                    FEC_Sys_Channel__c,
                    FEC_Creator_Email__c,
                    FEC_Investigation_Conclusion__c,
                    CreatedDate,
                    LastModifiedDate
                FROM FEC_Integration_Case__c
                WHERE FEC_Parent_CaseID__c IN :buCaseIds
                ORDER BY CreatedDate
            ];
        }

        System.debug('tkCases size = ' + tkCases.size());

        // =====================================================
        // 4) BUILD HIERARCHY (FH → BU → TK)
        // =====================================================
        List<FEC_Integration_Case__c> hierarchy = new List<FEC_Integration_Case__c>();
        hierarchy.add(rootCase);

        for (FEC_Integration_Case__c bu : rootAndBu) {
            if (bu.FEC_Parent_CaseID__c == caseId) {
                hierarchy.add(bu);

                for (FEC_Integration_Case__c tk : tkCases) {
                    if (tk.FEC_Parent_CaseID__c == bu.FEC_CaseID__c) {
                        hierarchy.add(tk);
                    }
                }
            }
        }

        System.debug('Hierarchy order:');
        for (FEC_Integration_Case__c c : hierarchy) {
            System.debug('   • ' + c.FEC_CaseID__c);
        }

        // =====================================================
        // 5) LOAD ALL INFO RECORDS FOR HIERARCHY
        // =====================================================
        System.debug('Query FEC_Integration_Case_Info__c');

        Map<Id, List<FEC_Integration_Case_Info__c>> infoByCaseId =
            new Map<Id, List<FEC_Integration_Case_Info__c>>();

        List<FEC_Integration_Case_Info__c> infoRecords = [
            SELECT Id,
                FEC_Info_ID__c,
                FEC_Info_Value__c,
                FEC_Parent_Case__c
            FROM FEC_Integration_Case_Info__c
            WHERE FEC_Parent_Case__c IN :hierarchy
            ORDER BY FEC_Parent_Case__c, FEC_Info_ID__c
        ];

        System.debug('Info records size = ' + infoRecords.size());

        for (FEC_Integration_Case_Info__c inf : infoRecords) {
            if (!infoByCaseId.containsKey(inf.FEC_Parent_Case__c)) {
                infoByCaseId.put(inf.FEC_Parent_Case__c,
                    new List<FEC_Integration_Case_Info__c>());
            }
            infoByCaseId.get(inf.FEC_Parent_Case__c).add(inf);
        }

        // =====================================================
        // 6) BUILD TASK LIST (TK-* ONLY)
        // =====================================================
        System.debug('Build task list');

        List<Map<String, Object>> taskList = new List<Map<String, Object>>();

        for (FEC_Integration_Case__c c : hierarchy) {

            if (!c.FEC_CaseID__c.startsWith('TK-')) continue;

            Map<String, String> taskInfoMap = new Map<String, String>();

            if (infoByCaseId.containsKey(c.Id)) {
                for (FEC_Integration_Case_Info__c inf : infoByCaseId.get(c.Id)) {
                    taskInfoMap.put(inf.FEC_Info_ID__c, inf.FEC_Info_Value__c);
                }
            }

            taskList.add(new Map<String, Object>{
                'Id'               => c.Id,
                'TaskId'           => c.FEC_CaseID__c,
                'FraudTaskId'      => c.FEC_Service_Case_ID__c,
                'InvestigationConclusion' => c.FEC_Investigation_Conclusion__c,
                'FraudTaskUrl'     => c.FEC_Service_Case_ID__c != null
                        ? '/lightning/r/Case/' + c.FEC_Service_Case_ID__c + '/view'
                        : null,
                'TaskName'         => taskInfoMap.get('TaskName'),
                'UIC'              => taskInfoMap.get('UIC'),
                'AppId'            => taskInfoMap.get('AppID'),
                'ViolationType'    => taskInfoMap.get('ViolationType'),                
                'Status'           => c.FEC_Case_Status__c,
                'Deadline'         => formatDDMMYYYY(taskInfoMap.get('Deadline')),
                'CreatedDate'      => formatDateTime(c.CreatedDate),
                'LastModifiedDate' => formatDateTime(c.LastModifiedDate)
            });
        }

        System.debug('📊 taskList size = ' + taskList.size());

        // =====================================================
        // 7) BUILD FINAL HIERARCHY RESPONSE
        // =====================================================
        List<Map<String, Object>> hierarchyResponse = new List<Map<String, Object>>();

        for (FEC_Integration_Case__c c : hierarchy) {

            List<Map<String, String>> infos = new List<Map<String, String>>();

            if (infoByCaseId.containsKey(c.Id)) {
                for (FEC_Integration_Case_Info__c inf : infoByCaseId.get(c.Id)) {
                    //FEC_Source_Id__c='ApproDoc' AND FEC_Source_Parent_Id__c='CC02-06'                    
                    List<FEC_Master_Data_Integration__c> exist = [
                        SELECT FEC_Source_Field_Type__c FROM FEC_Master_Data_Integration__c WHERE FEC_Source_Id__c = :inf.FEC_Info_ID__c LIMIT 1
                        //SELECT FEC_Source_Field_Type__c FROM FEC_Master_Data_Integration__c WHERE FEC_Source_Id__c = :inf.FEC_Info_ID__c AND FEC_Source_Parent_Id__c = :c.FEC_Sub_Code__c  LIMIT 1
                    ];
                    String fileType = null;
                    String fileName = null;                    
                    if (!exist.isEmpty()) {
                        fileType = exist[0].FEC_Source_Field_Type__c;
                    }
                    if (fileType == 'file' && String.isNotBlank(inf.FEC_Info_Value__c)) {

                        String rawValue = inf.FEC_Info_Value__c;
                    
                        Integer firstSep = rawValue.indexOf('|');
                        Integer secondSep = rawValue.indexOf('|', firstSep + 1);
                    
                        if (firstSep > -1 && secondSep > -1) {
                            fileName = rawValue.substring(0, firstSep);
                        }
                    }
                    infos.add(new Map<String, String>{
                        'id'    => inf.FEC_Info_ID__c,
                        'value' => inf.FEC_Info_Value__c,
                        'fileType' => fileType,
                        'fileName' => fileName
                    });
                }
            }

            hierarchyResponse.add(new Map<String, Object>{
                'Id'                     => c.Id,
                'FEC_CaseID__c'          => c.FEC_CaseID__c,
                'FEC_Parent_CaseID__c'   => c.FEC_Parent_CaseID__c,
                'FEC_Service_Case_ID__c' => c.FEC_Service_Case_ID__c,
                'FEC_Case_Status__c'     => c.FEC_Case_Status__c,
                'FEC_Category__c'        => c.FEC_Category__c,
                'FEC_Sub_Category__c'    => c.FEC_Sub_Category__c,
                'FEC_Sub_Code__c'        => c.FEC_Sub_Code__c,
                'FEC_Remark__c'          => c.FEC_Remark__c,
                'FEC_Investigation_Conclusion__c' => c.FEC_Investigation_Conclusion__c,
                'FEC_Sys_Channel__c'     => c.FEC_Sys_Channel__c,
                'FEC_Creator_Email__c'   => c.FEC_Creator_Email__c,
                'CreatedDate'            => formatDateTime(c.CreatedDate),
                'LastModifiedDate'       => formatDateTime(c.LastModifiedDate),
                'Infos'                  => infos
            });
        }

        System.debug('[END] getFraudCaseDetail');

        return new Map<String, Object>{
            'hierarchy' => hierarchyResponse,
            'tasks'     => taskList
        };
    }






    public static String createFraudCaseService(
    String serviceCaseId,
    String channelCode,
    String parentCaseId,
    String caseId,
    String caseStatus,
    fecSoapFraudcaseServices.SysResponse sys,
    fecSoapFraudcaseServices.RequestInfo req,
    fecSoapFraudcaseServices.CustomerInfo cust,
    fecSoapFraudcaseServices.CreatorInfo creator
) {
    Map<String,Object> resp;
    try {
        System.debug('createFraudCaseService called. serviceCaseId=' + serviceCaseId + ', caseId=' + caseId + ', channel=' + channelCode);

        Boolean isUpsertCase = upsertFraudCaseService(
            serviceCaseId,
            channelCode,
            parentCaseId,
            caseId,
            caseStatus,
            sys,
            req,
            cust,
            creator
        );
        
        System.debug('upsertFraudCaseService returned: ' + isUpsertCase);

        if (isUpsertCase) {
            resp = fecFraudCaseUtil.success('Fraud case created successfully.', caseId);
        } else {
            resp = fecFraudCaseUtil.error('Fraud case creation failed.');
        }
        return JSON.serializePretty(resp);
    } catch (Exception ex) {
        System.debug('createFraudCaseService error: ' + ex.getMessage());
        System.debug(ex.getStackTraceString());
        resp = fecFraudCaseUtil.error('Exception: ' + ex.getMessage());
        return JSON.serializePretty(resp);
    }
}


    public static FEC_Integration_Case__c getIntegrationCaseById(String caseId) {
        List<FEC_Integration_Case__c> existing = [
                SELECT Id, FEC_CaseID__c, FEC_Service_Case_ID__c
                FROM FEC_Integration_Case__c
                WHERE FEC_CaseID__c = :caseId               
                LIMIT 1
            ];
        return existing.isEmpty() ? null : existing[0];
    }
    

    public static Boolean authenticate(String authHeader, String systemName) {
        try {
            //String authHeader = RestContext.request.headers.get('Authorization');

            if (String.isBlank(authHeader) || !authHeader.startsWith('Basic '))
                return false;

            String encoded = authHeader.substring(6);
            String decoded = EncodingUtil.base64Decode(encoded).toString();

            List<String> parts = decoded.split(':', 2);
            if (parts.size() != 2) return false;

            String user = parts[0];
            String pass = parts[1];

            FEC_Integration_API_Account__c acc = getApiAccount(systemName);
            if (acc == null) return false;

            return user == acc.FEC_Username__c &&
                pass == acc.FEC_Password__c;
        }
        catch (Exception e) {
            System.debug('Auth error: ' + e.getMessage());
            return false;
        }
    }

    // Convert SOAP master data into UI-friendly hierarchical map
    // Build UI-friendly hierarchical master data from Salesforce object
    public static Map<String, Object> buildUiMasterData() {

        Map<String, Object> result = new Map<String, Object>();
        List<Map<String, Object>> categories = new List<Map<String, Object>>();

        // Load full master data
        List<FEC_Master_Data_Integration__c> recs = [
            SELECT 
                FEC_Source_Id__c,
                FEC_Source_Parent_Id__c,
                FEC_Source_Name__c,
                FEC_Source_NameVN__c,
                FEC_Source_Type__c,
                FEC_Source_Field_Type__c,
                FEC_Source_Enum_Value__c,
                FEC_Source_Enum_Label__c,
                FEC_Source_Enum_LabelVN__c,
                FEC_Source_Is_Mandatory__c,
                FEC_PosOrder__c
            FROM FEC_Master_Data_Integration__c
            ORDER BY FEC_PosOrder__c NULLS LAST
        ];
        System.debug('➡ Load full master data        = ' + JSON.serializePretty(recs));

        // Group records by Type
        Map<String, List<FEC_Master_Data_Integration__c>> typeMap = new Map<String, List<FEC_Master_Data_Integration__c>>();
        for (FEC_Master_Data_Integration__c r : recs) {
            String t = r.FEC_Source_Type__c != null ? r.FEC_Source_Type__c : 'UNKNOWN';
            if (!typeMap.containsKey(t)) {
                typeMap.put(t, new List<FEC_Master_Data_Integration__c>());
            }
            typeMap.get(t).add(r);
        }

        // Safe shortcuts
        List<FEC_Master_Data_Integration__c> categoryList        = typeMap.containsKey('Category')         ? typeMap.get('Category')         : new List<FEC_Master_Data_Integration__c>();
        List<FEC_Master_Data_Integration__c> subCategoryList    = typeMap.containsKey('SubCategory')      ? typeMap.get('SubCategory')      : new List<FEC_Master_Data_Integration__c>();
        List<FEC_Master_Data_Integration__c> subCodeList        = typeMap.containsKey('SubCode')          ? typeMap.get('SubCode')          : new List<FEC_Master_Data_Integration__c>();
        List<FEC_Master_Data_Integration__c> additionalList     = typeMap.containsKey('AdditionalProperty')? typeMap.get('AdditionalProperty'): new List<FEC_Master_Data_Integration__c>();
        List<FEC_Master_Data_Integration__c> availableValueList = typeMap.containsKey('AvailableValue')   ? typeMap.get('AvailableValue')   : new List<FEC_Master_Data_Integration__c>();
        System.debug('➡ Load full master categoryList        = ' + JSON.serializePretty(categoryList));
        System.debug('➡ Load full master subCategoryList        = ' + JSON.serializePretty(subCategoryList));
        System.debug('➡ Load full master additionalList        = ' + JSON.serializePretty(additionalList));
        System.debug('➡ Load full master availableValueList        = ' + JSON.serializePretty(availableValueList));
        // ------------------------------------------------------------
        // BUILD TREE: Category → SubCategory → SubCode → AP → Values
        // ------------------------------------------------------------
        for (FEC_Master_Data_Integration__c cat : categoryList) {

            Map<String, Object> catNode = new Map<String, Object>{
                'id'            => cat.FEC_Source_Id__c,
                'name'          => cat.FEC_Source_Name__c,
                'nameVN'        => cat.FEC_Source_NameVN__c,
                'posOrder'      => cat.FEC_PosOrder__c,
                'subCategories' => new List<Object>()
            };

            // ---------------- SUBCATEGORY ----------------
            for (FEC_Master_Data_Integration__c sub : subCategoryList) {
                if (sub.FEC_Source_Parent_Id__c == cat.FEC_Source_Id__c) {

                    Map<String, Object> subNode = new Map<String, Object>{
                        'id'        => sub.FEC_Source_Id__c,
                        'name'      => sub.FEC_Source_Name__c,
                        'nameVN'    => sub.FEC_Source_NameVN__c,
                        'subCodes'  => new List<Object>()
                    };

                    // ---------------- SUBCODE ----------------
                    for (FEC_Master_Data_Integration__c sc : subCodeList) {
                        if (sc.FEC_Source_Parent_Id__c == sub.FEC_Source_Id__c) {

                            Map<String, Object> scNode = new Map<String, Object>{
                                'id'        => sc.FEC_Source_Id__c,
                                'name'      => sc.FEC_Source_Name__c,
                                'nameVN'    => sc.FEC_Source_NameVN__c,
                                'additionalProperties' => new List<Object>()
                            };

                            // ---------------- ADDITIONAL PROPERTY ----------------
                            for (FEC_Master_Data_Integration__c ap : additionalList) {
                                if (ap.FEC_Source_Parent_Id__c == sc.FEC_Source_Id__c) {

                                    Map<String, Object> apNode = new Map<String, Object>{
                                        'id'            => ap.FEC_Source_Id__c,
                                        'name'          => ap.FEC_Source_Name__c,
                                        'nameVN'        => ap.FEC_Source_NameVN__c,
                                        'type'          => ap.FEC_Source_Field_Type__c,
                                        'mandatory'     => ap.FEC_Source_Is_Mandatory__c,
                                        'availableValues' => new List<Object>()
                                    };

                                    // ---------------- AVAILABLE VALUES ----------------
                                    for (FEC_Master_Data_Integration__c av : availableValueList) {
                                        if (av.FEC_Source_Parent_Id__c == ap.FEC_Source_Id__c) {

                                            List<Object> avList = (List<Object>) apNode.get('availableValues');
                                            if (avList == null) {
                                                avList = new List<Object>();
                                                apNode.put('availableValues', avList);
                                            }

                                            avList.add(new Map<String, Object>{
                                                'id'     => av.FEC_Source_Enum_Value__c,
                                                'name'   => av.FEC_Source_Enum_Label__c,
                                                'nameVN' => av.FEC_Source_Enum_LabelVN__c
                                            });
                                        }
                                    }

                                    // Add AP → SubCode
                                    ((List<Object>)scNode.get('additionalProperties')).add(apNode);
                                }
                            }

                            // Add SubCode → SubCategory
                            ((List<Object>)subNode.get('subCodes')).add(scNode);
                        }
                    }

                    // Add SubCategory → Category
                    ((List<Object>)catNode.get('subCategories')).add(subNode);
                }
            }

            categories.add(catNode);
        }
        System.debug('➡ Load full all categories = ' + JSON.serializePretty(categories));
        result.put('categories', categories);
        return result;
    }
    

    // // Save base64 string to ContentVersion and link to parentId. returns ContentDocumentId
    // public static Id saveBase64File(String parentId, String base64Data, String fileName, String fileExt) {
    //     try {
    //         if (String.isBlank(base64Data)) return null;

    //         ContentVersion cv = new ContentVersion();
    //         cv.Title = fileName;
    //         cv.PathOnClient = fileName + '.' + fileExt;
    //         cv.VersionData = EncodingUtil.base64Decode(base64Data);
    //         insert cv;

    //         // get ContentDocumentId
    //         ContentVersion v = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
    //         Id contentDocumentId = v.ContentDocumentId;

    //         // link to record
    //         ContentDocumentLink link = new ContentDocumentLink(
    //             ContentDocumentId = contentDocumentId,
    //             LinkedEntityId = parentId,
    //             ShareType = 'V',
    //             Visibility = 'AllUsers'
    //         );
    //         insert link;
    //         return contentDocumentId;
    //     } catch (Exception ex) {
    //         System.debug('saveBase64File error: ' + ex.getMessage());
    //         return null;
    //     }
    // }

    // // Upsert case and also save AdditionalInfo and any files embedded inside AdditionalInfo values
    // public static Boolean upsertFraudCaseService(
    //     String serviceCaseId,
    //     String parentCaseId,
    //     String caseId,
    //     String caseStatus,
    //     fecSoapFraudcaseServices.SysResponse sys,
    //     fecSoapFraudcaseServices.RequestInfo req,
    //     fecSoapFraudcaseServices.CustomerInfo cust,
    //     fecSoapFraudcaseServices.CreatorInfo creator
    // ) {
    //     try {
    //         // 1) find existing
    //         FEC_Integration_Case__c rec;
    //         List<FEC_Integration_Case__c> existing = [
    //             SELECT Id
    //             FROM FEC_Integration_Case__c
    //             WHERE FEC_Service_Case_ID__c = :serviceCaseId
    //                OR CaseID__c = :caseId
    //             LIMIT 1
    //         ];

    //         if (!existing.isEmpty()) rec = existing[0]; else rec = new FEC_Integration_Case__c();

    //         // Map fields (use your field names)
    //         rec.CaseID__c = caseId;
    //         rec.FEC_Service_Case_ID__c = serviceCaseId;
    //         rec.FEC_Parent_CaseID__c = parentCaseId;
    //         rec.FEC_Case_Status__c = caseStatus;

    //         if (sys != null) {
    //             rec.FEC_Sys_Transaction_Id__c = sys.TransactionID;
    //             rec.FEC_Sys_Date_Time__c = sys.DateTime_x;
    //             rec.FEC_Sys_Channel__c = sys.Code;
    //         }

    //         if (cust != null) rec.FEC_Customer_User_Type__c = cust.UserType;
    //         if (creator != null) rec.FEC_Creator_Email__c = creator.CreatorEmail;

    //         if (req != null) {
    //             rec.FEC_Case_Type__c = req.CaseType;
    //             rec.FEC_Product_Type__c = req.ProductType;
    //             rec.FEC_Category__c = req.Category;
    //             rec.FEC_Sub_Category__c = req.SubCategory;
    //             rec.FEC_Sub_Code__c = req.SubCode;
    //             rec.FEC_Remark__c = req.Remarks;
    //         }

    //         rec.OwnerId = UserInfo.getUserId();
    //         upsert rec;

    //         // delete old AdditionalInfo
    //         if (rec.Id != null) {
    //             List<FEC_Integration_Case_Info__c> oldInfos = [
    //                 SELECT Id FROM FEC_Integration_Case_Info__c WHERE FEC_Parent_Case__c = :rec.Id
    //             ];
    //             if (!oldInfos.isEmpty()) delete oldInfos;
    //         }

    //         // insert AdditionalInfo; if value of info looks like base64 and ID indicates file,
    //         // save file and persist ContentDocumentId or filename in Info_Value
    //         if (req != null && req.AdditionalInfo != null) {
    //             List<FEC_Integration_Case_Info__c> toInsert = new List<FEC_Integration_Case_Info__c>();
    //             for (fecSoapFraudcaseServices.AdditionalInfo ai : req.AdditionalInfo) {
    //                 FEC_Integration_Case_Info__c info = new FEC_Integration_Case_Info__c();
    //                 info.FEC_Parent_Case__c = rec.Id;
    //                 info.FEC_Info_ID__c = ai.ID;
    //                 info.FEC_Info_Value__c = ai.Value;

    //                 // Heuristic: if ID name contains 'file' or 'image' and value looks like base64, save file
    //                 if (ai.Value != null && (ai.ID.toLowerCase().contains('file') || ai.ID.toLowerCase().contains('image') || ai.ID.toLowerCase().contains('photo'))) {
    //                     // assume client sent base64; store file
    //                     String base64 = ai.Value;
    //                     // if client sent "data:...;base64,AAAA", strip prefix
    //                     if (base64.contains('base64,')) base64 = base64.substringAfter('base64,');
    //                     Id docId = saveBase64File(rec.Id, base64, ai.ID, 'bin'); // extension unknown; use bin or client can send ext in AdditionalInfo ID/Value
    //                     if (docId != null) {
    //                         info.FEC_Info_Value__c = String.valueOf(docId); // store ContentDocumentId
    //                     }
    //                 }
    //                 toInsert.add(info);
    //             }
    //             if (!toInsert.isEmpty()) insert toInsert;
    //         }

    //         return true;

    //     } catch (Exception ex) {
    //         System.debug('upsertFraudCaseService error: ' + ex.getMessage());
    //         System.debug(ex.getStackTraceString());
    //         return false;
    //     }FEC_IntegrationFraudCaseClient
    // }

    // public static Integer syncMasterDataFraudIntegration() {
    //     String integrationChannelId = getIntegrationChannelCode('FIMA');
    //     // 1) Load ALL existing mapping records into a map for upsert comparison
    //     Map<String, FEC_Master_Data_Integration__c> existingMap = loadExisting(integrationChannelId); 
       
    //     fecSoapFraudcaseServices.Sys sys = new fecSoapFraudcaseServices.Sys();
    //     sys.Channel = 'PEGACSM';
    //     // Call client (mock or real)
    //     fecSoapFraudcaseServices.GetFraudMasterDataResponse_element res =
    //     FEC_IntegrationFraudCaseClient.getMasterData(sys);
        

    //    // Upsert bucket
    //     Map<String, FEC_Master_Data_Integration__c> upsertMap =
    //     new Map<String, FEC_Master_Data_Integration__c>();

    //    // NOW PROCESS APEX OBJECTS
    //     for (fecSoapFraudcaseServices.MasterDataItem item : res.MasterDataItems) {
    //         processMasterDataItem(
    //             item,
    //             null,
    //             '',
    //             upsertMap,
    //             existingMap,
    //             integrationChannelId
    //         );
    //     }

    //     // UPSERT
    //     upsertMasterDataRecords(upsertMap);

    //     return upsertMap.size();
    // }
    private static Boolean upsertFraudCaseService(
    String serviceCaseId,
    String channelCode,
    String parentCaseId,
    String caseId,
    String caseStatus,
    fecSoapFraudcaseServices.SysResponse sys,
    fecSoapFraudcaseServices.RequestInfo req,
    fecSoapFraudcaseServices.CustomerInfo cust,
    fecSoapFraudcaseServices.CreatorInfo creator
    ) {
        System.debug('==================== 🔍 UPSERT FRAUD CASE START ====================');

        // Log all raw inputs
        System.debug('➡ INPUT: serviceCaseId = ' + serviceCaseId);
        System.debug('➡ INPUT: channelCode    = ' + channelCode);
        System.debug('➡ INPUT: parentCaseId   = ' + parentCaseId);
        System.debug('➡ INPUT: caseId         = ' + caseId);
        System.debug('➡ INPUT: caseStatus     = ' + caseStatus);

        System.debug('➡ INPUT SYS        = ' + JSON.serializePretty(sys));
        System.debug('➡ INPUT REQUEST    = ' + JSON.serializePretty(req));
        System.debug('➡ INPUT CUSTOMER   = ' + JSON.serializePretty(cust));
        System.debug('➡ INPUT CREATOR    = ' + JSON.serializePretty(creator));

        try {

            // ==============================================================
            // 1) FIND EXISTING RECORD
            // ==============================================================
            System.debug('🔎 QUERY: Searching existing case...');

            List<FEC_Integration_Case__c> existing = [
                SELECT Id, FEC_CaseID__c, FEC_Service_Case_ID__c
                FROM FEC_Integration_Case__c
                WHERE FEC_Service_Case_ID__c = :serviceCaseId
                AND FEC_CaseID__c = :caseId
                LIMIT 1
            ];

            System.debug('QUERY RESULT: ' + JSON.serializePretty(existing));

            FEC_Integration_Case__c rec;

            if (!existing.isEmpty()) {
                System.debug('➡ EXISTING CASE FOUND → UPDATE');
                rec = existing[0];
            } else {
                System.debug('➡ NO EXISTING CASE → INSERT NEW');
                rec = new FEC_Integration_Case__c();
            }

            // ==============================================================
            // 2) MAP PRIMARY FIELDS
            // ==============================================================
            System.debug('MAPPING FIELDS...');

            rec.FEC_CaseID__c = caseId;
            rec.FEC_Service_Case_ID__c = serviceCaseId;
            rec.FEC_Parent_CaseID__c = parentCaseId;
            rec.FEC_Case_Status__c = caseStatus;

            // --- Sys ---
            if (sys != null) {
                rec.FEC_Sys_Transaction_Id__c = sys.TransactionID;
                rec.FEC_Sys_Date_Time__c = sys.DateTime_x;
                rec.FEC_Sys_Channel__c = channelCode;

                System.debug('SYS MAPPED: ' + JSON.serializePretty(sys));
            }

            // --- Customer Info ---
            if (cust != null) {
                rec.FEC_Customer_User_Type__c = cust.UserType;
            }

            // --- Creator Info ---
            if (creator != null) {
                rec.FEC_Creator_Email__c = creator.CreatorEmail;
            }

            // --- Request Info ---
            if (req != null) {
                rec.FEC_Case_Type__c = req.CaseType;
                rec.FEC_Product_Type__c = req.ProductType;
                rec.FEC_Category__c = req.Category;
                rec.FEC_Sub_Category__c = req.SubCategory;
                rec.FEC_Sub_Code__c = req.SubCode;
                rec.FEC_Remark__c = req.Remarks;

                System.debug('REQUEST INFO MAPPED: ' + JSON.serializePretty(req));
            }

            rec.OwnerId = UserInfo.getUserId();
            System.debug('OWNER MAPPED: ' + rec.OwnerId);

            // ==============================================================
            // 3) UPSERT CASE
            // ==============================================================
            System.debug('UPSERT CASE RECORD...');
            upsert rec;
            System.debug('UPSERT SUCCESS → NEW ID: ' + rec.Id);

            // ==============================================================
            // 4) DELETE OLD ADDITIONAL INFO
            // ==============================================================
            System.debug('CLEANING OLD ADDITIONAL INFO...');

            List<FEC_Integration_Case_Info__c> oldInfos = [
                SELECT Id
                FROM FEC_Integration_Case_Info__c
                WHERE FEC_Parent_Case__c = :rec.Id
            ];

            System.debug('OLD INFO FOUND: ' + oldInfos.size());

            if (!oldInfos.isEmpty()) {
                delete oldInfos;
                System.debug('OLD INFO DELETED');
            }

            // ==============================================================
            // 5) INSERT NEW AdditionalInfo
            // ==============================================================
            if (req != null && req.AdditionalInfo != null && !req.AdditionalInfo.isEmpty()) {

                System.debug('INSERT ADDITIONAL INFO...');

                List<FEC_Integration_Case_Info__c> addInfoRecords = new List<FEC_Integration_Case_Info__c>();

                for (fecSoapFraudcaseServices.AdditionalInfo ai : req.AdditionalInfo) {
                    System.debug('ADD INFO ITEM: ' + JSON.serializePretty(ai));

                    FEC_Integration_Case_Info__c info = new FEC_Integration_Case_Info__c();
                    info.FEC_Parent_Case__c = rec.Id;
                    info.FEC_Info_ID__c = ai.ID;
                    info.FEC_Info_Value__c = ai.Value;

                    addInfoRecords.add(info);
                }

                insert addInfoRecords;

                System.debug('INSERTED ADD INFO COUNT: ' + addInfoRecords.size());
            }

            System.debug('==================== ✅ UPSERT FRAUD CASE DONE ====================');
            return true;

        } catch (Exception ex) {
            System.debug('ERROR IN UPSERT FRAUD CASE: ' + ex.getMessage());
            System.debug('STACKTRACE: ' + ex.getStackTraceString());
            return false;
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String,Object> searchFraudCases(
        String fraudCaseId,        
        String nationalId,
        String phoneNumber,
        String applicationId,
        String contractNumber,
        String accountNumber,
        Integer pageNumber,
        Integer pageSize,
        String sortBy,
        String sortDirection
    ) {
        System.debug('START searchFraudCases');

        // Paging defaults
        if (pageNumber == null || pageNumber < 1) pageNumber = 1;
        if (pageSize == null || pageSize < 1) pageSize = 10;

        // =====================================================
        // 1. Parent Case Filters
        // =====================================================
        List<String> parentWhere = new List<String>();

        if (String.isNotBlank(fraudCaseId)) {
            parentWhere.add(
                'FEC_CaseID__c LIKE \'%' + String.escapeSingleQuotes(fraudCaseId) + '%\''
            );
        }

        // =====================================================
        // 2. Additional Info Filters (Apex filtering allowed)
        // =====================================================
        Map<String,String> infoFilters = new Map<String,String>{
            'nationalId'     => nationalId,
            'phoneNumber'    => phoneNumber,
            'applicationId'  => applicationId,
            'contractNumber' => contractNumber,
            'accountNumber'  => accountNumber
        };

        Set<Id> matchedCaseIds = new Set<Id>();
        Integer activeFilterCount = 0;

        for (String key : infoFilters.keySet()) {
            String val = infoFilters.get(key);
            if (String.isNotBlank(val)) {

                activeFilterCount++;
                System.debug('Filtering AdditionalInfo field: ' + key + ' LIKE %' + val + '%');

                // Step 1 — Filter by Info ID (allowed SOQL filter)
                List<FEC_Integration_Case_Info__c> rows = [
                    SELECT FEC_Parent_Case__c, FEC_Info_ID__c, FEC_Info_Value__c
                    FROM FEC_Integration_Case_Info__c
                    WHERE FEC_Info_ID__c = :key
                ];

                // Step 2 — Apex filtering for text contains
                for (FEC_Integration_Case_Info__c r : rows) {
                    if (r.FEC_Info_Value__c != null &&
                        r.FEC_Info_Value__c.contains(val)) {

                        matchedCaseIds.add(r.FEC_Parent_Case__c);
                    }
                }
            }
        }

        System.debug('AdditionalInfo matchedCaseIds before combining: ' + matchedCaseIds);

        if (activeFilterCount > 0 && matchedCaseIds.isEmpty()) {
            return new Map<String,Object>{
                'total' => 0,
                'pageRecords' => new List<Map<String,Object>>()
            };
        }

        if (!matchedCaseIds.isEmpty()) {
            parentWhere.add('Id IN :matchedCaseIds');
        }
        // Always enforce FH / TK
        parentWhere.add('(FEC_CaseID__c LIKE \'FH-%\' OR FEC_CaseID__c LIKE \'TK-%\')');

        // =====================================================
        // 3. Sorting
        // =====================================================
        Set<String> allowedSortFields = new Set<String>{
            'FEC_CaseID__c',
            'FEC_Service_Case_ID__c',
            'FEC_Category__c',
            'FEC_Sub_Category__c',
            'FEC_Sub_Code__c',
            'FEC_Case_Status__c',
            'CreatedDate'
        };

        if (String.isBlank(sortBy) || !allowedSortFields.contains(sortBy))
            sortBy = 'CreatedDate';

        if (sortDirection != 'ASC' && sortDirection != 'DESC')
            sortDirection = 'DESC';

        // =====================================================
        // 4. Build Final SOQL query
        // =====================================================
        String query =
            'SELECT Id, Name, FEC_CaseID__c, FEC_Service_Case_ID__c, FEC_Parent_CaseID__c,' +
            'FEC_Case_Status__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c,' +
            'FEC_Remark__c, CreatedDate, FEC_Sys_Channel__c, FEC_Creator_Email__c, ' +
            'CreatedBy.Id, CreatedBy.Name, CreatedBy.Email ' +
            'FROM FEC_Integration_Case__c ';

        if (!parentWhere.isEmpty()) {
            query += ' WHERE ' + String.join(parentWhere, ' AND ');
        }
        

        query += ' ORDER BY ' + sortBy + ' ' + sortDirection;

        System.debug('FINAL QUERY: ' + query);

        List<FEC_Integration_Case__c> allRecords = Database.query(query);
        Integer total = allRecords.size();

        // =====================================================
        // 5. Paging
        // =====================================================
        Integer startIdx = (pageNumber - 1) * pageSize;
        Integer endIdx   = Math.min(startIdx + pageSize, total);

        List<FEC_Integration_Case__c> pageList = new List<FEC_Integration_Case__c>();
        for (Integer i = startIdx; i < endIdx; i++) {
            pageList.add(allRecords[i]);
        }

        // =====================================================
        // 6. Load Account Number from AdditionalInfo
        // =====================================================
        Map<Id, String> accountNumberMap = new Map<Id, String>();

        if (!pageList.isEmpty()) {
            List<FEC_Integration_Case_Info__c> acctInfos = [
                SELECT FEC_Parent_Case__c, FEC_Info_ID__c, FEC_Info_Value__c
                FROM FEC_Integration_Case_Info__c
                WHERE FEC_Parent_Case__c IN :pageList
                AND FEC_Info_ID__c = 'AccountNumber'
            ];

            for (FEC_Integration_Case_Info__c info : acctInfos) {
                accountNumberMap.put(info.FEC_Parent_Case__c, info.FEC_Info_Value__c);
            }
        }

        // =====================================================
        // 7. Prepare final rows for LWC
        // =====================================================
        List<Map<String,Object>> finalRows = new List<Map<String,Object>>();

        for (FEC_Integration_Case__c c : pageList) {
            finalRows.add(new Map<String,Object>{
                'Id'                     => c.Id,
                'FEC_CaseID__c'          => c.FEC_CaseID__c,
                'FEC_Service_Case_ID__c' => c.FEC_Service_Case_ID__c,
                'FEC_Category__c'        => c.FEC_Category__c,
                'FEC_Sub_Category__c'    => c.FEC_Sub_Category__c,
                'FEC_Sub_Code__c'        => c.FEC_Sub_Code__c,
                'FEC_Case_Status__c'     => c.FEC_Case_Status__c,
                'CreatedDate'            => formatDateTime(c.CreatedDate),
                'FEC_Sys_Channel__c'     => c.FEC_Sys_Channel__c,
                
                // ⭐ Correct Account Number from AdditionalInfo
                'AccountNumber'          => accountNumberMap.containsKey(c.Id)
                                        ? accountNumberMap.get(c.Id)
                                        : null,
                'CreatedByEmail' => c.FEC_Creator_Email__c,
                'CreatedByName'  => c.CreatedBy.Name,                                       

                // 🔗 Hyperlink for LWC
                'ServiceCaseLink' => (c.FEC_Service_Case_ID__c != null ? '/' + c.FEC_Service_Case_ID__c : null),
                'FraudCaseLink'        => '/' + c.Id
            });
        }

        return new Map<String,Object>{
            'total' => total,
            'pageRecords' => finalRows
        };
    }



    public static Map<String,Object> extractRequestData(String raw) {
        // Extract XML string from "data": "....."
        String xmlData = extractXml(raw);
        //System.debug('EXTRACTED XML:\n' + xmlData);

        // Clean JSON body by replacing XML with ""
        String jsonClean = cleanJson(raw);
        //System.debug('CLEAN JSON FOR PARSING:\n' + jsonClean);

        // Now safe to deserialize
        Map<String,Object> wrapper =
            (Map<String,Object>) JSON.deserializeUntyped(jsonClean);

        Map<String,Object> detail =
            (Map<String,Object>) wrapper.get('detail');

        //System.debug('DETAIL MAP:\n' + JSON.serializePretty(detail));

        // Final combined return
        return new Map<String,Object>{
            'detail' => detail,
            'xml'    => xmlData
        };
    }





    // Private function
    private static String formatDDMMYYYY(String rawDate) {
        // Null / length guard
        if (String.isBlank(rawDate) || rawDate.length() != 8) {
            return null;
        }
        // Ensure numeric
        if (!rawDate.isNumeric()) {
            return null;
        }
        return rawDate.substring(6, 8) + '/' +
            rawDate.substring(4, 6) + '/' +
            rawDate.substring(0, 4);
    }

    // -----------------------------
    // JSON EXTRACTOR (remove XML block)
    // -----------------------------
    public static String formatDateTime(DateTime dt) {
        return dt != null ? dt.format('dd/MM/yyyy HH:mm:ss') : null;
    }
    
    
    // private static String cleanJson(String raw) {
    //     Integer start = raw.indexOf('"data":');
    //     Integer firstQuote = raw.indexOf('"', start + 7);
    //     Integer closingQuote = raw.lastIndexOf('"');

    //     String json = raw.substring(0, firstQuote) + '""' + raw.substring(closingQuote + 1);
    //     return json;
    // }
    private static String cleanJson(String raw) {

    if (String.isBlank(raw)) {
        return raw;
    }

    Integer dataKeyIdx = raw.indexOf('"data":');
    if (dataKeyIdx == -1) {
        return raw;
    }

    // Find the first quote after "data":
    Integer valueStart = raw.indexOf('"', dataKeyIdx + 7);
    if (valueStart == -1) {
        return raw;
    }

    // We must find the END of the data value.
    // Strategy:
    //  - data is followed by , "messageTime"
    Integer nextFieldIdx = raw.indexOf(',"messageTime"', valueStart);
    if (nextFieldIdx == -1) {
        return raw;
    }

    // Replace the whole data value with empty string
    String cleaned =
        raw.substring(0, valueStart + 1) +
        raw.substring(nextFieldIdx);

    // Ensure "data":""
    cleaned = cleaned.replaceFirst('"data":"', '"data":""');

    return cleaned;
}


    // -----------------------------
    // Extract XML from raw body
    // -----------------------------
    private static String extractXml(String raw) {
        Integer start = raw.indexOf('<');
        Integer endT   = raw.lastIndexOf('>');

        return (start >= 0 && endT >= 0) 
            ? raw.substring(start, endT+1)
            : null;
    }

    private static final Map<String, String> STATUS_MAP = new Map<String, String>{
        'Complete' => 'Resolved-Completed',
        'Cancel'    => 'Resolved-Cancel'
    };

    public static String mapCaseStatus(String inputStatus) {
        if (String.isBlank(inputStatus)) return null;
        return STATUS_MAP.containsKey(inputStatus)
            ? STATUS_MAP.get(inputStatus)
            : inputStatus; // return original if no mapping
    }

    private static FEC_Integration_API_Account__c getApiAccount(String systemName) {
        List<FEC_Integration_API_Account__c> listAcc = [
            SELECT FEC_Username__c, FEC_Password__c, FEC_Status__c
            FROM FEC_Integration_API_Account__c
            WHERE FEC_System_Name__c = :systemName
            AND FEC_Status__c = TRUE
            LIMIT 1
        ];
        return listAcc.isEmpty() ? null : listAcc[0];
    }

    // --------------------------------------------------------------------------------
    // Load existing data into a lookup map
    // --------------------------------------------------------------------------------
    private static Map<String, FEC_Master_Data_Integration__c> loadExisting(String integrationChannelId) {
        Map<String, FEC_Master_Data_Integration__c> mapData = new Map<String, FEC_Master_Data_Integration__c>();

        for (FEC_Master_Data_Integration__c rec : [
            SELECT 
                FEC_Source_Type__c,
                FEC_Source_Id__c,
                FEC_Source_Parent_Id__c,
                FEC_Source_Name__c,
                FEC_Source_NameVN__c,
                FEC_Source_Field_Type__c,
                FEC_Source_Enum_Value__c,
                FEC_Source_Enum_Label__c,
                FEC_Source_Enum_LabelVN__c,
                FEC_Source_Is_Mandatory__c,
                FEC_Source_Path__c
            FROM FEC_Master_Data_Integration__c
            WHERE FEC_Channel__c = :integrationChannelId
        ]) {
            String key = rec.FEC_Source_Type__c + '|' + rec.FEC_Source_Id__c + '|' + rec.FEC_Source_Parent_Id__c;
            mapData.put(key, rec);
        }
        return mapData;
    }

   
    // // --------------------------------------------------------------------------------
    // // Process Master Node
    // // --------------------------------------------------------------------------------
    // private static void processMasterDataItem(
    // fecSoapFraudcaseServices.MasterDataItem item,
    // String parentId,
    // String path,
    // Map<String, FEC_Master_Data_Integration__c> upsertMap,
    // Map<String, FEC_Master_Data_Integration__c> existingMap,
    // String integrationChannelId
    // ){
    //     if (item == null) return;

    //     String id      = item.ID;
    //     String name    = item.Name;
    //     String nameVN  = item.NameVN;
    //     String type    = item.Type_x;
    //     String newPath = (path == '' ? name : path + ' > ' + name);

    //     // Upsert core item types
    //     if (type != null && (
    //         type == 'Product' ||
    //         type == 'CaseType' ||
    //         type == 'Category' ||
    //         type == 'SubCategory' ||
    //         type == 'SubCode'
    //     )) {
    //         upsertNode(
    //             type,
    //             id,
    //             parentId,
    //             name,
    //             nameVN,
    //             null,    // field type
    //             null,    // mandatory
    //             null,    // enum value
    //             newPath,
    //             existingMap,
    //             upsertMap,
    //             integrationChannelId
    //         );
    //     }

    //     // =============================
    //     // PROCESS Additional Properties
    //     // =============================
    //     if (item.AdditionalProperties != null) {
    //         for (fecSoapFraudcaseServices.AdditionalProperty ap : item.AdditionalProperties) {
    //             processAdditionalProperty(
    //                 ap,
    //                 id,
    //                 newPath,
    //                 upsertMap,
    //                 existingMap,
    //                 integrationChannelId
    //             );
    //         }
    //     }

    //     // =============================
    //     // PROCESS Children (recursive)
    //     // =============================
    //     if (item.Children != null) {
    //         for (fecSoapFraudcaseServices.SclMasterCaseType child : item.Children) {
    //             // Convert child type to MasterDataItem-like object
    //             fecSoapFraudcaseServices.MasterDataItem tmp =
    //                 new fecSoapFraudcaseServices.MasterDataItem();

    //             tmp.ID       = child.ID;
    //             tmp.Name     = child.Name;
    //             tmp.NameVN   = child.NameVN;
    //             tmp.PosOrder = child.PosOrder;
    //             tmp.ApplyTo  = child.ApplyTo;
    //             tmp.Type_x   = child.Type_x;

    //             processMasterDataItem(
    //                 tmp,
    //                 id,
    //                 newPath,
    //                 upsertMap,
    //                 existingMap,
    //                 integrationChannelId
    //             );
    //         }
    //     }
    // }



    // private static void processAdditionalProperty(
    // fecSoapFraudcaseServices.AdditionalProperty ap,
    // String parentId,
    // String path,
    // Map<String, FEC_Master_Data_Integration__c> upsertMap,
    // Map<String, FEC_Master_Data_Integration__c> existingMap,
    // String integrationChannelId
    // ){
    //     if (ap == null) return;

    //     Boolean mandatory = (ap.Mandatory != null && ap.Mandatory);

    //     upsertNode(
    //         'AdditionalProperty',
    //         ap.ID,
    //         parentId,
    //         ap.Name,
    //         ap.NameVN,
    //         ap.Type_x,
    //         mandatory,
    //         null,
    //         path + ' > ' + ap.Name,
    //         existingMap,
    //         upsertMap,
    //         integrationChannelId
    //     );

    //     // Process Available Values
    //     if (ap.AvailableValues != null) {
    //         for (fecSoapFraudcaseServices.AvailableValue v : ap.AvailableValues) {
    //             upsertNode(
    //                 'AvailableValue',
    //                 v.ID,
    //                 ap.ID,
    //                 v.Name,
    //                 v.NameVN,
    //                 null,
    //                 null,
    //                 v.ID,
    //                 path + ' > ' + ap.Name + ' > ' + v.Name,
    //                 existingMap,
    //                 upsertMap,
    //                 integrationChannelId
    //             );
    //         }
    //     }
    // }
   

    // --------------------------------------------------------------------------------
    // Unified UPSERT helper
    // --------------------------------------------------------------------------------
    private static void upsertNode(
    String srcType,
    String srcId,
    String parentId,
    String name,
    String nameVN,
    String fieldType,
    Boolean mandatory,
    String enumValue,
    String fullPath,
    Map<String, FEC_Master_Data_Integration__c> existingMap,
    Map<String, FEC_Master_Data_Integration__c> upsertMap,
    String integrationChannelId,
    String applyTo,
    Integer posOrder
    ) {
        String key = srcType + '|' + srcId + '|' + parentId;
        FEC_Master_Data_Integration__c rec;

        if (existingMap.containsKey(key)) {
            rec = existingMap.get(key);
        } else {
            rec = new FEC_Master_Data_Integration__c();
            rec.FEC_Source_Type__c = srcType;
            rec.FEC_Source_Id__c = srcId;
            rec.FEC_Source_Parent_Id__c = parentId;
        }

        rec.FEC_Source_Name__c = name;
        rec.FEC_Source_NameVN__c = nameVN;
        rec.FEC_Source_Field_Type__c = fieldType;

        // ************* FIX START *************
        // Always enforce boolean
        if (mandatory == null) {
            rec.FEC_Source_Is_Mandatory__c = false;
        } else {
            rec.FEC_Source_Is_Mandatory__c = mandatory;
        }
        // ************* FIX END *************

        rec.FEC_Source_Enum_Value__c = enumValue;
        rec.FEC_Source_Path__c = fullPath;
        rec.FEC_Channel__c = integrationChannelId;
        rec.FEC_ApplyTo__c = applyTo;
        rec.FEC_PosOrder__c = posOrder;

        upsertMap.put(key, rec);
    }

    // --------------------------------------------------------------------------------
    // Helpers
    // --------------------------------------------------------------------------------
    private static String text(Dom.XmlNode parent, String name) {
        for (Dom.XmlNode c : parent.getChildElements())
            if (c.getName() == name) return c.getText();
        return null;
    }
    private static Dom.XmlNode getChildIgnoreNS(Dom.XmlNode node, String name) {
        for (Dom.XmlNode c : node.getChildElements())
            if (c.getName() == name ||
                (c.getName().contains(':') && c.getName().endsWith(name)))
                return c;
        return null;
    }
    private static Dom.XmlNode findChildByEndsWith(Dom.XmlNode node, String suffix) {
        for (Dom.XmlNode c : node.getChildElements())
            if (c.getName().endsWith(suffix)) return c;
        return null;
    }
    private static String getIntegrationChannelCode(String code) {
        List<FEC_Case_Channel__c> chs = [
            SELECT FEC_Alias__c, FEC_Code__c
            FROM FEC_Case_Channel__c
            WHERE FEC_Status__c = true
        ];

        for (FEC_Case_Channel__c c : chs) {
            if (c.FEC_Code__c == code) return c.FEC_Code__c;
        }
        return null;
    }
}