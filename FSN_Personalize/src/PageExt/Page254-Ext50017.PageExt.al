pageextension 50017 PageExtension50017 extends "Purchase Journal"
{
    layout
    {
        addafter(Amount)
        {
            field("Debit Amount14106";Rec."Debit Amount")
            {
                ApplicationArea = All;
            }
        }
        addafter("External Document No.")
        {
            field("Credit Amount83579";Rec."Credit Amount")
            {
                ApplicationArea = All;
            }
        }
        addafter("Account Type")
        {
            field("Debit Amount65638";Rec."Debit Amount")
            {
                ApplicationArea = All;
            }
        }
    }
}
