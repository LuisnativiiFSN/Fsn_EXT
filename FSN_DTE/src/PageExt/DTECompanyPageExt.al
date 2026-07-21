pageextension 50165 "Company Information Ext" extends "Company Information"
{
    layout
    {
        addafter(General)
        {
            group("FSN")
            {
                field("DTE Active Code"; "DTE Active Code")
                {
                    ApplicationArea = all;
                    trigger OnLookup(var Text: Text): Boolean
                    var
                        DTEActive: Record "DTE Parameter";
                    begin
                        if "DTE Active Code" <> '' then
                            DTEActive.Get("DTE Active Code");
                        if Page.RunModal(Page::"DTE Active", DTEActive) = Action::LookupOK then
                            Validate("DTE Active Code", DTEActive."Code");
                    end;
                }

                field("DTE Active Description"; "DTE Active Description")
                {
                    ApplicationArea = all;
                }
            }
        }
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        myInt: Integer;
}