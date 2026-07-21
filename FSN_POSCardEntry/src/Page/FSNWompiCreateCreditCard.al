/*page 50106 "FSN Wompi Create Credit Card"
{
    Caption = 'FSN Wompi Crear Tarjeta de Crédito';
    PageType = card;
    UsageCategory = Administration;
    ApplicationArea = all;
    SourceTable = "LSC POS Card Entry";
    SaveValues = true;
    RefreshOnActivate = true;
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = true;
    //SourceTableTemporary = true;

    layout
    {
        area(Content)
        {

            //Caption = 'FSN Wompi Guardar Tarjeta de Crédito';

            field(Receipt; Rec."Receipt No.")
            {
                Caption = 'Receipt';
                ApplicationArea = All;
                Editable = false;

            }
            field(pan; Card)
            {
                Caption = 'Card';
                ApplicationArea = All;
                Editable = editableVal;

            }

            field(LastValidDate; LastDate)
            {
                Caption = 'Fecha expiración, MM/AA :.';
                ToolTip = 'Formato valido MM/AA';
                Editable = editableVal;
                trigger OnValidate()
                var
                    TEXT000: Label 'Mes invalido %1';
                    TEXT001: Label 'Año invalido %1';
                begin
                    if LastDate = '' then begin
                        expirationMonth := 0;
                        expirationYear := 0;
                        exit;
                    end;

                    LastDate := DELCHR(LastDate, '=', '/');

                    Evaluate(expirationMonth, CopyStr(LastDate, 1, 2));
                    Evaluate(expirationYear, CopyStr(LastDate, 3, 4));

                    IF (expirationMonth > 12) OR (expirationMonth < 0) THEN
                        Error(TEXT000, expirationMonth);

                    expirationYear += 2000;

                    IF (expirationYear > 2099) OR (expirationYear < 2000) THEN
                        Error(TEXT001, expirationYear);

                    LastDate := CopyStr(LastDate, 1, 2) + '/' + CopyStr(LastDate, 3, 4);

                end;
            }

            field(DocumentType; DocumentType)
            {
                Caption = 'Tipo Documento :.';
                ToolTip = 'Tipo Documento DUI,Doc Extrangero';
                ApplicationArea = All;
                Editable = editableVal;

            }

            field(DUI; DocumentNo)
            {
                Caption = 'No Documento :.';
                ToolTip = 'Numero Documento';
                ApplicationArea = All;
                Editable = editableVal;
                trigger OnValidate()
                var
                    myInt: Integer;
                    Text015: Label 'Owner Card ::%1';
                    FSNUtility: Codeunit "FSN Utility";
                begin
                    IF DocumentType = DocumentType::DUI THEN
                        FSNUtility.POSNewLineFreeText("Receipt No.", 36, STRSUBSTNO(Text015, DocumentNo), 2)
                end;

            }

            field(cellPhoneNumber; cellPhoneNumber)
            {
                Caption = 'Telefono :.';
                ApplicationArea = All;
                Editable = editableVal;

            }

            field(email; email)
            {
                Caption = 'Email :.';
                ApplicationArea = All;
                Editable = editableVal;

            }

            /*field(Guardar; BooleanM)
            {
                //DataClassification = ToBeClassified;
                trigger OnValidate()
                var
                    myInt: Integer;
                    TEXT000: Label 'Desea guardar Tarjeta?';
                begin
                    if Card = '' then begin
                        CurrPage.Close();
                        exit;
                    end;

                    ValDataFrom();
                    IF POSGUI.PosConfirm(TEXT000, TRUE) THEN
                        CurrPage.Close();

                end;
            }*/


/*     }

 }*/

