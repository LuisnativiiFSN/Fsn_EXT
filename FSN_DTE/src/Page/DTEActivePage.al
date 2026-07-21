page 50091 "DTE Active"
{
    Caption = 'FSN DTE Active';
    PageType = List;
    SourceTable = "DTE Parameter";
    UsageCategory = Administration;
    ApplicationArea = all;
    Editable = true;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Type"; "Type")
                {
                    ApplicationArea = All;

                }
                field("DTE Active Code"; "Code")
                {
                    ApplicationArea = All;

                }

                field("DTE Active Description"; "Description")
                {
                    ApplicationArea = All;

                }
            }
        }
    }

    actions
    {
        /*area(Processing)
        {
            action(ActionName)
            {
                ApplicationArea = All;

                trigger OnAction()
                begin

                end;
            }
        }*/
    }

    var
        myInt: Integer;
}