pageextension 50040 "FSN DTE CustomerCardExt" extends "LSC Retail Customer Card"
{
    layout
    {

        addafter(General)
        {
            group("DTE")
            {
                field("DTE Tax ID Type"; "DTE Tax ID Type")
                {
                    ApplicationArea = all;
                    Caption = 'DTE Tax ID Type';
                }

                field("DTE Activity Code"; "DTE Activity Code")
                {
                    ApplicationArea = all;
                    Caption = 'DTE Activity Code';
                    trigger OnLookup(var Text: Text): Boolean
                    var
                        DTEActive: Record "DTE Parameter";
                    begin
                        if "DTE Activity Code" <> '' then
                            DTEActive.Get("DTE Activity Code");
                        if Page.RunModal(Page::"DTE Active", DTEActive) = Action::LookupOK then
                            Validate("DTE Activity Code", DTEActive."Code");
                    end;
                }

                field("DTE Active Description"; "DTE Active Description")
                {
                    ApplicationArea = all;
                    Caption = 'DTE Active Description';
                }
            }
        }
    }

    actions
    {
    }
}