/*actions
{
    area(Processing)
    {
        action(ActionName)
        {
            ApplicationArea = All;
            Caption = 'Guardar Informacion';
            Image = AllLines;
            Promoted = true;
            PromotedIsBig = true;
            PromotedCategory = Process;

            trigger OnAction()
            var
                CardRequestOnline: Page "FSN Card Request Online View";
                PAGEProcessOnline: page "FSN Card Request Online";
                TEXT000: Label 'Desea guardar informacion de la tarjeta?';
                TEXT001: Label 'Guardando Informacion, Espere.......';
                TEXT002: Label 'Debe completar la informacion';
                TEXT003: Label 'Media de pago ya AUTORIZADA';
                TEXT004: Label 'Fecha Expiracion invalida %1';
                TEXT005: Label 'Code Result: %1 \ ERROR Debe validar los datos';
                TEXT006: Label 'Code Result: %1 \ Datos enviados con exito, validar mensaje de texto con el cliente.';
                Error: Text;
                Windows: Dialog;
                ReponseResult: Text;
                json, obj : JsonObject;
                token: JsonToken;
                cid: Text;
                FechaText: Text[5];
                CodeResult: Integer;
            begin

                IF not (Rec."Authorisation Ok") then begin
                    Error := '';
                    if Card <> '' then begin
                        if POSGUI.PosConfirm(TEXT000, true) then begin
                            ValDataFrom(Error);
                            if Error = '' then begin
                                Windows.OPEN(TEXT001);
                                Windows.UPDATE;

                                FechaText := LastDate;
                                FechaText := DELCHR(FechaText, '=', '/');

                                Evaluate(expirationMonth, CopyStr(FechaText, 1, 2));
                                Evaluate(expirationYear, CopyStr(FechaText, 3, 4));

                                IF (expirationMonth > 12) OR (expirationMonth < 0) THEN
                                    Message(STRSUBSTNO(TEXT004, expirationMonth));

                                expirationYear += 2000;

                                IF (expirationYear > 2099) OR (expirationYear < 2000) THEN
                                    Error(STRSUBSTNO(TEXT004, expirationYear));

                                ReponseResult := WompiIntegration.SedFormSaveCreditCard(Rec."Receipt No.", Rec."Line No.", Card, expirationMonth, expirationYear, Format(DocumentType), DocumentNo, cellPhoneNumber, email, CodeResult);

                                IF CodeResult = 200 THEN begin
                                    Message(StrSubstNo(TEXT006, 00)); //OnValidateCardNumber(Card)
                                END ELSE
                                    ERROR(STRSUBSTNO(TEXT005, CodeResult));
                                Windows.Close();
                                CurrPage.Close();
                            end else begin
                                Message(Error);
                                exit;
                            end;
                        end;
                    end else
                        Error(TEXT002);
                end else
                    Error(TEXT003);
            end;
        }
    }
}

trigger OnOpenPage()
var
    Customer: Record Customer;
    Transaction: Record "LSC POS Transaction";
    DelOrder: Record "LSC Delivery Order";
    POSTransLine: Record "LSC POS Trans. Line";
begin
    Card := '';
    editableVal := true;
    CurrPage.SetRecord(Globals);

    if Globals."Authorisation Ok" then
        editableVal := false;

    IF Transaction.GET(Rec."Receipt No.") THEN;
    if Customer.get(Transaction."Customer No.") then;

    if Rec."EFT Additional ID" <> '' then
        Card := DELCHR(SeparateCharCard(Decrypt(Rec."EFT Additional ID")), '=', '-');

    if Rec."Expiry Date" <> '' then
        LastDate := ConvertLastDateFromParameter(Rec."Expiry Date");
    IF Customer."DTE Tax ID Type" = Customer."DTE Tax ID Type"::DUI THEN begin
        IF POSTransLine.GET("Receipt No.", 36) THEN
            IF STRPOS(POSTransLine.Description, '::') > 0 THEN
                DocumentNo := COPYSTR(POSTransLine.Description, STRPOS(POSTransLine.Description, '::') + 2)
            ELSE
                DocumentNo := COPYSTR(POSTransLine.Description, 1, 20)
        else
            DocumentNo := '';
        DocumentType := DocumentType::DUI;
    end;

    IF Customer."DTE Tax ID Type" = Customer."DTE Tax ID Type"::"Carnet de Residente" THEN begin
        DocumentNo := Customer."FSN Foreign document";
        DocumentType := DocumentType::CarnetResidente;
    end;

    email := Customer."E-Mail";

    if DelOrder.Get(Rec."Receipt No.") then
        cellPhoneNumber := DelOrder."Phone No.";

end;

var
    POSSESSION: Codeunit "LSC POS Session";
    myInt: Integer;
    BooleanM: Boolean;
    Card: Text[50];
    expirationMonth: Integer;
    expirationYear: Integer;
    DocumentNo: text[10];
    DocumentType: Option DUI,CarnetResidente;
    cellPhoneNumber: text[8];
    email: Text;
    LastDate: Text;
    WompiIntegration: Codeunit "FSN Wompi Integration";
    POSGUI: Codeunit "LSC POS GUI";
    Globals: Record "LSC POS Card Entry";
    editableVal: Boolean;

procedure ConvertLastDateFromParameter(pLastCardDate: Text[5]): Text[5]
begin
    IF STRLEN(pLastCardDate) <> 4 THEN
        EXIT(pLastCardDate);

    EXIT(COPYSTR(pLastCardDate, 3, 2) + '/' + COPYSTR(pLastCardDate, 1, 2));
end;

procedure ValDataFrom(var errormessage: Text)
var
    myInt: Integer;
    TEXT000: Label 'Se debe completar la información';
    TEXT001: Label 'Fecha Expiracion no puede ser vacio';
    TEXT002: Label 'Numero de Documento no puede ser vacio';
    TEXT003: Label 'Numero de telefono no puede ser vacio';
    TEXT004: Label 'Correo electronico no puede ser vacio';
begin
    if Card <> '' then begin
        if LastDate = '' then
            errormessage := TEXT001;

        if DocumentNo = '' then
            errormessage := TEXT002;

        if cellPhoneNumber = '' then
            errormessage := TEXT003;

        if email = '' then
            errormessage := TEXT004;



    end;
end;

local procedure OnValidateCardNumber(CardNumber: Text[150])
var
    Card: Text[150];
    BINList: Record "FSN BIN Bank";
    ReponseText: Text;
    json, obj : JsonObject;
    array: JsonArray;
    token: JsonToken;
    TEXTERROR: Label 'Code Result: %1 \ filtrar tarjeta';
    CodeResult: Integer;
begin

    ReponseText := WompiIntegration.FilterCreditCard(format(DocumentType), DocumentNo, CodeResult);

    CodeResult := 0;
    if NOT (ReponseText IN ['', '{}']) then begin
        json.ReadFrom(ReponseText);
        if json.SelectToken('customerId', token) then
            POSSESSION.SetValue('SALESCCPROCESSCUS', token.AsValue().AsText());

        Card := ValidateCard(CardNumber);
        Rec."Card Number" := Card;
        Rec."EFT Additional ID" := Encrypt(Card);
        //28981
        Rec."FSN BIN No." := '';
        Rec."FSN Bank Name" := '';
        Rec."FSN Last Digits" := '';
        Rec."Expiry Date" := LastDate;
        Rec."Auth.code" := '0000';
        IF STRLEN(Card) >= 6 THEN BEGIN
            Rec."FSN BIN No." := COPYSTR(Card, 1, 6);
            Rec."FSN Last Digits" := COPYSTR(Card, STRLEN(Card) - 3);

            IF BINList.GET(Rec."FSN BIN No.") THEN
                Rec."FSN Bank Name" := BINList."Bank Name";

        END;

        MODIFY;
        Rec.GET(Rec."Store No.", Rec."POS Terminal No.", Rec."Entry No.");
    end else
        error(STRSUBSTNO(TEXTERROR, CodeResult));//28981
end;

procedure ValidateCard(CardInput: Text[150]): Text[150]
var
    Dec: Decimal;
    tmpTarjeta: Text[150];
    i: Integer;
    _int: Integer;
    j: Text[1];
begin
    tmpTarjeta := '';
    FOR i := 1 TO STRLEN(CardInput) DO BEGIN
        j := COPYSTR(CardInput, i, 1);
        IF EVALUATE(_int, j) AND (j <> '-') THEN
            tmpTarjeta += j;
    END;

    IF (STRLEN(tmpTarjeta) > 13) AND (STRLEN(tmpTarjeta) < 17) THEN
        EXIT(tmpTarjeta);

    EXIT('');
end;

procedure SeparateCharCard(Card: Text[150]): Text[150]
var
    _i: Integer;
    Number: Text[150];
begin

    IF Card <> '' THEN BEGIN
        Number := Card;
        Card := '';
        FOR _i := 1 TO STRLEN(Number) DO BEGIN
            Card += COPYSTR(Number, _i, 1);
            IF (_i MOD 4 = 0) AND (_i < STRLEN(Number)) THEN
                Card += '-';
        END;
    END;
    IF Card = '' THEN
        EXIT(Number);

    EXIT(Card)
end;

procedure SETGLOBALVALUE(POSCardEntry: Record "LSC POS Card Entry")
begin
    Globals := POSCardEntry;
end;
}*/