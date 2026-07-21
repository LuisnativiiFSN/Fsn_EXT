page 50095 "DTE POS Customer"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = Customer;
    Editable = true;
    DeleteAllowed = false;
    //InsertAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    CardPageId = 50096;
    //SourceTableTemporary = true;


    layout
    {
        area(Content)
        {
            field(typeFilter; typeFilter)
            {
                ApplicationArea = all;
            }
            field(filtro; filtro)
            {
                ApplicationArea = all;
                trigger OnValidate()
                var
                    repeatrecord: Boolean;
                begin
                    //Customer.Reset();

                    //Rec.Reset();
                    //Rec.DeleteAll(false);
                    //Rec.init;
                    //Clear(Rec);
                    Rec.Reset();
                    FilterGroup(0);
                    //repeatrecord := false;
                    case typeFilter of
                        typefilter::Codigo:
                            begin
                                Rec.SetRange("No.", filtro);
                                //Customer.SetRange("No.", filtro);
                                if Rec.FindFirst() then;
                            end;
                        typefilter::"Doc.Extranjero":
                            begin
                                Rec.SetRange("FSN Foreign document", filtro);
                                //Customer.SetRange("FSN Foreign document", filtro);
                                if Rec.FindFirst() then;
                            end;
                        typefilter::DUI:
                            begin
                                Rec.SetCurrentKey("FSN DUI");
                                Rec.SetRange("FSN DUI", filtro);
                                //Customer.SetRange("FSN DUI", filtro);
                                if Rec.FindFirst() then;
                            end;
                        typefilter::NIT:
                            begin
                                Rec.SetRange("VAT Registration No.", filtro);
                                //Customer.SetRange("VAT Registration No.", filtro);
                                if Rec.FindFirst() then;
                            end;
                        typefilter::Nombre:
                            begin
                                Rec.SetCurrentKey("Search Name");
                                Rec.SetFilter("Search Name", '*' + UpperCase(filtro) + '*');
                                if Rec.find('-') then;

                                //Customer.SetFilter("Search Name", '*' + UpperCase(filtro) + '*');
                            end;
                        typefilter::NRC:
                            begin
                                Rec.SetRange("FSN NRC", filtro);
                                if Rec.FindFirst() then;
                                //Customer.SetRange("FSN NRC", filtro);
                            end;
                        typefilter::Telefono:
                            begin
                                Rec.SetRange("Phone No.", filtro);
                                if Rec.FindFirst() then;
                                //Customer.SetRange("Phone No.", filtro);
                            end;
                    end;

                    FilterGroup(-1);
                    /*if Customer.Find('-') then
                        repeat
                            Rec.Init();
                            Rec := Customer;
                            Rec.Insert();
                        until Customer.Next() = 0;
                    CurrPage.Update();
                    */
                end;
            }
            repeater(Customer)
            {
                field("No."; "No.") { ApplicationArea = All; Editable = false; }
                field(Name; Name) { ApplicationArea = All; Editable = false; }
                field("DTE Tax ID Type"; "DTE Tax ID Type") { ApplicationArea = All; Editable = false; Caption = 'Doc. Tributario'; }
                field("FSN DUI"; "FSN DUI") { ApplicationArea = All; Editable = false; }
                field("FSN Foreign document"; "FSN Foreign document") { ApplicationArea = All; Editable = false; }
                field("VAT Registration No."; "VAT Registration No.") { ApplicationArea = All; Caption = 'NIT'; Editable = false; }
                //field("FSN Birthday"; "FSN Birthday") { ApplicationArea = All; }
                //field("FSN Gender"; "FSN Gender") { ApplicationArea = All; }
                field("Phone No."; "Phone No.") { ApplicationArea = All; Editable = false; }
                //field("Mobile Phone No."; "Mobile Phone No.") { ApplicationArea = All; }
                //field(Address; Address) { ApplicationArea = All; }
                //field("Post Code"; "Post Code") { ApplicationArea = All; }
                field("FSN NRC"; "FSN NRC") { ApplicationArea = All; Editable = false; }
                field(City; City) { ApplicationArea = All; Editable = false; Caption = 'Ciudad'; }
                //field("DTE Activity Code"; "DTE Activity Code") { ApplicationArea = All; }

            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SELECCIONAR)
            {
                Promoted = true;
                Caption = 'SELECCIONAR';
                PromotedIsBig = true;
                Image = Customer;
                PromotedCategory = Process;
                ApplicationArea = All;
                trigger OnAction()
                var
                    session: Codeunit "LSC POS Session";
                    POSTransactionCode: Codeunit "LSC POS Transaction";
                    MemberAcc: Record "LSC Member Account";
                    MemberShip: Record "LSC Membership Card";
                    MemberShipTem: Record "LSC Membership Card" temporary;
                    PTL: Record "LSC POS Trans. Line";
                    PT: Record "LSC POS Transaction";
                    CurrInput: Text[100];
                    Ok: Boolean;
                    pCustCardDTE: Page "DTE POS Customer Card";
                begin
                    MemberShipTem.Reset();
                    Clear(MemberShipTem);
                    Clear(CurrInput);
                    Clear(Ok);
                    MemberAcc.Reset();
                    MemberAcc.SetRange("Linked To Customer No.", Rec."No.");
                    if MemberAcc.Find('-') then begin
                        MemberShip.Reset();
                        MemberShip.SetRange("Account No.", MemberAcc."No.");
                        if MemberShip.Find('-') then
                            repeat
                                if (MemberShip."Last Valid Date" >= Today) and MemberShip."Linked to Account" then begin

                                    if Rec."Customer Disc. Group" <> 'VIP' then begin
                                        Rec."Customer Disc. Group" := 'VIP';
                                        Rec.Modify();
                                        IF Rec.get(Rec."No.") then;
                                    end;

                                    MemberShipTem.Init();
                                    MemberShipTem := MemberShip;
                                    MemberShipTem.Insert();
                                end;
                            until MemberShip.Next() = 0;

                        MemberShipTem.Reset();
                        MemberShipTem.SetCurrentKey("Last Valid Date");
                        if MemberShipTem.Find('+') then
                            CurrInput := MemberShipTem."Card No.";
                        if CurrInput <> '' then begin
                            POSTransactionCode.SetCurrInput(CurrInput);
                            Ok := POSTransactionCode.CheckMemberCard();
                            CurrInput := '';
                            POSTransactionCode.SetCurrInput(CurrInput);
                        end;
                        if Ok then begin
                            CurrPage.Close();
                            exit;
                        end;

                    end;

                    PTL.Reset();
                    PTL.SetRange("Receipt No.", POSTransactionCode.GetReceiptNo());
                    PTL.SetRange("Entry Type", PTL."Entry Type"::FreeText);
                    PTL.SetRange("Text Type", PTL."Text Type"::"Member Text");
                    PTL.DeleteAll();
                    IF PT.Get(POSTransactionCode.GetReceiptNo()) THEN begin
                        PT."Member Card No." := '';
                        PT."Starting Point Balance" := 0;
                        PT.Modify(true);
                    end;
                    POSTransactionCode.SetPOSTransaction(PT);
                    POSTransactionCode.SelectCustPressed(Rec."No.");
                    CurrPage.Close();
                end;
            }
            action("NUEVO CLIENTE")
            {
                Promoted = true;
                Caption = 'CREAR CLIENTE';
                PromotedIsBig = true;
                Image = NewCustomer;
                PromotedCategory = Process;
                ApplicationArea = All;
                trigger OnAction()
                VAR
                    Customer_New: Record Customer;
                    CustomerTemplate: Record Customer;
                    Store_l: Record "LSC Store";
                    Retail_l: Record "LSC Retail Setup";
                    Functionality: Record "LSC POS Func. Profile";
                    Action_l: Action;
                    wasDelete: Boolean;
                begin
                    Retail_l.Get();
                    if Store_l.Get(Retail_l."Local Store No.") then;
                    Customer_New.Init();
                    Functionality.Get('#FASANI');

                    CustomerTemplate.get(Functionality."New Customer Defaults");
                    Customer_New := CustomerTemplate;
                    Customer_New."No." := '';
                    Customer_New.Name := '';
                    Customer_New.Address := '';
                    Customer_New."DTE Tax ID Type" := Customer_New."DTE Tax ID Type"::DUI;
                    Customer_New.Validate("Post Code", Store_l."Post Code");
                    Customer_New.Insert(true);
                    Commit();
                    Action_l := Page.RunModal(50096, Customer_New);

                    wasDelete := false;
                    if Customer_New.Name = '' then begin
                        Customer_New.Delete(true);
                        wasDelete := true;
                        SetCustomerDefault();
                        exit;
                    end;

                    Rec.Reset();
                    Rec.FilterGroup(0);
                    Rec.SetRange("No.", Customer_New."No.");
                    Rec.FindFirst();
                    Rec.FilterGroup(-1);
                end;
            }
        }


    }
    VAR
        filtro: Text[100];
        typeFilter: Option Codigo,Nombre,DUI,NIT,"Doc.Extranjero",NRC,Telefono;
        Customer: Record Customer;

    local procedure SetCustomerDefault()
    var
        RetailSetup_l: Record "LSC Retail Setup";
        CodeComodin: Code[20];
        POSTransactionCode: Codeunit "LSC POS Transaction";
        PT: Record "LSC POS Transaction";
        numero: Integer;
    begin
        //Rec.Reset();
        //Rec.DeleteAll();

        if PT.Get(POSTransactionCode.GetReceiptNo()) then begin
            if (PT."Customer No." <> '') and Customer.get(PT."Customer No.") then begin
                Rec.FilterGroup(0);
                Rec.Reset();
                Rec.SetRange("No.", Customer."No.");
                //Rec := Customer;
                //Rec.Insert();
                Rec.FilterGroup(-1);
                exit;
            end;
        end;

        RetailSetup_l.Get();
        CodeComodin := CopyStr(RetailSetup_l."Local Store No.", 2);
        Evaluate(numero, CodeComodin);
        CodeComodin := 'G' + Format(numero);
        if not Customer.get(CodeComodin) then begin
            Customer.Reset();
            Customer.FindFirst();
            Rec.FilterGroup(0);
            Rec.Reset();
            Rec.SetRange("No.", Customer."No.");
            //Rec := Customer;
            //Rec.Insert();
            Rec.FilterGroup(-1);
            //Rec.Init();
            //Rec := Customer;
            //Rec.insert(false);
        end else begin
            Rec.FilterGroup(0);
            Rec.Reset();
            Rec.SetRange("No.", Customer."No.");
            //Rec := Customer;
            //Rec.Insert();
            Rec.FilterGroup(-1);
            //Rec := Customer;
            //Rec.Insert();
        end;
    end;

    trigger OnInit()
    var
        RetailSetup_l: Record "LSC Retail Setup";
        CodeComodin: Code[20];
        POSTransactionCode: Codeunit "LSC POS Transaction";
        PT: Record "LSC POS Transaction";
    begin
        SetCustomerDefault();
        /*
        //Rec.Reset();
        //Rec.DeleteAll();

        if PT.Get(POSTransactionCode.GetReceiptNo()) then begin
            if (PT."Customer No." <> '') and Customer.get(PT."Customer No.") then begin
                Rec.FilterGroup(0);
                Rec.Reset();
                Rec.SetRange("No.", Customer."No.");
                //Rec := Customer;
                //Rec.Insert();
                Rec.FilterGroup(2);
                exit;
            end;
        end;

        RetailSetup_l.Get();
        CodeComodin := 'G' + CopyStr(RetailSetup_l."Local Store No.", 2, 2);
        if not Customer.get(CodeComodin) then begin
            Customer.Reset();
            Customer.FindFirst();
            Rec.FilterGroup(0);
            Rec.Reset();
            Rec.SetRange("No.", Customer."No.");
            //Rec := Customer;
            //Rec.Insert();
            Rec.FilterGroup(2);
            //Rec.Init();
            //Rec := Customer;
            //Rec.insert(false);
        end else begin
            Rec.FilterGroup(0);
            Rec.Reset();
            Rec.SetRange("No.", Customer."No.");
            //Rec := Customer;
            //Rec.Insert();
            Rec.FilterGroup(2);
            //Rec := Customer;
            //Rec.Insert();
        end;
        */
    end;

    /*trigger OnInsertRecord()
    var
        NewCustomer: Record Customer;
        Customer: Record Customer;
        Err: Label 'No se puede crear cliente';
    begin
        //NewCustomer.Init();
        //if not Customer.Get(NewCustomer.CreateNewCustomer('',false)) then
        Error(Err);

    end;*/

}