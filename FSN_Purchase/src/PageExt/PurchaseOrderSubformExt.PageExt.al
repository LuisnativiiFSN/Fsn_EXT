pageextension 50130 "Purchase Order Subform Ext" extends "Purchase Order Subform"
{
    layout
    {
        addafter("VAT Prod. Posting Group")
        {
            field("Gen. Bus. Posting Group"; "Gen. Bus. Posting Group")
            {

            }
            field("Gen. Prod. Posting Group"; "Gen. Prod. Posting Group")
            {
            }
        }
        addafter(Control43)
        {
            group(Invoicing)
            {
                Caption = 'Detail Invoicing';
                field("Total Amount Excl. VAT Inv"; TotalPurchLineInv.Amount)
                {
                    ApplicationArea = Suite;
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
                    ApplicationArea = Suite;
                    AutoFormatExpression = Currency.Code;
                    AutoFormatType = 1;
                    CaptionClass = DocumentTotals.GetTotalVATCaption(Currency.Code);
                    Caption = 'Total VAT';
                    Editable = false;
                    ToolTip = 'Specifies the sum of VAT amounts on all lines in the document.';
                }
                field("Total Amount Incl. VAT Inv"; TotalPurchLineInv."Amount Including VAT")
                {
                    ApplicationArea = Suite;
                    AutoFormatExpression = Currency.Code;
                    AutoFormatType = 1;
                    CaptionClass = DocumentTotals.GetTotalInclVATCaption(Currency.Code);
                    Caption = 'Total Amount Incl. VAT';
                    Editable = false;
                    ToolTip = 'Specifies the sum of the value in the Line Amount Incl. VAT field on all lines in the document minus any discount amount in the Invoice Discount Amount field.';
                }
            }
        }


    }
    actions
    {
        addafter(BlanketOrder)
        {
            action(PurchaseLinesToInvoice)
            {
                ApplicationArea = Suite;
                Caption = 'Purchase Lines To Invoice';
                Image = BlanketOrder;
                ToolTip = 'View purchase Lines To Invoice';
                trigger OnAction()
                begin
                    Rec.SetFilter("Qty. to Invoice", '>0');
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        TotalPurchLineInv: Record "Purchase Line";
        TotalPurchLineLCYInv: Record "Purchase Line";
        VATAmountTextInv: Text[30];
        VATAmountInv: Decimal;
        Currency: Record Currency;
        DocumentTotals: Codeunit "Document Totals";

    trigger OnAfterGetRecord()
    begin

    end;

    trigger OnAfterGetCurrRecord()
    begin
        Currency.InitRoundingPrecision();
        CalculateTotalsInv();
    end;

    procedure CalculateTotalsInv()
    var
        PurchPost: Codeunit "Purch.-Post";
        TempPurchLine: Record "Purchase Line" temporary;
        PurchaseHeader: Record "Purchase Header";
    begin
        if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, Rec."Document No.") then begin
            Clear(TempPurchLine);
            Clear(PurchPost);
            PurchPost.GetPurchLines(PurchaseHeader, TempPurchLine, 1);
            Clear(PurchPost);
            PurchPost.SumPurchLinesTemp(PurchaseHeader, TempPurchLine, 1, TotalPurchLineInv, TotalPurchLineLCYInv, VATAmountInv, VATAmountTextInv);
        end;
    end;

}