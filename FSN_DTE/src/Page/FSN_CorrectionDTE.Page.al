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

                    case "Post Parameter" of
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
            DTEInvoce := true;
            if SalesInvHeader."No." <> Rec."Menu ID" then
                Message('El DTE Invoice %1 ya existe en la Factura de Venta No. %2', Rec."Set Current-Input", SalesInvHeader."No.");
        end;

        SalesInvHeader.Reset();
        SalesInvHeader.SetRange("DTE AuthNumber", Rec."Current-Description");
        if SalesInvHeader.FindFirst() then begin
            DTEAuthNum := true;
            if SalesInvHeader."No." <> Rec."Menu ID" then
                Message('El DTE AuthNumber %1 ya existe en la Factura de Venta No. %2', Rec."Current-Description", SalesInvHeader."No.");
        end;

        SalesInvHeader.Reset();
        SalesInvHeader.SetRange("Signature Validation", Rec."Current-Description2");
        if SalesInvHeader.FindFirst() then begin
            SigVal := true;
            if SalesInvHeader."No." <> Rec."Menu ID" then
                Message('El Signature Validation %1 ya existe en la Factura de Venta No. %2', Rec."Current-Description2", SalesInvHeader."No.");
        end;

        exit(DTEInvoce or DTEAuthNum or SigVal);
    end;

    procedure ModifyPurchaseInvoiceHeader()
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchRecHeader: Record "Purch. Rcpt. Header";
    begin
        if PurchInvHeader.Get(Rec."Menu ID") then begin
            if ValPurchaseInvoice() then
                exit;

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
            PurchInvHeader."Vendor Invoice No." := Rec."Set Current-Input";
            PurchInvHeader.Modify();
            // Update related Receipt Header if exists

            Message('DTE de Factura de Compra actualizado correctamente.');
        end else
            Error('No se encontró la Factura de Compra con No. %1', Rec."Menu ID");
    end;

    local procedure ValPurchaseInvoice(): Boolean
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        DTEInvoce: Boolean;
        DTEAuthNum: Boolean;
        SigVal: Boolean;
    begin
        PurchInvHeader.Reset();
        PurchInvHeader.SetRange("DTE Invoice", Rec."Set Current-Input");
        if PurchInvHeader.FindFirst() then begin
            DTEInvoce := true;
            if PurchInvHeader."No." <> Rec."Menu ID" then
                Message('El DTE Invoice %1 ya existe en la Factura de Compra No. %2', Rec."Set Current-Input", PurchInvHeader."No.");
        end;
        PurchInvHeader.Reset();
        PurchInvHeader.SetRange("DTE AuthNumber", Rec."Current-Description");
        if PurchInvHeader.FindFirst() then begin
            DTEAuthNum := true;
            if PurchInvHeader."No." <> Rec."Menu ID" then
                Message('El DTE AuthNumber %1 ya existe en la Factura de Compra No. %2', Rec."Current-Description", PurchInvHeader."No.");
        end;
        PurchInvHeader.Reset();
        PurchInvHeader.SetRange("Signature Validation", Rec."Current-Description2");
        if PurchInvHeader.FindFirst() then begin
            SigVal := true;
            if PurchInvHeader."No." <> Rec."Menu ID" then
                Message('El Signature Validation %1 ya existe en la Factura de Compra No. %2', Rec."Current-Description2", PurchInvHeader."No.");
        end;
        exit(DTEInvoce or DTEAuthNum or SigVal);
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
            DTEInvoce := true;
            if SalesCrMemoHeader."No." <> Rec."Menu ID" then
                Message('El DTE Invoice %1 ya existe en la Nota de Crédito de Venta No. %2', Rec."Set Current-Input", SalesCrMemoHeader."No.");
        end;
        SalesCrMemoHeader.Reset();
        SalesCrMemoHeader.SetRange("DTE AuthNumber", Rec."Current-Description");
        if SalesCrMemoHeader.FindFirst() then begin
            DTEAuthNum := true;
            if SalesCrMemoHeader."No." <> Rec."Menu ID" then
                Message('El DTE AuthNumber %1 ya existe en la Nota de Crédito de Venta No. %2', Rec."Current-Description", SalesCrMemoHeader."No.");
        end;
        SalesCrMemoHeader.Reset();
        SalesCrMemoHeader.SetRange("Signature Validation", Rec."Current-Description2");
        if SalesCrMemoHeader.FindFirst() then begin
            SigVal := true;
            if SalesCrMemoHeader."No." <> Rec."Menu ID" then
                Message('El Signature Validation %1 ya existe en la Nota de Crédito de Venta No. %2', Rec."Current-Description2", SalesCrMemoHeader."No.");
        end;
        exit(DTEInvoce or DTEAuthNum or SigVal);
    end;

    // Update Purchase Credit Memo DTE fields
    local procedure ModifyPurchCrMemoHdr()
    var
        PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
    begin
        if PurchCrMemoHdr.Get(Rec."Menu ID") then begin
            if ValPurchaseMemo() then
                exit;
            PurchCrMemoHdr.Validate("DTE Invoice", Rec."Set Current-Input");
            PurchCrMemoHdr.Validate("DTE AuthNumber", Rec."Current-Description");
            PurchCrMemoHdr.Validate("Signature Validation", Rec."Current-Description2");
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
    begin
        PurchCrMemoHdr.Reset();
        PurchCrMemoHdr.SetRange("DTE Invoice", Rec."Set Current-Input");
        if PurchCrMemoHdr.FindFirst() then begin
            DTEInvoce := true;
            if PurchCrMemoHdr."No." <> Rec."Menu ID" then
                Message('El DTE Invoice %1 ya existe en la Nota de Crédito de Compra No. %2', Rec."Set Current-Input", PurchCrMemoHdr."No.");
        end;
        PurchCrMemoHdr.Reset();
        PurchCrMemoHdr.SetRange("DTE AuthNumber", Rec."Current-Description");
        if PurchCrMemoHdr.FindFirst() then begin
            DTEAuthNum := true;
            if PurchCrMemoHdr."No." <> Rec."Menu ID" then
                Message('El DTE AuthNumber %1 ya existe en la Nota de Crédito de Compra No. %2', Rec."Current-Description", PurchCrMemoHdr."No.");
        end;
        PurchCrMemoHdr.Reset();
        PurchCrMemoHdr.SetRange("Signature Validation", Rec."Current-Description2");
        if PurchCrMemoHdr.FindFirst() then begin
            SigVal := true;
            if PurchCrMemoHdr."No." <> Rec."Menu ID" then
                Message('El Signature Validation %1 ya existe en la Nota de Crédito de Compra No. %2', Rec."Current-Description2", PurchCrMemoHdr."No.");
        end;
        exit(DTEInvoce or DTEAuthNum or SigVal);
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