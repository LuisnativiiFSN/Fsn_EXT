page 50055 "FSN PAQUETERIA"
{
    PageType = StandardDialog;
    UsageCategory = Administration;
    ApplicationArea = All;
    RefreshOnActivate = true;
    SourceTable = "LSC Delivery Order";
    SourceTableTemporary = true;
    DeleteAllowed = false;
    SaveValues = true;
    Caption = 'PAQUETERIA';


    layout
    {
        area(Content)
        {
            group(Group)
            {
                field("Recibo"; GlobalDelivery."Order No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                    StyleExpr = 'Favorable';
                }
                field("Fecha hora"; DateT)
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = 'StrongAccent';
                }
                field("Correo"; Email)
                {
                    ApplicationArea = All;
                    Editable = false;
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        CustomerInformation();
                    end;
                }

                field("Phone No."; TELEFONO)
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("Directions de cliente"; Direccion)
                {
                    ApplicationArea = All;
                    Editable = false;
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        CustomerInformation();
                    end;
                }

                field("Indicaciones"; Indicaciones)
                {
                    ApplicationArea = All;
                    Editable = Call;
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        updatePosTransLine;
                    end;
                }
                field(PESO; PESO)
                {
                    caption = 'Peso';
                    ApplicationArea = All;
                    Editable = Call;
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        if PESO <= 100 then
                            updatePosTransLine
                        ELSE begin
                            Message('El peso no puede ser mayor a 100 Lb.');
                            PESO := 100;
                        end;

                    end;
                }
                field(Unidad_M; Unidad_M)
                {
                    ApplicationArea = All;
                    Editable = Call;
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        updatePosTransLine;
                    end;
                }
                field("Codigo postal"; GlobalCustomer."Post Code")
                {
                    ApplicationArea = All;
                    Editable = Call;
                    TableRelation = "Post Code";
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        ValidatePostCode();
                        CustomerInformation();

                    end;
                }
                field(Departamento; Departamento)
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Municipio; Municipio)
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field(TipoS; TipoS)
                {
                    ApplicationArea = All;
                    Caption = 'Tipo de servicio';
                    Editable = false;
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        TServicio();
                    end;
                }
                field(Monto; Monto)
                {
                    Editable = false;
                }
                field(Guia; Guia)
                {
                    Style = Strong;
                    StyleExpr = 'Favorable';
                    Editable = false;
                }

            }
        }
    }



    var

        DateT: DateTime;
        Email: Text;
        Indicaciones: Text[100];
        Monto: Decimal;
        TipoS: Option "Servicio Entrega Regular","Cobro contra entrega";
        Nombre: Text[100];
        Direccion: Text[100];
        TELEFONO: Code[20];
        PESO: Integer;
        Guia: Text;
        Cpostal: Code[20];
        Unidad_M: Option Lb;
        Municipio: Text[30];
        Departamento: Text[30];
        postl: Record "LSC POS Trans. Line";
        GlobalDelivery: Record "LSC Delivery Order";
        PosTransaction: Record "LSC POS Transaction";
        Customer: Record Customer;
        GlobalParametroPQ: Record "FSN Parameter";
        Call: Boolean;
        RetailSetup_l: Record "LSC Retail Setup";
        POSSESSION: Codeunit "LSC POS Session";
        FSNUtility: Codeunit "FSN Utility";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        GlobalInfo: Record "LSC POS Trans. Infocode Entry";
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: Text;
        GlobalCustomer: Record Customer;
        PostCodeC: Code[20];
        Edit: Boolean;

    trigger OnOpenPage()
    var

        FSNUtility: Codeunit "FSN Utility";
        PosTransLine: Record "LSC POS Trans. Line";
        DelOrder: Record "LSC Delivery Order";
        POSSESSION: Codeunit "LSC POS Session";
        WebServi: Record "FSN WebServiceTable";
        TypeHelper: Codeunit "Type Helper";
        InputTime: Time;
        Hour: Integer;
        Minute: Integer;
        Second: Integer;
        date: Date;
    begin

        GlobalDelivery := Rec;
        GlobalInfo.Reset();
        GlobalParametro(POSSESSION.GetValue('VALOR'));
        GlobalInfo.SetRange("Receipt No.", GlobalDelivery."Order No.");
        GlobalInfo.SetRange("Source Code", GlobalParametroPQ.Valor);
        GlobalInfo.SetRange("Transaction Type", GlobalInfo."Transaction Type"::"Sales Entry");
        if GlobalInfo.FindFirst() then begin
            if NOT (StrPos(GlobalInfo.Information, 'FSN') > 0) THEN
                VaLService()
            ELSE begin
                POSSESSION.SetValue('GUIAC807', GlobalInfo.Information);
                Guia := GlobalInfo.Information;
            end;
        end else
            VaLService();

        RetailSetup_l.Get();
        if RetailSetup_l."FSN Is Local Receipt" and (RetailSetup_l."FSN Last Slipt No." <> '') and (Guia = '') then begin
            Call := true;
        end else
            Call := false;


        IF PosTransaction.Get(GlobalDelivery."Order No.") then begin
            if Customer.Get(PosTransaction."Customer No.") then begin
                ValidateCustomer(Customer);
                ValidatePostCode;
                CreateWebTable(PosTransaction);

                if WebServi.Get(GlobalDelivery."Order No.") then begin
                    if WebServi."Value Text 1" = 'Servicio Entrega Regular' then
                        TipoS := Tipos::"Servicio Entrega Regular"
                    else
                        TipoS := Tipos::"Cobro contra entrega";
                    PESO := WebServi."C807 peso";
                end;
                Unidad_M := Unidad_M::Lb;
                updatePosTransLine();
            end;

            if Guia = '' then
                Monto := ValidatePaymentOrder(PosTransaction."Receipt No.")
            else
                Monto := WebServi.Amount;
            /* InputTime := Time;
             TypeHelper.GetHMSFromTime(Hour, Minute, Second, InputTime);
             if Hour >= 14 then begin
                 date := CalcDate('<+1D>', Today);
                 DateT := CreateDateTime(date, 100000T);
             end else*/
            DateT := CreateDateTime(PosTransaction."Trans. Date", PosTransaction."Trans Time");
            Email := Customer."E-Mail";
            TELEFONO := GlobalDelivery."Phone No.";
            Nombre := Customer.Name;
            Direccion := GlobalDelivery.Directions;
            TServicio;
        end;
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        WebServi: Record "FSN WebServiceTable";
    begin
        WebServi.Reset();
        if WebServi.Get(GlobalDelivery."Order No.") then
            if WebServi."C807 peso" = 0 then begin
                Message('Debe de ingresar el peso del paquete');
                exit(false);
            end;
    end;

    trigger OnClosePage()
    var
        myInt: Integer;
        Text1601: Label 'Guia de C807 : ';
    begin
        Email := '';
        TELEFONO := '';
        Nombre := '';
        Direccion := '';
        PESO := 1;
        Indicaciones := '';
        Guia := '';
        Municipio := '';
        Departamento := '';
        PostCodeC := '';
        Indicaciones := '';
        POSSESSION.SetValue('GUIAC807', '');
    end;

    procedure SETGLOBALVALUE(POSDeliveryOrder: Record "LSC Delivery Order")
    begin
        GlobalDelivery := POSDeliveryOrder;
    end;

    procedure CustomerInformation()
    var
        myInt: Integer;
        PosTransLine: Record "LSC POS Trans. Line";
        Customer_1: Record Customer;
        PosTransaction: Record "LSC POS Transaction";
    begin
        PosTransaction.Reset();
        if PosTransaction.Get(GlobalDelivery."Order No.") THEN begin
            Customer_1.Reset();
            IF Customer_1.Get(PosTransaction."Customer No.") then begin
                Customer_1.Address := Direccion;
                Customer_1."E-Mail" := Email;
                Customer_1."Post Code" := PostCodeC;
                Customer_1.Modify();
                Commit();
            end;
        end;
    end;

    procedure updatePosTransLine()
    var
        myInt: Integer;
        WebServi: Record "FSN WebServiceTable";
    begin

        if WebServi.Get(GlobalDelivery."Order No.") then begin
            WebServi.Mail := Format(PESO);
            WebServi."C807 peso" := PESO;
            WebServi."Last Error Text" := CopyStr(Indicaciones, 1, 100);
            WebServi."Unidad de medida" := Format(Unidad_M);
            WebServi.Modify();
            Commit();
        end;
    end;


    procedure GlobalParametro(Item: code[20])
    var
        myInt: Integer;

    begin
        GlobalParametroPQ.Reset();
        GlobalParametroPQ.SetRange(Grupo, 'PAQUETERIA');
        GlobalParametroPQ.SetRange(valor, Item);
        if GlobalParametroPQ.FindFirst() then
            POSSESSION.SetValue('VALOR', Item);
    end;

    procedure ValidateCustomer(Customer: Record Customer)
    var
        MensC001: Label 'Cliente no posee correo electronico';
        MensC002: Label 'Cliente no posee codigo postal';
        MensC003: Label 'Cliente no posee dirección';
    begin
        GlobalCustomer := Customer;
        if Customer."E-Mail" = '' then
            Message(MensC001);
        if Customer."Post Code" = '' then
            Message(MensC002);
        if Customer.Address = '' then
            Message(MensC003);
    end;

    procedure ValidatePostCode()
    var
        myInt: Integer;
        PostCode: Record "Post Code";
    begin
        PostCode.Reset();
        PostCode.SetRange(Code, GlobalCustomer."Post Code");
        if PostCode.FindFirst() then begin
            Municipio := PostCode.County;
            Departamento := PostCode.City;
            PostCodeC := PostCode.Code;
        end;
    end;

    procedure CreateWebTable(PosTrans: Record "LSC POS Transaction")
    var
        WebServ: Record "FSN WebServiceTable";
    begin
        if not WebServ.Get(PosTrans."Receipt No.") then begin
            WebServ.INIT();
            WebServ.LastSlipNo := PosTrans."Receipt No.";
            WebServ."C807 peso" := 0;
            if BlockCCE then
                WebServ."Value Text 1" := Format(TipoS::"Cobro contra entrega")
            else
                WebServ."Value Text 1" := Format(TipoS::"Servicio Entrega Regular");
            WebServ."Unidad de medida" := Format(Unidad_M::Lb);
            WebServ.Store := PosTrans."Store No.";
            WebServ.Terminal := PosTrans."POS Terminal No.";
            WebServ."Customer No." := PosTrans."Customer No.";
            WebServ."Sell-to Contact No." := PosTrans."Sell-to Contact No.";
            WebServ.Date := Today;
            WebServ.Time := Time;
            WebServ.insert();
            Commit();
        end;
    end;

    procedure TServicio()
    var
        myInt: Integer;
        WebServ: Record "FSN WebServiceTable";
    begin
        if WebServ.Get(GlobalDelivery."Order No.") then begin
            WebServ."Value Text 1" := Format(TipoS);
            WebServ.Amount := Monto;
            WebServ.Modify();
            Commit();
        end;
    end;

    procedure VaLService()
    var
        myInt: Integer;
        WebServ: Record "FSN WebServiceTable";
    begin
        if WebServ.Get(GlobalDelivery."Order No.") then begin
            if BlockCCE then
                WebServ."Value Text 1" := Format(TipoS::"Cobro contra entrega")
            else
                WebServ."Value Text 1" := Format(TipoS::"Servicio Entrega Regular");
            WebServ.Modify();
            Commit();
        end;
    end;

    procedure ValidatePaymentOrder(OrderNo: Code[20]): Decimal
    var
        PosTransaction: Record "LSC POS Transaction";
        DELAmount: Decimal;
        DELDiscount: Decimal;
        DELBalance: Decimal;
    begin
        PosTransaction.Reset();
        if PosTransaction.Get(OrderNo) then begin

            PosTransaction.CalcFields("Gross Amount", PosTransaction."Line Discount", "Income/Exp. Amount");

            if not (POSSESSION.GetValue('Amount') in ['0.00', '0']) then begin
                if Evaluate(DELAmount, POSSESSION.GetValue('Amount')) then;
            end else
                DELAmount := PosTransaction."Gross Amount" + PosTransaction."Line Discount" + PosTransaction."Income/Exp. Amount";

            if not (POSSESSION.GetValue('Discount') in ['0.00', '0']) then begin
                if Evaluate(DELDiscount, POSSESSION.GetValue('Discount')) then;
            end else
                DELDiscount := (-(PosTransaction."Line Discount"));

            exit(PosTransaction."Gross Amount" + PosTransaction."Income/Exp. Amount")
        end;
    end;

    procedure BlockCCE(): Boolean
    var
        PosInfocode: Record "LSC POS Trans. Infocode Entry";
    begin
        PosInfocode.Reset();
        PosInfocode.SetRange("Receipt No.", GlobalDelivery."Order No.");
        PosInfocode.SetRange("Transaction Type", PosInfocode."Transaction Type"::"Payment Entry");
        PosInfocode.SetRange(Infocode, 'OREFECT');
        PosInfocode.SetRange(Subcode, 'C807');
        if PosInfocode.FindFirst() then
            exit(true)
        else
            exit(false)
    end;
}