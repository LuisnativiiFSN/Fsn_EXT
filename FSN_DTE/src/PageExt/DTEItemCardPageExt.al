pageextension 50042 "FSN DTE ItemCardExt" extends "LSC Retail Item Card"
{
    layout
    {
        addafter(General)
        {
            group("DTE")
            {
                field("DTE SuggestedSalePrice"; "DTE SuggestedSalePrice")
                {
                    ApplicationArea = all;
                }
                field("DTE Unit Of Measure"; "DTE Unit Of Measure")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
    }
}