pageextension 50046 "FSN DTE Post Code Page Ext" extends "Post Codes"
{

    layout
    {
        addafter("County")
        {

            field("DTE District"; "DTE District")
            {
                ApplicationArea = all;
            }
            field("DTE State"; "DTE State")
            {
                ApplicationArea = all;
            }

        }
    }
}