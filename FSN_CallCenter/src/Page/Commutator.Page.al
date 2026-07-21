page 50049 "FSN Commutator"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FSN Commutator";

    layout
    {
        area(Content)
        {
            repeater(Commutator)
            {
                field("Host Name"; "Host Name")
                {
                    ApplicationArea = All;
                }
                field(Extension; Extension)
                {
                    ApplicationArea = All;
                }
                field(Description; Description)
                {
                    ApplicationArea = All;
                }
                field(StaffID; StaffID)
                {
                    ApplicationArea = All;
                }
                field(Fecha; Date)
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
}