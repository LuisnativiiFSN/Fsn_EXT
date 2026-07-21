pageextension 50013 PageExtension50013 extends "Posted Sales Cr. Memo Subform"
{
    layout
    {
        modify("Tax Area Code")
        {
            Visible = false;
        }
        modify("Return Reason Code")
        {
            Visible = false;
        }
        modify("Tax Group Code")
        {
            Visible = false;
        }
        modify("Shortcut Dimension 2 Code")
        {
            Visible = false;
        }
        modify("Deferral Code")
        {
            Visible = false;
        }
        moveafter("Unit Cost (LCY)"; "Line Discount %")
        addafter("Shortcut Dimension 1 Code")
        {
            field("VAT Prod. Posting Group50127"; Rec."VAT Prod. Posting Group")
            {
                ApplicationArea = All;
            }
        }
    }
}
