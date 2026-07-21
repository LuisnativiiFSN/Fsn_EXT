/// <summary>
/// Page Tester PreBiller (ID 50089).
/// </summary>

/*page 50088 "Tester PreBiller"
{
    ApplicationArea = All;
    Caption = 'Tester Prebiller WS';
    PageType = Card;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(RunProcess_Content)
            {
                Caption = 'RunProcess';
                Visible = RunProcess_Band;
                field(arrItem; arrItem)
                {
                    ApplicationArea = All;
                    Caption = 'arrItem';
                    MultiLine = true;
                    ToolTip = 'JSon Array of Items';

                    trigger onvalidate()
                    var
                        jarr: JsonArray;
                    begin
                        if not jarr.ReadFrom(arrItem) then
                            Error('Invalid JSON');
                    end;
                }
                field(ArrDescription; ArrDescription)
                {
                    ApplicationArea = All;
                    Caption = 'ArrDescription';
                    MultiLine = true;
                    ToolTip = 'JSon Array of Description';

                    trigger onvalidate()
                    var
                        jarr: JsonArray;
                    begin
                        if not jarr.ReadFrom(ArrDescription) then
                            Error('Invalid JSON');
                    end;
                }
                field(ArrUOM; ArrUOM)
                {
                    ApplicationArea = All;
                    Caption = 'ArrUnitOfMeasure';
                    MultiLine = true;
                    ToolTip = 'JSon Array of UOM';

                    trigger onvalidate()
                    var
                        jarr: JsonArray;
                    begin
                        if not jarr.ReadFrom(ArrUOM) then
                            Error('Invalid JSON');
                    end;
                }
                field(ArrQty; ArrQty)
                {
                    ApplicationArea = All;
                    Caption = 'ArrQuantity';
                    MultiLine = true;
                    ToolTip = 'JSon Array of Quantity';

                    trigger onvalidate()
                    var
                        jarr: JsonArray;
                    begin
                        if not jarr.ReadFrom(arrQty) then
                            Error('Invalid JSON');
                    end;
                }
                field(ArrEntryType; ArrEntryType)
                {
                    ApplicationArea = All;
                    Caption = 'ArrEntryType';
                    MultiLine = true;
                    ToolTip = 'JSon Array of EntryType';

                    trigger onvalidate()
                    var
                        jarr: JsonArray;
                    begin
                        if not jarr.ReadFrom(ArrEntryType) then
                            Error('Invalid JSON');
                    end;
                }
                field(StoreNoRunProcess; StoreNo)
                {
                    ApplicationArea = All;
                    Caption = 'Store No';
                }
                field(TerminalRunProcess; TerminalNo)
                {
                    ApplicationArea = All;
                    Caption = 'Terminal No';
                }
                field(StaffRunProcess; Staff)
                {
                    ApplicationArea = All;
                    Caption = 'Staff';
                }
                field(ManagerKey; ManagerKey)
                {
                    ApplicationArea = All;
                    Caption = 'Manager Key';
                }
                field(CustomerNoRunProcess; CustomerNo)
                {
                    ApplicationArea = All;
                    Caption = 'Customer No';
                }
                field(MemberCardRunProcess; MemberCard)
                {
                    ApplicationArea = All;
                    Caption = 'Member Card';
                }
                field(SchemeCodeRunProcess; SchemeCode)
                {
                    ApplicationArea = All;
                    Caption = 'Scheme Code';
                }
                field(PointsRunProcess; Points)
                {
                    ApplicationArea = All;
                    Caption = 'Points';
                }
                field(ReqFromID; ReqFromID)
                {
                    ApplicationArea = All;
                    Caption = 'ReqFromID';
                }
                field(ArrPrice; ArrPrice)
                {
                    ApplicationArea = All;
                    Caption = 'ArrPrice';
                    MultiLine = true;
                    ToolTip = 'JSon Array of Price';

                    trigger onvalidate()
                    var
                        jarr: JsonArray;
                    begin
                        if not jarr.ReadFrom(ArrPrice) then
                            Error('Invalid JSON');
                    end;
                }
                field(ArrDiscount; ArrDiscount)
                {
                    ApplicationArea = All;
                    Caption = 'ArrDiscount';
                    MultiLine = true;
                    ToolTip = 'JSon Array of Discount';

                    trigger onvalidate()
                    var
                        jarr: JsonArray;
                    begin
                        if not jarr.ReadFrom(ArrDiscount) then
                            Error('Invalid JSON');
                    end;
                }
                field(ArrAmount; ArrAmount)
                {
                    ApplicationArea = All;
                    Caption = 'ArrAmount';
                    MultiLine = true;
                    ToolTip = 'JSon Array of Amount';

                    trigger onvalidate()
                    var
                        jarr: JsonArray;
                    begin
                        if not jarr.ReadFrom(ArrAmount) then
                            Error('Invalid JSON');
                    end;
                }
                field(ArrEffDisc; ArrEffDisc)
                {
                    ApplicationArea = All;
                    Caption = 'ArrEffDisc';
                    MultiLine = true;
                    ToolTip = 'JSon Array of EffDisc';

                    trigger onvalidate()
                    var
                        jarr: JsonArray;
                    begin
                        if not jarr.ReadFrom(ArrEffDisc) then
                            Error('Invalid JSON');
                    end;
                }
                field(ArrEffAmount; ArrEffAmount)
                {
                    ApplicationArea = All;
                    Caption = 'ArrEffAmount';
                    MultiLine = true;
                    ToolTip = 'JSon Array of EffAmount';

                    trigger onvalidate()
                    var
                        jarr: JsonArray;
                    begin
                        if not jarr.ReadFrom(ArrEffAmount) then
                            Error('Invalid JSON');
                    end;
                }
                field(TotalAmount; TotalAmount)
                {
                    ApplicationArea = All;
                    Caption = 'Total Amount';
                }
                field(TotalDiscount; TotalDiscount)
                {
                    ApplicationArea = All;
                    Caption = 'Total Discount';
                }
                field(Balance; Balance)
                {
                    ApplicationArea = All;
                    Caption = 'Balance';
                }
                Field(BalanceVIP; BalanceVIP)
                {
                    ApplicationArea = All;
                    Caption = 'Balance VIP';
                }
                field(resRunProcess; res)
                {
                    ApplicationArea = All;
                    Caption = 'Response';
                    MultiLine = true;
                }
                field(CodeRunProcess; Code)
                {
                    ApplicationArea = All;
                    Caption = 'Code';
                }
                field(OnlyCalc; OnlyCalc)
                {
                    ApplicationArea = All;
                    Caption = 'OnlyCalc';
                }
            }
            group(GetItemByKey_Content)
            {
                Caption = 'GetItemByKey';
                Visible = GetItemByKey_Band;
                field(ItemCode; ItemCode)
                {
                    ApplicationArea = All;
                    Caption = 'Item Code';
                }
                field(res; res)
                {
                    ApplicationArea = All;
                    Caption = 'Response';
                    MultiLine = true;
                }
                field(Code; Code)
                {
                    ApplicationArea = All;
                    Caption = 'Code';
                }
            }
            group(MemberManagement_Content)
            {
                Caption = 'MemberManagement';
                Visible = MemberManagement_Band;
                field(MemberCard; MemberCard)
                {
                    ApplicationArea = All;
                    Caption = 'Member Card';
                }
                field(ClubCode; ClubCode)
                {
                    ApplicationArea = All;
                    Caption = 'Club Code';
                }
                field(SchemeCode; SchemeCode)
                {
                    ApplicationArea = All;
                    Caption = 'Scheme Code';
                }
                field(CustomerNo; CustomerNo)
                {
                    ApplicationArea = All;
                    Caption = 'Customer No';
                }
                field(TerminalNo; TerminalNo)
                {
                    ApplicationArea = All;
                    Caption = 'Terminal No';
                }
                field(IDAccountSuggest; IDAccountSuggest)
                {
                    ApplicationArea = All;
                    Caption = 'ID Account Suggest';
                }
                field(Beneficiary; Beneficiary)
                {
                    ApplicationArea = All;
                    Caption = 'Beneficiary';
                }
                field(Action; Action)
                {
                    ApplicationArea = All;
                    Caption = 'Action';
                }
                field(Staff; Staff)
                {
                    ApplicationArea = All;
                    Caption = 'Staff';
                }
                field(Response_Code; Code)
                {
                    ApplicationArea = All;
                    Caption = 'Response Code';
                }
                field(Response_Text; res)
                {
                    ApplicationArea = All;
                    Caption = 'Response Text';
                    MultiLine = true;
                }
            }
            group(GetMemberInfo_Content)
            {
                Caption = 'GetMemberInfo';
                Visible = GetMemberInfo_Band;
                field(DUI; DUI)
                {
                    ApplicationArea = All;
                    Caption = 'DUI';
                }
                field(CardMemberInfo; MemberCard)
                {
                    ApplicationArea = All;
                    Caption = 'Member Card';
                }
                field(LastMemberCard; LastMemberCard)
                {
                    ApplicationArea = All;
                    Caption = 'Last Member Card';
                }
                field(LastValidDate; LastValidDate)
                {
                    ApplicationArea = All;
                    Caption = 'Last Valid Date';
                }
                field(CalculatePoints; CalculatePoints)
                {
                    ApplicationArea = All;
                    Caption = 'Calculate Points';
                }
                field(Points; Points)
                {
                    ApplicationArea = All;
                    Caption = 'Points';
                }
                field(CodeMemberInfo; Code)
                {
                    ApplicationArea = All;
                    Caption = 'Response Code';
                }
                field(ResMemberInfo; res)
                {
                    ApplicationArea = All;
                    Caption = 'Response Text';
                    MultiLine = true;
                }
            }
            group(CustomerManagement_Content)
            {
                Caption = 'CustomerManagement';
                Visible = CustomerManagement_Band;

                field(StoreNo; StoreNo)
                {
                    ApplicationArea = All;
                    Caption = 'Store No';
                }
                field(Terminal_CustMgt; TerminalNo)
                {
                    ApplicationArea = All;
                    Caption = 'Terminal No';
                }
                field(_Code; _Code)
                {
                    ApplicationArea = All;
                    Caption = 'Code';
                }
                field(Name; Name)
                {
                    ApplicationArea = All;
                    Caption = 'Name';
                }
                field(DUICustMgt; DUI)
                {
                    ApplicationArea = All;
                    Caption = 'DUI';
                }
                field(TaxID; TaxID)
                {
                    ApplicationArea = All;
                    Caption = 'Tax ID';
                }
                field(Phone; Phone)
                {
                    ApplicationArea = All;
                    Caption = 'Phone';
                }
                field(Phone2; Phone2)
                {
                    ApplicationArea = All;
                    Caption = 'Phone 2';
                }
                field(Birthdate; Birthdate)
                {
                    ApplicationArea = All;
                    Caption = 'Birthdate';
                }
                field(ClientType; ClientType)
                {
                    ApplicationArea = All;
                    Caption = 'Client Type';
                }
                field(Gender; Gender)
                {
                    ApplicationArea = All;
                    Caption = 'Gender';
                }
                field(Email; Email)
                {
                    ApplicationArea = All;
                    Caption = 'Email';
                }
                field(Address; Address)
                {
                    ApplicationArea = All;
                    Caption = 'Address';
                }
                field(City; City)
                {
                    ApplicationArea = All;
                    Caption = 'City';
                }
                field(NIT; NIT)
                {
                    ApplicationArea = All;
                    Caption = 'NIT';
                }
                field(NRC; NRC)
                {
                    ApplicationArea = All;
                    Caption = 'NRC';
                }
                field(Giro; Giro)
                {
                    ApplicationArea = All;
                    Caption = 'Giro';
                }
                field(ExtrageroNo; ExtrageroNo)
                {
                    ApplicationArea = All;
                    Caption = 'Extragero No';
                }
                field(resCustMgt; res)
                {
                    ApplicationArea = All;
                    Caption = 'Response Text';
                    MultiLine = true;
                }
                field(CodeCustMgt; Code)
                {
                    ApplicationArea = All;
                    Caption = 'Response Code';
                }
                field(ActionCustMgt; Action)
                {
                    ApplicationArea = All;
                    Caption = 'Action';
                }
                field(_Trigger; _Trigger)
                {
                    ApplicationArea = All;
                    Caption = 'Trigger';
                }
            }
            group(GetItemList_Content)
            {
                Caption = 'GetItemList';
                Visible = GetItemList_Band;

                field(Json; Json)
                {
                    ApplicationArea = All;
                    Caption = 'Json';
                    MultiLine = true;
                }
                field(resItemList; res)
                {
                    ApplicationArea = All;
                    Caption = 'Response Text';
                    MultiLine = true;
                }
                field(CodeItemList; Code)
                {
                    ApplicationArea = All;
                    Caption = 'Response Code';
                }
            }
            group(GetCustomerList_Content)
            {
                Caption = 'GetCustomerList';
                Visible = GetCustomerList_Band;

                field(JsonCustList; Json)
                {
                    ApplicationArea = All;
                    Caption = 'Json';
                    MultiLine = true;
                }
                field(resCustomerList; res)
                {
                    ApplicationArea = All;
                    Caption = 'Response Text';
                    MultiLine = true;
                }
            }
            group(GetMemberCardsByCust_Content)
            {
                Caption = 'GetMemberCardsByCust';
                Visible = GetMemberCardsByCust_Band;

                field(CustomerNoGetMemberCard; CustomerNo)
                {
                    ApplicationArea = All;
                    Caption = 'Customer No';
                }
                field(resMemberCards; res)
                {
                    ApplicationArea = All;
                    Caption = 'Response Text';
                    MultiLine = true;
                }
            }
            group(getDistrict_Content)
            {
                Visible = GetDistrict_Band;

                grid(districtGrid)
                {
                    Caption = 'District';
                    field(districtCode; districtCode)
                    {
                        ApplicationArea = All;
                        Caption = 'District Code';
                        Style = StrongAccent;
                        MultiLine = true;
                    }
                    field(districtName; districtName)
                    {
                        ApplicationArea = All;
                        Caption = 'District Name';
                        MultiLine = true;
                    }

                }
            }
            group(WsXmlStandard_Content)
            {
                Visible = WsXmlStandard_Band;
                field(WSXmlStandart; Xml)
                {
                    ApplicationArea = All;
                    Caption = 'XmlRequest';
                    MultiLine = true;
                }
                field(WSXmlStandartResponse; res)
                {
                    ApplicationArea = All;
                    Caption = 'XmlResponse';
                    MultiLine = true;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            group(RunProcess_Actions)
            {
                Caption = 'RunProcess';
                action("RunProcess_Test")
                {
                    ApplicationArea = All;
                    Caption = 'Test Endpoint';

                    trigger OnAction()
                    var
                        jarray: JsonArray;
                        _arrItem, _arrDesc, _arrUOM : array[50] of Code[100];
                        _arrQty, _arrEntryType : array[50] of Integer;
                        _arrPrice, _arrDisc, _arrAmt, _arreffAmt, _arreffDisc : array[50] of Decimal;
                    begin
                        if not RunProcess_Band then
                            Error(ErrorInfoText);

                        //process array of items
                        jarray.ReadFrom(arrItem);
                        ProcessJsonArrayCode(jarray, _arrItem);
                        Clear(jarray);

                        //process array of descriptions
                        jarray.ReadFrom(ArrDescription);
                        ProcessJsonArrayCode(jarray, _arrDesc);
                        Clear(jarray);

                        //process array of UOM
                        jarray.ReadFrom(ArrUOM);
                        ProcessJsonArrayCode(jarray, _arrUOM);
                        Clear(jarray);

                        //process array of Qty
                        jarray.ReadFrom(ArrQty);
                        ProcessJsonArrayInt(jarray, _arrQty);
                        Clear(jarray);

                        //process array of EntryType
                        jarray.ReadFrom(ArrEntryType);
                        ProcessJsonArrayInt(jarray, _arrEntryType);
                        Clear(jarray);

                        //process array of Price
                        jarray.ReadFrom(ArrPrice);
                        ProcessJsonArrayDecimal(jarray, _arrPrice);
                        Clear(jarray);

                        //process array of Discount
                        jarray.ReadFrom(ArrDiscount);
                        ProcessJsonArrayDecimal(jarray, _arrDisc);
                        Clear(jarray);

                        //process array of Amount
                        jarray.ReadFrom(ArrAmount);
                        ProcessJsonArrayDecimal(jarray, _arrAmt);
                        Clear(jarray);

                        //process array of Effective Amount
                        jarray.ReadFrom(ArrEffAmount);
                        ProcessJsonArrayDecimal(jarray, _arreffAmt);
                        Clear(jarray);

                        //process array of Effective Discount
                        jarray.ReadFrom(ArrEffDisc);
                        ProcessJsonArrayDecimal(jarray, _arreffDisc);
                        Clear(jarray);

                        Return := wsprefac.RunProcess(_arrItem, _arrDesc, _arrUOM, _arrQty, _arrEntryType, StoreNo, TerminalNo, Staff, ManagerKey, CustomerNo, MemberCard, SchemeCode, Points, ReqFromID, _arrPrice, _arrDisc, _arrAmt, _arreffDisc, _arreffAmt, TotalAmount, TotalDiscount, Balance, BalanceVIP, Code, res, OnlyCalc);

                        jsonIntToText(ArrQty, _arrQty);
                        jsonIntToText(ArrEntryType, _arrEntryType);
                        jsonDecimalToText(ArrPrice, _arrPrice);
                        jsonDecimalToText(ArrDiscount, _arrDisc);
                        jsonDecimalToText(ArrAmount, _arrAmt);
                        jsonDecimalToText(ArrEffDisc, _arreffDisc);
                        jsonDecimalToText(ArrEffAmount, _arreffAmt);

                        Message(StrSubstNo('Return: %1', Return));
                    end;
                }
                action("RunProcess_Show")
                {
                    ApplicationArea = All;
                    Caption = 'Show Endpoint';

                    trigger OnAction()
                    begin
                        ChangeVisible(Endpoints::RunProcess);
                    end;
                }
            }
            group(GetItemByKey_Actions)
            {
                Caption = 'GetItemByKey';
                action("GetItemByKey_Test")
                {
                    ApplicationArea = All;
                    Caption = 'Test Endpoint';

                    trigger OnAction()
                    begin
                        if not GetItemByKey_Band then
                            Error(ErrorInfoText);

                        wsprefac.GetItemByKey(ItemCode, res, Code);
                    end;
                }
                action("GetItemByKey_Show")
                {
                    ApplicationArea = All;
                    Caption = 'Show Endpoint';

                    trigger OnAction()
                    begin
                        ChangeVisible(Endpoints::GetItemByKey);
                    end;
                }
            }
            group(MemberManagement_Actions)
            {
                Caption = 'MemberManagement';
                action("MemberManagement_Test")
                {
                    ApplicationArea = All;
                    Caption = 'Test Endpoint';

                    trigger OnAction()
                    begin
                        if not MemberManagement_Band then
                            Error(ErrorInfoText);

                        return := wsprefac.MemberManagement(MemberCard, ClubCode, SchemeCode, CustomerNo, TerminalNo, IDAccountSuggest, Beneficiary, Action, Staff, res, Code);

                        Message(StrSubstNo('Return: %1', Return));
                    end;
                }
                action("MemberManagement_Show")
                {
                    ApplicationArea = All;
                    Caption = 'Show Endpoint';

                    trigger OnAction()
                    begin
                        ChangeVisible(Endpoints::MemberManagement);
                    end;
                }
            }
            group(GetMemberInfo_Actions)
            {
                Caption = 'GetMemberInfo';
                action("GetMemberInfo_Test")
                {
                    ApplicationArea = All;
                    Caption = 'Test Endpoint';

                    trigger OnAction()
                    begin
                        if not GetMemberInfo_Band then
                            Error(ErrorInfoText);

                        wsprefac.GetMemberInfo(DUI, MemberCard, LastMemberCard, LastValidDate, CalculatePoints, Points, Code, res);
                    end;
                }
                action("GetMemberInfo_Show")
                {
                    ApplicationArea = All;
                    Caption = 'Show Endpoint';

                    trigger OnAction()
                    begin
                        ChangeVisible(Endpoints::GetMemberInfo);
                    end;
                }
            }
            group(CustomerManagement_Actions)
            {
                Caption = 'CustomerManagement';
                action(CustomerManagement_Test)
                {
                    ApplicationArea = All;
                    Caption = 'Test Endpoint';

                    trigger OnAction()
                    begin
                        if not CustomerManagement_Band then
                            Error(ErrorInfoText);

                        //return := wsprefac.CustomerManagement(StoreNo, TerminalNo, _Code, Name, DUI, TaxID, Phone, Phone2, Birthdate, ClientType, Gender, Email, Address, City, NIT, NRC, Giro, ExtrageroNo, Code, res, Action, _Trigger);

                        Message(StrSubstNo('Return: %1', Return));
                    end;
                }
                action(CustomerManagement_Show)
                {
                    ApplicationArea = All;
                    Caption = 'Show Endpoint';

                    trigger OnAction()
                    begin
                        ChangeVisible(Endpoints::CustomerManagement);
                    end;
                }
            }
            group(GetItemList_Actions)
            {
                Caption = 'GetItemList';
                action("GetItemList_Test")
                {
                    ApplicationArea = All;
                    Caption = 'Test Endpoint';

                    trigger OnAction()
                    begin
                        if not GetItemList_Band then
                            Error(ErrorInfoText);

                        wsprefac.GetItemList(Json, res, Code);
                    end;
                }
                action("GetItemList_Show")
                {
                    ApplicationArea = All;
                    Caption = 'Show Endpoint';

                    trigger OnAction()
                    begin
                        ChangeVisible(Endpoints::GetItemList);
                    end;
                }
            }
            group(GetCustomerList_Actions)
            {
                Caption = 'GetCustomerList';
                action("GetCustomerList_Test")
                {
                    ApplicationArea = All;
                    Caption = 'Test Endpoint';

                    trigger OnAction()
                    begin
                        if not GetCustomerList_Band then
                            Error(ErrorInfoText);

                        wsprefac.GetCustomerList(Json, res);
                    end;
                }
                action("GetCustomerList_Show")
                {
                    ApplicationArea = All;
                    Caption = 'Show Endpoint';

                    trigger OnAction()
                    begin
                        ChangeVisible(Endpoints::GetCustomerList);
                    end;
                }
            }
            group(GetMemberCardsByCust_Actions)
            {
                Caption = 'GetMemberCardsByCust';
                action("GetMemberCardsByCust_Test")
                {
                    ApplicationArea = All;
                    Caption = 'Test Endpoint';

                    trigger OnAction()
                    begin
                        if not GetMemberCardsByCust_Band then
                            Error(ErrorInfoText);

                        wsprefac.GetMemberCardsByCust(CustomerNo, res);
                    end;
                }
                action("GetMemberCardsByCust_Show")
                {
                    ApplicationArea = All;
                    Caption = 'Show Endpoint';

                    trigger OnAction()
                    begin
                        ChangeVisible(Endpoints::GetMemberCardsByCust);
                    end;
                }
            }
            group(getDistrict_Actions)
            {
                Caption = 'getDistrict';
                action("getDistrict_Test")
                {
                    ApplicationArea = All;
                    Caption = 'Test Endpoint';

                    trigger OnAction()
                    begin
                        if not getDistrict_Band then
                            Error(ErrorInfoText);

                        json := wsprefac.getDistrict();
                        jarray.ReadFrom(json);
                        //set data in grid from json
                        foreach jtoken in jarray do begin
                            jobject := jtoken.AsObject();
                            //set data in grid from json
                            jObject.SelectToken('code', jtoken);
                            districtCode += StrSubstNo('%1\', jtoken.AsValue().AsText());

                            jObject.SelectToken('district', jtoken);
                            districtName += StrSubstNo('%1\', jtoken.AsValue().AsText());
                        end;
                    end;
                }
                action("getDistrict_Show")
                {
                    ApplicationArea = All;
                    Caption = 'Show Endpoint';

                    trigger OnAction()
                    begin
                        ChangeVisible(Endpoints::getDistrict);
                    end;
                }
            }
            group(WsXmlStandard_Actions)
            {
                Caption = 'WsXmlStandard';
                action("WsXmlStandart_Test")
                {
                    ApplicationArea = All;
                    Caption = 'Test Endpoint';

                    trigger OnAction()
                    var
                        id: Text;
                    begin
                        id := 'FSN_POST_REMISSION';
                        if not WsXmlStandard_Band then
                            Error(ErrorInfoText);

                        wsprefac.WSXMLStandar(Xml, res, id);
                    end;
                }
                action("WsXmlStandart_Show")
                {
                    ApplicationArea = All;
                    Caption = 'Show Endpoint';

                    trigger OnAction()
                    begin
                        ChangeVisible(Endpoints::WsXmlStandard);
                    end;
                }
            }
        }
    }

    var
        #region response
        res: Text;
        Code: Text;
        #endregion
        #region Store
        StoreNo: Code[10];
        TerminalNo: Code[10];
        Staff: Code[20];
        ManagerKey: Code[20];
        #endregion
        #region MemberCard
        MemberCard: Text[100];
        LastMemberCard: Text[100];
        LastValidDate: Text[20];
        CalculatePoints: Boolean;
        Points: Decimal;
        SchemeCode: Code[10];
        ClubCode: Code[10];
        Beneficiary: Text[100];
        #endregion
        #region Customer
        CustomerNo: Code[20];
        Name: Text[50];
        DUI: Code[20];
        TaxID: Integer;
        Phone: Text[30];
        Phone2: Text[20];
        Birthdate: Date;
        ClientType: Integer;
        Gender: Integer;
        Email: Text[100];
        Address: Text[100];
        City: Text[100];
        NIT: Text[30];
        NRC: Text[30];
        Giro: Text[120];
        ExtrageroNo: Code[20];
        #endregion
        ItemCode: Code[20];
        _Code: Code[20];
        IDAccountSuggest: Code[20];
        Action: Integer;
        _Trigger: Boolean;
        ArrItem: Text;
        ArrDescription: Text;
        ArrUOM: Text;
        ArrQty: Text;
        ArrEntryType: Text;
        ArrPrice: Text;
        ArrDiscount: Text;
        ArrAmount: Text;
        ArrEffDisc: Text;
        ArrEffAmount: Text;
        ReqFromID: Code[20];
        districtCode: Text;
        districtName: Text;
        TotalAmount: Decimal;
        TotalDiscount: Decimal;
        Balance: Decimal;
        BalanceVIP: Decimal;
        OnlyCalc: Boolean;
        Json, Xml : Text;
        jobject: JsonObject;
        jtoken: JsonToken;
        jarray: JsonArray;

        #region band variables
        RunProcess_Band: Boolean;
        GetItemByKey_Band: Boolean;
        MemberManagement_Band: Boolean;
        GetMemberInfo_Band: Boolean;
        CustomerManagement_Band: Boolean;
        GetItemList_Band: Boolean;
        GetCustomerList_Band: Boolean;
        GetMemberCardsByCust_Band: Boolean;
        GetDistrict_Band: Boolean;
        WsXmlStandard_Band: Boolean;
        #endregion
        #region control variables
        wsprefac: codeunit "FSN WS Prefacturador";
        Endpoints: Enum "Prebiller endpoints";
        #endregion
        ErrorInfoText: Label 'You must show the endpoint before testing it.';
        Return: Variant;

    local procedure ChangeVisible(option: Enum "Prebiller endpoints")
    begin
        ClearAll();

        case option of
            option::GetItemByKey:
                GetItemByKey_Band := true;
            option::MemberManagement:
                MemberManagement_Band := true;
            option::GetMemberInfo:
                GetMemberInfo_Band := true;
            option::CustomerManagement:
                CustomerManagement_Band := true;
            option::RunProcess:
                RunProcess_Band := true;
            option::GetItemList:
                GetItemList_Band := true;
            option::GetCustomerList:
                GetCustomerList_Band := true;
            option::GetMemberCardsByCust:
                GetMemberCardsByCust_Band := true;
            option::getDistrict:
                getDistrict_Band := true;
            option::WsXmlStandard:
                WsXmlStandard_Band := true;
        end;
    end;

    local procedure ProcessJsonArrayCode(jArray: JsonArray; var Array: array[50] of Code[100])
    var
        i: Integer;
        jObject: JsonToken;
    begin
        i := 1;
        foreach JObject in jArray do begin
            if i > 50 then
                exit;
            Array[i] := JObject.AsValue().AsCode();
            i += 1;
        end;
    end;

    local procedure ProcessJsonArrayDecimal(jArray: JsonArray; var Array: array[50] of Decimal)
    var
        i: Integer;
        jObject: JsonToken;
    begin
        i := 1;
        foreach JObject in jArray do begin
            if i > 50 then
                exit;
            Array[i] := JObject.AsValue().AsDecimal();
            i += 1;
        end;
    end;

    local procedure ProcessJsonArrayInt(jArray: JsonArray; var Array: array[50] of Integer)
    var
        i: Integer;
        jObject: JsonToken;
    begin
        i := 1;
        foreach JObject in jArray do begin
            if i > 50 then
                exit;
            Array[i] := JObject.AsValue().AsInteger();
            i += 1;
        end;
    end;

    local procedure jsonIntToText(var text: Text; Array: array[50] of Integer)
    var
        i: Integer;
    begin
        text := '[';
        for i := 1 to 50 do begin
            if Array[i] <> 0 then
                text += StrSubstNo('%1,', Array[i]);
        end;
        text := CopyStr(text, 1, StrLen(text) - 1);
        text += ']';
    end;

    local procedure jsonDecimalToText(var text: Text; Array: array[50] of Decimal)
    var
        i: Integer;
    begin
        text := '[';
        for i := 1 to 50 do begin
            if Array[i] <> 0 then
                text += StrSubstNo('%1,', Array[i]);
        end;
        text := CopyStr(text, 1, StrLen(text) - 1);
        text += ']';
    end;
}*/