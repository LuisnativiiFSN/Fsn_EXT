pageextension 50014 PageExtension50014 extends "Purch. Invoice Subform"
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
        addafter("Shortcut Dimension 2 Code")
        {
            field("VAT Prod. Posting Group17197"; Rec."VAT Prod. Posting Group")
            {
                ApplicationArea = All;
            }
            field("VAT Bus. Posting Group"; Rec."VAT Bus. Posting Group")
            {
                ApplicationArea = All;
            }
            field("Gen. Bus. Posting Group94815"; Rec."Gen. Bus. Posting Group")
            {
                ApplicationArea = All;
            }
            field("Gen. Prod. Posting Group19336"; Rec."Gen. Prod. Posting Group")
            {
                ApplicationArea = All;
            }
        }
        modify("Shortcut Dimension 2 Code")
        {
            Visible = false;
        }
    }
}
