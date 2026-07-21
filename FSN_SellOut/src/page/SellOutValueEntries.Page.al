/*page 50056 "FSN Sell Out Value Entries"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FSN Sell Out Value Entry";
    Editable = false;
    layout
    {
        area(Content)
        {
            repeater("Sell Out")
            {
                field("Transaction No."; "Transaction No.")
                {
                    ApplicationArea = All;
                }
                field("Store No."; "Store No.")
                {
                    ApplicationArea = All;
                }
                field("POS Terminal No."; "POS Terminal No.")
                {
                    ApplicationArea = All;
                }
                field("Receipt No."; "Receipt No.")
                {
                    ApplicationArea = All;
                }
                field("Offer No."; "Offer No.")
                {
                    ApplicationArea = All;
                }
                field("Offer Type"; "Offer Type")
                {
                    ApplicationArea = All;
                }
                field("Item No."; "Item No.")
                {
                    ApplicationArea = All;
                }

                field("Sell Out Amount"; "Sell Out Amount")
                {
                    ApplicationArea = all;
                }
                field("Sell Out Type"; "Sell Out Type")
                {
                    ApplicationArea = all;
                }
                field("Value Sell Out"; "Value Sell Out")
                {
                    ApplicationArea = all;
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
}*/