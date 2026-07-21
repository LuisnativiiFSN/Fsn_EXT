pageextension 50162 "FSN DTE Trans. Header Ext" extends "LSC Transaction Register"
{

    layout
    {
        addafter("Transaction Type")
        {

            field("DTE Tax ID Type"; "DTE Tax ID Type")
            {
                ApplicationArea = all;
            }
        }
    }
}