pageextension 50124 PageExtension50021 extends "Purch. Cr. Memo Subform"
{
    layout
    {
        modify(Type)
        {
            Width = 10;
        }
        modify("Tax Area Code")
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
        addafter("Line Discount Amount")
        {
            field("VAT Prod. Posting Group91974"; Rec."VAT Prod. Posting Group")
            {
                ApplicationArea = All;
            }
        }

    }
}
