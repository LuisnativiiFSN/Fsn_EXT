pageextension 50029 PageExtension50029 extends "Sales Invoice Subform"
{
    layout
    {
        modify("Tax Area Code")
        {
            Visible = false;
        }
        modify("Qty. to Assign")
        {
            Visible = false;
        }
        modify("Shortcut Dimension 2 Code")
        {
            Visible = false;
        }
        addafter("Shortcut Dimension 1 Code")
        {
            field("VAT Prod. Posting Group36093"; Rec."VAT Prod. Posting Group")
            {
                ApplicationArea = All;
            }
        }
        modify("Tax Group Code")
        {
            Visible = false;
        }
    }
}
