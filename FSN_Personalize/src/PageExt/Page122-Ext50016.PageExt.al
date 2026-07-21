pageextension 50016 PageExtension50016 extends "G/L Entries Preview"
{
    layout
    {
        addafter("Gen. Posting Type")
        {
            field("G/L Account No.31595";Rec."G/L Account No.")
            {
                ApplicationArea = All;
            }
        }
        addafter("Bal. Account No.")
        {
            field("Document Date48787";Rec."Document Date")
            {
                ApplicationArea = All;
            }
            field("User ID92527";Rec."User ID")
            {
                ApplicationArea = All;
            }
        }
    }
}
