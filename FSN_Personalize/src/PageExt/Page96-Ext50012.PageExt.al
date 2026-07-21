pageextension 50012 PageExtension50012 extends "Sales Cr. Memo Subform"
{
    layout
    {
        modify("Tax Area Code")
        {
            Visible = false;
        }
        modify("Tax Group Code")
        {
            Visible = false;
        }
        moveafter("Unit of Measure Code"; "Line Discount %")
        modify("Shortcut Dimension 2 Code")
        {
            Visible = false;
        }
        modify("Qty. to Assign")
        {
            Visible = false;
        }
        modify("Qty. Assigned")
        {
            Visible = false;
        }
        addafter("Amount Including VAT")
        {
            field("VAT Prod. Posting Group67506"; Rec."VAT Prod. Posting Group")
            {
                ApplicationArea = All;
            }
            field("Gen. Prod. Posting Group"; Rec."Gen. Prod. Posting Group")
            {
                ApplicationArea = All;
            }
        }
        moveafter("Amount Including VAT"; "Shortcut Dimension 1 Code")
    }
}
