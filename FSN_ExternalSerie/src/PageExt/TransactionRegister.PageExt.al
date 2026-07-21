pageextension 50009 "FSN Transaction Register Ext" extends "LSC Transaction Register"
{
    layout
    {
        // Add changes to page layout here
        addafter("Customer No.")
        {
            field("FSN No. Serie NCF"; Rec."FSN No. Serie NCF")
            {
                ApplicationArea = All;
            }

            field("FSN NCF"; Rec."FSN NCF")
            {
                ApplicationArea = All;
            }

            field("Document Type"; Rec."FSN Document Type")
            {
                ApplicationArea = All;
            }

            field("Fiscal Serie"; Rec."FSN Fiscal Serie")
            {
                ApplicationArea = All;
            }

            field("Resolution"; Rec."FSN Resolution")
            {
                ApplicationArea = All;
            }

        }
    }

    actions
    {
        // Add changes to page actions here

    }

}