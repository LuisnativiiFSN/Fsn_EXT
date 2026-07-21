pageextension 50117 "Posted Transfer Receipt Ext" extends "Posted Transfer Receipt"
{
    layout
    {
        addafter("Shortcut Dimension 2 Code")
        {
            field("External Document No."; "External Document No.")
            {
                //ApplicationArea = Dimensions;
                Caption = 'Nº documento externo';
                Editable = false;
            }

            field(StatusCertificate; StatusCertificate)
            {
                //ApplicationArea = Dimensions;
                Caption = 'Estado';
                StyleExpr = StyleStatusText;
                Editable = false;
            }
        }
    }

    actions
    {
        addfirst(navigation)
        {
            action(CertifitTransfer)
            {
                ApplicationArea = All;
                Image = GeneralLedger;
                Promoted = true;
                PromotedCategory = Process;
                Caption = 'FSN Certificar';
                ToolTip = 'FSN Certificar';
                PromotedIsBig = true;
                trigger OnAction()
                begin
                    IF Rec."Transfer-from Code" <> 'CD' then
                        SendDTEReception(Rec, true);
                end;
            }
        }
    }

    var
        myInt: Integer;
        StatusCertificate: Option Certificado,"No Certificado";
        StyleStatus: Option None,Standard,StandardAccent,Strong,StrongAccent,Attention,AttentionAccent,Favorable,Unfavorable,Ambiguous,Subordinate;
        StyleStatusText: Text;

    procedure ProStyleStutus(TextStatus: Text)
    var
        myInt: Integer;
    begin
        if (TextStatus in ['Certificado']) then
            StyleStatusText := Format(StyleStatus::Favorable)
        else
            StyleStatusText := Format(StyleStatus::Unfavorable);
    end;

    trigger OnOpenPage()

    begin

    end;

    trigger OnAfterGetRecord()
    var
        FSNDTEH: Record "FSN DTE Transaction Header";
    begin
        IF STRLEN(Rec."Transfer Order No.") > 10 THEN BEGIN//28981
            IF FSNDTEH.GET(COPYSTR(Rec."Transfer Order No.", 1, 10), COPYSTR(Rec."Transfer Order No.", 11, 10), 0) THEN BEGIN
                IF (FSNDTEH."DTE AuthNumber" <> '') AND (FSNDTEH."Signature Validation" <> '') THEN begin
                    StatusCertificate := StatusCertificate::Certificado;
                    ProStyleStutus(Format(StatusCertificate));
                end else begin
                    StatusCertificate := StatusCertificate::"No Certificado";
                    ProStyleStutus(Format(StatusCertificate));
                end;

            END ELSE begin
                StatusCertificate := StatusCertificate::"No Certificado";
                ProStyleStutus(Format(StatusCertificate));
            end;
        END ELSE
            IF FSNDTEH.GET(Rec."Transfer Order No.", '1', 0) THEN begin
                IF (FSNDTEH."DTE AuthNumber" <> '') AND (FSNDTEH."Signature Validation" <> '') THEN begin
                    StatusCertificate := StatusCertificate::Certificado;
                    ProStyleStutus(Format(StatusCertificate));
                end else begin
                    StatusCertificate := StatusCertificate::"No Certificado";
                    ProStyleStutus(Format(StatusCertificate));
                end;
            END ELSE begin
                StatusCertificate := StatusCertificate::"No Certificado";
                ProStyleStutus(Format(StatusCertificate));
            end;
    end;

    procedure SendDTEReception(var TransferReceiptHeader: Record "Transfer Receipt Header"; Production: Boolean)
    var
        ToStore: Record "LSC Store";
        FromStore: Record "LSC Store";
        Json: Text;
        TransferReceiptLIne: Record "Transfer Receipt Line";
        FSN_DTE: Record "FSN DTE Transaction Header";
        NoSerie: Codeunit "NoSeriesManagement";
        NoSeries: Record "No. Series";
        NextSerie: Code[35];
        Item_l: Record Item;
        UM_l: Record "Item Unit of Measure";
        TotalCost: Decimal;
        i: Integer;
        e: Boolean;
        UnitCost: Decimal;
        TotalLine: Decimal;
        codeMH: Text[10];
        CodeNameMH: Text[10];
        DTEAuth_: Text[50];
        DTESign_: Text[50];
        NoText: array[2] of Text[75];
        FSN: Codeunit "FSN Utility";
        TxtDollars: Text;
        RespCenter: Record "Responsibility Center";
        StoreFiltDTE: Record "LSC Store";
        TerminalFiltDTE: Record "LSC POS Terminal";
        jsonInfo, SellerInfo, AddressInfo, BuyerInfo, TaxInfo, BuyerAddressInfo, TranfLineInfo, TotalInfo, DiscountsInfo, adendaInfo : JsonObject;
        JSonStringInformation: Text;
        sb: DotNet StringBuilder;
        Array1, Array2 : JsonArray;
        jValue: JsonValue;
        TransNo: Integer;
        TEXT001: Label 'Error al generar remision electronica.';
        TEXT002: Label 'No se encuentra numero de serie %1';
        TEXT003: Label 'Procesando DTE, Espere.......';
        TEXT004: Label 'Recepcion transferencia %1 Certificada';
        TEXT005: Label 'Configuracion DTE Store y DTE Terminal no existe para la tienda %1 en FSN FASANI Setup \ \ Transferencia %2 No Certificada.';
        TEXT006: Label 'Configuracion DTE no existe para la tienda %1 en FSN FASANI Setup \ \ Transferencia %2 No Certificada.';
        FSNParameter: Record "FSN Fasani Setup";
        Windows: Dialog;
        DTEValTransct: Codeunit "DTE Validate Transaction";
        Tokenv: Text;
    begin

        CLEAR(FSN_DTE);
        CLEAR(e);
        IF FSNParameter.GET(TransferReceiptHeader."LSC Store-from") then begin
            if (FSNParameter."DTE Store" = '') or (FSNParameter."DTE Terminal" = '') then
                Error(TEXT005, TransferReceiptHeader."LSC Store-from", TransferReceiptHeader."Transfer Order No.");
        end else
            Error(TEXT006, TransferReceiptHeader."LSC Store-from", TransferReceiptHeader."Transfer Order No.");

        IF STRLEN(TransferReceiptHeader."Transfer Order No.") > 10 THEN BEGIN//28981
            IF FSN_DTE.GET(COPYSTR(TransferReceiptHeader."Transfer Order No.", 1, 10), COPYSTR(TransferReceiptHeader."Transfer Order No.", 11, 10), 0) THEN BEGIN
                IF TransferReceiptHeader."External Document No." <> FSN_DTE."DTE Invoice" THEN BEGIN
                    TransferReceiptHeader."External Document No." := FSN_DTE."DTE Invoice";
                    TransferReceiptHeader.MODIFY;
                END;
                e := TRUE;

                IF (FSN_DTE."DTE AuthNumber" <> '') AND (FSN_DTE."Signature Validation" <> '') THEN begin
                    Message(STRSUBSTNO(TEXT004, TransferReceiptHeader."Transfer Order No."));
                    exit;
                end;

            END;
        END ELSE
            IF FSN_DTE.GET(TransferReceiptHeader."Transfer Order No.", '1', 0) THEN BEGIN
                IF TransferReceiptHeader."External Document No." <> FSN_DTE."DTE Invoice" THEN BEGIN
                    TransferReceiptHeader."External Document No." := FSN_DTE."DTE Invoice";
                    TransferReceiptHeader.MODIFY;
                END;

                e := TRUE;

                IF (FSN_DTE."DTE AuthNumber" <> '') AND (FSN_DTE."Signature Validation" <> '') THEN begin
                    Message(STRSUBSTNO(TEXT004, TransferReceiptHeader."Transfer Order No."));
                    exit;
                end;
            END;
        FromStore.GET(TransferReceiptHeader."LSC Store-from");
        ToStore.GET(TransferReceiptHeader."LSC Store-to");
        StoreFiltDTE.GET(TransferReceiptHeader."LSC Store-from");
        IF not FSNParameter.GET(TransferReceiptHeader."LSC Store-from") then
            EXIT;
        RespCenter.Get(StoreFiltDTE."No.");
        TerminalFiltDTE.Reset();
        TerminalFiltDTE.SetRange("Store No.", StoreFiltDTE."No.");
        TerminalFiltDTE.SetRange(TerminalFiltDTE."DTE CodeSellingPointMH", 'P002');
        IF TerminalFiltDTE.FindFirst() THEN;
        IF NOT e THEN BEGIN
            FSN_DTE.INIT;
            FSN_DTE."Store No." := COPYSTR(TransferReceiptHeader."Transfer Order No.", 1, 10);
            IF STRLEN(TransferReceiptHeader."Transfer Order No.") > 10 THEN
                FSN_DTE."POS Terminal No." := COPYSTR(TransferReceiptHeader."Transfer Order No.", 11, 10)
            ELSE
                FSN_DTE."POS Terminal No." := '1';
            FSN_DTE."DTE AuthNumber" := COPYSTR(UpperCase(CreateGuid()), 2, 36);
            FSN_DTE."Transaction No." := 0;
            FSN_DTE."Creating Date" := TODAY;
            FSN_DTE."Document Type" := '04';

            IF NOT NoSeries.Get((COPYSTR(FromStore."No.", 1, 5) + 'TRDTE')) THEN
                ERROR(STRSUBSTNO(TEXT002, (COPYSTR(FromStore."No.", 1, 5) + 'TRDTE')));
            NextSerie := NoSerie.GetNextNo((COPYSTR(FromStore."No.", 1, 5) + 'TRDTE'), TODAY, TRUE);
            FSN_DTE."DTE EnrolledTimeStamp" := NextSerie;
            StoreFiltDTE.GET(TransferReceiptHeader."LSC Store-from");
            RespCenter.Get(StoreFiltDTE."No.");
            TerminalFiltDTE.Reset();
            TerminalFiltDTE.SetRange("Store No.", StoreFiltDTE."No.");
            TerminalFiltDTE.SetRange(TerminalFiltDTE."DTE CodeSellingPointMH", 'P002');
            IF TerminalFiltDTE.FindFirst() THEN;
            //IF FSNParameter.GET(Transfer."Store-from") AND (FSNParameter."DTE Store" <> '') AND (FSNParameter."DTE Terminal" <> '') THEN
            FSN_DTE."DTE Invoice" := 'DTE-04-' + FSNParameter."DTE Store" + FSNParameter."DTE Terminal" + '-' + NextSerie;
            //ELSE
            //FSN_DTE."DTE Invoice" := 'DTE-04-00' + COPYSTR(Transfer."Store-from",2,2) + '0000-' +  NextSerie;
            if not FSN_DTE.INSERT(TRUE) then
                FSN_DTE.Modify(TRUE);

            TransferReceiptHeader."External Document No." := FSN_DTE."DTE Invoice";
            TransferReceiptHeader.MODIFY;
        END;

        if FSN_DTE."DTE Invoice" = '' then begin
            IF NOT NoSeries.Get((COPYSTR(FromStore."No.", 1, 5) + 'TRDTE')) THEN
                ERROR(STRSUBSTNO(TEXT002, (COPYSTR(FromStore."No.", 1, 5) + 'TRDTE')));

            NextSerie := NoSerie.GetNextNo((COPYSTR(FromStore."No.", 1, 5) + 'TRDTE'), TODAY, TRUE);
            FSN_DTE."DTE EnrolledTimeStamp" := NextSerie;
            FSN_DTE."DTE Invoice" := 'DTE-04-' + FSNParameter."DTE Store" + FSNParameter."DTE Terminal" + '-' + NextSerie;
            FSN_DTE.Modify(TRUE);

            TransferReceiptHeader."External Document No." := FSN_DTE."DTE Invoice";
            TransferReceiptHeader.MODIFY;
        end;

        IF NOT Production THEN
            EXIT;
        COMMIT;
        i := 0;

        IF FromStore."No." = 'DIFERENCIA' THEN
            CodeNameMH := 'AUX1'
        ELSE
            CodeNameMH := FSNParameter."DTE Store";

        codeMH := FSNParameter."DTE Store";

        jsonInfo.Add('GUID', FSN_DTE."DTE AuthNumber");
        jsonInfo.Add('DocumentType', '04');
        jsonInfo.Add('OperationType', '01');
        jsonInfo.Add('IssuedDate', FORMAT(DATE2DMY(TODAY, 3)) + '-' + FORMAT(DATE2DMY(TODAY, 2)) + '-' + FORMAT(DATE2DMY(TODAY, 1)));
        jsonInfo.Add('IssuedTime', FORMAT(TIME, 9));
        jsonInfo.Add('IdShop', CodeNameMH);
        jsonInfo.Add('Secuencial', FSN_DTE."DTE EnrolledTimeStamp");
        if Evaluate(TransNo, FSN_DTE."DTE EnrolledTimeStamp") then;
        jsonInfo.Add('TransNo', FSN_DTE."DTE EnrolledTimeStamp");
        jsonInfo.Add('PrintTicket', false);
        jValue.SetValueToNull();
        jsonInfo.Add('Contingency', jValue);

        SellerInfo.Add('Name', 'Farmacia San Nicolas S.A. de C.V.');
        SellerInfo.Add('NRC', '406-5');
        SellerInfo.Add('NIT', '0614-221265-001-4');
        SellerInfo.Add('CodeSellingPoint', 'P002');
        SellerInfo.Add('CodeSellingPointMH', 'P002');
        SellerInfo.Add('TypeEstablishment', '01');
        SellerInfo.Add('CodeEstablishment', CodeNameMH);
        SellerInfo.Add('codeEstablishmentMH', codeMH);
        SellerInfo.Add('Phone', '2555-5555');
        SellerInfo.Add('Email', RespCenter."E-Mail");
        SellerInfo.Add('ActivityCode', '46491');
        SellerInfo.Add('ActivityDesc', 'Venta al por mayor de productos medicinales, cosméticos, perfumería y productos de limpieza');

        jsonInfo.Add('Seller', SellerInfo);

        AddressInfo.Add('AddressLine', FromStore.Address);
        AddressInfo.Add('District', '05');
        AddressInfo.Add('State', '01');

        SellerInfo.Add('Address', AddressInfo);

        jsonInfo.Add('Buyer', BuyerInfo);
        BuyerInfo.Add('NRC', '406-5');

        BuyerInfo.Add('TaxInformation', TaxInfo);
        TaxInfo.Add('ID', '36');
        TaxInfo.Add('Value', '0614-221265-001-4');

        BuyerInfo.Add('ActivityCode', '46491');
        BuyerInfo.Add('ActivityDesc', 'Venta al por mayor de productos medicinales, cosméticos, perfumería y productos de limpieza');
        BuyerInfo.Add('Name', 'Farmacia San Nicolas S.A. de C.V.');
        BuyerInfo.Add('ComercialName', ToStore.Name);
        BuyerInfo.Add('Phone', '22253733');
        BuyerInfo.Add('Email', RespCenter."E-Mail");

        BuyerInfo.Add('Address', BuyerAddressInfo);
        BuyerAddressInfo.Add('AddressLine', ToStore.Address);
        BuyerAddressInfo.Add('District', '11');
        BuyerAddressInfo.Add('State', '05');

        BuyerInfo.Add('BienTitulo', '04');

        TotalCost := 0;
        i := 0;

        TransferReceiptLIne.RESET;
        TransferReceiptLIne.SETRANGE(TransferReceiptLIne."Document No.", TransferReceiptHeader."No.");
        //TransferLIne.SETRANGE(TransferLIne."Derived From Line No.", 0);
        TransferReceiptLIne.SETFILTER(TransferReceiptLIne.Quantity, '>0');
        TransferReceiptLIne.FIND('-');
        REPEAT

            Item_l.GET(TransferReceiptLIne."Item No.");
            UM_l.GET(TransferReceiptLIne."Item No.", TransferReceiptLIne."Unit of Measure");
            IF Item_l."Unit Cost" = 0 THEN
                Item_l."Unit Cost" := 0.01;

            UnitCost := Item_l."Unit Cost" * UM_l."Qty. per Unit of Measure";
            TotalCost += ROUND(UnitCost * TransferReceiptLIne.Quantity, 0.01);
            TotalLine := ROUND(UnitCost * TransferReceiptLIne.Quantity, 0.01);
            UnitCost := ROUND(TotalLine / TransferReceiptLIne.Quantity, 0.00001);

            Clear(TranfLineInfo);
            TranfLineInfo.Add('Code', TransferReceiptLIne."Item No.");
            TranfLineInfo.Add('Name', DELCHR(TransferReceiptLIne.Description, '=', '"'));
            TranfLineInfo.Add('UnitOfMeasure', '59');
            TranfLineInfo.Add('ProductType', '1');
            TranfLineInfo.Add('Quantity', DELCHR(FORMAT(TransferReceiptLIne.Quantity), '=', ','));
            TranfLineInfo.Add('SuggestedSalePrice', '0.00');
            TranfLineInfo.Add('Discount', '0.00');
            TranfLineInfo.Add('NO_GRAVADO', '0.00');
            TranfLineInfo.Add('VENTA_NO_SUJETA', '0.00');
            TranfLineInfo.Add('VENTA_EXENTA', '0.00');
            TranfLineInfo.Add('VENTA_GRAVADA', DELCHR(FORMAT(TotalLine), '=', ','));
            TranfLineInfo.Add('Total', DELCHR(FORMAT(TotalLine), '=', ','));
            TranfLineInfo.Add('price', DELCHR(FORMAT(UnitCost), '=', ','));
            jValue.SetValueToNull();
            TranfLineInfo.Add('Document', jValue);
            Array1.Add(TranfLineInfo);
        UNTIL TransferReceiptLIne.NEXT = 0;

        jsonInfo.Add('ProductList', Array1);

        CLEAR(NoText);
        CLEAR(FSN);
        //TxtDollars := FSN.FormatNoText1(NoText, ABS(ROUND(TotalCost * 0.13, 0.01) + TotalCost));
        TxtDollars := FSN.Num2Text(ABS(ROUND(TotalCost * 0.13, 0.01) + TotalCost));

        jValue.SetValueToNull();
        jsonInfo.Add('PaymentList', jValue);

        jsonInfo.Add('Totals', TotalInfo);
        TotalInfo.Add('SubTotal', DELCHR(FORMAT(TotalCost), '=', ','));
        TotalInfo.Add('TOTAL_NO_GRAVADO', '0.00');
        TotalInfo.Add('TOTAL_NO_SUJETA', '0.00');

        TotalInfo.Add('Discounts', DiscountsInfo);
        DiscountsInfo.Add('Exento', '0.00');
        DiscountsInfo.Add('Gravado', '0.00');

        TotalInfo.Add('TOTAL_EXENTO', '0.00');
        TotalInfo.Add('TOTAL_GRAVADO', DELCHR(FORMAT(TotalCost), '=', ','));
        TotalInfo.Add('IVA', FORMAT(ROUND(TotalCost * 0.13, 0.01)));
        TotalInfo.Add('IvaPercibido', '0.00');
        TotalInfo.Add('IvaRetenido', '0.00');
        TotalInfo.Add('RetencionRenta', '0.00');
        TotalInfo.Add('InWords', TxtDollars);
        TotalInfo.Add('Amount', DELCHR(FORMAT(ROUND(TotalCost * 0.13, 0.01) + TotalCost)));

        adendaInfo.Add('name', 'SucDestino');
        adendaInfo.Add('data', 'SucDestino');
        adendaInfo.Add('value', ToStore.Name + ' ' + TransferReceiptHeader."Transfer Order No.");
        Array2.Add(adendaInfo);

        jsonInfo.Add('adenda', Array2);

        jsonInfo.WriteTo(JSonStringInformation);
        sb := sb.StringBuilder();
        sb.Append(JSonStringInformation);
        //Message(JSonStringInformation);

        Windows.OPEN(TEXT003);
        Windows.UPDATE;
        DTEValTransct.DTERemission(JSonStringInformation, TransferReceiptHeader."Transfer Order No.", DTESign_, DTEAuth_, Tokenv);
        Windows.Close();

        IF DTEAuth_ <> '' THEN BEGIN
            FSN_DTE."DTE AuthNumber" := DTEAuth_;
            FSN_DTE."Signature Validation" := DTESign_;
            FSN_DTE.MODIFY(TRUE);
            COMMIT;

        END ELSE
            ERROR(TEXT001);
    end;

}