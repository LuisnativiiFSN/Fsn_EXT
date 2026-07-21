page 50040 "FSN POS Exchange Setup"
{

    Caption = 'FSN POS Exchange Setup';
    PageType = List;
    SourceTable = "FSN POS Exchange Setup";
    ApplicationArea = All;
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
                field("POS Exchange Code"; "POS Exchange Code")
                {
                }
                field(Description; Description)
                {
                }
                field("Quantity Sale"; "Quantity Sale")
                {
                }
                field("Quantity Gift"; "Quantity Gift")
                {
                }
                field("Control Type"; "Control Type")
                {
                }
                field("Authorization Type"; "Authorization Type")
                {
                }
                field("Type Recovery"; "Type Recovery")
                {
                }
                field("Starting Date"; "Starting Date")
                {
                }
                field("Ending Date"; "Ending Date")
                {
                }
                field("Print Setup ID"; "Print Setup ID")
                {
                }
                field("Print Require ID"; "Print Require ID")
                {
                }
                field("Cust. Disc. Group Filter"; "Cust. Disc. Group Filter")
                {
                }
                field("Official Page Url"; "Official Page Url")
                {
                }
                field("Use Inventory"; "Use Inventory")
                {
                    Caption = 'Use Inventory';
                    //Editable = false;
                }
                field("Item Journal Template"; "Item Journal Template")
                {
                }
                field("Transfer-to Code"; "Transfer-to Code")
                {
                }
                field(Coupon; Coupon)
                {
                }
            }
        }
    }

    actions
    {
    }
}

