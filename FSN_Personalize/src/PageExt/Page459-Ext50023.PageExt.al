pageextension 50168 PageExtension50023 extends "Sales & Receivables Setup"
{
    layout
    {
        addafter("Direct Debit Mandate Nos.")
        {
            field("FSN PITS Sales Nos.91943"; Rec."FSN PITS Sales Nos.")
            {
                ApplicationArea = All;
            }
        }
    }
}
