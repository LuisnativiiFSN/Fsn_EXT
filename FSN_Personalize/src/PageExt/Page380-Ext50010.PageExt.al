pageextension 50010 PageExtension50010 extends "Bank Acc. Reconciliation Lines"
{
    layout
    {
        addafter("Transaction Date")
        {
            field("Additional Transaction Info52997";Rec."Additional Transaction Info")
            {
                ApplicationArea = All;
            }
            field("Document No.60432";Rec."Document No.")
            {
                ApplicationArea = All;
            }
            field("Check No.25861";Rec."Check No.")
            {
                ApplicationArea = All;
            }
            field(Description36798;Rec.Description)
            {
                ApplicationArea = All;
            }
        }
        modify(Description)
        {
        Visible = false;
        }
        modify("Statement Amount")
        {
        Visible = false;
        }
        modify(Difference)
        {
        Visible = false;
        }
        modify("Applied Amount")
        {
        Visible = false;
        }
        addafter(Type)
        {
            field("Statement Amount50218";Rec."Statement Amount")
            {
                ApplicationArea = All;
            }
            field("Applied Amount70016";Rec."Applied Amount")
            {
                ApplicationArea = All;
            }
            field(Difference46822;Rec.Difference)
            {
                ApplicationArea = All;
            }
        }
    }
}
