page 50028 "FSN Insured Card"
{
    // WVILLALTA23SEPT19           -  New page

    Caption = 'Insured Card';
    PageType = Card;
    SourceTable = "FSN Insured Links";
    ApplicationArea = all;
    UsageCategory = Documents;

    layout
    {
        area(content)
        {
            group(General)
            {
                field("Company No."; "Company No.")
                {
                }
                field(Card; Card)
                {
                }
                field("Customer No."; "Customer No.")
                {
                    DrillDownPageID = "FSN Customers Select";
                    LookupPageID = "FSN Customers Select";
                }
                field(Name; Name)
                {
                }
                field(Relation; Relation)
                {
                }
                field("Parent Card"; "Parent Card")
                {
                }
                field(Email; Email)
                {
                }
                field(Inactive; Inactive)
                {
                    Editable = false;
                }
            }
        }
    }

    actions
    {
    }
}

