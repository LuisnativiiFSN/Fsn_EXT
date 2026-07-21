/// <summary>
/// Page FSN DTE Transaction Header (ID 50090).
/// </summary>
page 50090 "FSN DTE Transaction Header"
{
    Caption = 'FSN DTE Transaction Register';
    PageType = List;
    SourceTable = "FSN DTE Transaction Header";
    UsageCategory = Administration;
    ApplicationArea = all;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Store No."; "Store No.")
                {
                    ApplicationArea = All;

                }
                field("POS Terminal No."; "POS Terminal No.")
                {
                    ApplicationArea = All;

                }
                field("Transaction No."; "Transaction No.")
                {
                    ApplicationArea = All;

                }
                field("DTE AuthNumber"; "DTE AuthNumber")
                {
                    ApplicationArea = All;

                }
                field("IS ANULLED"; Status)
                {
                    ApplicationArea = All;

                }
                field("Created Date"; "Creating Date")
                {
                    ApplicationArea = All;

                }
                field("Replication Counter"; "Replication Counter")
                {
                    ApplicationArea = All;

                }
                field("Document Type"; "Document Type")
                {
                    ApplicationArea = All;

                }
                field("Signature Validation"; "Signature Validation")
                {
                    ApplicationArea = All;
                }
                field("DTE Invoice"; "DTE Invoice")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ActionName)
            {
                ApplicationArea = All;

                trigger OnAction()
                begin

                end;
            }
        }
    }

    var
        myInt: Integer;
}