pageextension 50007 "FSN PostedPurchRcptListExt" extends "Posted Purchase Receipts"
{
    layout
    {
        addafter("Location Code")
        {

            field("FSN last message"; "FSN last message")
            {
                ApplicationArea = all;
                StyleExpr = StyleExprTxt2;

            }
            field("FSN Vendor Invoice No."; "FSN Vendor Invoice No.")
            {
                ApplicationArea = all;
            }
            field("Store No."; "LSC Store No.")
            {
                ApplicationArea = all;
            }
            field("Invoiced"; Invoiced)
            {
                Caption = 'Facturado';
                ApplicationArea = All;
                StyleExpr = StyleExprTxt;
            }
            /* field("Order No."; "Order No.")
            {
                TableRelation = "Purch. Inv. Header" WHERE("Order No." = FIELD("Order No."),
                "Vendor Invoice No." = FIELD("FSN Vendor Invoice No."));
            } */

        }

        addlast(Content)
        {

            group("Detail Invoicing")
            {
                Visible = DetailInvocing;
                Caption = 'Detail Invoicing';
                field("PH Document Date"; PurchaseHeader."Document Date")
                {
                    ApplicationArea = Basic;
                    Caption = 'Document Date';
                }
                field("PH Posting Date"; PurchaseHeader."Posting Date")
                {
                    ApplicationArea = Basic;
                    Caption = 'Posting Date';

                }
                field("Due Date"; PurchaseHeader."Due Date")
                {
                    ApplicationArea = Basic;
                    Caption = 'Due Date';

                }
                field("PH Vendor Invoice Serie"; PurchaseHeader."Vendor Invoice Serie")
                {
                    ApplicationArea = Basic;
                    Caption = 'Vendor Invoice Serie';
                }
                field("PH Vendor Invoice Number"; PurchaseHeader."Vendor Invoice Number")
                {
                    ApplicationArea = Basic;
                    Caption = 'Vendor Invoice Number';
                }
                field("PH Vendor Invoice No."; PurchaseHeader."Vendor Invoice No.")
                {
                    ApplicationArea = Basic;
                    Caption = 'Vendor Invoice No.';
                }
                field("PH DTE Invoice"; PurchaseHeader."DTE Invoice")
                {
                    ApplicationArea = Basic;
                    Caption = 'DTE';
                }
                field("PH DTE AuthNumber"; PurchaseHeader."DTE AuthNumber")
                {
                    ApplicationArea = Basic;
                    Caption = 'DTE AuthNumber';
                }
                field("PH Signature Validation"; PurchaseHeader."Signature Validation")
                {
                    ApplicationArea = Basic;
                    Caption = 'Signature Validation';
                }
                field("Total Amount Excl. VAT Inv"; TotalPurchLineInv.Amount)
                {
                    ApplicationArea = Basic;
                    AutoFormatExpression = Currency.Code;
                    AutoFormatType = 1;
                    CaptionClass = DocumentTotals.GetTotalExclVATCaption(Currency.Code);
                    Caption = 'Total Amount Excl. VAT';
                    DrillDown = false;
                    Editable = false;
                    ToolTip = 'Specifies the sum of the value in the Line Amount Excl. VAT field on all lines in the document minus any discount amount in the Invoice Discount Amount field.';
                }
                field("Total VAT Amount Inv"; VATAmountInv)
                {
                    ApplicationArea = Basic;
                    AutoFormatExpression = Currency.Code;
                    AutoFormatType = 1;
                    CaptionClass = DocumentTotals.GetTotalVATCaption(Currency.Code);
                    Caption = 'Total VAT';
                    Editable = false;
                    ToolTip = 'Specifies the sum of VAT amounts on all lines in the document.';
                }
                field("Total Amount Incl. VAT Inv"; TotalPurchLineInv."Amount Including VAT")
                {
                    ApplicationArea = Basic;
                    AutoFormatExpression = Currency.Code;
                    AutoFormatType = 1;
                    CaptionClass = DocumentTotals.GetTotalInclVATCaption(Currency.Code);
                    Caption = 'Total Amount Incl. VAT';
                    Editable = false;
                    ToolTip = 'Specifies the sum of the value in the Line Amount Incl. VAT field on all lines in the document minus any discount amount in the Invoice Discount Amount field.';
                }
                field("FSN Withholding Tax Amount"; PurchaseHeader."FSN Withholding Tax Amount")
                {
                    ApplicationArea = Basic;
                    AutoFormatExpression = Currency.Code;
                    AutoFormatType = 1;
                    Caption = 'Withholding Tax Amount (USD)';
                    Editable = false;
                }
            }

        }
    }

    actions
    {
        addafter("Co&mments")
        {
            action("Apply Invoice")
            {
                Caption = 'Apply Invoice';
                Promoted = true;
                PromotedCategory = Process;
                Image = PurchaseInvoice;
                ShortCutKey = 'Ctrl+F7';
                ToolTip = 'Si la recepción tiene unidades pendientes de facturar, se cargará la información a la pagina de Factura Compra para su procesamiento. (Ctrl+F7)';
                trigger OnAction()
                var
                    PurchaseLine: Record "Purchase Line";
                    PurchRcptLine: Record "Purch. Rcpt. Line";
                    invoiceList: List of [Text];
                    invoice: Text;
                    util: Codeunit "FSN External Purch. Manager";
                    PO: Page "Purchase Order";
                    guion: Integer;
                    Ret: Record "Purch. Withh. Contribution";
                    WithhSocSecTax: Codeunit "Withholding - Contribution";
                    POSSESSION: Codeunit "LSC POS Session";
                    PurchPost: Codeunit "Purch.-Post";
                    TempPurchLine: Record "Purchase Line" temporary;
                begin

                    if Rec.Invoiced then begin
                        Message(Text002, Rec."No.");
                        exit;
                    end;

                    Clear(PurchaseHeader);
                    invFSNUtilityDTE(Rec."No.");
                    if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, Rec."Order No.") then begin
                        PurchaseHeader.Status := PurchaseHeader.Status::Open;
                        PurchaseHeader."Posting Date" := Rec."Posting Date";
                        PurchaseHeader.Modify(true);
                        PurchaseLine.Reset();
                        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
                        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
                        if PurchaseLine.FindFirst() then begin
                            repeat begin
                                PurchaseLine.Validate(PurchaseLine."Qty. to Invoice", 0);
                                PurchaseLine.Modify();
                            end until PurchaseLine.Next() = 0;
                        end;

                        if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, Rec."Order No.") then;
                        PurchRcptLine.Reset();
                        PurchRcptLine.SetRange("Document No.", Rec."No.");
                        PurchRcptLine.SetFilter(Quantity, '<>%1', 0);
                        if PurchRcptLine.find('-') then
                            repeat
                                if PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", PurchRcptLine."Line No.") then begin
                                    PurchaseLine.Validate("Qty. to Invoice", PurchRcptLine.Quantity);
                                    //PurchaseLine.Validate("Direct Unit Cost", PurchRcptLine."Direct Unit Cost");
                                    PurchaseLine.Modify(true);
                                end;
                            until PurchRcptLine.next = 0;
                        PurchaseHeader.Reset();
                        PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Order);
                        PurchaseHeader.SetRange("No.", Rec."Order No.");
                        if PurchaseHeader.FindFirst() then begin
                            invoice := rec."FSN Vendor Invoice No.";
                            if invoice.Contains('-') then begin
                                invoiceList := invoice.Split('-');
                                if invoice.Contains('DTE') then begin
                                    if "DTE Invoice" <> '' then begin
                                        invoice := "DTE Invoice";
                                        invoiceList := invoice.Split('-');
                                        PurchaseHeader.Validate("Vendor Invoice Number", DelChr((invoiceList.Get(invoiceList.Count)), '<', '0'));
                                        PurchaseHeader.Validate("Vendor Invoice Serie", invoiceList.Get(1) + DelChr(invoiceList.Get(2), '=', '0'));
                                        PurchaseHeader."DTE Invoice" := "DTE Invoice";
                                        PurchaseHeader."DTE AuthNumber" := "DTE AuthNumber";
                                        PurchaseHeader."Signature Validation" := "Signature Validation";
                                        //US606-JH Ingresar la fecha de emisión del DTE
                                        if "DTE AuthNumber" <> '' then begin
                                            FSNRecepPurchDTE.Reset();
                                            FSNRecepPurchDTE.SetFilter("DTE AuthNumber", '%1', "DTE AuthNumber");
                                            if FSNRecepPurchDTE.FindFirst() then
                                                PurchaseHeader."Document Date" := DT2Date(FSNRecepPurchDTE."Issue Date");
                                        end;
                                    end else begin
                                        PurchaseHeader.Validate("Vendor Invoice Serie", invoiceList.Get(1));
                                        PurchaseHeader.Validate("Vendor Invoice Number", DelChr((invoiceList.Get(invoiceList.Count)), '<', '0'));
                                    end;
                                end else begin
                                    PurchaseHeader.Validate("Vendor Invoice Number", DelChr((invoiceList.Get(invoiceList.Count)), '<', '0'));
                                    PurchaseHeader.Validate("Vendor Invoice Serie", invoiceList.Get(1));
                                end;
                                PurchaseHeader."Vendor Invoice No." := PurchaseHeader."Vendor Invoice Serie" + '-' + PurchaseHeader."Vendor Invoice Number";
                                PurchaseHeader."Unique Document No." := PurchaseHeader."Vendor Invoice No.";
                            end else
                                PurchaseHeader."Vendor Invoice No." := Rec."FSN Vendor Invoice No.";

                            PurchaseHeader."Sub Type" := PurchaseHeader."Sub Type";
                            PurchaseHeader."Last Receiving No." := Rec."No.";
                            PurchaseHeader."FSN VAT Difference" := Rec."FSN VAT Difference";
                            PurchaseHeader."Job Queue Entry ID" := '00000000-0000-0000-0000-000000000000';
                            PurchaseHeader."Job Queue Status" := PurchaseHeader."Job Queue Status"::" ";
                            WithhSocSecTax.CalculateWithholdingTax(PurchaseHeader, FALSE);
                            if Ret.Get(Ret."Document Type"::Order, PurchaseHeader."No.") then
                                PurchaseHeader."FSN Withholding Tax Amount" := Ret."Withholding Tax Amount Others";
                            PurchaseHeader.Status := PurchaseHeader.Status::Released;
                            PurchaseHeader.Modify(true);
                            Clear(TempPurchLine);
                            Clear(PurchPost);
                            PurchPost.GetPurchLines(PurchaseHeader, TempPurchLine, 1);
                            Clear(PurchPost);
                            PurchPost.SumPurchLinesTemp(PurchaseHeader, TempPurchLine, 1, TotalPurchLineInv, TotalPurchLineLCYInv, VATAmountInv, VATAmountTextInv);
                            //PO.SetTableView(PurchaseHeader);
                            //PO.Run();
                            DetailInvocing := true;
                        end;
                    end else
                        Message(Text001, Rec."Order No.");
                    CurrPage.Update(true);
                end;
            }
            action("View Invoice")
            {
                caption = 'View Invoice';
                Promoted = true;
                PromotedCategory = Process;
                Image = PurchaseInvoice;
                ShortCutKey = 'Ctrl+F8';
                ToolTip = 'Si la recepción tiene unidades pendientes de facturar, se cargará la información a la pagina de Factura Compra para su procesamiento. (Ctrl+F8)';
                trigger OnAction()
                var
                    PurchaseLine: Record "Purchase Line";
                    PurchRcptLine: Record "Purch. Rcpt. Line";
                    invoiceList: List of [Text];
                    invoice: Text;
                    util: Codeunit "FSN External Purch. Manager";
                    PO: Page "Purchase Order";
                    guion: Integer;
                    Ret: Record "Purch. Withh. Contribution";
                    WithhSocSecTax: Codeunit "Withholding - Contribution";
                    POSSESSION: Codeunit "LSC POS Session";
                    PurchPost: Codeunit "Purch.-Post";
                    TempPurchLine: Record "Purchase Line" temporary;
                begin

                    if Rec.Invoiced then begin
                        Message(Text002, Rec."No.");
                        exit;
                    end;

                    Clear(PurchaseHeader);
                    invFSNUtilityDTE(Rec."No.");
                    if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, Rec."Order No.") then begin
                        PurchaseHeader.Status := PurchaseHeader.Status::Open;
                        PurchaseHeader."Posting Date" := Rec."Posting Date";
                        PurchaseHeader.Modify(true);
                        PurchaseLine.Reset();
                        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
                        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
                        if PurchaseLine.FindFirst() then begin
                            repeat begin
                                PurchaseLine.Validate(PurchaseLine."Qty. to Invoice", 0);
                                PurchaseLine.Modify();
                            end until PurchaseLine.Next() = 0;
                        end;

                        if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, Rec."Order No.") then;
                        PurchRcptLine.Reset();
                        PurchRcptLine.SetRange("Document No.", Rec."No.");
                        PurchRcptLine.SetFilter(Quantity, '<>%1', 0);
                        if PurchRcptLine.find('-') then
                            repeat
                                if PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", PurchRcptLine."Line No.") then begin
                                    PurchaseLine.Validate("Qty. to Invoice", PurchRcptLine.Quantity);
                                    //PurchaseLine.Validate("Direct Unit Cost", PurchRcptLine."Direct Unit Cost");
                                    PurchaseLine.Modify(true);
                                end;
                            until PurchRcptLine.next = 0;
                        PurchaseHeader.Reset();
                        PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Order);
                        PurchaseHeader.SetRange("No.", Rec."Order No.");
                        if PurchaseHeader.FindFirst() then begin
                            invoice := rec."FSN Vendor Invoice No.";
                            if invoice.Contains('-') then begin
                                invoiceList := invoice.Split('-');
                                if invoice.Contains('DTE') then begin
                                    if "DTE Invoice" <> '' then begin
                                        invoice := "DTE Invoice";
                                        invoiceList := invoice.Split('-');
                                        PurchaseHeader.Validate("Vendor Invoice Number", DelChr((invoiceList.Get(invoiceList.Count)), '<', '0'));
                                        PurchaseHeader.Validate("Vendor Invoice Serie", invoiceList.Get(1) + DelChr(invoiceList.Get(2), '=', '0'));
                                        PurchaseHeader."DTE Invoice" := "DTE Invoice";
                                        PurchaseHeader."DTE AuthNumber" := "DTE AuthNumber";
                                        PurchaseHeader."Signature Validation" := "Signature Validation";
                                        //US606-JH Ingresar la fecha de emisión del DTE
                                        if "DTE AuthNumber" <> '' then begin
                                            FSNRecepPurchDTE.Reset();
                                            FSNRecepPurchDTE.SetFilter("DTE AuthNumber", '%1', "DTE AuthNumber");
                                            if FSNRecepPurchDTE.FindFirst() then
                                                PurchaseHeader."Document Date" := DT2Date(FSNRecepPurchDTE."Issue Date");
                                        end;
                                    end else begin
                                        PurchaseHeader.Validate("Vendor Invoice Serie", invoiceList.Get(1));
                                        PurchaseHeader.Validate("Vendor Invoice Number", DelChr((invoiceList.Get(invoiceList.Count)), '<', '0'));
                                    end;
                                end else begin
                                    PurchaseHeader.Validate("Vendor Invoice Number", DelChr((invoiceList.Get(invoiceList.Count)), '<', '0'));
                                    PurchaseHeader.Validate("Vendor Invoice Serie", invoiceList.Get(1));
                                end;
                                PurchaseHeader."Vendor Invoice No." := PurchaseHeader."Vendor Invoice Serie" + '-' + PurchaseHeader."Vendor Invoice Number";
                                PurchaseHeader."Unique Document No." := PurchaseHeader."Vendor Invoice No.";
                            end else
                                PurchaseHeader."Vendor Invoice No." := Rec."FSN Vendor Invoice No.";

                            PurchaseHeader."Sub Type" := PurchaseHeader."Sub Type";
                            PurchaseHeader."Last Receiving No." := Rec."No.";
                            PurchaseHeader."FSN VAT Difference" := Rec."FSN VAT Difference";
                            PurchaseHeader."Job Queue Entry ID" := '00000000-0000-0000-0000-000000000000';
                            PurchaseHeader."Job Queue Status" := PurchaseHeader."Job Queue Status"::" ";
                            WithhSocSecTax.CalculateWithholdingTax(PurchaseHeader, FALSE);
                            if Ret.Get(Ret."Document Type"::Order, PurchaseHeader."No.") then
                                PurchaseHeader."FSN Withholding Tax Amount" := Ret."Withholding Tax Amount Others";
                            PurchaseHeader.Status := PurchaseHeader.Status::Released;
                            PurchaseHeader.Modify(true);
                            Clear(TempPurchLine);
                            Clear(PurchPost);
                            PurchPost.GetPurchLines(PurchaseHeader, TempPurchLine, 1);
                            Clear(PurchPost);
                            PurchPost.SumPurchLinesTemp(PurchaseHeader, TempPurchLine, 1, TotalPurchLineInv, TotalPurchLineLCYInv, VATAmountInv, VATAmountTextInv);
                            PO.SetTableView(PurchaseHeader);
                            PO.Run();
                            DetailInvocing := true;
                        end;
                    end else
                        Message(Text001, Rec."Order No.");
                    CurrPage.Update(true);
                end;
            }
            action(PostAndInvoiceJobQueueEntry)
            {

                Caption = 'P&ost and Invoice with Job Queue';
                Image = JobTimeSheet;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ShortCutKey = 'Ctrl+F9';
                ToolTip = 'Post and invoice the purchase order with the job queue.(Ctrl+F9)';
                trigger OnAction()
                var
                    purchPost: Codeunit "Purch.-Post";
                    PurchSetup: Record "Purchases & Payables Setup";
                    PurchPostViaJobQueue: Codeunit "Purchase Post via Job Queue";
                    JobQueueEntry: Record "Job Queue Entry";
                begin
                    if Rec.Invoiced then begin
                        Message(Text002, Rec."No.");
                        exit;
                    end;
                    JobQueueEntry.Reset();
                    JobQueueEntry.SetRange("FSN Order No", Rec."Order No.");
                    JobQueueEntry.SetRange("FSN HRC No", Rec."No.");
                    JobQueueEntry.SetRange("Job Queue Category Code", 'CONT_COMP');
                    if JobQueueEntry.FindFirst() then
                        Error(Text004, Rec."No.");

                    Clear(PurchaseHeader);
                    if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, Rec."Order No.") then begin
                        PurchSetup.Get();
                        PurchaseHeader.Receive := false;
                        PurchaseHeader.Invoice := true;
                        if PurchSetup."Post with Job Queue" then
                            PurchPostViaJobQueue.EnqueuePurchDoc(PurchaseHeader);
                    end;
                end;
            }
        }
    }
    trigger OnOpenPage()
    begin
        Rec.SetRange("Posting Date", Today);
        DetailInvocing := false;
    end;

    trigger OnAfterGetRecord()
    var
        purchRcptLine: Record "Purch. Rcpt. Line";
    begin
        if Rec."FSN last message" <> '' then
            StyleExprTxt2 := 'Unfavorable'
        else
            StyleExprTxt2 := '';

    end;

    var
        StyleExprTxt: Text;
        StyleExprTxt2: Text;
        FSNUtility: Codeunit "FSN Utility";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        MsgResult: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;

        Processed: Boolean;
        "DTE AuthNumber", "DTE Invoice", "Signature Validation" : Code[100];
        PurchaseHeader: Record "Purchase Header";
        TotalPurchLineInv: Record "Purchase Line";
        TotalPurchLineLCYInv: Record "Purchase Line";
        VATAmountTextInv: Text[30];
        VATAmountInv: Decimal;
        Currency: Record Currency;
        DocumentTotals: Codeunit "Document Totals";

        DetailInvocing: Boolean;
        Text001: Label 'No se encontró la orden de compra No. %1 asociada a la recepción.';
        Text002: Label 'La recepción No. %1 ya ha sido facturada.';
        Text003: Label 'La recepción No. %1 fue enviada a cola proyecto, F5 para actualizar estado';
        Text004: Label 'La recepción No. %1 ya esta programada en cola proyecto, revisar estado antes de programar la siguiente';
        FSNRecepPurchDTE: Record "FSN Recep. Purch. DTE";

    local procedure invFSNUtilityDTE("iNo": Code[20])
    var
        myInt: Integer;
    begin
        RequestID := 'DTE-LIBROIVA';
        XMLRequest := iNo;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        "DTE AuthNumber" := PosMenuLineTemp."Current-Description";
        "DTE Invoice" := PosMenuLineTemp."Set Current-Input";
        "Signature Validation" := PosMenuLineTemp."Current-Description2";

    end;
}
