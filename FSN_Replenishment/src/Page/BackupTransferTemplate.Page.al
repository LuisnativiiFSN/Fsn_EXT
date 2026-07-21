page 50047 "FSN Backorder Template"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FSN BackOrder Transfer Line";
    Caption = 'Backorder Template';
    layout
    {
        area(Content)
        {
            repeater("Backup Replen. Template")
            {
                field("Item No."; "Item No.")
                {
                    ApplicationArea = All;
                }
                field("Variant Code"; "Variant Code")
                {
                    ApplicationArea = all;
                }
                field(Description; Description)
                {
                    ApplicationArea = All;
                }
                field("Location Code"; "Location Code")
                {
                    ApplicationArea = All;
                }
                field("Location Name"; "Location Name")
                {
                    ApplicationArea = all;
                }
                field("System Suggested Quantity"; "System Suggested Quantity")
                {
                    ApplicationArea = all;
                }
                field(Quantity; Quantity)
                {
                    ApplicationArea = all;
                }
                field("Calculation Type"; "Calculation Type")
                {
                    ApplicationArea = all;
                }
                field("Effective Inventory"; "Effective Inventory")
                {
                    ApplicationArea = all;
                }
                field("Average Daily Sales"; "Average Daily Sales")
                {
                    ApplicationArea = all;
                }
                field(Decision; Decision)
                {
                    ApplicationArea = all;
                }
                field("Vendor Name"; "Vendor Name")
                {
                    ApplicationArea = all;
                }
                field("Warehouse Effective Inventory"; "Warehouse Effective Inventory")
                {
                    ApplicationArea = all;
                }
                field(Multiple; Multiple)
                {
                    ApplicationArea = all;
                }
                field(Date; Date)
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

}