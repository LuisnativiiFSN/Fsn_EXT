pageextension 50155 "FSN Purchase Invoices" extends "Purchase Invoices"
{
    layout
    {
        addafter(Amount)
        {
            field("Amount incl. VAT"; "Amount including VAT")
            {
                ApplicationArea = All;
                Caption = 'Amount incl. VAT';
                ToolTip = 'The total amount of the invoice, including VAT.';
            }
        }
    }
}