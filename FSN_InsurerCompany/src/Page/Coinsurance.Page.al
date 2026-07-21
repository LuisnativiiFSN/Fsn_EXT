page 50023 "FSN Coinsurance"
{
    // WVILLALTA23SEPT19           - New page

    Caption = 'Coinsurance';
    PageType = List;
    SourceTable = "FSN Coinsurance";
    ApplicationArea = all;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("No."; "No.")
                {
                }
                field(Description; Description)
                {
                }
                field("Percent Benefit"; "Percent Benefit")
                {
                }
                field("Mail Address"; "Mail Address")
                {
                }
                field("Customer Filter"; "Customer Filter")
                {
                }
            }
        }
    }

    actions
    {
    }
}

