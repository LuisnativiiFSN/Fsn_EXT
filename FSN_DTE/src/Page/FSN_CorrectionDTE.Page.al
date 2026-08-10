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
        SalesInvHeader: Record "Sales Invoice Header";
        DTEInvoiceChanged: Boolean;
        DTEAuthChanged: Boolean;
        SigValChanged: Boolean;
        NewExternalDocNo: Code[35];
        OldDTEInvoice: Code[31];
        OldDTEAuthNumber: Code[36];
        OldSignatureValidation: Text[50];
        OldExternalDocNo: Code[35];
    begin
        if SalesInvHeader.Get(Rec."Menu ID") then begin
            OldDTEInvoice := SalesInvHeader."DTE Invoice";
            OldDTEAuthNumber := SalesInvHeader."DTE AuthNumber";
            OldSignatureValidation := SalesInvHeader."Signature Validation";
            OldExternalDocNo := SalesInvHeader."External Document No.";

            if ValRegSalesInvoice() then
                exit;

            DTEInvoiceChanged := SalesInvHeader."DTE Invoice" <> Rec."Set Current-Input";
            DTEAuthChanged := SalesInvHeader."DTE AuthNumber" <> Rec."Current-Description";
            SigValChanged := SalesInvHeader."Signature Validation" <> Rec."Current-Description2";

            if not (DTEInvoiceChanged or DTEAuthChanged or SigValChanged) then
                Error('No hay cambios para modificar en la Factura de Venta %1.', SalesInvHeader."No.");

            if DTEInvoiceChanged then
                SalesInvHeader.Validate("DTE Invoice", Rec."Set Current-Input");
            if DTEAuthChanged then
                SalesInvHeader.Validate("DTE AuthNumber", Rec."Current-Description");
            if SigValChanged then
                SalesInvHeader.Validate("Signature Validation", Rec."Current-Description2");

            if DTEInvoiceChanged then begin
                NewExternalDocNo := GetUniqueSalesInvExternalDocNo(Rec."Set Current-Input", SalesInvHeader."Posting Date", SalesInvHeader."No.");
                SalesInvHeader.Validate("External Document No.", NewExternalDocNo);
                UpdateSalesInvoiceRelatedExternalDocNo(SalesInvHeader."No.", NewExternalDocNo);
            end;

            SalesInvHeader.Modify();
            ShowDTEChangeSummary(
                'Factura de Venta', SalesInvHeader."No.",
                OldDTEInvoice, SalesInvHeader."DTE Invoice",
                OldDTEAuthNumber, SalesInvHeader."DTE AuthNumber",
                OldSignatureValidation, SalesInvHeader."Signature Validation",
                OldExternalDocNo, SalesInvHeader."External Document No.");
        end else
            Error('No se encontró la Factura de Venta con No. %1', Rec."Menu ID");
    end;

    procedure ValRegSalesInvoice(): Boolean
    var
        SalesInvHeader: Record "Sales Invoice Header";
        CurrentSalesInvHeader: Record "Sales Invoice Header";
        DTEInvoiceChanged: Boolean;
        DTEAuthChanged: Boolean;
        SigValChanged: Boolean;
    begin
        if not CurrentSalesInvHeader.Get(Rec."Menu ID") then
            Error('No se encontro la Factura de Venta %1 para validar.', Rec."Menu ID");

        DTEInvoiceChanged := CurrentSalesInvHeader."DTE Invoice" <> Rec."Set Current-Input";
        DTEAuthChanged := CurrentSalesInvHeader."DTE AuthNumber" <> Rec."Current-Description";
        SigValChanged := CurrentSalesInvHeader."Signature Validation" <> Rec."Current-Description2";

        if DTEInvoiceChanged and (Rec."Set Current-Input" <> '') then begin
            SalesInvHeader.Reset();
            SalesInvHeader.SetRange("DTE Invoice", Rec."Set Current-Input");
            SalesInvHeader.SetFilter("No.", '<>%1', Rec."Menu ID");
            if SalesInvHeader.FindFirst() then
                Error('El DTE Invoice %1 ya existe en la Factura de Venta No. %2.', Rec."Set Current-Input", SalesInvHeader."No.");
        end;

        if DTEAuthChanged and (Rec."Current-Description" <> '') then begin
            SalesInvHeader.Reset();
            SalesInvHeader.SetRange("DTE AuthNumber", Rec."Current-Description");
            SalesInvHeader.SetFilter("No.", '<>%1', Rec."Menu ID");
            if SalesInvHeader.FindFirst() then
                Error('El DTE AuthNumber %1 ya existe en la Factura de Venta No. %2.', Rec."Current-Description", SalesInvHeader."No.");
        end;

        if SigValChanged and (Rec."Current-Description2" <> '') then begin
            SalesInvHeader.Reset();
            SalesInvHeader.SetRange("Signature Validation", Rec."Current-Description2");
            SalesInvHeader.SetFilter("No.", '<>%1', Rec."Menu ID");
            if SalesInvHeader.FindFirst() then
                Error('El Signature Validation %1 ya existe en la Factura de Venta No. %2.', Rec."Current-Description2", SalesInvHeader."No.");
        end;

        exit(false);
    end;

    procedure ModifyPurchaseInvoiceHeader()
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchRecHeader: Record "Purch. Rcpt. Header";
        PurchRecHeaderVariant: Variant;
        DTEInvoiceChanged: Boolean;
        DTEAuthChanged: Boolean;
        SigValChanged: Boolean;
        NewVendorInvoiceNo: Code[35];
        OldDTEInvoice: Code[31];
        OldDTEAuthNumber: Code[36];
        OldSignatureValidation: Text[50];
        OldVendorInvoiceNo: Code[35];
    begin
        if PurchInvHeader.Get(Rec."Menu ID") then begin
            OldDTEInvoice := PurchInvHeader."DTE Invoice";
            OldDTEAuthNumber := PurchInvHeader."DTE AuthNumber";
            OldSignatureValidation := PurchInvHeader."Signature Validation";
            OldVendorInvoiceNo := PurchInvHeader."Vendor Invoice No.";

            if ValPurchaseInvoice() then
                exit;

            DTEInvoiceChanged := PurchInvHeader."DTE Invoice" <> Rec."Set Current-Input";
            DTEAuthChanged := PurchInvHeader."DTE AuthNumber" <> Rec."Current-Description";
            SigValChanged := PurchInvHeader."Signature Validation" <> Rec."Current-Description2";

            if not (DTEInvoiceChanged or DTEAuthChanged or SigValChanged) then
                Error('No hay cambios para modificar en la Factura de Compra %1.', PurchInvHeader."No.");

            if DTEInvoiceChanged then
                PurchInvHeader.Validate("DTE Invoice", Rec."Set Current-Input");
            if DTEAuthChanged then
                PurchInvHeader.Validate("DTE AuthNumber", Rec."Current-Description");
            if SigValChanged then
                PurchInvHeader.Validate("Signature Validation", Rec."Current-Description2");

            if DTEInvoiceChanged then begin
                NewVendorInvoiceNo := GetUniquePurchInvVendorInvoiceNo(Rec."Set Current-Input", PurchInvHeader."Posting Date", PurchInvHeader."Buy-from Vendor No.", PurchInvHeader."No.");
                PurchInvHeader.Validate("Vendor Invoice No.", NewVendorInvoiceNo);
                PurchInvHeader.Validate("Vendor Invoice Number", NewVendorInvoiceNo);
                UpdatePurchaseInvoiceRelatedExternalDocNo(PurchInvHeader."No.", NewVendorInvoiceNo);
            end;

            PurchInvHeader.Modify();

            if FindPurchaseReceiptForInvoice(PurchInvHeader."No.", PurchRecHeader) then begin
                if DTEInvoiceChanged then begin
                    PurchRecHeader.Validate("DTE Invoice", Rec."Set Current-Input");
                    PurchRecHeaderVariant := PurchRecHeader;
                    if not ValidateFieldByName(PurchRecHeaderVariant, 'FSN Vendor Invoice No.', NewVendorInvoiceNo) then
                        Error('No se encontro el campo FSN Vendor Invoice No. en la recepcion de compra %1.', PurchRecHeader."No.");
                    PurchRecHeader := PurchRecHeaderVariant;
                end;
                if DTEAuthChanged then
                    PurchRecHeader.Validate("DTE AuthNumber", Rec."Current-Description");
                if SigValChanged then
                    PurchRecHeader.Validate("Signature Validation", Rec."Current-Description2");
                PurchRecHeader.Modify();
            end else
                Error('No se encontro una recepcion de compra relacionada por lineas para la factura %1.', PurchInvHeader."No.");

            ShowDTEChangeSummary(
                'Factura de Compra', PurchInvHeader."No.",
                OldDTEInvoice, PurchInvHeader."DTE Invoice",
                OldDTEAuthNumber, PurchInvHeader."DTE AuthNumber",
                OldSignatureValidation, PurchInvHeader."Signature Validation",
                OldVendorInvoiceNo, PurchInvHeader."Vendor Invoice No.");
        end else
            Error('No se encontro la Factura de Compra con No. %1', Rec."Menu ID");
    end;

    local procedure FindPurchaseReceiptForInvoice(InvoiceNo: Code[20]; var PurchRecHeader: Record "Purch. Rcpt. Header"): Boolean
    var
        PurchInvLine: Record "Purch. Inv. Line";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        TempPurchRcptHeader: Record "Purch. Rcpt. Header" temporary;
    begin
        PurchInvLine.Reset();
        PurchInvLine.SetRange("Document No.", InvoiceNo);
        PurchInvLine.SetFilter(Quantity, '<>%1', 0);

        if PurchInvLine.FindSet() then
            repeat
                PurchRcptLine.Reset();
                PurchRcptLine.SetRange("Order No.", PurchInvLine."Order No.");
                PurchRcptLine.SetRange("No.", PurchInvLine."No.");
                PurchRcptLine.SetRange(Quantity, PurchInvLine.Quantity);

                if PurchRcptLine.FindSet() then
                    repeat
                        if not TempPurchRcptHeader.Get(PurchRcptLine."Document No.") then begin
                            TempPurchRcptHeader.Init();
                            TempPurchRcptHeader."No." := PurchRcptLine."Document No.";
                            TempPurchRcptHeader.Insert();
                        end;
                    until PurchRcptLine.Next() = 0;
            until PurchInvLine.Next() = 0;

        if TempPurchRcptHeader.Count() > 1 then
            Error(
                'Se encontraron %1 recepciones de compra relacionadas por lineas para la factura %2. Se esperaba solamente una.',
                TempPurchRcptHeader.Count(),
                InvoiceNo);

        if not TempPurchRcptHeader.FindFirst() then
            exit(false);

        exit(PurchRecHeader.Get(TempPurchRcptHeader."No."));
    end;

    local procedure ValPurchaseInvoice(): Boolean
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        CurrentPurchInvHeader: Record "Purch. Inv. Header";
        PostingYear: Integer;
        YearStart: Date;
        YearEnd: Date;
        DTEInvoiceChanged: Boolean;
        DTEAuthChanged: Boolean;
        SigValChanged: Boolean;
    begin
        if not CurrentPurchInvHeader.Get(Rec."Menu ID") then
            Error('No se encontro la Factura de Compra %1 para validar.', Rec."Menu ID");

        DTEInvoiceChanged := CurrentPurchInvHeader."DTE Invoice" <> Rec."Set Current-Input";
        DTEAuthChanged := CurrentPurchInvHeader."DTE AuthNumber" <> Rec."Current-Description";
        SigValChanged := CurrentPurchInvHeader."Signature Validation" <> Rec."Current-Description2";

        PostingYear := Date2DMY(CurrentPurchInvHeader."Posting Date", 3);
        YearStart := DMY2Date(1, 1, PostingYear);
        YearEnd := DMY2Date(31, 12, PostingYear);

        if DTEInvoiceChanged and (Rec."Set Current-Input" <> '') then begin
            PurchInvHeader.Reset();
            PurchInvHeader.SetRange("DTE Invoice", Rec."Set Current-Input");
            PurchInvHeader.SetRange("Buy-from Vendor No.", CurrentPurchInvHeader."Buy-from Vendor No.");
            PurchInvHeader.SetRange("Posting Date", YearStart, YearEnd);
            PurchInvHeader.SetFilter("No.", '<>%1', Rec."Menu ID");
            if PurchInvHeader.FindFirst() then
                Error(
                    'El DTE Invoice %1 ya existe para el proveedor %2 en el anio %3, en la Factura de Compra No. %4.',
                    Rec."Set Current-Input",
                    CurrentPurchInvHeader."Buy-from Vendor No.",
                    PostingYear,
                    PurchInvHeader."No.");
        end;

        if DTEAuthChanged and (Rec."Current-Description" <> '') then begin
            PurchInvHeader.Reset();
            PurchInvHeader.SetRange("DTE AuthNumber", Rec."Current-Description");
            PurchInvHeader.SetFilter("No.", '<>%1', Rec."Menu ID");
            if PurchInvHeader.FindFirst() then
                Error(
                    'El Codigo Generacion %1 ya existe en la Factura de Compra No. %2.',
                    Rec."Current-Description",
                    PurchInvHeader."No.");
        end;

        if SigValChanged and (Rec."Current-Description2" <> '') then begin
            PurchInvHeader.Reset();
            PurchInvHeader.SetRange("Signature Validation", Rec."Current-Description2");
            PurchInvHeader.SetFilter("No.", '<>%1', Rec."Menu ID");
            if PurchInvHeader.FindFirst() then
                Error(
                    'El Sello Validacion %1 ya existe en la Factura de Compra No. %2.',
                    Rec."Current-Description2",
                    PurchInvHeader."No.");
        end;

        exit(false);
    end;

    // Update Sales Credit Memo DTE fields
    local procedure ModifySalesCreditMemo()
    var
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        DTEInvoiceChanged: Boolean;
        DTEAuthChanged: Boolean;
        SigValChanged: Boolean;
        NewExternalDocNo: Code[35];
        OldDTEInvoice: Code[31];
        OldDTEAuthNumber: Code[36];
        OldSignatureValidation: Text[50];
        OldExternalDocNo: Code[35];
    begin
        if SalesCrMemoHeader.Get(Rec."Menu ID") then begin
            OldDTEInvoice := SalesCrMemoHeader."DTE Invoice";
            OldDTEAuthNumber := SalesCrMemoHeader."DTE AuthNumber";
            OldSignatureValidation := SalesCrMemoHeader."Signature Validation";
            OldExternalDocNo := SalesCrMemoHeader."External Document No.";

            if ValSalesCred() then
                exit;

            DTEInvoiceChanged := SalesCrMemoHeader."DTE Invoice" <> Rec."Set Current-Input";
            DTEAuthChanged := SalesCrMemoHeader."DTE AuthNumber" <> Rec."Current-Description";
            SigValChanged := SalesCrMemoHeader."Signature Validation" <> Rec."Current-Description2";

            if not (DTEInvoiceChanged or DTEAuthChanged or SigValChanged) then
                Error('No hay cambios para modificar en la Nota de Credito de Venta %1.', SalesCrMemoHeader."No.");

            if DTEInvoiceChanged then
                SalesCrMemoHeader.Validate("DTE Invoice", Rec."Set Current-Input");
            if DTEAuthChanged then
                SalesCrMemoHeader.Validate("DTE AuthNumber", Rec."Current-Description");
            if SigValChanged then
                SalesCrMemoHeader.Validate("Signature Validation", Rec."Current-Description2");

            if DTEInvoiceChanged then begin
                NewExternalDocNo := GetUniqueSalesCrMemoExternalDocNo(Rec."Set Current-Input", SalesCrMemoHeader."Posting Date", SalesCrMemoHeader."No.");
                SalesCrMemoHeader.Validate("External Document No.", NewExternalDocNo);
                UpdateSalesCrMemoRelatedExternalDocNo(SalesCrMemoHeader."No.", NewExternalDocNo);
            end;

            SalesCrMemoHeader.Modify();
            ShowDTEChangeSummary(
                'Nota de Credito de Venta', SalesCrMemoHeader."No.",
                OldDTEInvoice, SalesCrMemoHeader."DTE Invoice",
                OldDTEAuthNumber, SalesCrMemoHeader."DTE AuthNumber",
                OldSignatureValidation, SalesCrMemoHeader."Signature Validation",
                OldExternalDocNo, SalesCrMemoHeader."External Document No.");
        end else
            Error('No se encontro la Nota de Credito de Venta con No. %1', Rec."Menu ID");
    end;

    local procedure ValSalesCred(): Boolean
    var
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        CurrentSalesCrMemoHeader: Record "Sales Cr.Memo Header";
        DTEInvoiceChanged: Boolean;
        DTEAuthChanged: Boolean;
        SigValChanged: Boolean;
    begin
        if not CurrentSalesCrMemoHeader.Get(Rec."Menu ID") then
            Error('No se encontro la Nota de Credito de Venta %1 para validar.', Rec."Menu ID");

        DTEInvoiceChanged := CurrentSalesCrMemoHeader."DTE Invoice" <> Rec."Set Current-Input";
        DTEAuthChanged := CurrentSalesCrMemoHeader."DTE AuthNumber" <> Rec."Current-Description";
        SigValChanged := CurrentSalesCrMemoHeader."Signature Validation" <> Rec."Current-Description2";

        if DTEInvoiceChanged and (Rec."Set Current-Input" <> '') then begin
            SalesCrMemoHeader.Reset();
            SalesCrMemoHeader.SetRange("DTE Invoice", Rec."Set Current-Input");
            SalesCrMemoHeader.SetFilter("No.", '<>%1', Rec."Menu ID");
            if SalesCrMemoHeader.FindFirst() then
                Error(
                    'El DTE Invoice %1 ya existe en la Nota de Credito de Venta No. %2.',
                    Rec."Set Current-Input",
                    SalesCrMemoHeader."No.");
        end;

        if DTEAuthChanged and (Rec."Current-Description" <> '') then begin
            SalesCrMemoHeader.Reset();
            SalesCrMemoHeader.SetRange("DTE AuthNumber", Rec."Current-Description");
            SalesCrMemoHeader.SetFilter("No.", '<>%1', Rec."Menu ID");
            if SalesCrMemoHeader.FindFirst() then
                Error(
                    'El Codigo Generacion %1 ya existe en la Nota de Credito de Venta No. %2.',
                    Rec."Current-Description",
                    SalesCrMemoHeader."No.");
        end;

        if SigValChanged and (Rec."Current-Description2" <> '') then begin
            SalesCrMemoHeader.Reset();
            SalesCrMemoHeader.SetRange("Signature Validation", Rec."Current-Description2");
            SalesCrMemoHeader.SetFilter("No.", '<>%1', Rec."Menu ID");
            if SalesCrMemoHeader.FindFirst() then
                Error(
                    'El Sello Validacion %1 ya existe en la Nota de Credito de Venta No. %2.',
                    Rec."Current-Description2",
                    SalesCrMemoHeader."No.");
        end;

        exit(false);
    end;

    // Update Purchase Credit Memo DTE fields
    local procedure ModifyPurchCrMemoHdr()
    var
        PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
        DTEInvoiceChanged: Boolean;
        DTEAuthChanged: Boolean;
        SigValChanged: Boolean;
        NewExternalDocNo: Code[35];
        OldDTEInvoice: Code[31];
        OldDTEAuthNumber: Code[36];
        OldSignatureValidation: Text[50];
        OldExternalDocNo: Code[35];
    begin
        if PurchCrMemoHdr.Get(Rec."Menu ID") then begin
            OldDTEInvoice := PurchCrMemoHdr."DTE Invoice";
            OldDTEAuthNumber := PurchCrMemoHdr."DTE AuthNumber";
            OldSignatureValidation := PurchCrMemoHdr."Signature Validation";
            OldExternalDocNo := PurchCrMemoHdr."Vendor Cr. Memo No.";

            if ValPurchaseMemo() then
                exit;

            DTEInvoiceChanged := PurchCrMemoHdr."DTE Invoice" <> Rec."Set Current-Input";
            DTEAuthChanged := PurchCrMemoHdr."DTE AuthNumber" <> Rec."Current-Description";
            SigValChanged := PurchCrMemoHdr."Signature Validation" <> Rec."Current-Description2";

            if not (DTEInvoiceChanged or DTEAuthChanged or SigValChanged) then
                Error('No hay cambios para modificar en la Nota de Credito de Compra %1.', PurchCrMemoHdr."No.");

            if DTEInvoiceChanged then
                PurchCrMemoHdr.Validate("DTE Invoice", Rec."Set Current-Input");
            if DTEAuthChanged then
                PurchCrMemoHdr.Validate("DTE AuthNumber", Rec."Current-Description");
            if SigValChanged then
                PurchCrMemoHdr.Validate("Signature Validation", Rec."Current-Description2");

            if DTEInvoiceChanged then begin
                NewExternalDocNo := GetUniqueExternalDocumentNo(Rec."Set Current-Input", PurchCrMemoHdr."Posting Date");
                PurchCrMemoHdr.Validate("Vendor Cr. Memo No.", NewExternalDocNo);
                UpdatePurchCrMemoRelatedExternalDocNo(PurchCrMemoHdr."No.", NewExternalDocNo);
            end;
            PurchCrMemoHdr.Modify();
            ShowDTEChangeSummary(
                'Nota de Credito de Compra', PurchCrMemoHdr."No.",
                OldDTEInvoice, PurchCrMemoHdr."DTE Invoice",
                OldDTEAuthNumber, PurchCrMemoHdr."DTE AuthNumber",
                OldSignatureValidation, PurchCrMemoHdr."Signature Validation",
                OldExternalDocNo, PurchCrMemoHdr."Vendor Cr. Memo No.");
        end else
            Error('No se encontró la Nota de Crédito de Compra con No. %1', Rec."Menu ID");
    end;

    local procedure ValPurchaseMemo(): Boolean
    var
        PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
        CurrentPurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
        PostingYear: Integer;
        YearStart: Date;
        YearEnd: Date;
        DTEInvoiceChanged: Boolean;
        DTEAuthChanged: Boolean;
        SigValChanged: Boolean;
    begin
        if not CurrentPurchCrMemoHdr.Get(Rec."Menu ID") then
            Error('No se encontro la Nota de Credito de Compra %1 para validar.', Rec."Menu ID");

        DTEInvoiceChanged := CurrentPurchCrMemoHdr."DTE Invoice" <> Rec."Set Current-Input";
        DTEAuthChanged := CurrentPurchCrMemoHdr."DTE AuthNumber" <> Rec."Current-Description";
        SigValChanged := CurrentPurchCrMemoHdr."Signature Validation" <> Rec."Current-Description2";

        PostingYear := Date2DMY(CurrentPurchCrMemoHdr."Posting Date", 3);
        YearStart := DMY2Date(1, 1, PostingYear);
        YearEnd := DMY2Date(31, 12, PostingYear);

        if DTEInvoiceChanged and (Rec."Set Current-Input" <> '') then begin
            PurchCrMemoHdr.Reset();
            PurchCrMemoHdr.SetRange("DTE Invoice", Rec."Set Current-Input");
            PurchCrMemoHdr.SetRange("Buy-from Vendor No.", CurrentPurchCrMemoHdr."Buy-from Vendor No.");
            PurchCrMemoHdr.SetRange("Posting Date", YearStart, YearEnd);
            PurchCrMemoHdr.SetFilter("No.", '<>%1', Rec."Menu ID");
            if PurchCrMemoHdr.FindFirst() then
                Error(
                    'El DTE Invoice %1 ya existe para el proveedor %2 en el anio %3, en la Nota de Credito de Compra No. %4.',
                    Rec."Set Current-Input",
                    CurrentPurchCrMemoHdr."Buy-from Vendor No.",
                    PostingYear,
                    PurchCrMemoHdr."No.");
        end;

        if DTEAuthChanged and (Rec."Current-Description" <> '') then begin
            PurchCrMemoHdr.Reset();
            PurchCrMemoHdr.SetRange("DTE AuthNumber", Rec."Current-Description");
            PurchCrMemoHdr.SetFilter("No.", '<>%1', Rec."Menu ID");
            if PurchCrMemoHdr.FindFirst() then
                Error(
                    'El Codigo Generacion %1 ya existe en la Nota de Credito de Compra No. %2.',
                    Rec."Current-Description",
                    PurchCrMemoHdr."No.");
        end;

        if SigValChanged and (Rec."Current-Description2" <> '') then begin
            PurchCrMemoHdr.Reset();
            PurchCrMemoHdr.SetRange("Signature Validation", Rec."Current-Description2");
            PurchCrMemoHdr.SetFilter("No.", '<>%1', Rec."Menu ID");
            if PurchCrMemoHdr.FindFirst() then
                Error(
                    'El Sello Validacion %1 ya existe en la Nota de Credito de Compra No. %2.',
                    Rec."Current-Description2",
                    PurchCrMemoHdr."No.");
        end;

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

        while VendorExternalDocumentNoExists(ExternalDocNo) do begin
            if StrLen(ExternalDocNo) >= MaxStrLen(ExternalDocNo) then
                Error('No se pudo generar un External Document No. unico para %1 porque %2 ya alcanzo el largo maximo.', DTEInvoice, ExternalDocNo);

            ExternalDocNo := CopyStr(ExternalDocNo + '.', 1, MaxStrLen(ExternalDocNo));
        end;

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

        while PurchInvVendorInvoiceNoExists(VendorInvoiceNo, VendorNo, CurrentDocumentNo) do begin
            if StrLen(VendorInvoiceNo) >= MaxStrLen(VendorInvoiceNo) then
                Error('No se pudo generar un Vendor Invoice No. unico para %1 porque %2 ya alcanzo el largo maximo.', DTEInvoice, VendorInvoiceNo);

            VendorInvoiceNo := CopyStr(VendorInvoiceNo + '.', 1, MaxStrLen(VendorInvoiceNo));
        end;

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

    local procedure GetUniqueSalesCrMemoExternalDocNo(DTEInvoice: Code[31]; ReferenceDate: Date; CurrentDocumentNo: Code[20]): Code[35]
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

        while SalesCrMemoExternalDocumentNoExists(ExternalDocNo, CurrentDocumentNo) do begin
            if StrLen(ExternalDocNo) >= MaxStrLen(ExternalDocNo) then
                Error('No se pudo generar un External Document No. unico para %1 porque %2 ya alcanzo el largo maximo.', DTEInvoice, ExternalDocNo);

            ExternalDocNo := CopyStr(ExternalDocNo + '.', 1, MaxStrLen(ExternalDocNo));
        end;

        exit(ExternalDocNo);
    end;

    local procedure SalesCrMemoExternalDocumentNoExists(ExternalDocNo: Code[35]; CurrentDocumentNo: Code[20]): Boolean
    var
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        SalesCrMemoHeader.Reset();
        SalesCrMemoHeader.SetRange("External Document No.", ExternalDocNo);
        if CurrentDocumentNo <> '' then
            SalesCrMemoHeader.SetFilter("No.", '<>%1', CurrentDocumentNo);
        exit(SalesCrMemoHeader.FindFirst());
    end;

    local procedure GetUniqueSalesInvExternalDocNo(DTEInvoice: Code[31]; ReferenceDate: Date; CurrentDocumentNo: Code[20]): Code[35]
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

        while SalesInvExternalDocumentNoExists(ExternalDocNo, CurrentDocumentNo) do begin
            if StrLen(ExternalDocNo) >= MaxStrLen(ExternalDocNo) then
                Error('No se pudo generar un External Document No. unico para %1 porque %2 ya alcanzo el largo maximo.', DTEInvoice, ExternalDocNo);

            ExternalDocNo := CopyStr(ExternalDocNo + '.', 1, MaxStrLen(ExternalDocNo));
        end;

        exit(ExternalDocNo);
    end;

    local procedure SalesInvExternalDocumentNoExists(ExternalDocNo: Code[35]; CurrentDocumentNo: Code[20]): Boolean
    var
        SalesInvHeader: Record "Sales Invoice Header";
    begin
        SalesInvHeader.Reset();
        SalesInvHeader.SetRange("External Document No.", ExternalDocNo);
        if CurrentDocumentNo <> '' then
            SalesInvHeader.SetFilter("No.", '<>%1', CurrentDocumentNo);
        exit(SalesInvHeader.FindFirst());
    end;

    local procedure UpdateSalesInvoiceRelatedExternalDocNo(DocumentNo: Code[20]; NewExternalDocNo: Code[35])
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
        GLEntry: Record "G/L Entry";
        LegalLedgerEntry: Record "Legal Ledger Entry";
    begin
        CustLedgerEntry.Reset();
        CustLedgerEntry.SetRange("Document Type", CustLedgerEntry."Document Type"::Invoice);
        CustLedgerEntry.SetRange("Document No.", DocumentNo);
        CustLedgerEntry.SetFilter("External Document No.", '<>%1', '');
        if CustLedgerEntry.FindSet() then
            repeat
                CustLedgerEntry.Validate("External Document No.", NewExternalDocNo);
                CustLedgerEntry.Modify();
            until CustLedgerEntry.Next() = 0;

        GLEntry.Reset();
        GLEntry.SetRange("Document Type", GLEntry."Document Type"::Invoice);
        GLEntry.SetRange("Source Code", 'VENTAS');
        GLEntry.SetRange("Document No.", DocumentNo);
        GLEntry.SetFilter("External Document No.", '<>%1', '');
        if GLEntry.FindSet() then
            repeat
                GLEntry.Validate("External Document No.", NewExternalDocNo);
                GLEntry.Modify();
            until GLEntry.Next() = 0;

        LegalLedgerEntry.Reset();
        LegalLedgerEntry.SetRange("Sub Type", 'FACT-V');
        LegalLedgerEntry.SetRange("No.", DocumentNo);
        LegalLedgerEntry.SetFilter("External Document No.", '<>%1', '');
        if LegalLedgerEntry.FindSet() then
            repeat
                LegalLedgerEntry.Validate("External Document No.", NewExternalDocNo);
                LegalLedgerEntry.Modify();
            until LegalLedgerEntry.Next() = 0;
    end;

    local procedure UpdateSalesCrMemoRelatedExternalDocNo(DocumentNo: Code[20]; NewExternalDocNo: Code[35])
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
        GLEntry: Record "G/L Entry";
        LegalLedgerEntry: Record "Legal Ledger Entry";
    begin
        CustLedgerEntry.Reset();
        CustLedgerEntry.SetRange("Document Type", CustLedgerEntry."Document Type"::"Credit Memo");
        CustLedgerEntry.SetRange("Document No.", DocumentNo);
        if CustLedgerEntry.FindSet() then
            repeat
                CustLedgerEntry.Validate("External Document No.", NewExternalDocNo);
                CustLedgerEntry.Modify();
            until CustLedgerEntry.Next() = 0;

        GLEntry.Reset();
        GLEntry.SetRange("Document Type", GLEntry."Document Type"::"Credit Memo");
        GLEntry.SetRange("Source Code", 'VENTAS');
        GLEntry.SetRange("Document No.", DocumentNo);
        if GLEntry.FindSet() then
            repeat
                GLEntry.Validate("External Document No.", NewExternalDocNo);
                GLEntry.Modify();
            until GLEntry.Next() = 0;

        LegalLedgerEntry.Reset();
        LegalLedgerEntry.SetRange("Sub Type", 'NC-V');
        LegalLedgerEntry.SetRange("No.", DocumentNo);
        if LegalLedgerEntry.FindSet() then
            repeat
                LegalLedgerEntry.Validate("External Document No.", NewExternalDocNo);
                LegalLedgerEntry.Modify();
            until LegalLedgerEntry.Next() = 0;
    end;

    local procedure UpdatePurchaseInvoiceRelatedExternalDocNo(DocumentNo: Code[20]; NewExternalDocNo: Code[35])
    var
        VendorLedgerEntry: Record "Vendor Ledger Entry";
        GLEntry: Record "G/L Entry";
        LegalLedgerEntry: Record "Legal Ledger Entry";
    begin
        VendorLedgerEntry.Reset();
        VendorLedgerEntry.SetRange("Document Type", VendorLedgerEntry."Document Type"::Invoice);
        VendorLedgerEntry.SetRange("Document No.", DocumentNo);
        if VendorLedgerEntry.FindSet() then
            repeat
                VendorLedgerEntry.Validate("External Document No.", NewExternalDocNo);
                VendorLedgerEntry.Modify();
            until VendorLedgerEntry.Next() = 0;

        GLEntry.Reset();
        GLEntry.SetRange("Document Type", GLEntry."Document Type"::Invoice);
        GLEntry.SetRange("Source Code", 'COMPRAS');
        GLEntry.SetRange("Document No.", DocumentNo);
        if GLEntry.FindSet() then
            repeat
                GLEntry.Validate("External Document No.", NewExternalDocNo);
                GLEntry.Modify();
            until GLEntry.Next() = 0;

        LegalLedgerEntry.Reset();
        LegalLedgerEntry.SetRange("Sub Type", 'CCF-C');
        LegalLedgerEntry.SetRange("No.", DocumentNo);
        if LegalLedgerEntry.FindSet() then
            repeat
                LegalLedgerEntry.Validate("External Document No.", NewExternalDocNo);
                LegalLedgerEntry.Modify();
            until LegalLedgerEntry.Next() = 0;
    end;

    local procedure UpdatePurchCrMemoRelatedExternalDocNo(DocumentNo: Code[20]; NewExternalDocNo: Code[35])
    var
        VendorLedgerEntry: Record "Vendor Ledger Entry";
        GLEntry: Record "G/L Entry";
        LegalLedgerEntry: Record "Legal Ledger Entry";
    begin
        VendorLedgerEntry.Reset();
        VendorLedgerEntry.SetRange("Document Type", VendorLedgerEntry."Document Type"::"Credit Memo");
        VendorLedgerEntry.SetRange("Document No.", DocumentNo);
        if VendorLedgerEntry.FindSet() then
            repeat
                VendorLedgerEntry.Validate("External Document No.", NewExternalDocNo);
                VendorLedgerEntry.Modify();
            until VendorLedgerEntry.Next() = 0;

        GLEntry.Reset();
        GLEntry.SetRange("Document Type", GLEntry."Document Type"::"Credit Memo");
        GLEntry.SetRange("Source Code", 'COMPRAS');
        GLEntry.SetRange("Document No.", DocumentNo);
        if GLEntry.FindSet() then
            repeat
                GLEntry.Validate("External Document No.", NewExternalDocNo);
                GLEntry.Modify();
            until GLEntry.Next() = 0;

        LegalLedgerEntry.Reset();
        LegalLedgerEntry.SetRange("Sub Type", 'NC-C');
        LegalLedgerEntry.SetRange("No.", DocumentNo);
        if LegalLedgerEntry.FindSet() then
            repeat
                LegalLedgerEntry.Validate("External Document No.", NewExternalDocNo);
                LegalLedgerEntry.Modify();
            until LegalLedgerEntry.Next() = 0;
    end;

    local procedure ShowDTEChangeSummary(DocumentType: Text; DocumentNo: Code[20]; OldDTEInvoice: Text; NewDTEInvoice: Text; OldDTEAuthNumber: Text; NewDTEAuthNumber: Text; OldSignatureValidation: Text; NewSignatureValidation: Text; OldAbbreviatedDTE: Text; NewAbbreviatedDTE: Text)
    var
        DocumentDescription: Text;
    begin
        DocumentDescription := StrSubstNo('%1 %2', DocumentType, DocumentNo);

        Message(
            '%1 se modifico correctamente.\DTE Invoice: %2 -> %3\Codigo Generacion: %4 -> %5\Sello Validacion: %6 -> %7\DTE abreviado: %8 -> %9',
            DocumentDescription,
            OldDTEInvoice,
            NewDTEInvoice,
            OldDTEAuthNumber,
            NewDTEAuthNumber,
            OldSignatureValidation,
            NewSignatureValidation,
            OldAbbreviatedDTE,
            NewAbbreviatedDTE);
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

    local procedure ValidateFieldByName(var RecordVariant: Variant; FieldName: Text; NewValue: Text): Boolean
    var
        RecordRef: RecordRef;
        FieldRef: FieldRef;
        FieldIndex: Integer;
    begin
        RecordRef.GetTable(RecordVariant);

        for FieldIndex := 1 to RecordRef.FieldCount do begin
            FieldRef := RecordRef.FieldIndex(FieldIndex);
            if FieldRef.Name = FieldName then begin
                FieldRef.Validate(NewValue);
                RecordRef.SetTable(RecordVariant);
                exit(true);
            end;
        end;

        exit(false);
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
