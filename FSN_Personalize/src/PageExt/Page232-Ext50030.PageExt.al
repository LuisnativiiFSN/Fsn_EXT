pageextension 50030 PageExtension50030 extends "Apply Customer Entries"
{
    layout
    {
        addafter(AppliesToID)
        {
            field("Applies-to ID85483"; Rec."Applies-to ID")
            {
                ApplicationArea = All;
            }
        }
        addafter("Document No.")
        {
            field("External Document No.25304"; Rec."External Document No.")
            {
                ApplicationArea = All;
            }
        }
    }
}
