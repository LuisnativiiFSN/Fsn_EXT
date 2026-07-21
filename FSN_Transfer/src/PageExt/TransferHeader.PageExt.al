pageextension 50064 "FSN Transfer Header" extends "Transfer Order"
{
    layout
    {
        addafter(Status)
        {
            field("ExternalDocument No."; "External Document No.")
            {
                ApplicationArea = All;
                Editable = true;
                Caption = 'Nº documento externo';
                ToolTip = 'Nº documento externo';
            }
        }
    }
}