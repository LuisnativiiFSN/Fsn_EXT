page 50051 "FSN Web Table Page"
{
    Caption = 'FSN Web Table Page';
    PageType = Card;
    UsageCategory = Lists;
    ApplicationArea = All;
    SourceTable = "FSN WebServiceTable";
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = true;
    PromotedActionCategories = 'Processing';
    layout
    {
        area(content)
        {
            field(tipo; tipo)
            {
                Caption = 'Tipo';
                Editable = false;
                Style = Strong;
                StyleExpr = 'Favorable';

            }
            group("DOMICILIO Y PARA LLEVAR")
            {
                Caption = 'Domicilio y Para Llevar.';

                field(Domicilio; DomicilioTake)
                {
                    Caption = 'Domicilio';
                    OptionCaption = 'CASA,TRABAJO,OTROS,PARA LLEVAR';
                    Editable = True;

                    trigger OnValidate()
                    var
                    begin
                        ValidateTakeTypeOrder;
                    end;
                }
                field("No Telef."; PhoneNo)
                {
                    Caption = 'No Telef :.';
                    ApplicationArea = All;
                    Editable = false;

                    trigger OnValidate()
                    var
                    begin
                        Globals."Sell-to Contact No." := PhoneNo;
                        Globals.Modify();
                    end;
                }
                field(Nombre; NameV)
                {
                    Caption = 'Nombre :.';
                    ApplicationArea = All;
                    Editable = true;

                    trigger OnValidate()
                    var
                    begin
                        if DelContTEMP.get(PhoneNo) then begin
                            DelContTEMP.Name := NameV;
                            DelContTEMP.Modify();
                        end;
                        UpdateAddress(DomicilioTake);
                        UpdateAdressWebTable();
                    end;
                }
                /*field(Email; Email)
                {
                    Caption = 'Correo';
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        IF PhoneNo <> '' THEN BEGIN
                            CUSTOMER.RESET;
                            CUSTOMER.SETRANGE("Phone No.", PhoneNo);
                            if CUSTOMER.Find('-') then begin
                                CUSTOMER."E-Mail" := Email;
                                CUSTOMER.Modify();
                            end;
                        end;
                    end;
                }*/
                field("Ciudad"; Address2V)
                {
                    Caption = 'Ciudad :.';
                    ApplicationArea = All;
                    Editable = false;

                    trigger OnValidate()
                    var
                    begin
                    end;
                }

                field("Colonia/Calle"; AddressV)
                {
                    Caption = 'Colonia/Calle :.';
                    ApplicationArea = All;
                    Editable = true;
                    TableRelation = "LSC Delivery Street";
                    ShowMandatory = true;
                    NotBlank = true;
                    trigger OnValidate()
                    var
                        myInt: Integer;
                        delS: Record "LSC Delivery Street";
                    begin
                        delS.Reset();
                        delS.SetRange("Street Name", AddressV);
                        if delS.Find('-') then begin
                            //DeliveryStreet(delS);
                            IF AddressV <> '' then begin
                                //Restaurante := delS."Restaurant No.";
                            end;
                        end;
                        UpdateAddress(DomicilioTake);
                        ValidateTakeTypeOrder();
                        UpdateAdressWebTable();
                    end;
                }
                field("Restriccion"; FSNDSRestriction)
                {
                    Caption = 'Restriccion :.';
                    ApplicationArea = All;
                    Editable = false;

                    trigger OnValidate()
                    var
                    begin
                    end;
                }
                field("Direccion"; DirectionsV)
                {
                    Caption = 'Direccion :.';
                    ApplicationArea = All;
                    Editable = true;
                    ShowMandatory = true;
                    //ToolTip = DirectionsV;
                    trigger OnValidate()
                    var
                    begin
                        UpdateAddress(DomicilioTake);
                        UpdateAdressWebTable();
                    end;
                }
                field("Tienda: "; Restaurante)
                {
                    Editable = true;
                    TableRelation = "LSC Distribution Location";
                    Visible = PREFACTURA;
                    ShowMandatory = true;

                    trigger OnValidate()
                    var
                    begin
                        if (StrPos(Restaurante, 'F') = 0) or (POSSESSION.StoreNo() = Restaurante) or (Restaurante = 'F') or (StrLen(Restaurante) > 4)
                        then begin
                            Restaurante := '';
                            Message('Se debe seleccionar una tienda válida');
                        end;
                        UpdateAdressWebTable();
                    end;
                }
                field("Sugeridas"; suggest)
                {
                    Caption = 'Sugeridas :.';
                    ApplicationArea = All;
                    Editable = false;

                    trigger OnValidate()
                    var
                    begin
                    end;
                }
                field("Llave Alterna"; FSNAlterKey)
                {
                    Caption = 'Llave Alterna :.';
                    ApplicationArea = All;
                    Editable = false;
                    Visible = false;

                    trigger OnValidate()
                    var
                    begin
                    end;
                }
                field("N° Orden: "; POSSESSION.GetValue('CURRORDER'))
                {
                    Editable = false;
                    Style = Strong;
                    StyleExpr = 'StrongAccent';
                }
            }
            group("Ingresar Comentario")
            {
                Caption = 'Comentarios';
                field("Comentario"; ComentText)
                {
                    Caption = 'Comentarios :.';
                    ApplicationArea = All;
                    Editable = true;

                    trigger OnValidate()
                    var
                        LinkNumber: Integer;
                        pNextLine: Integer;
                        NewPOSTransLine: Record "LSC POS Trans. Line";
                        pPOSTransLine: Record "LSC POS Trans. Line";
                        ErrorL: Label 'El comentario debe de ser menor a 65 caracteres';
                    begin
                        if StrLen(ComentText) > 65 then
                            Error(ErrorL);
                        IF LinkNumber = 0 THEN BEGIN
                            pNextLine := 10000;
                            pPOSTransLine.RESET;
                            pPOSTransLine.SETCURRENTKEY("Receipt No.", "Line No.");
                            pPOSTransLine.SETRANGE(pPOSTransLine."Receipt No.", Rec.LastSlipNo);
                            IF pPOSTransLine.FINDLAST THEN
                                pNextLine := pPOSTransLine."Line No." + 10000;
                        END ELSE
                            pNextLine := LinkNumber;

                        NewPOSTransLine.Init();
                        NewPOSTransLine."Receipt No." := Rec.LastSlipNo;
                        NewPOSTransLine."Store No." := POSSESSION.StoreNo();
                        NewPOSTransLine."POS Terminal No." := POSSESSION.TerminalNo();
                        NewPOSTransLine."Entry Type" := NewPOSTransLine."Entry Type"::FreeText;
                        NewPOSTransLine."Text Type" := NewPOSTransLine."Text Type"::"Freetext Input";
                        NewPOSTransLine.VALIDATE(NewPOSTransLine.Description, COPYSTR(UpperCase(ComentText), 1, MAXSTRLEN(NewPOSTransLine.Description)));
                        NewPOSTransLine."Line No." := pNextLine;
                        IF NewPOSTransLine.Insert(true) then begin
                            freetextValue := true;
                            clear(ComentText);
                        end;
                    end;

                }
            }
        }
    }

    actions
    {
        area(Processing)
        {

            action("ACTUALIZAR INFORMACION")
            {
                ApplicationArea = All;
                Caption = 'GUARDAR INFORMACION';
                Image = Save;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                Visible = DAF;
                trigger OnAction()
                var
                    myInt: Integer;
                    DeliveryOrd: Record "LSC Delivery Order";
                    FSNWebServiceTable: Record "FSN WebServiceTable";
                    DelContAddr: Record "LSC Delivery Contact Address";
                    DeliveryStreet: Record "LSC Delivery Street";
                    Mens: Label 'Datos actualizados';
                    Customer: Record Customer;
                begin
                    IF FSNWebServiceTable.Get(POSSESSION.GetValue('CURRORDER')) then
                        if DeliveryOrd.Get(POSSESSION.GetValue('CURRORDER')) then begin
                            if DelContAddr.Get(FSNWebServiceTable."Sell-to Contact No.", DomicilioTake) then;
                            DeliveryStreet.Reset();
                            DeliveryStreet.SetRange("Street Name", DelContAddr."Street Name");
                            if DeliveryStreet.FindFirst() then;
                            DeliveryOrd.Address := CopyStr(DeliveryStreet."Street Name", 1, 50);
                            DeliveryOrd."Address 2" := DeliveryStreet."Address 2";
                            DeliveryOrd.Directions := DirectionsV;
                            DeliveryOrd."Order Type Option" := DomicilioTake + 1;
                            DeliveryOrd."Post Code" := DeliveryStreet."Post Code";
                            DeliveryOrd.City := DeliveryStreet.City;
                            DeliveryOrd."FSN Alter Key" := DeliveryStreet."FSN Alter Key";
                            DeliveryOrd."FSN Street Name" := DelContAddr."FSN Street Name";
                            DeliveryOrd."FSN Confirm Date" := Today;
                            DeliveryOrd."FSN Confirm Time" := Time();
                            DeliveryOrd."FSN Directions" := DelContAddr.Directions;
                            if DeliveryOrd."Directions" = '' then
                                if Customer.Get(Rec."Customer No.") then begin
                                    DeliveryOrd."Directions" := Customer.Address;
                                end;
                            DeliveryOrd.Modify();
                            Message(Mens);
                            POSSESSION.SetValue('DEL-PickupDate', Format(DeliveryOrd."Order Date"));
                            POSSESSION.SetValue('DEL-PickupTime', format(DeliveryOrd."Contact Pickup Time"));
                        end;
                end;
            }
        }
    }

    var
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        MsgResult: Text;
        ComentText: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        POSSESSION: Codeunit "LSC POS Session";
        Globals: Record "FSN WebServiceTable";
        DomicilioTake: Option Home,Work,Other,Takeout;
        suggest: Text;
        NameV: Text[100];
        AddressV: text[80];
        Address2V: Text[30];
        FSNDSRestriction: text[50];
        DirectionsV: text[100];
        FSNAlterKey: Integer;
        PhoneNo: Code[30];
        DelCustAddr: Record "LSC Delivery Contact Address";
        DelContTEMP: Record Contact;
        Text080: Label 'El restaurante %1 ya está seleccionado. ¿Quieres cambiarlo al restaurante %2?';
        ProcesarPedido: Boolean;
        Restaurante: Code[10];
        DelStreet_l: Record "LSC Delivery Street";
        Cotizacion: Text[250];
        InputZipCode: code[20];
        InputCity: Text[30];
        InputGrid: Code[20];
        DAF: Boolean;
        PREFACTURA: Boolean;
        PedidoNo: Code[20];
        GlobalContact: Record "Contact" temporary;
        FSNUtility: Codeunit "FSN Utility";
        tipo: Text;
        PosTransac: Record "LSC POS Transaction";
        Customer: Record Customer;
        freetextValue: Boolean;

    trigger OnOpenPage()
    var
        EvalTake: Integer;
    begin
        freetextValue := false;
        if (POSSESSION.GetValue('FSNCREATEPREFAC') = 'TRUE') or (CopyStr(Globals.LastSlipNo, 1, 1) = 'X') then begin
            PREFACTURA := true;
            DAF := false;
            tipo := 'Prefactura hacia call-center'
        end
        ELSE begin
            DAF := true;
            PREFACTURA := false;
            tipo := 'Rutas hacia DAF';
        end;

        if PosTransac.Get(POSSESSION.GetValue('CURRORDER')) then begin
            IF Customer.Get(PosTransac."Customer No.") then;
        end;
        Rec := Globals;
        PhoneNo := Rec."Sell-to Contact No.";
        NameV := Rec."Last Name";
        Restaurante := Rec."Store Selected";
        if Evaluate(EvalTake, Globals."Value Text 1") then begin
            CASE EvalTake OF
                0:
                    DomicilioTake := DomicilioTake::Home;
                1:
                    DomicilioTake := DomicilioTake::Work;
                2:
                    DomicilioTake := DomicilioTake::Other;
                3:
                    DomicilioTake := DomicilioTake::Takeout;
            END;
        end
        else
            DomicilioTake := DomicilioTake::Home;
        ValidateTakeTypeOrder();
        UpdateAdressWebTable();
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        IF (PREFACTURA) and (Globals."Store Selected" = '') then begin
            Message('El campo Tienda no debe estar vacío');
            EXIT(false);
        end;
        if (AddressV = '') or (DirectionsV = '') then begin
            Message('Campos obligatorios no deben estar vacíos');
            EXIT(false);
        end;
    end;

    trigger OnClosePage()
    var
        myInt: Integer;
        DeliveryOrd: Record "LSC Delivery Order";
        FSNWebServiceTable: Record "FSN WebServiceTable";
        DelContAddr: Record "LSC Delivery Contact Address";
        DeliveryStreet: Record "LSC Delivery Street";
        Mens: Label 'Datos actualizados';
        Customer: Record Customer;
        Postransaction: Record "LSC POS Transaction";
        menuLine: Record "LSC POS Menu Line";
        posTransC: Codeunit "LSC POS Transaction";
    begin
        IF DAF then begin
            IF FSNWebServiceTable.Get(POSSESSION.GetValue('CURRORDER')) then
                if DeliveryOrd.Get(POSSESSION.GetValue('CURRORDER')) then begin
                    if DelContAddr.Get(FSNWebServiceTable."Sell-to Contact No.", DomicilioTake) then;
                    DeliveryStreet.Reset();
                    DeliveryStreet.SetRange("Street Name", DelContAddr."Street Name");
                    if DeliveryStreet.FindFirst() then;
                    DeliveryOrd.Address := CopyStr(DeliveryStreet."Street Name", 1, 50);
                    DeliveryOrd."Address 2" := DeliveryStreet."Address 2";
                    DeliveryOrd.Directions := DirectionsV;
                    DeliveryOrd."Order Type Option" := DomicilioTake + 1;
                    DeliveryOrd."Post Code" := DeliveryStreet."Post Code";
                    DeliveryOrd.City := DeliveryStreet.City;
                    DeliveryOrd."FSN Alter Key" := DeliveryStreet."FSN Alter Key";
                    DeliveryOrd."FSN Street Name" := DelContAddr."FSN Street Name";
                    DeliveryOrd."FSN Confirm Date" := Today;
                    DeliveryOrd."FSN Confirm Time" := Time();
                    DeliveryOrd."FSN Directions" := DelContAddr.Directions;
                    if DeliveryOrd."Directions" = '' then
                        if Customer.Get(Rec."Customer No.") then begin
                            DeliveryOrd."Directions" := Customer.Address;
                        end;
                    DeliveryOrd.Modify();
                    POSSESSION.SetValue('DEL-PickupDate', Format(DeliveryOrd."Order Date"));
                    POSSESSION.SetValue('DEL-PickupTime', format(DeliveryOrd."Contact Pickup Time"));


                    if Postransaction.Get(DeliveryOrd."Order No.") then begin
                        Postransaction.Comment := DeliveryOrd.Name;
                        Postransaction."Sell-to Contact No." := DeliveryOrd."Phone No.";
                        Postransaction."Sales Type" := 'DELIVERY';
                        Postransaction.Validate("Hosp. Type Sequence");

                        menuLine.Command := 'CANCEL2';
                        posTransC.run(menuLine);

                        menuLine.Command := 'TOTAL';
                        posTransC.run(menuLine);
                    end;

                    Message(Mens);
                end;
        end;

        if freetextValue then begin
            menuLine.Command := 'CANCEL2';
            posTransC.run(menuLine);

            menuLine.Command := 'TOTAL';
            posTransC.run(menuLine);
        end;
    end;

    procedure SETGLOBALVALUE(WebTable: Record "FSN WebServiceTable")
    begin
        Globals := WebTable;
        Rec := WebTable;
    end;

    procedure SETGLOBALCONTAC(CONTACT: Record "Contact")
    begin
        GlobalContact.COPY(CONTACT);
    end;

    procedure UpdateAddress(DeliveryType: Option Home,Work,Other,Takeout)
    var
        DelStreet: Record "LSC Delivery Street";
        DelCustAddr: Record "LSC Delivery Contact Address";
        HospSetup: Record "LSC Hospitality Setup";
        Contact: Record Contact;
        PosTr: Record "LSC POS Transaction";
        Customer: Record Customer;
    begin
        if PosTr.Get(POSSESSION.GetValue('CURRORDER')) then begin
            IF Customer.Get(PosTr."Customer No.") then;
        end;

        if not DelCustAddr.Get(PhoneNo, DeliveryType) then begin
            DelCustAddr.Init;
            DelCustAddr."Phone No." := PhoneNo;
            DelCustAddr."Address Type" := DeliveryType;// - 1; Prueba 
            Clear(AddressV);
            Clear(Address2V);
            Clear(InputZipCode);
            Clear(InputCity);
            Clear(DirectionsV);
            Clear(Restaurante);
            Clear(InputGrid);
            Clear(suggest);
        end;
        DelStreet.Reset();
        DelStreet.SetRange("Street Name", DelCustAddr."Street Name"); //CopyStr(Rec.Address, 3, 30)
        if DelStreet.FindFirst() then begin
            suggest := DelStreet."FSN Stores Suggest";
        end;
        DomicilioTake := DeliveryType;
        if CopyStr(AddressV, 1, 2) = '1 ' then
            DelCustAddr."Street Name" := CopyStr(AddressV, 3, 30)
        else
            DelCustAddr."Street Name" := AddressV;
        DelCustAddr."Street No." := Format(1);
        DelCustAddr."Address 2" := Address2V;
        DelCustAddr.Directions := DirectionsV;
        DelCustAddr.City := InputCity;
        DelCustAddr."Post Code" := InputZipCode;
        DelCustAddr."Grid Code" := InputGrid;
        IF Restaurante = '' then begin
        end ELSE
            DelCustAddr."Restaurant No." := Restaurante;
        DelCustAddr."Grid Code" := InputGrid;

        if not DelCustAddr.Modify(true) then
            DelCustAddr.Insert(true);
        Commit;

        Contact.Reset();
        if not Contact.Get(PhoneNo) then begin
            Contact.Init();
            Contact."No." := PhoneNo;
            Contact."Phone No." := PhoneNo;
            Contact.Name := Customer.Name;
            Contact."Search Name" := Customer.Name;
            Contact."LSC Date Created" := Today;
        end;
        IF Restaurante <> '' then begin
            Contact."LSC Next Order Restaurant" := Restaurante;
            IF not Contact.Insert(true) then
                Contact.Modify(true);
        end;
    end;

    procedure UpdateAdressWebTable()
    var
        SalesType: Integer;
        SalesTypes: Record "LSC Sales Type";
        POSTransaction: Record "LSC POS Transaction";
        WebTableUpdate: Record "FSN WebServiceTable";
    begin
        CASE DomicilioTake OF
            DomicilioTake::Home:
                SalesType := 0;
            DomicilioTake::Work:
                SalesType := 1;
            DomicilioTake::Other:
                SalesType := 2;
            DomicilioTake::Takeout:
                SalesType := 3;
        END;
        WebTableUpdate.Reset();
        IF WebTableUpdate.Get(Rec.LastSlipNo) then begin
            case DomicilioTake of
                DomicilioTake::Home, DomicilioTake::Other, DomicilioTake::Work:
                    WebTableUpdate."Order Type" := WebTableUpdate."Order Type"::FromStoreDelivery;
                else
                    WebTableUpdate."Order Type" := WebTableUpdate."Order Type"::FromStoreTakeaway;
            end;
            WebTableUpdate."Value Text 1" := format(SalesType);
            WebTableUpdate."Store Selected" := Restaurante;
            WebTableUpdate.Modify();

            Globals.Reset();
            Globals := WebTableUpdate;
        end;
    end;

    Procedure ValidateTakeTypeOrder()
    var
        DelCustAddr: Record "LSC Delivery Contact Address";
        SalesOptinInt: Integer;
        DelCont: Record Contact;
    begin
        CASE DomicilioTake of
            DomicilioTake::Home:
                SalesOptinInt := 0;
            DomicilioTake::Work:
                SalesOptinInt := 1;
            DomicilioTake::Other:
                SalesOptinInt := 2;
            DomicilioTake::Takeout:
                SalesOptinInt := 3;
        END;
        DelCustAddr.Reset();
        if DelCustAddr.Get(PhoneNo, DomicilioTake) then begin
            DelStreet_l.Reset();
            DelStreet_l.SetRange("Street Name", DelCustAddr."Street Name");//CopyStr(Rec.Address, 3, 30)
            if DelStreet_l.FindFirst() then begin
                DelStreet_l.CalcFields(City);
                RequestID := 'SALE-PREFCONSULT';
                XMLRequest := Format(DelStreet_l."FSN Alter Key");
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);

            end;
            DomicilioTake := DelCustAddr."Address Type";
            suggest := XMLResponse;
            PhoneNo := DelCustAddr."Phone No.";
            AddressV := DelStreet_l."Street Name";
            Address2V := DelStreet_l."Address 2";
            InputCity := DelStreet_l.City;
            InputZipCode := DelStreet_l."Post Code";
            FSNDSRestriction := '';
            DirectionsV := DelCustAddr.Directions;
            InputGrid := DelStreet_l."Grid Code";
            if PosTransac.Get(POSSESSION.GetValue('CURRORDER')) then begin
                IF Customer.Get(PosTransac."Customer No.") then;
            end;
            if DirectionsV = '' then
                DirectionsV := Customer.Address;
            UpdateAdressWebTable();
            UpdateAddress(DomicilioTake);
        end else
            UpdateAddress(DomicilioTake);
    end;
}

