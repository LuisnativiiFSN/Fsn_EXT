pageextension 50166 "FSN Document Type Card PageExt" extends "Document Sub Type Card"
{
    layout
    {
        addafter(Group)
        {
            group("DTE")
            {
                field("DTE Serie No"; "DTE Serie No")
                {
                    ApplicationArea = all;
                    Caption = 'Serie DTE';
                }

                field("DTE Certify"; "DTE Certify")
                {
                    ApplicationArea = all;
                    Caption = 'Certificar DTE';
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