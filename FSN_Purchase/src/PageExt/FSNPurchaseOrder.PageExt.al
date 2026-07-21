pageextension 50119 "FSN Purchase Order" extends "Purchase Order"
{
    layout
    {
        addafter(Status)
        {
            field("DTE AuthNumber"; Rec."DTE AuthNumber")
            {
                ApplicationArea = All;
            }
            field("DTE Invoice"; Rec."DTE Invoice")
            {
                ApplicationArea = All;
                trigger OnLookup(var Text: Text): Boolean
                var
                    ExtPurch: Codeunit "FSN External Purch. Manager";
                begin
                    if ExtPurch.OnLookupDte(Rec) then begin
                        Rec.Modify(true);
                        CurrPage.Update(true);
                    end;
                end;

                trigger OnValidate()
                var
                    ExtPurch: Codeunit "FSN External Purch. Manager";
                begin
                    if ExtPurch.OnValidateDte(Rec) then begin
                        Rec.Modify(true);
                        CurrPage.Update(true);
                    end;
                end;

            }
            field("Signature Validation";
            Rec."Signature Validation")
            {
                ApplicationArea = All;
            }
            field("Associated Credit Memo";
            Rec."Associated Credit Memo")
            {
                ApplicationArea = All;
            }

        }
        addbefore("Invoice Details")
        {
            /*group(Invoicing)
            {
                Caption = 'Detail Invoicing';
                field(Total_Invoicing;
                TotalAmount1[2])
                {
                    ApplicationArea = Basic, Suite;
                    AutoFormatExpression = "Currency Code";
                    AutoFormatType = 1;
                    CaptionClass = GetCaptionClass(Text001, false);
                    Caption = 'Total';
                    ToolTip = 'Specifies the total amount less any invoice discount amount and excluding VAT for the purchase order.';
                    Editable = false;

                }
                field(VATAmount_Invoicing;
                VATAmount[2])
                {
                    ApplicationArea = Basic, Suite;
                    AutoFormatExpression = "Currency Code";
                    AutoFormatType = 1;
                    CaptionClass = Format(VATAmountText[2]);
                    Caption = 'VAT Amount';
                    Editable = true;
                    ToolTip = 'Specifies the total VAT amount that has been calculated for all the lines in the purchase order.';
                    //V59 Considerar variacion del iva segun configuracion contabilidad
                    trigger OnValidate()
                    var
                        PurchLine: Record "Purchase Line";
                        ReleasePurchaseDocument:
                            Codeunit "Release Purchase Document";
                        GenSet:
                            Record "General Ledger Setup";
                    begin
                        GenSet.Get();
                        if GenSet."Max. VAT Difference Allowed" < abs(VATAmount[2] - TempVATAmountLine2."Calculated VAT Amount") then
                            Error(Text005, GenSet."Max. VAT Difference Allowed");
                        TempVATAmountLine2."VAT Amount" := VATAmount[2];
                        TempVATAmountLine2."Amount Including VAT" := TempVATAmountLine2."VAT Amount" + TempVATAmountLine2."VAT Base";
                        TempVATAmountLine2."VAT Difference" := VATAmount[2] - TempVATAmountLine2."Calculated VAT Amount";
                        TempVATAmountLine2.Modified := true;
                        TempVATAmountLine2.Modify(true);

                        ActiveTab := ActiveTab::Invoicing;
                        VATLinesDrillDown(TempVATAmountLine2, true);
                        UpdateHeaderInfo(2, TempVATAmountLine2);

                        if TempVATAmountLine2.GetAnyLineModified then begin
                            UpdateVATOnPurchLines;
                            RefreshOnAfterGetRecord;
                        end;

                        //PurchLine.UpdateVATOnLines(1, Rec, PurchLine, TempVATAmountLine2);
                        //PurchLine.UpdateVATOnLines(0, Rec, PurchLine, TempVATAmountLine2);
                        ReleasePurchaseDocument.CalcAndUpdateVATOnLines(Rec, PurchLine);
                        CurrPage.PurchLines.Page.Update(true);
                        CurrPage.Update(true);

                    end;
                    //V59******************************
                }
                field(TotalInclVAT_Invoicing; TotalAmount2[2])
                {
                    ApplicationArea = Basic, Suite;
                    AutoFormatExpression = "Currency Code";
                    AutoFormatType = 1;
                    CaptionClass = GetCaptionClass(Text001, true);
                    Caption = 'Total Incl. VAT';
                    Editable = false;
                    ToolTip = 'Specifies the amount, including VAT. On the Invoicing FastTab, this is the amount that is posted to the vendor''s account for all the lines in the purchase order if you post the purchase order as invoiced.';
                }

                field(Quantity_Invoicing; TotalPurchLine[2].Quantity)
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Quantity';
                    DecimalPlaces = 0 : 5;
                    Editable = false;
                    ToolTip = 'Specifies the total quantity of G/L account entries, fixed assets, and/or items in the purchase order.';
                }
                

            }*/
            group(Withholding)
            {
                Caption = 'Detail Withhold';
                field("FSN Withholding Tax Amount"; Rec."FSN Withholding Tax Amount")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                /*
                field("Withhold DTE Invoice"; Rec."Withhold DTE Invoice")
                {
                    ApplicationArea = All;
                }
                field("Withhold DTE AuthNumber"; Rec."Withhold DTE AuthNumber")
                {
                    ApplicationArea = All;
                }
                field("Withhold Sign. Validation"; Rec."Withhold Sign. Validation")
                {
                    ApplicationArea = All;
                }*/
            }

        }
        //Ocultando FactBox para tener mejor rendimiento
        modify("Attached Documents")
        {
            Visible = false;
        }
        modify(Control23)
        {
            Visible = false;
        }
        modify(Control1903326807)
        {
            Visible = false;
        }
        modify(ApprovalFactBox)
        {
            Visible = false;
        }
        modify(Control1901138007)
        {
            Visible = false;
        }
        modify(Control1904651607)
        {
            Visible = false;
        }
        modify(IncomingDocAttachFactBox)
        {
            Visible = false;
        }
        modify(Control1903435607)
        {
            Visible = false;
        }
        modify(Control1906949207)
        {
            Visible = false;
        }
        modify(Control3)
        {
            Visible = false;
        }
        modify(WorkflowStatus)
        {
            Visible = false;
        }
        modify(Control1900383207)
        {
            Visible = false;
        }
        modify(Control1905767507)
        {
            Visible = false;
        }
    }
    actions
    {
        addafter("P&osting")
        {
            action(PostAndInvoiceJobQueueEntry)
            {
                ApplicationArea = Suite;
                Caption = 'P&ost and Invoice with Job Queue';
                Ellipsis = true;
                Image = JobTimeSheet;
                Promoted = true;
                PromotedCategory = Category6;
                PromotedIsBig = true;
                ShortCutKey = 'F9';
                ToolTip = 'Post and invoice the purchase order with the job queue.';
                trigger OnAction()
                var
                    purchPost: Codeunit "Purch.-Post";
                    PurchSetup: Record "Purchases & Payables Setup";
                    PurchPostViaJobQueue: Codeunit "Purchase Post via Job Queue";
                    JobQueueEntry: Record "Job Queue Entry";
                    Text001: Label 'La recepción No. %1 ya esta programada en cola proyecto, revisar estado antes de programar la siguiente';
                begin
                    JobQueueEntry.Reset();
                    JobQueueEntry.SetRange("FSN Order No", Rec."No.");
                    JobQueueEntry.SetRange("FSN HRC No", Rec."Last Receiving No.");
                    JobQueueEntry.SetRange("Job Queue Category Code", 'CONT_COMP');
                    if JobQueueEntry.FindFirst() then
                        Error(Text001, Rec."No.");
                    PurchSetup.Get();
                    Rec.Receive := false;
                    Rec.Invoice := true;
                    if PurchSetup."Post with Job Queue" then
                        PurchPostViaJobQueue.EnqueuePurchDoc(Rec);
                end;
            }

        }
    }
    VAR
    /*  Text000: Label 'Purchase %1 Invoicing';
     Text001: Label 'Total';
     Text002: Label 'Amount';
     Text003: Label '%1 must not be 0.';
     Text004: Label '%1 must not be greater than %2.';
     Text005: Label 'Diferencia IVA no debe exceder Máx. diferencia IVA permitida = %1';
     TotalPurchLine: array[3] of Record "Purchase Line";
     TotalPurchLineLCY: array[3] of Record "Purchase Line";
     Vend: Record Vendor;
     TempVATAmountLine1: Record "VAT Amount Line" temporary;
     TempVATAmountLine2: Record "VAT Amount Line" temporary;
     TempVATAmountLine3: Record "VAT Amount Line" temporary;
     TempVATAmountLine4: Record "VAT Amount Line" temporary;
     PurchSetup: Record "Purchases & Payables Setup";
     PurchPost: Codeunit "Purch.-Post";
     VATLinesForm: Page "VAT Amount Lines";
     TotalAmount1: array[3] of Decimal;
     TotalAmount2: array[3] of Decimal;
     VATAmount: array[3] of Decimal;
     PrepmtTotalAmount: Decimal;
     PrepmtVATAmount: Decimal;
     PrepmtTotalAmount2: Decimal;
     VATAmountText: array[3] of Text[30];
     PrepmtVATAmountText: Text[30];
     PrepmtInvPct: Decimal;
     PrepmtDeductedPct: Decimal;
     i: Integer;
     PrevNo: Code[20];
     ActiveTab: Option General,Invoicing,Shipping,Prepayment;
     PrevTab: Option General,Invoicing,Shipping,Prepayment;
     VATLinesFormIsEditable: Boolean;
     AllowInvDisc: Boolean;
     AllowVATDifference: Boolean;

     UpdateInvDiscountQst: Label 'One or more lines have been invoiced. The discount distributed to invoiced lines will not be taken into account.\\Do you want to update the invoice discount?';
     CurrencyCode: Code[10]; */


    trigger OnAfterGetRecord()
    begin
        /* RefreshOnAfterGetRecord; */
    end;

    trigger OnModifyRecord(): Boolean
    begin

    end;

    trigger OnOpenPage()
    begin
        /* PurchSetup.Get();
         AllowInvDisc :=
           not (PurchSetup."Calc. Inv. Discount" and VendInvDiscRecExists("Invoice Disc. Code"));
         AllowVATDifference :=
           PurchSetup."Allow VAT Difference" and
           not ("Document Type" in ["Document Type"::Quote, "Document Type"::"Blanket Order"]);
         OnOpenPageOnBeforeSetEditable(AllowInvDisc, AllowVATDifference, Rec);
         VATLinesFormIsEditable := AllowVATDifference or AllowInvDisc;
         CurrPage.Editable := VATLinesFormIsEditable; */

    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        PurchLine: Record "Purchase Line";
        ReleasePurchaseDocument: Codeunit "Release Purchase Document";
    begin
        /*  GetVATSpecification(PrevTab);
         ReleasePurchaseDocument.CalcAndUpdateVATOnLines(Rec, PurchLine);
         exit(true); */
    end;

    /* local procedure RefreshOnAfterGetRecord()
    var
        PurchLine: Record "Purchase Line";
        TempPurchLine: Record "Purchase Line" temporary;
        PurchPostPrepayments: Codeunit "Purchase-Post Prepayments";
        OptionValueOutOfRange: Integer;
        IsHandled: Boolean;
    begin
        CurrPage.Caption(StrSubstNo(Text000, "Document Type"));

        if PrevNo = "No." then
            exit;
        PrevNo := "No.";
        FilterGroup(2);
        SetRange("No.", PrevNo);
        FilterGroup(0);

        Clear(PurchLine);
        Clear(TotalPurchLine);
        Clear(TotalPurchLineLCY);

        for i := 1 to 3 do begin
            TempPurchLine.DeleteAll();
            Clear(TempPurchLine);
            Clear(PurchPost);
            PurchPost.GetPurchLines(Rec, TempPurchLine, i - 1);
            Clear(PurchPost);
            case i of
                1:
                    PurchLine.CalcVATAmountLines(0, Rec, TempPurchLine, TempVATAmountLine1);
                2:
                    PurchLine.CalcVATAmountLines(0, Rec, TempPurchLine, TempVATAmountLine2);
                3:
                    PurchLine.CalcVATAmountLines(0, Rec, TempPurchLine, TempVATAmountLine3);
            end;

            PurchPost.SumPurchLinesTemp(
              Rec, TempPurchLine, i - 1, TotalPurchLine[i], TotalPurchLineLCY[i],
              VATAmount[i], VATAmountText[i]);

            IsHandled := false;
            OnRefreshOnAfterGetRecordAfterSumPurchLinesTemp(TempPurchLine, IsHandled);
            If not IsHandled then
                if "Prices Including VAT" then begin
                    TotalAmount2[i] := TotalPurchLine[i].Amount;
                    TotalAmount1[i] := TotalAmount2[i] + VATAmount[i];
                    TotalPurchLine[i]."Line Amount" := TotalAmount1[i] + TotalPurchLine[i]."Inv. Discount Amount";
                end else begin
                    TotalAmount1[i] := TotalPurchLine[i].Amount;
                    TotalAmount2[i] := TotalPurchLine[i]."Amount Including VAT";
                end;
        end;

        TempPurchLine.DeleteAll();
        Clear(TempPurchLine);
        PurchPostPrepayments.GetPurchLines(Rec, 0, TempPurchLine);
        PurchPostPrepayments.SumPrepmt(
          Rec, TempPurchLine, TempVATAmountLine4, PrepmtTotalAmount, PrepmtVATAmount, PrepmtVATAmountText);
        PrepmtInvPct :=
          Pct(TotalPurchLine[1]."Prepmt. Amt. Inv.", PrepmtTotalAmount);
        PrepmtDeductedPct :=
          Pct(TotalPurchLine[1]."Prepmt Amt Deducted", TotalPurchLine[1]."Prepmt. Amt. Inv.");
        if "Prices Including VAT" then begin
            PrepmtTotalAmount2 := PrepmtTotalAmount;
            PrepmtTotalAmount := PrepmtTotalAmount + PrepmtVATAmount;
        end else
            PrepmtTotalAmount2 := PrepmtTotalAmount + PrepmtVATAmount;

        if Vend.Get("Pay-to Vendor No.") then
            Vend.CalcFields("Balance (LCY)")
        else
            Clear(Vend);

        TempVATAmountLine1.ModifyAll(Modified, false);
        TempVATAmountLine2.ModifyAll(Modified, false);
        TempVATAmountLine3.ModifyAll(Modified, false);
        TempVATAmountLine4.ModifyAll(Modified, false);

        OptionValueOutOfRange := -1;
        PrevTab := OptionValueOutOfRange;
        UpdateHeaderInfo(2, TempVATAmountLine2);
    end;

    local procedure UpdateHeaderInfo(IndexNo: Integer; var VATAmountLine: Record "VAT Amount Line")
    var
        CurrExchRate: Record "Currency Exchange Rate";
        UseDate: Date;
    begin
        TotalPurchLine[IndexNo]."Inv. Discount Amount" := VATAmountLine.GetTotalInvDiscAmount;
        TotalAmount1[IndexNo] :=
          TotalPurchLine[IndexNo]."Line Amount" - TotalPurchLine[IndexNo]."Inv. Discount Amount";
        VATAmount[IndexNo] := VATAmountLine.GetTotalVATAmount;
        if "Prices Including VAT" then begin
            TotalAmount1[IndexNo] := VATAmountLine.GetTotalAmountInclVAT;
            TotalAmount2[IndexNo] := TotalAmount1[IndexNo] - VATAmount[IndexNo];
            TotalPurchLine[IndexNo]."Line Amount" :=
              TotalAmount1[IndexNo] + TotalPurchLine[IndexNo]."Inv. Discount Amount";
        end else
            TotalAmount2[IndexNo] := TotalAmount1[IndexNo] + VATAmount[IndexNo];

        OnUpdateHeaderInfoAfterCalcTotalAmount(Rec);

        if "Prices Including VAT" then
            TotalPurchLineLCY[IndexNo].Amount := TotalAmount2[IndexNo]
        else
            TotalPurchLineLCY[IndexNo].Amount := TotalAmount1[IndexNo];
        if "Currency Code" <> '' then begin
            if "Posting Date" = 0D then
                UseDate := WorkDate
            else
                UseDate := "Posting Date";

            TotalPurchLineLCY[IndexNo].Amount :=
              CurrExchRate.ExchangeAmtFCYToLCY(
                UseDate, "Currency Code", TotalPurchLineLCY[IndexNo].Amount, "Currency Factor");
        end;
    end;

    local procedure GetVATSpecification(QtyType: Option General,Invoicing,Shipping)
    begin
        case QtyType of
            QtyType::General:
                begin
                    VATLinesForm.GetTempVATAmountLine(TempVATAmountLine1);
                    if TempVATAmountLine1.GetAnyLineModified then
                        UpdateHeaderInfo(1, TempVATAmountLine1);
                end;
            QtyType::Invoicing:
                begin
                    VATLinesForm.GetTempVATAmountLine(TempVATAmountLine2);
                    if TempVATAmountLine2.GetAnyLineModified then
                        UpdateHeaderInfo(2, TempVATAmountLine2);
                end;
            QtyType::Shipping:
                VATLinesForm.GetTempVATAmountLine(TempVATAmountLine3);
        end;
    end;

    local procedure UpdateTotalAmount(IndexNo: Integer)
    var
        SaveTotalAmount: Decimal;
    begin
        CheckAllowInvDisc;
        if "Prices Including VAT" then begin
            SaveTotalAmount := TotalAmount1[IndexNo];
            UpdateInvDiscAmount(IndexNo);
            TotalAmount1[IndexNo] := SaveTotalAmount;
        end;
        with TotalPurchLine[IndexNo] do
            "Inv. Discount Amount" := "Line Amount" - TotalAmount1[IndexNo];
        UpdateInvDiscAmount(IndexNo);
    end;

    local procedure UpdateInvDiscAmount(ModifiedIndexNo: Integer)
    var
        ConfirmManagement: Codeunit "Confirm Management";
        PartialInvoicing: Boolean;
        MaxIndexNo: Integer;
        IndexNo: array[2] of Integer;
        i: Integer;
        InvDiscBaseAmount: Decimal;
    begin
        CheckAllowInvDisc;
        if not (ModifiedIndexNo in [1, 2]) then
            exit;

        if InvoicedLineExists then
            if not ConfirmManagement.GetResponseOrDefault(UpdateInvDiscountQst, true) then
                Error('');

        if ModifiedIndexNo = 1 then
            InvDiscBaseAmount := TempVATAmountLine1.GetTotalInvDiscBaseAmount(false, "Currency Code")
        else
            InvDiscBaseAmount := TempVATAmountLine2.GetTotalInvDiscBaseAmount(false, "Currency Code");

        if InvDiscBaseAmount = 0 then
            Error(Text003, TempVATAmountLine2.FieldCaption("Inv. Disc. Base Amount"));

        if TotalPurchLine[ModifiedIndexNo]."Inv. Discount Amount" / InvDiscBaseAmount > 1 then
            Error(
              Text004,
              TotalPurchLine[ModifiedIndexNo].FieldCaption("Inv. Discount Amount"),
              TempVATAmountLine2.FieldCaption("Inv. Disc. Base Amount"));

        PartialInvoicing := (TotalPurchLine[1]."Line Amount" <> TotalPurchLine[2]."Line Amount");

        IndexNo[1] := ModifiedIndexNo;
        IndexNo[2] := 3 - ModifiedIndexNo;
        if (ModifiedIndexNo = 2) and PartialInvoicing then
            MaxIndexNo := 1
        else
            MaxIndexNo := 2;

        if not PartialInvoicing then
            if ModifiedIndexNo = 1 then
                TotalPurchLine[2]."Inv. Discount Amount" := TotalPurchLine[1]."Inv. Discount Amount"
            else
                TotalPurchLine[1]."Inv. Discount Amount" := TotalPurchLine[2]."Inv. Discount Amount";

        for i := 1 to MaxIndexNo do
            with TotalPurchLine[IndexNo[i]] do begin
                if (i = 1) or not PartialInvoicing then
                    if IndexNo[i] = 1 then begin
                        TempVATAmountLine1.SetInvoiceDiscountAmount(
                          "Inv. Discount Amount", "Currency Code", "Prices Including VAT", "VAT Base Discount %");
                    end else
                        TempVATAmountLine2.SetInvoiceDiscountAmount(
                          "Inv. Discount Amount", "Currency Code", "Prices Including VAT", "VAT Base Discount %");

                if (i = 2) and PartialInvoicing then
                    if IndexNo[i] = 1 then begin
                        InvDiscBaseAmount := TempVATAmountLine2.GetTotalInvDiscBaseAmount(false, "Currency Code");
                        if InvDiscBaseAmount = 0 then
                            TempVATAmountLine1.SetInvoiceDiscountPercent(
                              0, "Currency Code", "Prices Including VAT", false, "VAT Base Discount %")
                        else
                            TempVATAmountLine1.SetInvoiceDiscountPercent(
                              100 * TempVATAmountLine2.GetTotalInvDiscAmount / InvDiscBaseAmount,
                              "Currency Code", "Prices Including VAT", false, "VAT Base Discount %");
                    end else begin
                        InvDiscBaseAmount := TempVATAmountLine1.GetTotalInvDiscBaseAmount(false, "Currency Code");
                        if InvDiscBaseAmount = 0 then
                            TempVATAmountLine2.SetInvoiceDiscountPercent(
                              0, "Currency Code", "Prices Including VAT", false, "VAT Base Discount %")
                        else
                            TempVATAmountLine2.SetInvoiceDiscountPercent(
                              100 * TempVATAmountLine1.GetTotalInvDiscAmount / InvDiscBaseAmount,
                              "Currency Code", "Prices Including VAT", false, "VAT Base Discount %");
                    end;
            end;

        UpdateHeaderInfo(1, TempVATAmountLine1);
        UpdateHeaderInfo(2, TempVATAmountLine2);

        if ModifiedIndexNo = 1 then
            VATLinesForm.SetTempVATAmountLine(TempVATAmountLine1)
        else
            VATLinesForm.SetTempVATAmountLine(TempVATAmountLine2);

        "Invoice Discount Calculation" := "Invoice Discount Calculation"::Amount;
        "Invoice Discount Value" := TotalPurchLine[1]."Inv. Discount Amount";
        Modify;
        UpdateVATOnPurchLines;
    end; 

    local procedure UpdatePrepmtAmount()
    var
        TempPurchLine: Record "Purchase Line" temporary;
        PurchPostPrepmt: Codeunit "Purchase-Post Prepayments";
    begin
        PurchPostPrepmt.UpdatePrepmtAmountOnPurchLines(Rec, PrepmtTotalAmount);
        PurchPostPrepmt.GetPurchLines(Rec, 0, TempPurchLine);
        PurchPostPrepmt.SumPrepmt(
          Rec, TempPurchLine, TempVATAmountLine4, PrepmtTotalAmount, PrepmtVATAmount, PrepmtVATAmountText);
        PrepmtInvPct :=
          Pct(TotalPurchLine[1]."Prepmt. Amt. Inv.", PrepmtTotalAmount);
        PrepmtDeductedPct :=
          Pct(TotalPurchLine[1]."Prepmt Amt Deducted", TotalPurchLine[1]."Prepmt. Amt. Inv.");
        if "Prices Including VAT" then begin
            PrepmtTotalAmount2 := PrepmtTotalAmount;
            PrepmtTotalAmount := PrepmtTotalAmount + PrepmtVATAmount;
        end else
            PrepmtTotalAmount2 := PrepmtTotalAmount + PrepmtVATAmount;
        Modify;
    end;

    local procedure GetCaptionClass(FieldCaption: Text[100]; ReverseCaption: Boolean): Text[80]
    begin
        if "Prices Including VAT" xor ReverseCaption then
            exit('2,1,' + FieldCaption);

        exit('2,0,' + FieldCaption);
    end;

    procedure UpdateVATOnPurchLines()
    var
        PurchLine: Record "Purchase Line";
    begin
        GetVATSpecification(ActiveTab);
        if TempVATAmountLine1.GetAnyLineModified then
            PurchLine.UpdateVATOnLines(0, Rec, PurchLine, TempVATAmountLine1);
        if TempVATAmountLine2.GetAnyLineModified then
            PurchLine.UpdateVATOnLines(1, Rec, PurchLine, TempVATAmountLine2);
        PrevNo := '';
    end;

    local procedure VendInvDiscRecExists(InvDiscCode: Code[20]): Boolean
    var
        VendInvDisc: Record "Vendor Invoice Disc.";
    begin
        VendInvDisc.SetRange(Code, InvDiscCode);
        exit(VendInvDisc.FindFirst);
    end;

    local procedure CheckAllowInvDisc()
    var
        VendInvDisc: Record "Vendor Invoice Disc.";
    begin
        if not AllowInvDisc then
            Error(
              Text005,
              VendInvDisc.TableCaption, FieldCaption("Invoice Disc. Code"), "Invoice Disc. Code");
    end;

    local procedure Pct(Numerator: Decimal; Denominator: Decimal): Decimal
    begin
        if Denominator = 0 then
            exit(0);
        exit(Round(Numerator / Denominator * 10000, 1));
    end;

    local procedure VATLinesDrillDown(var VATLinesToDrillDown: Record "VAT Amount Line"; ThisTabAllowsVATEditing: Boolean)
    begin
        Clear(VATLinesForm);
        VATLinesForm.SetTempVATAmountLine(VATLinesToDrillDown);
        VATLinesForm.InitGlobals(
          "Currency Code", AllowVATDifference, AllowVATDifference and ThisTabAllowsVATEditing,
          "Prices Including VAT", AllowInvDisc, "VAT Base Discount %");
        VATLinesForm.GetTempVATAmountLine(VATLinesToDrillDown);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnOpenPageOnBeforeSetEditable(var AllowInvDisc: Boolean; var AllowVATDifference: Boolean; PurchaseHeader: Record "Purchase Header")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeValidatePrepmtTotalAmount2(PurchaseHeader: Record "Purchase Header"; var PrepmtTotalAmount: Decimal; var PrepmtTotalAmount2: Decimal)
    begin
    end;

    [IntegrationEvent(true, false)]
    local procedure OnRefreshOnAfterGetRecordAfterSumPurchLinesTemp(var TempPurchLine: Record "Purchase Line"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(true, false)]
    local procedure OnUpdateHeaderInfoAfterCalcTotalAmount(var PurchaseHeader: Record "Purchase Header")
    begin
    end; */

}
