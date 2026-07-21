pageextension 50015 PageExtension50015 extends "LSC Store Card"
{
    layout
    {
        addafter("Location Code")
        {
            field("Global Dimension 1 Code68335";Rec."Global Dimension 1 Code")
            {
                ApplicationArea = All;
            }
            field("Global Dimension 2 Code87291";Rec."Global Dimension 2 Code")
            {
                ApplicationArea = All;
            }
        }
    }
}
