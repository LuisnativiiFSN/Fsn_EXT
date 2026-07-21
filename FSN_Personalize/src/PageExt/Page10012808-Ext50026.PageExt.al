pageextension 50026 PageExtension50026 extends "LSC Retail Receiving List"
{
    layout
    {
        addafter("Location Code")
        {
            field("Vendor Invoice No.70478";Rec."Vendor Invoice No.")
            {
                ApplicationArea = All;
            }
        }
    }
}
