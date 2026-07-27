page 50119 "FSN Correction DTE"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "LSC POS Menu Line";
    SourceTableTemporary = true;
    MultipleNewLines = false;
    DeleteAllowed = false;
    InsertAllowed = false;


    layout
    {
        area(Content)
        {
            group(GroupName)
            {
                Caption = 'Ajuste DTE';
                grid(f)
                {
                    field("Post Parameter"; "Post Parameter")
                    {
                        ApplicationArea = All;
                        Caption = 'Tipo Movimiento:';
                        Editable = false;
                        Style = Strong;
                        StyleExpr = 'Favorable';

                    }
                    field("Menu ID"; "Menu ID")
                    {
                        ApplicationArea = All;
                        Caption = 'No. :';
                        Editable = false;
                        Style = Strong;
                        StyleExpr = 'Favorable';
                    }
                }
            }
            group(Dte)
            {
                Caption = 'DTE';
                grid(a)
                {
                    field("Set Current-Input"; "Set Current-Input")
                    {
                        ApplicationArea = All;
                        Caption = 'DTE Invoice';
                    }
                }
                grid(b)
                {
                    field("Current-Description"; "Current-Description")
                    {
                        ApplicationArea = All;
                        Caption = 'Codigo Generacion';
                    }
                }
                grid(c)
                {
                    field("Current-Description2"; "Current-Description2")
                    {
                        ApplicationArea = All;
                        Caption = 'Sello Validacion';
                    }
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ActionName)
            {
                Caption = 'Modificar DTE';
                Image = Import;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                PromotedOnly = true;

                trigger OnAction()
                var
                begin

                    case "Post Parameter" of //primer saltola modificar DTE
                        'Hist. Facturas Ventas':
                            begin
                                // Update Sales Invoice DTE fields
                                ModifySalesInvoiceHeader();
                            end;
                        'Histórico facturas compra':
                            begin
                                // Update Purchase Invoice DTE fields
                                ModifyPurchaseInvoiceHeader();
                            end;
                        'Nota de crédito venta regis.':
                            begin
                                // Update Sales Credit Memo DTE fields
                                ModifySalesCreditMemo();
                            end;
                        'Nota créd. compra registrada':
                            begin
                                // Update Purchase Credit Memo DTE fields
                                ModifyPurchCrMemoHdr();
                            end;
                        else
                            Error('Tipo de Movimiento no reconocido: %1', "Post Parameter");
                    end;
                end;
            }
        }
    }

    var
        myInt: Integer;
        GPosMenuLine: Record "LSC POS Menu Line" temporary;

    procedure MenuLine(PosMenuLines: Record "LSC POS Menu Line" temporary)
    var
        myInt: Integer;
    begin
        GPosMenuLine := PosMenuLines;
    end;

    trigger OnOpenPage()
    var
        myInt: Integer;
    begin
        Rec := GPosMenuLine;
        Rec.Insert();
    end;

    procedure ModifySalesInvoiceHeader()
    var
        myInt: Integer;
        SalesInvHeader: Record "Sales Invoice Header";
    begin
        if SalesInvHeader.Get(Rec."Menu ID") then begin

            if ValRegSalesInvoice() then
                exit;
            SalesInvHeader.Validate("DTE Invoice", Rec."Set Current-Input");
            SalesInvHeader.Validate("DTE AuthNumber", Rec."Current-Description");
            SalesInvHeader.Validate("Signature Validation", Rec."Current-Description2");
            SalesInvHeader."External Document No." := Rec."Set Current-Input";
            SalesInvHeader.Modify();
            Message('DTE de Factura de Venta actualizado correctamente.');
        end else
            Error('No se encontró la Factura de Venta con No. %1', Rec."Menu ID");
    end;

    procedure ValRegSalesInvoice(): Boolean
    var
        SalesInvHeader: Record "Sales Invoice Header";
        DTEInvoce: Boolean;
        DTEAuthNum: Boolean;
        SigVal: Boolean;
    begin
        SalesInvHeader.Reset();
        SalesInvHeader.SetRange("DTE Invoice", Rec."Set Current-Input");
        if SalesInvHeader.FindFirst() then begin
            if SalesInvHeader."No." <> Rec."Menu ID" then begin
                DTEInvoce := true;
                Message('El DTE Invoice %1 ya existe en la Factura de Venta No. %2', Rec."Set Current-Input", SalesInvHeader."No.");
            end;
        end;

        SalesInvHeader.Reset();
        SalesInvHeader.SetRange("DTE AuthNumber", Rec."Current-Description");
        if SalesInvHeader.FindFirst() then begin
            if SalesInvHeader."No." <> Rec."Menu ID" then begin
                DTEAuthNum := true;
                Message('El DTE AuthNumber %1 ya existe en la Factura de Venta No. %2', Rec."Current-Description", SalesInvHeader."No.");
            end;
        end;

        SalesInvHeader.Reset();
        SalesInvHeader.SetRange("Signature Validation", Rec."Current-Description2");
        if SalesInvHeader.FindFirst() then begin
            if SalesInvHeader."No." <> Rec."Menu ID" then begin
                SigVal := true;
                Message('El Signature Validation %1 ya existe en la Factura de Venta No. %2', Rec."Current-Description2", SalesInvHeader."No.");
            end;
        end;

        exit(DTEInvoce or DTEAuthNum or SigVal);
    end;

    procedure ModifyPurchaseInvoiceHeader()
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchRecHeader: Record "Purch. Rcpt. Header";
        DTEFieldsChanged: Boolean;
        NewVendorInvoiceNo: Code[35];
    begin
        if PurchInvHeader.Get(Rec."Menu ID") then begin
            if ValPurchaseInvoice() then
                exit;

            DTEFieldsChanged :=
                (PurchInvHeader."DTE Invoice" <> Rec."Set Current-Input") or
                (PurchInvHeader."DTE AuthNumber" <> Rec."Current-Description") or
                (PurchInvHeader."Signature Validation" <> Rec."Current-Description2");

            PurchRecHeader.Reset();
            PurchRecHeader.SetRange("DTE AuthNumber", PurchInvHeader."DTE AuthNumber");
            if PurchRecHeader.FindFirst() then begin
                PurchRecHeader.Validate("DTE Invoice", Rec."Set Current-Input");
                PurchRecHeader.Validate("DTE AuthNumber", Rec."Current-Description");
                PurchRecHeader.Validate("Signature Validation", Rec."Current-Description2");
                PurchRecHeader.Modify();
            end;

            PurchInvHeader.Validate("DTE Invoice", Rec."Set Current-Input");
            PurchInvHeader.Validate("DTE AuthNumber", Rec."Current-Description");
            PurchInvHeader.Validate("Signature Validation", Rec."Current-Description2");

            if DTEFieldsChanged then begin
                NewVendorInvoiceNo := GetUniquePurchInvVendorInvoiceNo(Rec."Set Current-Input", PurchInvHeader."Posting Date", PurchInvHeader."Buy-from Vendor No.", PurchInvHeader."No.");
                PurchInvHeader.Validate("Vendor Invoice No.", NewVendorInvoiceNo);
                Message(
                    'DTE abreviado actualizado en Vendor Invoice No. Documento=%1, nuevo valor=%2.',
                    PurchInvHeader."No.",
                    NewVendorInvoiceNo);
            end else
                Message('DTE abreviado no se actualizo porque no hubo cambios en DTE Invoice, Codigo Generacion ni Sello Validacion.');

            PurchInvHeader.Modify();
            Message('DTE de Factura de Compra actualizado correctamente.');
        end else
            Error('No se encontro la Factura de Compra con No. %1', Rec."Menu ID");
    end;

    local procedure ValPurchaseInvoice(): Boolean
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        CurrentPurchInvHeader: Record "Purch. Inv. Header";
        DTEInvoce: Boolean;
        DTEAuthNum: Boolean;
        SigVal: Boolean;
        PostingYear: Integer;
        YearStart: Date;
        YearEnd: Date;
        SuggestedVendorInvoiceNo: Code[35];
    begin
        if not CurrentPurchInvHeader.Get(Rec."Menu ID") then begin
            Message('DEBUG Factura Compra: no se encontro la factura actual %1 para validar.', Rec."Menu ID");
            exit(true);
        end;

        PostingYear := Date2DMY(CurrentPurchInvHeader."Posting Date", 3);
        YearStart := DMY2Date(1, 1, PostingYear);
        YearEnd := DMY2Date(31, 12, PostingYear);

        Message(
            'DEBUG Factura Compra: Documento=%1, Proveedor=%2, Fecha registro=%3, Anio=%4, Vendor Invoice No. actual=%5.',
            Rec."Menu ID",
            CurrentPurchInvHeader."Buy-from Vendor No.",
            CurrentPurchInvHeader."Posting Date",
            PostingYear,
            CurrentPurchInvHeader."Vendor Invoice No.");

        Message(
            'DATOS ACTUALES: DTE Invoice=%1, Codigo Generacion=%2, Sello Validacion=%3.',
            CurrentPurchInvHeader."DTE Invoice",
            CurrentPurchInvHeader."DTE AuthNumber",
            CurrentPurchInvHeader."Signature Validation");

        Message(
            'DATOS INGRESADOS: DTE Invoice=%1, Codigo Generacion=%2, Sello Validacion=%3.',
            Rec."Set Current-Input",
            Rec."Current-Description",
            Rec."Current-Description2");

        if (CurrentPurchInvHeader."DTE Invoice" = Rec."Set Current-Input") and
           (CurrentPurchInvHeader."DTE AuthNumber" = Rec."Current-Description") and
           (CurrentPurchInvHeader."Signature Validation" = Rec."Current-Description2")
        then
            Message('INFO: los datos ingresados son iguales a los datos actuales de la factura %1.', Rec."Menu ID");

        PurchInvHeader.Reset();
        if Rec."Set Current-Input" <> '' then begin
            PurchInvHeader.SetRange("DTE Invoice", Rec."Set Current-Input");
            PurchInvHeader.SetRange("Buy-from Vendor No.", CurrentPurchInvHeader."Buy-from Vendor No.");
            PurchInvHeader.SetRange("Posting Date", YearStart, YearEnd);
            PurchInvHeader.SetFilter("No.", '<>%1', Rec."Menu ID");
            if PurchInvHeader.FindFirst() then begin
                DTEInvoce := true;
                Message(
                    'VALIDACION FALLIDA: el DTE Invoice %1 ya existe para el proveedor %2 en el anio %3. Factura encontrada=%4, Vendor Invoice No.=%5, Fecha registro=%6.',
                    Rec."Set Current-Input",
                    CurrentPurchInvHeader."Buy-from Vendor No.",
                    PostingYear,
                    PurchInvHeader."No.",
                    PurchInvHeader."Vendor Invoice No.",
                    PurchInvHeader."Posting Date");
            end else
                Message(
                    'VALIDACION OK: no existe otro DTE Invoice %1 para el proveedor %2 entre %3 y %4.',
                    Rec."Set Current-Input",
                    CurrentPurchInvHeader."Buy-from Vendor No.",
                    YearStart,
                    YearEnd);
        end else
            Message('VALIDACION OMITIDA: DTE Invoice viene vacio.');

        PurchInvHeader.Reset();
        if Rec."Current-Description" <> '' then begin
            PurchInvHeader.SetRange("DTE AuthNumber", Rec."Current-Description");
            PurchInvHeader.SetFilter("No.", '<>%1', Rec."Menu ID");
            if PurchInvHeader.FindFirst() then begin
                DTEAuthNum := true;
                Message(
                    'VALIDACION FALLIDA: el Codigo Generacion %1 ya existe en la Factura de Compra No. %2.',
                    Rec."Current-Description",
                    PurchInvHeader."No.");
            end else
                Message('VALIDACION OK: no existe otro Codigo Generacion %1 en facturas de compra.', Rec."Current-Description");
        end else
            Message('VALIDACION OMITIDA: Codigo Generacion viene vacio.');

        PurchInvHeader.Reset();
        if Rec."Current-Description2" <> '' then begin
            PurchInvHeader.SetRange("Signature Validation", Rec."Current-Description2");
            PurchInvHeader.SetFilter("No.", '<>%1', Rec."Menu ID");
            if PurchInvHeader.FindFirst() then begin
                SigVal := true;
                Message(
                    'VALIDACION FALLIDA: el Sello Validacion %1 ya existe en la Factura de Compra No. %2.',
                    Rec."Current-Description2",
                    PurchInvHeader."No.");
            end else
                Message('VALIDACION OK: no existe otro Sello Validacion %1 en facturas de compra.', Rec."Current-Description2");
        end else
            Message('VALIDACION OMITIDA: Sello Validacion viene vacio.');

        if DTEInvoce or DTEAuthNum or SigVal then begin
            Message(
                'RESULTADO VALIDACION: NO se puede modificar. DTE Invoice duplicado=%1, Codigo Generacion duplicado=%2, Sello Validacion duplicado=%3.',
                DTEInvoce,
                DTEAuthNum,
                SigVal);
            exit(true);
        end;

        Message('RESULTADO VALIDACION: OK, se puede modificar la Factura de Compra %1.', Rec."Menu ID");

        SuggestedVendorInvoiceNo := GetUniquePurchInvVendorInvoiceNo(Rec."Set Current-Input", CurrentPurchInvHeader."Posting Date", CurrentPurchInvHeader."Buy-from Vendor No.", CurrentPurchInvHeader."No.");
        Message(
            'DEBUG Vendor Invoice No.: DTE Invoice nuevo=%1, abreviado unico sugerido=%2.',
            Rec."Set Current-Input",
            SuggestedVendorInvoiceNo);

        exit(false);
    end;

    // Update Sales Credit Memo DTE fields
    local procedure ModifySalesCreditMemo()
    var
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        if SalesCrMemoHeader.Get(Rec."Menu ID") then begin
            if ValSalesCred() then
                exit;
            SalesCrMemoHeader.Validate("DTE Invoice", Rec."Set Current-Input");
            SalesCrMemoHeader.Validate("DTE AuthNumber", Rec."Current-Description");
            SalesCrMemoHeader.Validate("Signature Validation", Rec."Current-Description2");
            SalesCrMemoHeader."External Document No." := Rec."Set Current-Input";
            SalesCrMemoHeader.Modify();
            Message('DTE de Nota de Crédito de Venta actualizado correctamente.');
        end else
            Error('No se encontró la Nota de Crédito de Venta con No. %1', Rec."Menu ID");
    end;

    local procedure ValSalesCred(): Boolean
    var
        DTEInvoce: Boolean;
        DTEAuthNum: Boolean;
        SigVal: Boolean;
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        SalesCrMemoHeader.Reset();
        SalesCrMemoHeader.SetRange("DTE Invoice", Rec."Set Current-Input");
        if SalesCrMemoHeader.FindFirst() then begin
            if SalesCrMemoHeader."No." <> Rec."Menu ID" then begin
                DTEInvoce := true;
                Message('El DTE Invoice %1 ya existe en la Nota de Crédito de Venta No. %2', Rec."Set Current-Input", SalesCrMemoHeader."No.");
            end;
        end;
        SalesCrMemoHeader.Reset();
        SalesCrMemoHeader.SetRange("DTE AuthNumber", Rec."Current-Description");
        if SalesCrMemoHeader.FindFirst() then begin
            if SalesCrMemoHeader."No." <> Rec."Menu ID" then begin
                DTEAuthNum := true;
                Message('El DTE AuthNumber %1 ya existe en la Nota de Crédito de Venta No. %2', Rec."Current-Description", SalesCrMemoHeader."No.");
            end;
        end;
        SalesCrMemoHeader.Reset();
        SalesCrMemoHeader.SetRange("Signature Validation", Rec."Current-Description2");
        if SalesCrMemoHeader.FindFirst() then begin
            if SalesCrMemoHeader."No." <> Rec."Menu ID" then begin
                SigVal := true;
                Message('El Signature Validation %1 ya existe en la Nota de Crédito de Venta No. %2', Rec."Current-Description2", SalesCrMemoHeader."No.");
            end;
        end;
        exit(DTEInvoce or DTEAuthNum or SigVal);
    end;

    // Update Purchase Credit Memo DTE fields
    local procedure ModifyPurchCrMemoHdr()
    var
        PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
        DTEFieldsChanged: Boolean;
        NewExternalDocNo: Code[35];
    begin
        if PurchCrMemoHdr.Get(Rec."Menu ID") then begin
            if ValPurchaseMemo() then
                exit;
            DTEFieldsChanged :=
                (PurchCrMemoHdr."DTE Invoice" <> Rec."Set Current-Input") or
                (PurchCrMemoHdr."DTE AuthNumber" <> Rec."Current-Description") or
                (PurchCrMemoHdr."Signature Validation" <> Rec."Current-Description2");
            PurchCrMemoHdr.Validate("DTE Invoice", Rec."Set Current-Input");
            PurchCrMemoHdr.Validate("DTE AuthNumber", Rec."Current-Description");
            PurchCrMemoHdr.Validate("Signature Validation", Rec."Current-Description2");
            if DTEFieldsChanged then begin
                NewExternalDocNo := GetUniqueExternalDocumentNo(Rec."Set Current-Input", PurchCrMemoHdr."Posting Date");
                PurchCrMemoHdr.Validate("Vendor Cr. Memo No.", NewExternalDocNo);
                Message(
                    'DTE abreviado actualizado en Vendor Cr. Memo No. Documento=%1, nuevo valor=%2.',
                    PurchCrMemoHdr."No.",
                    NewExternalDocNo);
            end else
                Message('DTE abreviado no se actualizo porque no hubo cambios en DTE Invoice, Codigo Generacion ni Sello Validacion.');
            PurchCrMemoHdr.Modify();
            Message('DTE de Nota de Crédito de Compra actualizado correctamente.');
        end else
            Error('No se encontró la Nota de Crédito de Compra con No. %1', Rec."Menu ID");
    end;

    local procedure ValPurchaseMemo(): Boolean
    var
        DTEInvoce: Boolean;
        DTEAuthNum: Boolean;
        SigVal: Boolean;
        PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
        CurrentPurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
        VendorLedgerEntry: Record "Vendor Ledger Entry";
        PostingYear: Integer;
        YearStart: Date;
        YearEnd: Date;
        SuggestedExternalDocNo: Code[35];
    begin
        if not CurrentPurchCrMemoHdr.Get(Rec."Menu ID") then begin
            Message('DEBUG NC Compra: no se encontro la nota de credito actual %1 para validar.', Rec."Menu ID");
            exit(true);
        end;

        PostingYear := Date2DMY(CurrentPurchCrMemoHdr."Posting Date", 3);
        YearStart := DMY2Date(1, 1, PostingYear);
        YearEnd := DMY2Date(31, 12, PostingYear);

        Message(
            'DEBUG NC Compra: inicia validacion. Documento=%1, Proveedor=%2, Fecha registro=%3, Anio=%4, DTE Invoice=%5, Codigo Generacion=%6, Sello Validacion=%7, Vendor Cr. Memo No.=%8',
            Rec."Menu ID",
            CurrentPurchCrMemoHdr."Buy-from Vendor No.",
            CurrentPurchCrMemoHdr."Posting Date",
            PostingYear,
            Rec."Set Current-Input",
            Rec."Current-Description",
            Rec."Current-Description2",
            CurrentPurchCrMemoHdr."Vendor Cr. Memo No.");

        Message(
            'DATOS ACTUALES: DTE Invoice=%1, Codigo Generacion=%2, Sello Validacion=%3.',
            CurrentPurchCrMemoHdr."DTE Invoice",
            CurrentPurchCrMemoHdr."DTE AuthNumber",
            CurrentPurchCrMemoHdr."Signature Validation");

        Message(
            'DATOS INGRESADOS: DTE Invoice=%1, Codigo Generacion=%2, Sello Validacion=%3.',
            Rec."Set Current-Input",
            Rec."Current-Description",
            Rec."Current-Description2");

        if (CurrentPurchCrMemoHdr."DTE Invoice" = Rec."Set Current-Input") and
           (CurrentPurchCrMemoHdr."DTE AuthNumber" = Rec."Current-Description") and
           (CurrentPurchCrMemoHdr."Signature Validation" = Rec."Current-Description2")
        then
            Message('INFO: los datos ingresados son iguales a los datos actuales de la nota %1.', Rec."Menu ID");

        PurchCrMemoHdr.Reset();
        if Rec."Set Current-Input" <> '' then begin
            PurchCrMemoHdr.SetRange("DTE Invoice", Rec."Set Current-Input");
            PurchCrMemoHdr.SetRange("Buy-from Vendor No.", CurrentPurchCrMemoHdr."Buy-from Vendor No.");
            PurchCrMemoHdr.SetRange("Posting Date", YearStart, YearEnd);
            PurchCrMemoHdr.SetFilter("No.", '<>%1', Rec."Menu ID");
            if PurchCrMemoHdr.FindFirst() then begin
                DTEInvoce := true;
                Message(
                    'VALIDACION FALLIDA: el DTE Invoice %1 ya existe para el proveedor %2 en el anio %3. Nota encontrada=%4, Vendor Cr. Memo No.=%5, Fecha registro=%6.',
                    Rec."Set Current-Input",
                    CurrentPurchCrMemoHdr."Buy-from Vendor No.",
                    PostingYear,
                    PurchCrMemoHdr."No.",
                    PurchCrMemoHdr."Vendor Cr. Memo No.",
                    PurchCrMemoHdr."Posting Date");
            end else
                Message(
                    'VALIDACION OK: no existe otro DTE Invoice %1 para el proveedor %2 entre %3 y %4.',
                    Rec."Set Current-Input",
                    CurrentPurchCrMemoHdr."Buy-from Vendor No.",
                    YearStart,
                    YearEnd);
        end else
            Message('VALIDACION OMITIDA: DTE Invoice viene vacio.');

        PurchCrMemoHdr.Reset();
        if Rec."Current-Description" <> '' then begin
            PurchCrMemoHdr.SetRange("DTE AuthNumber", Rec."Current-Description");
            PurchCrMemoHdr.SetFilter("No.", '<>%1', Rec."Menu ID");
            if PurchCrMemoHdr.FindFirst() then begin
                DTEAuthNum := true;
                Message(
                    'VALIDACION FALLIDA: el Codigo Generacion %1 ya existe en la Nota de Credito de Compra No. %2.',
                    Rec."Current-Description",
                    PurchCrMemoHdr."No.");
            end else
                Message('VALIDACION OK: no existe otro Codigo Generacion %1 en notas de credito de compra.', Rec."Current-Description");
        end else
            Message('VALIDACION OMITIDA: Codigo Generacion viene vacio.');

        PurchCrMemoHdr.Reset();
        if Rec."Current-Description2" <> '' then begin
            PurchCrMemoHdr.SetRange("Signature Validation", Rec."Current-Description2");
            PurchCrMemoHdr.SetFilter("No.", '<>%1', Rec."Menu ID");
            if PurchCrMemoHdr.FindFirst() then begin
                SigVal := true;
                Message(
                    'VALIDACION FALLIDA: el Sello Validacion %1 ya existe en la Nota de Credito de Compra No. %2.',
                    Rec."Current-Description2",
                    PurchCrMemoHdr."No.");
            end else
                Message('VALIDACION OK: no existe otro Sello Validacion %1 en notas de credito de compra.', Rec."Current-Description2");
        end else
            Message('VALIDACION OMITIDA: Sello Validacion viene vacio.');

        if DTEInvoce or DTEAuthNum or SigVal then begin
            Message(
                'RESULTADO VALIDACION: NO se puede modificar. DTE Invoice duplicado=%1, Codigo Generacion duplicado=%2, Sello Validacion duplicado=%3.',
                DTEInvoce,
                DTEAuthNum,
                SigVal);
            exit(true);
        end;

        Message('RESULTADO VALIDACION: OK, se puede modificar la Nota de Credito de Compra %1.', Rec."Menu ID");

        VendorLedgerEntry.Reset();
        if CurrentPurchCrMemoHdr."Vendor Cr. Memo No." <> '' then begin
            VendorLedgerEntry.SetRange("External Document No.", CurrentPurchCrMemoHdr."Vendor Cr. Memo No.");
            if VendorLedgerEntry.FindFirst() then begin
                Message(
                    'External Document No. actual %1 ya existe en Vendor Ledger Entry. Se generara un nuevo abreviado desde el DTE Invoice nuevo %2.',
                    CurrentPurchCrMemoHdr."Vendor Cr. Memo No.",
                    Rec."Set Current-Input");
                SuggestedExternalDocNo := GetUniqueExternalDocumentNo(Rec."Set Current-Input", CurrentPurchCrMemoHdr."Posting Date");
                Message(
                    'External Document No. actual %1 ya existe en Vendor Ledger Entry. Se debe usar el DTE abreviado unico %2.',
                    CurrentPurchCrMemoHdr."Vendor Cr. Memo No.",
                    SuggestedExternalDocNo);
            end else
                Message('External Document No. actual %1 no existe en Vendor Ledger Entry. Se mantiene ese valor.', CurrentPurchCrMemoHdr."Vendor Cr. Memo No.");
        end else
            Message('External Document No.: Vendor Cr. Memo No. esta vacio en la nota %1.', CurrentPurchCrMemoHdr."No.");

        exit(false);
    end;

    local procedure GetUniqueExternalDocumentNo(DTEInvoice: Code[31]; ReferenceDate: Date): Code[35]
    var
        ExternalDocNo: Code[35];
        DTEType: Text[10];
        ConsecutiveNo: Text[30];
        ReferenceYear: Text[4];
        FirstHyphenPos: Integer;
        RelativeSecondHyphenPos: Integer;
        SecondHyphenPos: Integer;
        LastHyphenPos: Integer;
    begin
        if DTEInvoice = '' then
            exit('');

        FirstHyphenPos := StrPos(DTEInvoice, '-');
        if FirstHyphenPos = 0 then
            exit(CopyStr(DTEInvoice, 1, MaxStrLen(ExternalDocNo)));

        RelativeSecondHyphenPos := StrPos(CopyStr(DTEInvoice, FirstHyphenPos + 1), '-');
        if RelativeSecondHyphenPos = 0 then
            exit(CopyStr(DTEInvoice, 1, MaxStrLen(ExternalDocNo)));

        SecondHyphenPos := FirstHyphenPos + RelativeSecondHyphenPos;
        LastHyphenPos := FindLastCharacterPosition(DTEInvoice, '-');
        if LastHyphenPos = 0 then
            exit(CopyStr(DTEInvoice, 1, MaxStrLen(ExternalDocNo)));

        DTEType := DelChr(CopyStr(DTEInvoice, FirstHyphenPos + 1, SecondHyphenPos - FirstHyphenPos - 1), '<', '0');
        if DTEType = '' then
            DTEType := '0';

        ConsecutiveNo := DelChr(CopyStr(DTEInvoice, LastHyphenPos + 1), '<', '0');
        if ConsecutiveNo = '' then
            ConsecutiveNo := '0';

        if ReferenceDate = 0D then
            ReferenceDate := WorkDate();

        ReferenceYear := Format(Date2DMY(ReferenceDate, 3));
        ExternalDocNo := CopyStr('DTE' + DTEType + '-' + CopyStr(ReferenceYear, 3, 2) + ConsecutiveNo, 1, MaxStrLen(ExternalDocNo));

        Message('DEBUG DTE abreviado: valor inicial generado=%1.', ExternalDocNo);

        while VendorExternalDocumentNoExists(ExternalDocNo) do begin
            Message('DEBUG DTE abreviado: %1 ya existe en Vendor Ledger Entry. Se agregara un punto.', ExternalDocNo);

            if StrLen(ExternalDocNo) >= MaxStrLen(ExternalDocNo) then
                Error('No se pudo generar un External Document No. unico para %1 porque %2 ya alcanzo el largo maximo.', DTEInvoice, ExternalDocNo);

            ExternalDocNo := CopyStr(ExternalDocNo + '.', 1, MaxStrLen(ExternalDocNo));
        end;

        Message('DEBUG DTE abreviado: valor final unico=%1.', ExternalDocNo);

        exit(ExternalDocNo);
    end;

    local procedure VendorExternalDocumentNoExists(ExternalDocNo: Code[35]): Boolean
    var
        VendorLedgerEntry: Record "Vendor Ledger Entry";
    begin
        VendorLedgerEntry.Reset();
        VendorLedgerEntry.SetRange("External Document No.", ExternalDocNo);
        exit(VendorLedgerEntry.FindFirst());
    end;

    local procedure GetUniquePurchInvVendorInvoiceNo(DTEInvoice: Code[31]; ReferenceDate: Date; VendorNo: Code[20]; CurrentDocumentNo: Code[20]): Code[35]
    var
        VendorInvoiceNo: Code[35];
        DTEType: Text[10];
        ConsecutiveNo: Text[30];
        ReferenceYear: Text[4];
        FirstHyphenPos: Integer;
        RelativeSecondHyphenPos: Integer;
        SecondHyphenPos: Integer;
        LastHyphenPos: Integer;
    begin
        if DTEInvoice = '' then
            exit('');

        FirstHyphenPos := StrPos(DTEInvoice, '-');
        if FirstHyphenPos = 0 then
            exit(CopyStr(DTEInvoice, 1, MaxStrLen(VendorInvoiceNo)));

        RelativeSecondHyphenPos := StrPos(CopyStr(DTEInvoice, FirstHyphenPos + 1), '-');
        if RelativeSecondHyphenPos = 0 then
            exit(CopyStr(DTEInvoice, 1, MaxStrLen(VendorInvoiceNo)));

        SecondHyphenPos := FirstHyphenPos + RelativeSecondHyphenPos;
        LastHyphenPos := FindLastCharacterPosition(DTEInvoice, '-');
        if LastHyphenPos = 0 then
            exit(CopyStr(DTEInvoice, 1, MaxStrLen(VendorInvoiceNo)));

        DTEType := DelChr(CopyStr(DTEInvoice, FirstHyphenPos + 1, SecondHyphenPos - FirstHyphenPos - 1), '<', '0');
        if DTEType = '' then
            DTEType := '0';

        ConsecutiveNo := DelChr(CopyStr(DTEInvoice, LastHyphenPos + 1), '<', '0');
        if ConsecutiveNo = '' then
            ConsecutiveNo := '0';

        if ReferenceDate = 0D then
            ReferenceDate := WorkDate();

        ReferenceYear := Format(Date2DMY(ReferenceDate, 3));
        VendorInvoiceNo := CopyStr('DTE' + DTEType + '-' + CopyStr(ReferenceYear, 3, 2) + ConsecutiveNo, 1, MaxStrLen(VendorInvoiceNo));

        Message('DEBUG Vendor Invoice No. abreviado: valor inicial generado=%1.', VendorInvoiceNo);

        while PurchInvVendorInvoiceNoExists(VendorInvoiceNo, VendorNo, CurrentDocumentNo) do begin
            Message('DEBUG Vendor Invoice No. abreviado: %1 ya existe para el proveedor %2. Se agregara un punto.', VendorInvoiceNo, VendorNo);

            if StrLen(VendorInvoiceNo) >= MaxStrLen(VendorInvoiceNo) then
                Error('No se pudo generar un Vendor Invoice No. unico para %1 porque %2 ya alcanzo el largo maximo.', DTEInvoice, VendorInvoiceNo);

            VendorInvoiceNo := CopyStr(VendorInvoiceNo + '.', 1, MaxStrLen(VendorInvoiceNo));
        end;

        Message('DEBUG Vendor Invoice No. abreviado: valor final unico=%1.', VendorInvoiceNo);

        exit(VendorInvoiceNo);
    end;

    local procedure PurchInvVendorInvoiceNoExists(VendorInvoiceNo: Code[35]; VendorNo: Code[20]; CurrentDocumentNo: Code[20]): Boolean
    var
        PurchInvHeader: Record "Purch. Inv. Header";
    begin
        PurchInvHeader.Reset();
        PurchInvHeader.SetRange("Vendor Invoice No.", VendorInvoiceNo);
        PurchInvHeader.SetRange("Buy-from Vendor No.", VendorNo);
        if CurrentDocumentNo <> '' then
            PurchInvHeader.SetFilter("No.", '<>%1', CurrentDocumentNo);
        exit(PurchInvHeader.FindFirst());
    end;

    local procedure FindLastCharacterPosition(Value: Text; Character: Text[1]): Integer
    var
        Position: Integer;
        LastPosition: Integer;
    begin
        for Position := 1 to StrLen(Value) do
            if CopyStr(Value, Position, 1) = Character then
                LastPosition := Position;

        exit(LastPosition);
    end;

    procedure ValidateDuplicDTE(): Boolean
    var
        SalesInvHeader: Record "Sales Invoice Header";
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchRecHeader: Record "Purch. Rcpt. Header";
        PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        
    end;
}
