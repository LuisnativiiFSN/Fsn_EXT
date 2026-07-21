page 50107 "FSN Filter Credit Card Wompi"
{
    PageType = list;
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = true;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "LSC POS Menu Line";
    PromotedActionCategories = 'Process,Check,Report,Vouchers';
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {

            group(FilterCreditCard)
            {
                Caption = 'Filtrar Tarjeta';
                field(DocumentType; DocumentType)
                {
                    Caption = 'Tipo Documento';
                    Editable = true;
                    trigger OnValidate()
                    begin

                    end;
                }

                field(NoDocument; NoDocument)
                {
                    Caption = 'N° Documento';
                    Editable = true;
                    trigger OnValidate()
                    var
                        ReponseText: text;
                        json, obj : JsonObject;
                        array: JsonArray;
                        token: JsonToken;
                        test1: Text;
                        test2: Text;
                        posMenuLineTemp: Record "LSC POS Menu Line" temporary;
                        PageFilter: Page "FSN Filter Credit Card Wompi";
                        TEXT001: Label 'Extrayendo la Informacion, Espere.......';
                        TEXT002: Label 'Code Result: %1 \ Datos no encontrados';
                        Windows: Dialog;
                        cUSTOM: Text;
                        CodeResult: Integer;
                    begin
                        Clear(Rec);
                        Rec.DeleteAll();
                        Windows.OPEN(TEXT001);
                        Windows.UPDATE;
                        ReponseText := WompiIntegration.FilterCreditCard(format(DocumentType), NoDocument, CodeResult);

                        if NOT (ReponseText IN ['', '{}']) then begin
                            json.ReadFrom(ReponseText);
                            if json.SelectToken('customerId', token) then
                                POSSESSION.SetValue('SALESCCPROCESSCUS', token.AsValue().AsText());

                            if json.SelectToken('creditCardQueryResults', token) then
                                array := token.AsArray();

                            if array.Count = 0 then
                                exit;

                            foreach token in array do begin
                                Rec.Init();
                                Rec."Profile ID" := '#FASANI';
                                Rec."Menu ID" := 'WOMPI';
                                Rec."Key No." += 1;
                                obj := token.AsObject();

                                if obj.SelectToken('lastDigits', token) then
                                    Rec.Parameter := token.AsValue().AsText();

                                if obj.SelectToken('maskedCreditCard', token) then
                                    Rec.Description := token.AsValue().AsText();
                                Rec.Insert();
                            end;
                        end else
                            Message(STRSUBSTNO(TEXT002, CodeResult));
                        CurrPage.Update(false);
                        Windows.Close();
                    end;
                }


            }
            repeater(Control1)
            {
                field(lastDigits; Rec.Parameter)
                {
                    Caption = 'Ultimos Digitos';
                    ApplicationArea = All;

                }

                field(maskedCreditCard; Rec.Description)
                {
                    ApplicationArea = All;

                }
            }
        }
    }

    actions
    {
        area(Processing)
        {

            action(Selecionar)
            {
                ApplicationArea = All;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                Caption = 'Seleccionar';
                trigger OnAction()
                var
                begin
                    ProcessLine(True);
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
    begin
        POSSESSION.SetValue('SALESCCPROCESSCUS', ' ');
    end;

    trigger OnClosePage()
    var
    begin
        //ProcessLine(false);
    end;

    trigger OnAfterGetRecord()
    begin

    end;

    local procedure OnValidateCardNumber(CardNumber: Text[150])
    var
        Card: Text[150];
        BINList: Record "FSN BIN Bank";
        POSCardEntry: Record "LSC POS Card Entry";
    begin

        if POSCardEntry.Get(GlobalsPosCardEntry."Store No.", GlobalsPosCardEntry."POS Terminal No.", GlobalsPosCardEntry."Entry No.") then begin

            Card := ValidateCard(CardNumber);
            /*IF CopyStr(Card, 9, 10) <> 'X' THEN begin
                POSCardEntry."EFT Additional ID" := Encrypt(Card);
            end ELSE begin*/
            POSCardEntry."EFT Additional ID" := Card;
            //end;
            //

            POSCardEntry."Auth.code" := '0000';//Clear from wompi

            POSCardEntry."FSN BIN No." := '';
            POSCardEntry."FSN Bank Name" := '';
            //POSCardEntry."Expiry Date" := LastDate;
            IF STRLEN(Card) >= 6 THEN BEGIN
                POSCardEntry."FSN BIN No." := COPYSTR(Card, 1, 6);
                POSCardEntry."FSN Last Digits" := COPYSTR(Card, STRLEN(Card) - 3);

                IF BINList.GET(POSCardEntry."FSN BIN No.") THEN
                    POSCardEntry."FSN Bank Name" := BINList."Bank Name";

            END;

            POSCardEntry.MODIFY;
            POSCardEntry.GET(POSCardEntry."Store No.", POSCardEntry."POS Terminal No.", POSCardEntry."Entry No.");
        end;
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
            IF (j <> ' ') THEN
                tmpTarjeta += j;
        END;

        IF (STRLEN(tmpTarjeta) > 13) AND (STRLEN(tmpTarjeta) < 17) THEN
            EXIT(tmpTarjeta);

        EXIT('');
    end;

    procedure SETGLOBALVALUE(POSCardEntry: Record "LSC POS Card Entry")
    begin
        GlobalsPosCardEntry := POSCardEntry;
    end;

    procedure ProcessLine(ClosePage: Boolean)
    var
        myInt: Integer;
        pgCardReOnline: Page "FSN Card Request Online";
        TEXT000: Label 'Linea de pago en estado AUTORIZADO';
    begin
        IF not (GlobalsPosCardEntry."Authorisation Ok") then begin
            if Description <> '' then begin
                CurrPage.GetRecord(Rec);
                OnValidateCardNumber(Description);
                if ClosePage then
                    CurrPage.Close();
            end;
        end else
            Error(TEXT000);
    end;

    var
        GlobalsPosCardEntry: Record "LSC POS Card Entry";
        WompiIntegration: Codeunit "FSN Wompi Integration";
        NoCreditCard: Text;
        NoDocument: text;
        DocumentType: Option DUI,CarnetResidente;
        myInt: Integer;
        POSSESSION: Codeunit "LSC POS Session";

}